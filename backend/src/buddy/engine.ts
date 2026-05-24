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
  if (ratio < 0.5) return "sick";
  if (ratio <= 0.85) return "happy";
  if (ratio <= 1.1) return "nervous";
  return "hungry";
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

export function addDaysToDateString(dateString: string, days: number): string {
  const date = new Date(`${dateString}T00:00:00.000Z`);
  date.setUTCDate(date.getUTCDate() + days);
  return date.toISOString().slice(0, 10);
}

export function monthStartForDateString(dateString: string): string {
  return `${dateString.slice(0, 7)}-01`;
}

export function weekStartForDateString(dateString: string): string {
  const date = new Date(`${dateString}T00:00:00.000Z`);
  const day = date.getUTCDay();
  const daysFromMonday = (day + 6) % 7;
  date.setUTCDate(date.getUTCDate() - daysFromMonday);
  return date.toISOString().slice(0, 10);
}
