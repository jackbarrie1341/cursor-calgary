import { eq } from "drizzle-orm";
import type { RemovedTransaction, Transaction } from "plaid";
import { db } from "../db/client.js";
import { plaidItems, transactions } from "../db/schema.js";
import { plaidClient } from "../plaid/client.js";
import { recomputeBuddyState } from "./buddyService.js";

function amountToCents(amount: number): number {
  return Math.round(amount * 100);
}

function dateOrNull(value: string | null | undefined): string | null {
  return value ?? null;
}

async function upsertTransaction(userId: string, plaidItemId: string, transaction: Transaction) {
  await db
    .insert(transactions)
    .values({
      userId,
      plaidItemId,
      plaidTransactionId: transaction.transaction_id,
      amountCents: amountToCents(transaction.amount),
      authorizedDate: dateOrNull(transaction.authorized_date ?? transaction.date),
      postedDate: dateOrNull(transaction.date),
      merchantName: transaction.merchant_name ?? null,
      name: transaction.name,
      pending: transaction.pending,
      removed: false,
      raw: transaction
    })
    .onConflictDoUpdate({
      target: transactions.plaidTransactionId,
      set: {
        amountCents: amountToCents(transaction.amount),
        authorizedDate: dateOrNull(transaction.authorized_date ?? transaction.date),
        postedDate: dateOrNull(transaction.date),
        merchantName: transaction.merchant_name ?? null,
        name: transaction.name,
        pending: transaction.pending,
        removed: false,
        raw: transaction,
        updatedAt: new Date()
      }
    });
}

async function markRemoved(removed: RemovedTransaction) {
  await db
    .update(transactions)
    .set({ removed: true, updatedAt: new Date() })
    .where(eq(transactions.plaidTransactionId, removed.transaction_id));
}

export async function syncPlaidItemByPlaidItemId(plaidItemId: string) {
  const [item] = await db.select().from(plaidItems).where(eq(plaidItems.plaidItemId, plaidItemId)).limit(1);
  if (!item) {
    throw new Error(`Plaid item not found: ${plaidItemId}`);
  }

  return await syncPlaidItem(item.id);
}

export async function syncPlaidItem(itemId: string) {
  const [item] = await db.select().from(plaidItems).where(eq(plaidItems.id, itemId)).limit(1);
  if (!item) {
    throw new Error(`Plaid item not found: ${itemId}`);
  }

  let cursor = item.syncCursor ?? undefined;
  let nextCursor = cursor;
  let hasMore = true;

  while (hasMore) {
    const response = await plaidClient.transactionsSync({
      access_token: item.accessToken,
      cursor,
      count: 500
    });

    for (const transaction of response.data.added) {
      await upsertTransaction(item.userId, item.plaidItemId, transaction);
    }

    for (const transaction of response.data.modified) {
      await upsertTransaction(item.userId, item.plaidItemId, transaction);
    }

    for (const removed of response.data.removed) {
      await markRemoved(removed);
    }

    hasMore = response.data.has_more;
    nextCursor = response.data.next_cursor;
    cursor = nextCursor;
  }

  if (nextCursor) {
    await db
      .update(plaidItems)
      .set({ syncCursor: nextCursor, updatedAt: new Date() })
      .where(eq(plaidItems.id, item.id));
  }

  return await recomputeBuddyState(item.userId);
}
