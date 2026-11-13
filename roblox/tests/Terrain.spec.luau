-- Run: lute run roblox/tests/Terrain.spec.luau
-- The map is generated at server start, so these checks walk the pure height/material functions as data.
local Terrain = require("../src/server/Terrain")
local Regions = require("../src/shared/Regions")

local function check(cond, name)
	if not cond then
		error("FAIL " .. name)
	end
	print("ok", name)
end
local function at(x, y, z)
	return Terrain.materialAt({ x = x, y = y, z = z })
end
local function solid(m)
	return m ~= "Air" and m ~= "Water"
end
local S = Terrain.SPOTS
local W = Terrain.WATER_Y

-- Every land spot has open air to stand in and solid ground under it.
for _, name in { "lobby", "square", "wood", "ore_mouth", "ore_deep", "ore_crystal", "mine_mouth", "lake_pier", "sea_pier", "pine", "woods", "grove" } do
	local p = S[name]
	check(p ~= nil, name .. " exists")
	check(at(p.x, p.y + 3, p.z) == "Air", name .. " is open")
	check(solid(at(p.x, p.y - 1, p.z)), name .. " has ground")
end
-- Water spots: the lake pier end and the sea pier end stand over water.
check(at(S.fish.x, W - 1, S.fish.z) == "Water", "lake fishing spot is water")
check(at(S.fish_deep.x, W - 1, S.fish_deep.z) == "Water", "sea fishing spot is water")
check(Regions.fishNodeAt(S.fish.x, S.fish.z) == "fish", "lake spot -> fish")
check(Regions.fishNodeAt(S.fish_deep.x, S.fish_deep.z) == "fish_deep", "sea spot -> fish_deep")

-- The village is flat enough to build on (< 6 studs per 20) and the town is not buried.
for x = -100, 100, 20 do
	for z = -120, 60, 20 do
		check(math.abs(Terrain.height(x + 20, z) - Terrain.height(x, z)) < 6 and math.abs(Terrain.height(x, z + 20) - Terrain.height(x, z)) < 6, `village flat at {x},{z}`)
	end
end
for _, p in { { -40, -8 }, { -40, 16 }, { 40, 16 }, { -20, -32 }, { 22, -32 }, { 0, 30 }, { -30, -104 }, { 30, -56 }, { -78, -50 } } do
	check(at(p[1], 3, p[2]) == "Air" and solid(at(p[1], -1, p[2])), `town ground at {p[1]},{p[2]}`)
end

-- A walkable line from the lobby to every gather region: slope < 35 deg between 4-stud samples, no water.
local MAX_STEP = 4 * math.tan(math.rad(35))
for _, name in { "lake_pier", "sea_pier", "mine_mouth", "pine", "woods", "grove" } do
	local a, b = S.lobby, S[name]
	local len = math.sqrt((b.x - a.x) ^ 2 + (b.z - a.z) ^ 2)
	local n = math.ceil(len / 4)
	local ok, prev = true, Terrain.height(a.x, a.z)
	for i = 1, n do
		local x, z = a.x + (b.x - a.x) * i / n, a.z + (b.z - a.z) * i / n
		local h = Terrain.height(x, z)
		if math.abs(h - prev) > MAX_STEP or Regions.isWater(x, z) then
			ok = false
			print(`  blocked at {math.floor(x)},{math.floor(z)} step {h - prev}`)
			break
		end
		prev = h
	end
	check(ok, "walkable lobby -> " .. name)
end

-- Mine: walkable tunnel from the mouth down through all three caverns, with rock overhead.
local path = Terrain.TUNNEL
for i = 1, #path - 1 do
	local a, b = path[i], path[i + 1]
	local len = math.sqrt((b.x - a.x) ^ 2 + (b.z - a.z) ^ 2)
	check(math.abs(b.y - a.y) / len < math.tan(math.rad(35)), `tunnel leg {i} not too steep`)
	for t = 0, 1, 0.1 do
		local x, y, z = a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t, a.z + (b.z - a.z) * t
		check(at(x, y + 3, z) == "Air" and solid(at(x, y - 1, z)), `tunnel leg {i} walkable at t={t}`)
	end
end
for _, name in { "ore_mouth", "ore_deep", "ore_crystal" } do
	local p = S[name]
	check(solid(at(p.x, p.y + 30, p.z)), name .. " is underground") -- caverns are up to 26 tall
end

-- Mountain ring closes the map: tall at radius 540 all the way round.
local C = Regions.CENTER
for deg = 0, 358, 2 do
	local a = math.rad(deg)
	check(Terrain.height(C.x + 540 * math.cos(a), C.z + 540 * math.sin(a)) > 100, `ring closed at {deg} deg`)
end

-- Spawn: the lobby spawn pad sits above the generated ground.
check(S.lobby.y + 0.6 > Terrain.height(S.lobby.x, S.lobby.z + 8), "spawn above ground")
print("Terrain.spec passed")
