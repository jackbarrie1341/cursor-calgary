import type { BuddyMood } from "../db/schema.js";

export function daysInMonth(date: Date): number {
  return new Date(date.getFullYear(), date.getMonth() + 1, 0).getDate();
}

export function calculateDailyAllowanceCents(monthlyBudgetCents: number, date = new Date()): number {
  return Math.round(monthlyBudgetCents / daysInMonth(date));
}

export function moodForSpend(spentTodayCents: number, dailyAllowanceCents: number): BuddyMood {
  if (dailyAllowanceCents <= 0) return "sick";

  const ratio = spentTodayCents / dailyAllowanceCents;
  if (ratio <= 0.5) return "happy";
  if (ratio <= 0.8) return "nervous";
  if (ratio <= 1) return "hungry";
  return "sick";
}

export function streakForToday(spentTodayCents: number, dailyAllowanceCents: number, previousStreak: number | null): number {
  if (spentTodayCents > dailyAllowanceCents) return 0;
  return Math.max(previousStreak ?? 1, 1);
}

export function localDateString(date = new Date(), timeZone = "America/Edmonton"): string {
  const parts = new Intl.DateTimeFormat("en-CA", {
    timeZone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit"
  }).formatToParts(date);

  const year = parts.find((part) => part.type === "year")?.value;
  const month = parts.find((part) => part.type === "month")?.value;
  const day = parts.find((part) => part.type === "day")?.value;

  if (!year || !month || !day) {
    throw new Error("Unable to format local date");
  }

  return `${year}-${month}-${day}`;
}
