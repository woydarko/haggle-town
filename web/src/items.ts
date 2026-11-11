// The 12 items, mirroring server/src/items.ts (ids, names, tiers) for labels and colors. Prices always come from the API.
export type Category = "fish" | "wood" | "ore";
export type Tier = "common" | "rare" | "epic" | "legendary";
export type Item = { id: string; name: string; category: Category; tier: Tier };

export const CATEGORIES: Category[] = ["fish", "wood", "ore"];
export const TIERS: Tier[] = ["common", "rare", "epic", "legendary"];
export const CATEGORY_NAME: Record<Category, string> = { fish: "Fish", wood: "Wood", ore: "Ore" };
export const CATEGORY_MERCHANT: Record<Category, string> = { fish: "Fishmonger", wood: "Woodcutter", ore: "Smith" };
export const CLASS_NAME: Record<string, string> = { fisher: "Fisher", logger: "Logger", miner: "Miner" };

const NAMES: Record<Category, string[][]> = {
  fish: [["fish_sardine", "Sardine"], ["fish_trout", "Trout"], ["fish_salmon", "Salmon"], ["fish_koi", "Golden Koi"]],
  wood: [["wood_pine", "Pine"], ["wood_oak", "Oak"], ["wood_maple", "Maple"], ["wood_redwood", "Ancient Redwood"]],
  ore: [["ore_copper", "Copper"], ["ore_iron", "Iron"], ["ore_gold", "Gold"], ["ore_crystal", "Crystal"]],
};

export const ITEMS: Item[] = CATEGORIES.flatMap((category) => NAMES[category].map(([id, name], i) => ({ id, name, category, tier: TIERS[i] })));
const BY_ID = new Map(ITEMS.map((i) => [i.id, i]));

export const itemById = (id: string) => BY_ID.get(id);
/** Display name; v1 rows ("wood", "fish", "iron") fall back to the raw id. */
export const itemName = (id: string) => BY_ID.get(id)?.name ?? id;
export const tierColor = (tier: string) => `var(--tier-${tier})`;
