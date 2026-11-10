// The 12 tradeable items (mirrors economy/src/pricing.rs; ids are the NEP-245 token ids).
export type Category = "fish" | "wood" | "ore";
export type Tier = "common" | "rare" | "epic" | "legendary";
export type ItemDef = { id: string; name: string; category: Category; tier: Tier; base: number; target: number };

export const CATEGORIES: Category[] = ["fish", "wood", "ore"];
export const TIERS: Tier[] = ["common", "rare", "epic", "legendary"];
const CAT_BASE: Record<Category, number> = { fish: 20, wood: 15, ore: 30 };
const MULT: Record<Tier, number> = { common: 1, rare: 3, epic: 8, legendary: 30 };
const TARGET: Record<Tier, number> = { common: 120, rare: 40, epic: 12, legendary: 3 };
const NAMES: Record<Category, [string, string][]> = {
  fish: [["fish_sardine", "Sardine"], ["fish_trout", "Trout"], ["fish_salmon", "Salmon"], ["fish_koi", "Golden Koi"]],
  wood: [["wood_pine", "Pine"], ["wood_oak", "Oak"], ["wood_maple", "Maple"], ["wood_redwood", "Ancient Redwood"]],
  ore: [["ore_copper", "Copper"], ["ore_iron", "Iron"], ["ore_gold", "Gold"], ["ore_crystal", "Crystal"]],
};

export const ITEMS: ItemDef[] = CATEGORIES.flatMap((category) =>
  NAMES[category].map(([id, name], i) => {
    const tier = TIERS[i];
    return { id, name, category, tier, base: CAT_BASE[category] * MULT[tier], target: TARGET[tier] };
  }),
);
const BY_ID = new Map(ITEMS.map((i) => [i.id, i]));
export const TOKEN_IDS = ["coin", ...ITEMS.map((i) => i.id)];

export const itemById = (id: string): ItemDef | undefined => BY_ID.get(id);
export const itemOf = (category: Category, tier: Tier): ItemDef => ITEMS.find((i) => i.category === category && i.tier === tier)!;

export const CLASS_CATEGORY: Record<string, Category> = { fisher: "fish", logger: "wood", miner: "ore" };
export const MERCHANT_CATEGORY: Record<string, Category> = { fishmonger: "fish", woodcutter: "wood", smith: "ore" };
