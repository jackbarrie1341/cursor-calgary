import cors from "cors";
import express from "express";
import helmet from "helmet";
import { eq } from "drizzle-orm";
import { CountryCode, Products } from "plaid";
import { z } from "zod";
import { requireAuth, type AuthenticatedRequest } from "./auth.js";
import { calculateDailyAllowanceCents, localDateString, monthStartForDateString } from "./buddy/engine.js";
import { env } from "./config/env.js";
import { db, pool } from "./db/client.js";
import { buddyStates, plaidItems, profiles } from "./db/schema.js";
import { plaidClient } from "./plaid/client.js";
import { getBuddyPayload, recomputeBuddyState } from "./services/buddyService.js";
import { ensureSeededOwnedHats, getHatsPayload, HatOwnershipError, setEquippedHat } from "./services/hatsService.js";
import { syncPlaidItem, syncPlaidItemByPlaidItemId } from "./services/transactionSync.js";

const onboardingSchema = z.object({
  monthlyIncomeCents: z.number().int().nonnegative(),
  monthlyBudgetCents: z.number().int().positive(),
  buddyName: z.string().trim().min(1).max(40).optional(),
  displayName: z.string().trim().min(1).max(80).optional(),
  username: z.string().trim().min(3).max(20).regex(/^[a-zA-Z0-9_]+$/)
});

const exchangeSchema = z.object({
  publicToken: z.string().min(1)
});

const friendSearchSchema = z.object({
  q: z.string().trim().min(1).max(32)
});

const addFriendSchema = z.object({
  username: z.string().trim().min(3).max(20).regex(/^[a-zA-Z0-9_]+$/)
});

const colorSchema = z.object({
  catFillHue: z.number().min(0).max(1),
  catFillSaturation: z.number().min(0).max(1),
  catFillBrightness: z.number().min(0).max(1)
});

const equippedHatSchema = z.object({
  hatId: z.string().uuid().nullable().optional()
});

export const app = express();

app.use(helmet());
app.use(cors());
app.use(express.json({ limit: "1mb" }));

app.get("/health", (_req, res) => {
  res.json({ ok: true });
});

app.post("/onboarding", requireAuth, async (req, res, next) => {
  try {
    const authReq = req as AuthenticatedRequest;
    const input = onboardingSchema.parse(req.body);
    const dailyAllowanceCents = calculateDailyAllowanceCents(input.monthlyBudgetCents);

    await db
      .insert(profiles)
      .values({
        userId: authReq.userId,
        monthlyIncomeCents: input.monthlyIncomeCents,
        monthlyBudgetCents: input.monthlyBudgetCents,
        dailyAllowanceCents,
        displayName: input.displayName ?? "",
        username: input.username?.toLowerCase(),
        buddyName: input.buddyName ?? "Buddy"
      })
      .onConflictDoUpdate({
        target: profiles.userId,
        set: {
          monthlyIncomeCents: input.monthlyIncomeCents,
          monthlyBudgetCents: input.monthlyBudgetCents,
          dailyAllowanceCents,
          displayName: input.displayName ?? "",
          username: input.username?.toLowerCase(),
          buddyName: input.buddyName ?? "Buddy",
          updatedAt: new Date()
        }
      });

    await db
      .insert(buddyStates)
      .values({
        userId: authReq.userId,
        mood: "happy",
        spentTodayCents: 0,
        dailyAllowanceCents,
        streak: 1,
        stateDate: localDateString(new Date(), env.APP_TIME_ZONE)
      })
      .onConflictDoNothing();

    await ensureSeededOwnedHats(authReq.userId);

    res.json(await recomputeBuddyState(authReq.userId));
  } catch (error) {
    next(error);
  }
});

app.post("/plaid/create_link_token", requireAuth, async (req, res, next) => {
  try {
    const authReq = req as AuthenticatedRequest;
    const products = env.PLAID_PRODUCTS.split(",").map((product) => product.trim()) as Products[];
    const countryCodes = env.PLAID_COUNTRY_CODES.split(",").map((code) => code.trim()) as CountryCode[];

    const response = await plaidClient.linkTokenCreate({
      user: {
        client_user_id: authReq.userId
      },
      client_name: "Finance Buddy",
      products,
      country_codes: countryCodes,
      language: "en",
      webhook: `${env.PUBLIC_BASE_URL}/webhook`,
      transactions: {
        days_requested: 30
      }
    });

    res.json({ linkToken: response.data.link_token });
  } catch (error) {
    next(error);
  }
});

app.post("/plaid/exchange_public_token", requireAuth, async (req, res, next) => {
  try {
    const authReq = req as AuthenticatedRequest;
    const input = exchangeSchema.parse(req.body);
    const exchange = await plaidClient.itemPublicTokenExchange({
      public_token: input.publicToken
    });

    const [item] = await db
      .insert(plaidItems)
      .values({
        userId: authReq.userId,
        plaidItemId: exchange.data.item_id,
        accessToken: exchange.data.access_token
      })
      .onConflictDoUpdate({
        target: plaidItems.plaidItemId,
        set: {
          userId: authReq.userId,
          accessToken: exchange.data.access_token,
          updatedAt: new Date()
        }
      })
      .returning();

    const buddy = await syncPlaidItem(item.id);
    res.json(buddy);
  } catch (error) {
    next(error);
  }
});

