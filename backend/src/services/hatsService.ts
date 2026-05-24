import { and, eq, inArray } from "drizzle-orm";
import { db } from "../db/client.js";
import { hatCatalog, profiles, userOwnedHats } from "../db/schema.js";

export type HatSummary = {
  id: string;
  slug: string;
  name: string;
  assetKey: string;
  symbolName: string;
};

export type HatsPayload = {
  ownedHats: HatSummary[];
  equippedHatId: string | null;
};

type SeedHat = {
  slug: string;
  name: string;
  assetKey: string;
  symbolName: string;
  sortOrder: number;
  starterOwned: boolean;
};

const seedHats: SeedHat[] = [
  {
    slug: "headphones",
    name: "Headphones",
    assetKey: "hat_headphones",
    symbolName: "headphones",
    sortOrder: 1,
    starterOwned: true
  },
  {
    slug: "halo",
    name: "Halo",
    assetKey: "hat_halo",
    symbolName: "sun.max.fill",
    sortOrder: 2,
    starterOwned: true
  },
  {
    slug: "guard",
    name: "Guard Hat",
    assetKey: "hat_guard",
    symbolName: "shield.lefthalf.filled",
    sortOrder: 3,
    starterOwned: true
  },
  {
    slug: "sprout",
    name: "Sprout",
    assetKey: "Hat_Sprout",
    symbolName: "leaf.fill",
    sortOrder: 4,
    starterOwned: true
  },
  {
    slug: "party",
    name: "Party Hat",
    assetKey: "hat_party 1",
    symbolName: "party.popper.fill",
    sortOrder: 5,
    starterOwned: true
  },
  {
    slug: "krustykrab",
    name: "Krusty Krab Hat",
    assetKey: "hat_krustykrab",
    symbolName: "frying.pan.fill",
    sortOrder: 6,
    starterOwned: true
  }
];

export class HatOwnershipError extends Error {
  constructor() {
    super("You do not own that hat.");
    this.name = "HatOwnershipError";
  }
}

export async function getHatsPayload(userId: string): Promise<HatsPayload> {
  await ensureSeededOwnedHats(userId);
  return await readHatsPayload(userId);
}

export async function setEquippedHat(userId: string, hatId: string | null): Promise<HatsPayload> {
  await ensureSeededOwnedHats(userId);

  if (hatId === null) {
    await db
      .update(profiles)
      .set({
        equippedHatId: null,
        updatedAt: new Date()
      })
      .where(eq(profiles.userId, userId));

    return await readHatsPayload(userId);
  }

  const [owned] = await db
    .select({ hatId: userOwnedHats.hatId })
    .from(userOwnedHats)
    .where(and(eq(userOwnedHats.userId, userId), eq(userOwnedHats.hatId, hatId)))
    .limit(1);

  if (!owned) {
    throw new HatOwnershipError();
  }

  await db
    .update(profiles)
    .set({
      equippedHatId: hatId,
      updatedAt: new Date()
    })
    .where(eq(profiles.userId, userId));

  return await readHatsPayload(userId);
}

async function ensureHatCatalogSeeded() {
  for (const hat of seedHats) {
    await db
      .insert(hatCatalog)
      .values({
        slug: hat.slug,
        name: hat.name,
        assetKey: hat.assetKey,
        symbolName: hat.symbolName,
        sortOrder: hat.sortOrder,
        isActive: true
      })
      .onConflictDoUpdate({
        target: hatCatalog.slug,
        set: {
          name: hat.name,
          assetKey: hat.assetKey,
          symbolName: hat.symbolName,
          sortOrder: hat.sortOrder,
          isActive: true,
          updatedAt: new Date()
        }
      });
  }
}

export async function ensureSeededOwnedHats(userId: string) {
  await ensureHatCatalogSeeded();

  const starterSlugs = seedHats.filter((hat) => hat.starterOwned).map((hat) => hat.slug);
  if (starterSlugs.length === 0) {
    return;
  }

  const starterHats = await db
    .select({ id: hatCatalog.id })
    .from(hatCatalog)
    .where(inArray(hatCatalog.slug, starterSlugs));

  if (starterHats.length === 0) {
    return;
  }

  await db
    .insert(userOwnedHats)
    .values(starterHats.map((hat) => ({ userId, hatId: hat.id })))
    .onConflictDoNothing();
}

async function readHatsPayload(userId: string): Promise<HatsPayload> {
  const [profile] = await db
    .select({ equippedHatId: profiles.equippedHatId })
    .from(profiles)
    .where(eq(profiles.userId, userId))
    .limit(1);

  const ownedRows = await db
    .select({
      id: hatCatalog.id,
      slug: hatCatalog.slug,
      name: hatCatalog.name,
      assetKey: hatCatalog.assetKey,
      symbolName: hatCatalog.symbolName
    })
    .from(userOwnedHats)
    .innerJoin(hatCatalog, eq(userOwnedHats.hatId, hatCatalog.id))
    .where(and(eq(userOwnedHats.userId, userId), eq(hatCatalog.isActive, true)))
    .orderBy(hatCatalog.sortOrder, hatCatalog.name);

  const ownedHats = ownedRows.map((row) => ({
    id: row.id,
    slug: row.slug,
    name: row.name,
    assetKey: row.assetKey,
    symbolName: row.symbolName
  }));

  let equippedHatId = profile?.equippedHatId ?? null;
  if (equippedHatId && !ownedHats.some((hat) => hat.id == equippedHatId)) {
    equippedHatId = null;
    await db
      .update(profiles)
      .set({ equippedHatId: null, updatedAt: new Date() })
      .where(eq(profiles.userId, userId));
  }

  return {
    ownedHats,
    equippedHatId
  };
}
