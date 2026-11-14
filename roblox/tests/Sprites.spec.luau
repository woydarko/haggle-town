-- Run: lute run roblox/tests/Sprites.spec.luau
local Items = require("../src/shared/Items")
local Sprites = require("../src/shared/Sprites")

local function check(cond, name)
	if not cond then
		error("FAIL " .. name)
	end
	print("ok", name)
end

local ids = { "axe", "pickaxe", "rod", "anvil", "fish_mystery" } -- board illustrations (Lobby how-to) + Forge
for _, tool in { "axe", "pickaxe", "rod" } do
	for level = 1, 3 do
		table.insert(ids, `{tool}_{level}`) -- Forge level icons
	end
end
for _, item in Items.list do
	table.insert(ids, item.id)
end
for _, id in ids do
	local s = Sprites.get(id)
	check(s ~= nil, "sprite for " .. id)
	check(#s.rows == Sprites.SIZE, id .. " has 12 rows")
	local pixels = 0
	for r, row in s.rows do
		check(#row == Sprites.SIZE, `{id} row {r} is 12 wide`)
		for c = 1, #row do
			local ch = string.sub(row, c, c)
			if ch ~= "." then
				pixels += 1
				local hex = s.palette[ch]
				check(type(hex) == "string" and string.match(hex, "^%x%x%x%x%x%x$") ~= nil, `{id} colour '{ch}'`)
			end
		end
	end
	-- Runs merge same-colour neighbours in a row and still cover every pixel exactly once.
	local runs = Sprites.runs(id)
	local covered = 0
	for _, run in runs do
		covered += run.len
		for c = run.col, run.col + run.len - 1 do
			check(s.palette[string.sub(s.rows[run.row], c, c)] == run.hex, `{id} run colour at {run.row},{c}`)
		end
	end
	check(covered == pixels, id .. " runs cover all pixels")
	check(#runs < pixels, id .. " runs merge pixels")
end

check(Sprites.get("coin") == nil, "no sprite for unknown ids")
check(#Sprites.runs("nope") == 0, "no runs for unknown ids")
-- Same category shares a silhouette; tiers differ by colour so the bag reads as a set.
check(Sprites.get("fish_sardine").palette.a ~= Sprites.get("fish_koi").palette.a, "tiers differ in colour")
print("Sprites.spec passed")
