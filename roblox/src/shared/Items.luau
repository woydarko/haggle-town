--!strict
-- The 12 items, mirroring server/src/items.ts (ids, names, tiers). Prices come from the server, never from here.
-- No Roblox globals so roblox/tests/Items.spec.luau runs under Lute.

export type Item = { id: string, name: string, category: string, tier: string }

local TIERS = { "common", "rare", "epic", "legendary" }
local NAMES = {
	{ "fish", { { "fish_sardine", "Sardine" }, { "fish_trout", "Trout" }, { "fish_salmon", "Salmon" }, { "fish_koi", "Golden Koi" } } },
	{ "wood", { { "wood_pine", "Pine" }, { "wood_oak", "Oak" }, { "wood_maple", "Maple" }, { "wood_redwood", "Ancient Redwood" } } },
	{ "ore", { { "ore_copper", "Copper" }, { "ore_iron", "Iron" }, { "ore_gold", "Gold" }, { "ore_crystal", "Crystal" } } },
}

local Items = {
	TIERS = TIERS,
	CATEGORIES = { "fish", "wood", "ore" },
	list = {} :: { Item },
	byId = {} :: { [string]: Item },
	CLASS_CATEGORY = { fisher = "fish", logger = "wood", miner = "ore" } :: { [string]: string },
	MERCHANT_CATEGORY = { fishmonger = "fish", woodcutter = "wood", smith = "ore" } :: { [string]: string },
}

for _, cat in NAMES do
	for i, pair in cat[2] do
		local item = { id = pair[1], name = pair[2], category = cat[1], tier = TIERS[i] }
		table.insert(Items.list, item)
		Items.byId[item.id] = item
	end
end

function Items.ofCategory(category: string): { Item }
	local out = {}
	for _, item in Items.list do
		if item.category == category then
			table.insert(out, item)
		end
	end
	return out
end

-- Number of items in the bag (everything except coin).
function Items.bagCount(balances: { [string]: number }): number
	local n = 0
	for id, qty in balances do
		if Items.byId[id] then
			n += qty
		end
	end
	return n
end

return Items
