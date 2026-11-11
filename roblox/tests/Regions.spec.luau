-- Run: lute run roblox/tests/Regions.spec.luau
-- Region lookup shared by server (terrain, fishing check) and client (fishing cast, compass).
local Regions = require("../src/shared/Regions")

local function check(cond, name)
	if not cond then
		error("FAIL " .. name)
	end
	print("ok", name)
end

local L, V, M, G = Regions.LAKE, Regions.VILLAGE, Regions.MINE, Regions.GROVE
local seaPoint = Regions.along(Regions.SEA_D + 60) -- 60 studs out to sea on the coast diagonal
local shore = Regions.along(Regions.SEA_D - 40)

-- fishNodeAt: lake -> fish, sea -> fish_deep, land -> nil
check(Regions.fishNodeAt(L.x, L.z) == "fish", "lake centre is fish")
check(Regions.fishNodeAt(L.x, L.z - L.r + 20) == "fish", "near the lake shore is still fish")
check(Regions.fishNodeAt(seaPoint.x, seaPoint.z) == "fish_deep", "sea is fish_deep")
check(Regions.fishNodeAt(V.x, V.z) == nil, "village is land")
check(Regions.fishNodeAt(L.x, L.z - L.r - 20) == nil, "lake shore is land")
check(Regions.fishNodeAt(shore.x, shore.z) == nil, "sea shore is land")
check(Regions.fishNodeAt(M.x, M.z) == nil, "mine is land")
check(Regions.fishNodeAt(0 / 0, 5) == nil and Regions.fishNodeAt(1e9, 1e9) == nil, "NaN and far away are not water")

-- regionAt names the big areas
check(Regions.regionAt(V.x, V.z) == "village", "village")
check(Regions.regionAt(L.x, L.z) == "lake", "lake")
check(Regions.regionAt(M.x, M.z) == "mine", "mine")
check(Regions.regionAt(G.x, G.z) == "grove", "grove")
check(Regions.regionAt(seaPoint.x, seaPoint.z) == "coast", "sea is coast")
check(Regions.regionAt(-550, 760) == "pine", "north-west pine forest")
check(Regions.regionAt(-450, 200) == "woods", "west woods")
local c = Regions.CENTER
check(Regions.regionAt(c.x + 1100, c.z) == "peaks", "ring is peaks")

-- isWater agrees with fishNodeAt
check(Regions.isWater(L.x, L.z) and Regions.isWater(seaPoint.x, seaPoint.z), "lake and sea are water")
check(not Regions.isWater(V.x, V.z), "village is dry")
-- The sea stays inside the mountain ring (the ring closes the map).
for s = -700, 700, 50 do
	local p = Regions.along(Regions.SEA_D + 100, s)
	local r = math.sqrt((p.x - c.x) ^ 2 + (p.z - c.z) ^ 2)
	check(not Regions.isWater(p.x, p.z) or r < Regions.RING_IN, `sea inside the ring at s={s}`)
end
print("Regions.spec passed")
