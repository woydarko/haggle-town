-- Run: lute run roblox/tests/Items.spec.luau
local Items = require("../src/shared/Items")

local function check(cond, name)
	if not cond then
		error("FAIL " .. name)
	end
	print("ok", name)
end

-- Must match server/src/items.ts TOKEN_IDS (minus coin) in order.
local IDS = {
	"fish_sardine", "fish_trout", "fish_salmon", "fish_koi",
	"wood_pine", "wood_oak", "wood_maple", "wood_redwood",
	"ore_copper", "ore_iron", "ore_gold", "ore_crystal",
}
check(#Items.list == 12, "12 items")
for i, id in IDS do
	check(Items.list[i].id == id, "order " .. id)
end
check(Items.byId.fish_koi.name == "Golden Koi" and Items.byId.fish_koi.tier == "legendary", "koi is legendary")
check(Items.byId.ore_iron.tier == "rare" and Items.byId.ore_iron.category == "ore", "iron is rare ore")
check(Items.MERCHANT_CATEGORY.smith == "ore" and Items.CLASS_CATEGORY.logger == "wood", "category maps")
check(#Items.ofCategory("wood") == 4 and Items.ofCategory("wood")[4].id == "wood_redwood", "category list in tier order")
check(Items.bagCount({ coin = 900, fish_trout = 2, ore_gold = 1 }) == 3, "bag count skips coin")
check(Items.bagCount({}) == 0, "empty bag")
print("Items.spec passed")
