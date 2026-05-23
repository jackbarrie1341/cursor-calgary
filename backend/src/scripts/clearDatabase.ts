import { sql } from "drizzle-orm";
import { db, pool } from "../db/client.js";

async function main() {
  if (process.env.NODE_ENV === "production" && process.env.ALLOW_DB_CLEAR !== "true") {
    throw new Error("Refusing to clear production data without ALLOW_DB_CLEAR=true");
  }

  await db.execute(sql`
    truncate table
      friendships,
      transactions,
      plaid_items,
      buddy_states,
      profiles
    restart identity cascade
  `);

  console.log("Cleared Finance Buddy app tables: friendships, transactions, plaid_items, buddy_states, profiles");
  console.log("Supabase Auth users were not deleted.");
}

main()
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await pool.end();
  });
