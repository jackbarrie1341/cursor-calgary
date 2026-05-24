import { and, eq, isNull, sql } from "drizzle-orm";
import { env } from "../config/env.js";
import { addDaysToDateString, moodForSpend, localDateString, monthStartForDateString, streakForToday, weekStartForDateString } from "../buddy/engine.js";
import { db } from "../db/client.js";
import { buddyStates, plaidItems, profiles, transactions } from "../db/schema.js";

export type BuddyPayload = {
  mood: string;
  spentTodayCents: number;
  spentWeekCents: number;
  spentMonthCents: number;
  dailyAllowanceCents: number;
  streak: number;
  asOfDate: string;
  buddyName: string;
  catFillHue: number;
  catFillSaturation: number;
  catFillBrightness: number;
  isLinked: boolean;
  hasOnboarded: boolean;
};

export async function getBuddyPayload(userId: string): Promise<BuddyPayload> {
  const [profile] = await db.select().from(profiles).where(eq(profiles.userId, userId)).limit(1);
  const [state] = await db.select().from(buddyStates).where(eq(buddyStates.userId, userId)).limit(1);
  const [item] = await db.select({ id: plaidItems.id }).from(plaidItems).where(eq(plaidItems.userId, userId)).limit(1);

  if (!profile) {
    return {
      mood: "happy",
      spentTodayCents: 0,
      spentWeekCents: 0,
      spentMonthCents: 0,
      dailyAllowanceCents: 0,
      streak: 0,
      asOfDate: localDateString(new Date(), env.APP_TIME_ZONE),
      buddyName: "Buddy",
      catFillHue: 0.04,
      catFillSaturation: 0.48,
      catFillBrightness: 1,
      isLinked: Boolean(item),
      hasOnboarded: false
    };
  }

  if (!state) {
    return await recomputeBuddyState(userId);
  }

  return {
    mood: state.mood,
    spentTodayCents: state.spentTodayCents,
    spentWeekCents: await sumSpendCents(userId, state.stateDate, addDaysToDateString(weekStartForDateString(state.stateDate), 6)),
    spentMonthCents: await sumSpendCents(userId, monthStartForDateString(state.stateDate), state.stateDate),
    dailyAllowanceCents: state.dailyAllowanceCents,
    streak: state.streak,
    asOfDate: state.stateDate,
    buddyName: profile.buddyName,
    catFillHue: profile.catFillHue / 100,
    catFillSaturation: profile.catFillSaturation / 100,
    catFillBrightness: profile.catFillBrightness / 100,
    isLinked: Boolean(item),
    hasOnboarded: true
  };
}

export async function recomputeBuddyState(userId: string): Promise<BuddyPayload> {
  const [profile] = await db.select().from(profiles).where(eq(profiles.userId, userId)).limit(1);
  if (!profile) {
    throw new Error(`Profile not found for user ${userId}`);
  }

  const today = localDateString(new Date(), env.APP_TIME_ZONE);
  const spentTodayCents = await sumSpendCents(userId, today, today);
  const spentWeekCents = await sumSpendCents(userId, weekStartForDateString(today), addDaysToDateString(weekStartForDateString(today), 6));
  const spentMonthCents = await sumSpendCents(userId, monthStartForDateString(today), today);
  const [previousState] = await db.select().from(buddyStates).where(eq(buddyStates.userId, userId)).limit(1);
  const mood = moodForSpend(spentTodayCents, profile.dailyAllowanceCents);
  const streak = streakForToday(spentTodayCents, profile.dailyAllowanceCents, previousState?.streak ?? null);

  const [state] = await db
    .insert(buddyStates)
    .values({
      userId,
      mood,
      spentTodayCents,
      dailyAllowanceCents: profile.dailyAllowanceCents,
      streak,
      stateDate: today
    })
    .onConflictDoUpdate({
      target: buddyStates.userId,
      set: {
        mood,
        spentTodayCents,
        dailyAllowanceCents: profile.dailyAllowanceCents,
        streak,
        stateDate: today,
        updatedAt: new Date()
      }
    })
    .returning();

  const [item] = await db.select({ id: plaidItems.id }).from(plaidItems).where(eq(plaidItems.userId, userId)).limit(1);

  return {
    mood: state.mood,
    spentTodayCents: state.spentTodayCents,
    spentWeekCents,
    spentMonthCents,
    dailyAllowanceCents: state.dailyAllowanceCents,
    streak: state.streak,
    asOfDate: state.stateDate,
    buddyName: profile.buddyName,
    catFillHue: profile.catFillHue / 100,
    catFillSaturation: profile.catFillSaturation / 100,
    catFillBrightness: profile.catFillBrightness / 100,
    isLinked: Boolean(item),
    hasOnboarded: true
  };
}

async function sumSpendCents(userId: string, startDate: string, endDate: string): Promise<number> {
  const [sumRow] = await db
    .select({
      totalCents: sql<number>`coalesce(sum(case when ${transactions.amountCents} > 0 then ${transactions.amountCents} else 0 end), 0)::int`
    })
    .from(transactions)
    .where(
      and(
        eq(transactions.userId, userId),
        sql`${transactions.authorizedDate} >= ${startDate}`,
        sql`${transactions.authorizedDate} <= ${endDate}`,
        eq(transactions.removed, false)
      )
    );

  return sumRow?.totalCents ?? 0;
}

export async function userHasLinkedItem(userId: string): Promise<boolean> {
  const [item] = await db.select({ id: plaidItems.id }).from(plaidItems).where(eq(plaidItems.userId, userId)).limit(1);
  return Boolean(item);
}
