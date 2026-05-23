import cors from "cors";
import express from "express";
import helmet from "helmet";
import { eq } from "drizzle-orm";
import { CountryCode, Products } from "plaid";
import { z } from "zod";
import { requireAuth, type AuthenticatedRequest } from "./auth.js";
import { calculateDailyAllowanceCents, localDateString } from "./buddy/engine.js";
import { env } from "./config/env.js";
import { db } from "./db/client.js";
import { buddyStates, plaidItems, profiles } from "./db/schema.js";
import { plaidClient } from "./plaid/client.js";
import { getBuddyPayload, recomputeBuddyState } from "./services/buddyService.js";
import { syncPlaidItem, syncPlaidItemByPlaidItemId } from "./services/transactionSync.js";

const onboardingSchema = z.object({
  monthlyIncomeCents: z.number().int().nonnegative(),
  monthlyBudgetCents: z.number().int().positive(),
  buddyName: z.string().trim().min(1).max(40).optional()
});

const exchangeSchema = z.object({
  publicToken: z.string().min(1)
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
        buddyName: input.buddyName ?? "Buddy"
      })
      .onConflictDoUpdate({
        target: profiles.userId,
        set: {
          monthlyIncomeCents: input.monthlyIncomeCents,
          monthlyBudgetCents: input.monthlyBudgetCents,
          dailyAllowanceCents,
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

app.get("/buddy", requireAuth, async (req, res, next) => {
  try {
    const authReq = req as AuthenticatedRequest;
    res.json(await getBuddyPayload(authReq.userId));
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

  const message = error instanceof Error ? error.message : "Unknown error";
  res.status(500).json({ error: "internal_error", message });
});
