import { describe, expect, it } from "vitest";
import { calculateDailyAllowanceCents, localDateString, moodForSpend, streakForToday } from "../src/buddy/engine.js";

describe("buddy engine", () => {
  it("maps spend ratio to moods", () => {
    expect(moodForSpend(499, 1000)).toBe("sick");
    expect(moodForSpend(500, 1000)).toBe("happy");
    expect(moodForSpend(850, 1000)).toBe("happy");
    expect(moodForSpend(851, 1000)).toBe("nervous");
    expect(moodForSpend(1100, 1000)).toBe("nervous");
    expect(moodForSpend(1101, 1000)).toBe("hungry");
  });

  it("calculates daily allowance for the active month", () => {
    expect(calculateDailyAllowanceCents(310_000, new Date("2026-05-10T12:00:00Z"))).toBe(10_000);
    expect(calculateDailyAllowanceCents(280_000, new Date("2026-02-10T12:00:00Z"))).toBe(10_000);
  });

  it("resets streak when over allowance", () => {
    expect(streakForToday(1001, 1000, 5)).toBe(0);
    expect(streakForToday(999, 1000, 5)).toBe(5);
    expect(streakForToday(999, 1000, null)).toBe(1);
  });

  it("formats a local date in the configured timezone", () => {
    expect(localDateString(new Date("2026-05-23T06:00:00Z"), "America/Edmonton")).toBe("2026-05-23");
  });
});
