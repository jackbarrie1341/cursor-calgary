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
    equippedHatId: uuid("equipped_hat_id").references(() => hatCatalog.id, { onDelete: "set null" }),
    catFillHue: integer("cat_fill_hue").notNull().default(4),
    catFillSaturation: integer("cat_fill_saturation").notNull().default(48),
    catFillBrightness: integer("cat_fill_brightness").notNull().default(100),
    createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
    updatedAt: timestamp("updated_at", { withTimezone: true }).notNull().defaultNow()
  },
  (table) => ({
    usernameUnique: uniqueIndex("profiles_username_unique").on(table.username)
  })
);

export const hatCatalog = pgTable(
  "hat_catalog",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    slug: text("slug").notNull(),
    name: text("name").notNull(),
    assetKey: text("asset_key").notNull(),
    symbolName: text("symbol_name").notNull(),
    sortOrder: integer("sort_order").notNull().default(0),
    isActive: boolean("is_active").notNull().default(true),
    createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
    updatedAt: timestamp("updated_at", { withTimezone: true }).notNull().defaultNow()
  },
  (table) => ({
    slugUnique: uniqueIndex("hat_catalog_slug_unique").on(table.slug)
  })
);

export const userOwnedHats = pgTable(
  "user_owned_hats",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    userId: uuid("user_id")
      .notNull()
      .references(() => profiles.userId, { onDelete: "cascade" }),
    hatId: uuid("hat_id")
      .notNull()
      .references(() => hatCatalog.id, { onDelete: "cascade" }),
    ownedAt: timestamp("owned_at", { withTimezone: true }).notNull().defaultNow()
  },
  (table) => ({
    userIdIdx: index("user_owned_hats_user_id_idx").on(table.userId),
    hatIdIdx: index("user_owned_hats_hat_id_idx").on(table.hatId),
    userHatUnique: uniqueIndex("user_owned_hats_user_hat_unique").on(table.userId, table.hatId)
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
  buddyState: one(buddyStates),
  ownedHats: many(userOwnedHats),
  equippedHat: one(hatCatalog, {
    fields: [profiles.equippedHatId],
    references: [hatCatalog.id]
  })
}));

export const plaidItemsRelations = relations(plaidItems, ({ one }) => ({
  profile: one(profiles, {
    fields: [plaidItems.userId],
    references: [profiles.userId]
  })
}));

export const hatCatalogRelations = relations(hatCatalog, ({ many }) => ({
  owners: many(userOwnedHats)
}));

export const userOwnedHatsRelations = relations(userOwnedHats, ({ one }) => ({
  profile: one(profiles, {
    fields: [userOwnedHats.userId],
    references: [profiles.userId]
  }),
  hat: one(hatCatalog, {
    fields: [userOwnedHats.hatId],
    references: [hatCatalog.id]
  })
}));

export type BuddyMood = (typeof buddyMood.enumValues)[number];
