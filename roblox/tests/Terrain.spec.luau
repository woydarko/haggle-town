-- Run: lute run roblox/tests/Terrain.spec.luau
-- The map is never seen outside Studio, so these checks walk the terrain plan as data.
local Terrain = require("../src/server/Terrain")

local function check(cond, name)
	if not cond then
		error("FAIL " .. name)
	end
	print("ok", name)
end
local function at(x, y, z)
	return Terrain.materialAt({ x = x, y = y, z = z })
end
local S = Terrain.SPOTS

-- Every land spot has open air to stand in and solid ground under it.
for _, name in { "lobby", "square", "wood", "ore_mouth", "ore_deep" } do
	local p = S[name]
	check(at(p.x, 3, p.z) == "Air", name .. " is open")
	local floor = at(p.x, -1, p.z)
	check(floor ~= "Air" and floor ~= "Water", name .. " has ground")
end
check(at(S.fish.x, -1, S.fish.z) == "Water", "fishing spot is over the lake")
check(at(0, -1, 50) ~= "Water", "town edge is dry land")

-- Town buildings, stalls and the lobby are not buried in rock.
for _, p in { { -40, -8 }, { -40, 16 }, { 40, 16 }, { -20, -32 }, { 22, -32 }, { -22, 8 }, { 0, 30 }, { 22, 8 }, { -30, -104 }, { 30, -56 }, { -60, -40 } } do
	check(at(p[1], 3, p[2]) == "Air", `open at {p[1]},{p[2]}`)
end

-- Cave: walkable tunnel from the hill face to the deep chamber, with a roof over it.
for x = 60, 124, 4 do
	check(at(x, 3, S.ore_mouth.z) == "Air", `tunnel open at x={x}`)
end
check(at(100, 24, S.ore_mouth.z) == "Rock", "tunnel has a roof")
check(at(S.ore_deep.x, 24, S.ore_deep.z) == "Rock", "deep chamber is underground")

-- Mountain ring closes the valley: no gap at radius 200.
for deg = 0, 355, 5 do
	local a = math.rad(deg)
	local m = at(200 * math.cos(a), 3, 200 * math.sin(a))
	check(m == "Rock" or m == "Snow", `ring closed at {deg} deg`)
end

-- Every spot is within a 30 s walk (16 studs/s) of the lobby.
for name, p in S do
	local d = math.sqrt((p.x - S.lobby.x) ^ 2 + (p.z - S.lobby.z) ^ 2)
	check(d < 480, name .. " near the lobby")
end
print("Terrain.spec passed")