app.post("/webhook", async (req, res, next) => {
  try {
    if (req.body?.webhook_type === "TRANSACTIONS" && req.body?.webhook_code === "SYNC_UPDATES_AVAILABLE") {
      const plaidItemId = req.body.item_id;
      if (typeof plaidItemId === "string") {
        await syncPlaidItemByPlaidItemId(plaidItemId);
      }
    }

    res.json({ received: true });
  } catch (error) {
    next(error);
  }
});

app.post("/transactions/refresh", requireAuth, async (req, res, next) => {
  try {
    const authReq = req as AuthenticatedRequest;
    const [item] = await db.select().from(plaidItems).where(eq(plaidItems.userId, authReq.userId)).limit(1);
    if (!item) {
      res.status(409).json({ error: "no_linked_item" });
      return;
    }

    await plaidClient.transactionsRefresh({
      access_token: item.accessToken
    });

    res.json({ ok: true });
  } catch (error) {
    next(error);
  }
});

app.get("/spending", requireAuth, async (req, res, next) => {
  try {
    const authReq = req as AuthenticatedRequest;
    const today = localDateString(new Date(), env.APP_TIME_ZONE);
    const monthStart = monthStartForDateString(today);

    const transactionsResult = await pool.query(
      `
        select
          id,
          coalesce(merchant_name, name) as name,
          amount_cents as "amountCents",
          coalesce(authorized_date, posted_date)::text as date,
          pending
        from transactions
        where user_id = $1
          and removed = false
          and amount_cents > 0
        order by coalesce(authorized_date, posted_date) desc, created_at desc
        limit 50
      `,
      [authReq.userId]
    );

    const breakdownResult = await pool.query(
      `
        select
          coalesce(merchant_name, name) as name,
          sum(amount_cents)::int as "totalCents",
          count(*)::int as count,
          max(coalesce(authorized_date, posted_date))::text as "lastDate"
        from transactions
        where user_id = $1
          and removed = false
          and amount_cents > 0
          and coalesce(authorized_date, posted_date) >= $2
          and coalesce(authorized_date, posted_date) <= $3
        group by coalesce(merchant_name, name)
        order by sum(amount_cents) desc
        limit 10
      `,
      [authReq.userId, monthStart, today]
    );

    const totalResult = await pool.query(
      `
        select coalesce(sum(amount_cents), 0)::int as "monthTotalCents"
        from transactions
        where user_id = $1
          and removed = false
          and amount_cents > 0
          and coalesce(authorized_date, posted_date) >= $2
          and coalesce(authorized_date, posted_date) <= $3
      `,
      [authReq.userId, monthStart, today]
    );

    res.json({
      asOfDate: today,
      monthStartDate: monthStart,
      monthTotalCents: totalResult.rows[0]?.monthTotalCents ?? 0,
      transactions: transactionsResult.rows,
      monthlyBreakdown: breakdownResult.rows
    });
  } catch (error) {
    next(error);
  }
});

app.get("/buddy", requireAuth, async (req, res, next) => {
  try {
    const authReq = req as AuthenticatedRequest;
    res.json(await getBuddyPayload(authReq.userId));
  } catch (error) {
    next(error);
  }
});

app.patch("/profile/color", requireAuth, async (req, res, next) => {
  try {
    const authReq = req as AuthenticatedRequest;
    const input = colorSchema.parse(req.body);

    await db
      .update(profiles)
      .set({
        catFillHue: Math.round(input.catFillHue * 100),
        catFillSaturation: Math.round(input.catFillSaturation * 100),
        catFillBrightness: Math.round(input.catFillBrightness * 100),
        updatedAt: new Date()
      })
      .where(eq(profiles.userId, authReq.userId));

    res.json(await getBuddyPayload(authReq.userId));
  } catch (error) {
    next(error);
  }
});

app.get("/hats", requireAuth, async (req, res, next) => {
  try {
    const authReq = req as AuthenticatedRequest;
    res.json(await getHatsPayload(authReq.userId));
  } catch (error) {
    next(error);
  }
});

app.patch("/hats/equipped", requireAuth, async (req, res, next) => {
  try {
    const authReq = req as AuthenticatedRequest;
    const input = equippedHatSchema.parse(req.body);
    const hatId = input.hatId ?? null;
    res.json(await setEquippedHat(authReq.userId, hatId));
  } catch (error) {
    next(error);
  }
});

