import { relations } from "drizzle-orm";
import {
  boolean,
  date,
  index,
  integer,
  jsonb,
  pgEnum,
  pgTable,
  text,
  timestamp,
  uniqueIndex,
  uuid
} from "drizzle-orm/pg-core";

export const buddyMood = pgEnum("buddy_mood", ["happy", "nervous", "hungry", "sick"]);

export const profiles = pgTable(
  "profiles",
  {
    userId: uuid("user_id").primaryKey(),
    username: text("username"),
    displayName: text("display_name").notNull().default(""),
    monthlyIncomeCents: integer("monthly_income_cents").notNull(),
    monthlyBudgetCents: integer("monthly_budget_cents").notNull(),
    dailyAllowanceCents: integer("daily_allowance_cents").notNull(),
    buddyName: text("buddy_name").notNull().default("Buddy"),
    createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
    updatedAt: timestamp("updated_at", { withTimezone: true }).notNull().defaultNow()
  },
  (table) => ({
    usernameUnique: uniqueIndex("profiles_username_unique").on(table.username)
  })
);

export const plaidItems = pgTable(
  "plaid_items",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    userId: uuid("user_id")
      .notNull()
      .references(() => profiles.userId, { onDelete: "cascade" }),
    plaidItemId: text("plaid_item_id").notNull(),
    accessToken: text("access_token").notNull(),
    syncCursor: text("sync_cursor"),
    createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
    updatedAt: timestamp("updated_at", { withTimezone: true }).notNull().defaultNow()
  },
  (table) => ({
    userIdIdx: index("plaid_items_user_id_idx").on(table.userId),
    plaidItemUnique: uniqueIndex("plaid_items_plaid_item_id_unique").on(table.plaidItemId)
  })
);

export const transactions = pgTable(
  "transactions",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    userId: uuid("user_id")
      .notNull()
      .references(() => profiles.userId, { onDelete: "cascade" }),
    plaidItemId: text("plaid_item_id").notNull(),
    plaidTransactionId: text("plaid_transaction_id").notNull(),
    amountCents: integer("amount_cents").notNull(),
    authorizedDate: date("authorized_date"),
    postedDate: date("posted_date"),
    merchantName: text("merchant_name"),
    name: text("name").notNull(),
    pending: boolean("pending").notNull().default(false),
    removed: boolean("removed").notNull().default(false),
    raw: jsonb("raw").notNull(),
    createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
    updatedAt: timestamp("updated_at", { withTimezone: true }).notNull().defaultNow()
  },
  (table) => ({
    userDateIdx: index("transactions_user_authorized_date_idx").on(table.userId, table.authorizedDate),
    plaidTransactionUnique: uniqueIndex("transactions_plaid_transaction_id_unique").on(table.plaidTransactionId)
  })
);

export const buddyStates = pgTable(
  "buddy_states",
  {
    userId: uuid("user_id")
      .primaryKey()
      .references(() => profiles.userId, { onDelete: "cascade" }),
    mood: buddyMood("mood").notNull().default("happy"),
    spentTodayCents: integer("spent_today_cents").notNull().default(0),
    dailyAllowanceCents: integer("daily_allowance_cents").notNull(),
    streak: integer("streak").notNull().default(1),
    stateDate: date("state_date").notNull(),
    updatedAt: timestamp("updated_at", { withTimezone: true }).notNull().defaultNow()
  },
  (table) => ({
    stateDateIdx: index("buddy_states_state_date_idx").on(table.stateDate)
  })
);

export const friendships = pgTable(
  "friendships",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    userId: uuid("user_id")
      .notNull()
      .references(() => profiles.userId, { onDelete: "cascade" }),
    friendUserId: uuid("friend_user_id")
      .notNull()
      .references(() => profiles.userId, { onDelete: "cascade" }),
    createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow()
  },
  (table) => ({
    userIdIdx: index("friendships_user_id_idx").on(table.userId),
    friendUserIdIdx: index("friendships_friend_user_id_idx").on(table.friendUserId),
    pairUnique: uniqueIndex("friendships_user_friend_unique").on(table.userId, table.friendUserId)
  })
);

export const profilesRelations = relations(profiles, ({ many, one }) => ({
  plaidItems: many(plaidItems),
  buddyState: one(buddyStates)
}));

export const plaidItemsRelations = relations(plaidItems, ({ one }) => ({
  profile: one(profiles, {
    fields: [plaidItems.userId],
    references: [profiles.userId]
  })
}));

export type BuddyMood = (typeof buddyMood.enumValues)[number];
