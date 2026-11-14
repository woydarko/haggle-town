-- Run: lute run roblox/tests/ForgeView.spec.luau
-- Forge helpers: what is missing for the next level, which tool the player works towards, what the Buy tab badges.
local ForgeView = require("../src/shared/ForgeView")

local function check(cond, name)
	if not cond then
		error("FAIL " .. name)
	end
	print("ok", name)
end

local function tool(name: string, level: number, cost: { any }?): any
	return { tool = name, level = level, name = name, bonus = 0, next = if cost then { level = level + 1, name = name, bonus = 0.25, cost = cost } else nil }
end
local AXE = { { item = "ore_copper", name = "Copper", qty = 3, merchant = "smith" }, { item = "fish_sardine", name = "Sardine", qty = 3, merchant = "fishmonger" } }
local ROD = { { item = "wood_pine", name = "Pine", qty = 3, merchant = "woodcutter" }, { item = "ore_copper", name = "Copper", qty = 3, merchant = "smith" } }
local forge = { tool("axe", 1, AXE), tool("pickaxe", 3, nil), tool("rod", 1, ROD) }

local m = ForgeView.missing(forge[1], { ore_copper = 1, fish_sardine = 5 })
check(#m == 1 and m[1].item == "ore_copper" and m[1].qty == 2 and m[1].merchant == "smith", "missing counts what is still short")
check(#ForgeView.missing(forge[1], { ore_copper = 3, fish_sardine = 3 }) == 0, "nothing missing when the goods are there")
check(#ForgeView.missing(forge[2], {}) == 0, "master tool has no next level")

check(ForgeView.focus(forge, "logger").tool == "axe", "logger works towards the axe")
check(ForgeView.focus(forge, "miner").tool == "axe", "miner's pickaxe is maxed -> first tool that can still grow")
check(ForgeView.focus(nil, "logger") == nil, "no forge data yet -> nil")

local n = ForgeView.needsFrom(forge, "fisher", { ore_copper = 2 }, "smith")
check(n.ore_copper == 1, "fisher's rod needs 1 more copper from the smith")
check(next(ForgeView.needsFrom(forge, "fisher", {}, "fishmonger")) == nil, "rod needs nothing from the fishmonger")

local h = ForgeView.hint(forge, "logger", {})
check(h ~= nil and h.tool == "Axe" and h.level == 1 and h.need ~= nil and h.need.stall == "smith" and h.need.qty == 3, "hint names the first missing good and its seller")
h = ForgeView.hint(forge, "logger", { ore_copper = 3, fish_sardine = 3 })
check(h ~= nil and h.need == nil, "goods ready -> hint without need")
check(ForgeView.hint(forge, nil, {}) == nil, "no trade yet -> no hint")
check(ForgeView.pct(0.25) == "25%" and ForgeView.pct(0.5) == "50%", "percent text")
print("ForgeView.spec passed")