app.get("/friends", requireAuth, async (req, res, next) => {
  try {
    const authReq = req as AuthenticatedRequest;
    const result = await pool.query(
      `
        select
          p.user_id as "userId",
          p.username,
          p.display_name as "displayName",
          p.buddy_name as "buddyName",
          (p.cat_fill_hue::float / 100) as "catFillHue",
          (p.cat_fill_saturation::float / 100) as "catFillSaturation",
          (p.cat_fill_brightness::float / 100) as "catFillBrightness",
          coalesce(bs.mood::text, 'happy') as mood,
          coalesce(bs.streak, 0) as streak,
          hc.asset_key as "hatAssetKey",
          hc.symbol_name as "hatSymbolName"
        from friendships f
        join profiles p on p.user_id = f.friend_user_id
        left join buddy_states bs on bs.user_id = p.user_id
        left join hat_catalog hc on hc.id = p.equipped_hat_id and hc.is_active = true
        where f.user_id = $1
        order by f.created_at desc
      `,
      [authReq.userId]
    );

    res.json({ friends: result.rows });
  } catch (error) {
    next(error);
  }
});

app.get("/friends/search", requireAuth, async (req, res, next) => {
  try {
    const authReq = req as AuthenticatedRequest;
    const input = friendSearchSchema.parse(req.query);
    const query = input.q.toLowerCase();
    const result = await pool.query(
      `
        select
          p.user_id as "userId",
          p.username,
          p.display_name as "displayName",
          p.buddy_name as "buddyName",
          (p.cat_fill_hue::float / 100) as "catFillHue",
          (p.cat_fill_saturation::float / 100) as "catFillSaturation",
          (p.cat_fill_brightness::float / 100) as "catFillBrightness",
          coalesce(bs.mood::text, 'happy') as mood,
          coalesce(bs.streak, 0) as streak,
          hc.asset_key as "hatAssetKey",
          hc.symbol_name as "hatSymbolName",
          exists (
            select 1
            from friendships f
            where f.user_id = $1 and f.friend_user_id = p.user_id
          ) as "isFriend"
        from profiles p
        left join buddy_states bs on bs.user_id = p.user_id
        left join hat_catalog hc on hc.id = p.equipped_hat_id and hc.is_active = true
        where p.user_id <> $1
          and p.username is not null
          and p.username ilike $2
        order by p.username asc
        limit 10
      `,
      [authReq.userId, `${query}%`]
    );

    res.json({ results: result.rows });
  } catch (error) {
    next(error);
  }
});

app.post("/friends", requireAuth, async (req, res, next) => {
  try {
    const authReq = req as AuthenticatedRequest;
    const input = addFriendSchema.parse(req.body);
    const friend = await pool.query(
      `
        select user_id
        from profiles
        where username = $1
        limit 1
      `,
      [input.username.toLowerCase()]
    );

    if (friend.rowCount === 0) {
      res.status(404).json({ error: "friend_not_found", message: "No buddy with that code was found." });
      return;
    }

    const friendUserId = friend.rows[0].user_id;
    if (friendUserId === authReq.userId) {
      res.status(400).json({ error: "cannot_add_self", message: "You cannot add yourself as a friend." });
      return;
    }

    await pool.query(
      `
        insert into friendships (user_id, friend_user_id)
        values ($1, $2)
        on conflict (user_id, friend_user_id) do nothing
      `,
      [authReq.userId, friendUserId]
    );

    const result = await pool.query(
      `
        select
          p.user_id as "userId",
          p.username,
          p.display_name as "displayName",
          p.buddy_name as "buddyName",
          (p.cat_fill_hue::float / 100) as "catFillHue",
          (p.cat_fill_saturation::float / 100) as "catFillSaturation",
          (p.cat_fill_brightness::float / 100) as "catFillBrightness",
          coalesce(bs.mood::text, 'happy') as mood,
          coalesce(bs.streak, 0) as streak,
          hc.asset_key as "hatAssetKey",
          hc.symbol_name as "hatSymbolName"
        from profiles p
        left join buddy_states bs on bs.user_id = p.user_id
        left join hat_catalog hc on hc.id = p.equipped_hat_id and hc.is_active = true
        where p.user_id = $1
      `,
      [friendUserId]
    );

    res.status(201).json({ friend: result.rows[0] });
  } catch (error) {
    next(error);
  }
});

app.use((error: unknown, _req: express.Request, res: express.Response, _next: express.NextFunction) => {
  console.error(error);

  if (error instanceof z.ZodError) {
    res.status(400).json({ error: "invalid_request", details: error.flatten() });
    return;
  }

  if (isPostgresUniqueViolation(error, "profiles_username_unique")) {
    res.status(409).json({ error: "username_taken", message: "That buddy code is already taken." });
    return;
  }

  if (error instanceof HatOwnershipError) {
    res.status(409).json({ error: "hat_not_owned", message: error.message });
    return;
  }

  const message = error instanceof Error ? error.message : "Unknown error";
  res.status(500).json({ error: "internal_error", message });
});

function isPostgresUniqueViolation(error: unknown, constraint: string): boolean {
  return (
    typeof error === "object" &&
    error !== null &&
    "code" in error &&
    "constraint" in error &&
    error.code === "23505" &&
    error.constraint === constraint
  );
}
