-- Run: lute run roblox/tests/Village.spec.luau
-- The village is laid out as data so the plan can be checked: houses on plots beside streets, nothing on a road,
-- everything on the flat village ground, four gates at the street ends.
local Village = require("../src/shared/Village")
local Regions = require("../src/shared/Regions")

local function check(cond, name)
	if not cond then
		error("FAIL " .. name)
	end
	print("ok", name)
end

local V = Regions.VILLAGE
local function fromCentre(p)
	return math.sqrt((p.x - V.x) ^ 2 + (p.z - V.z) ^ 2)
end
-- Distance from point p to the segment a-b, and the closest point on it.
local function toSegment(p, a, b)
	local dx, dz = b.x - a.x, b.z - a.z
	local t = math.clamp(((p.x - a.x) * dx + (p.z - a.z) * dz) / (dx * dx + dz * dz), 0, 1)
	local cx, cz = a.x + dx * t, a.z + dz * t
	return math.sqrt((p.x - cx) ^ 2 + (p.z - cz) ^ 2), { x = cx, z = cz }
end
local roads = {}
for _, r in Village.ROADS do
	roads[r.name] = r
end
local ROAD_HALF = 3 -- roads are 6 studs wide
local S = Village.SQUARE

check(#Village.PLOTS >= 9, "at least 9 house plots") -- 34-stud plots since v5 (bigger houses)
for i, p in Village.PLOTS do
	local r = math.max(p.w, p.d) / 2
	check(fromCentre(p) + r <= V.r + 2, `plot {i} on flat village ground`)
	for j, q in Village.PLOTS do
		if j > i then
			check(math.sqrt((p.x - q.x) ^ 2 + (p.z - q.z) ^ 2) >= r + math.max(q.w, q.d) / 2, `plots {i} and {j} do not overlap`)
		end
	end
	for _, road in Village.ROADS do
		check(toSegment(p, road.from, road.to) >= r + ROAD_HALF, `plot {i} clear of the {road.name} road`)
	end
	check(math.abs(p.x - S.x) >= S.w / 2 + r or math.abs(p.z - S.z) >= S.d / 2 + r, `plot {i} clear of the square`)
	-- Front (LookVector of CFrame.Angles(0, yaw, 0)) points at its own street within 15 degrees.
	local own = roads[p.road]
	check(own ~= nil, `plot {i} names a real road`)
	local d, near = toSegment(p, own.from, own.to)
	check(d <= 30, `plot {i} sits beside the {p.road} road`)
	local look = { x = -math.sin(math.rad(p.yaw)), z = -math.cos(math.rad(p.yaw)) }
	local want = { x = (near.x - p.x) / d, z = (near.z - p.z) / d }
	check(look.x * want.x + look.z * want.z >= math.cos(math.rad(15)), `plot {i} faces the {p.road} road`)
end

-- Fixed places of the town are on the flat ground and off the roads they do not belong to.
for name, p in { well = Village.WELL, guild = Village.GUILD, spawn = Village.SPAWN } do
	check(fromCentre(p) <= V.r, name .. " on flat village ground")
end
for name, st in Village.STALLS do
	check(math.abs(st.x - S.x) <= S.w / 2 and math.abs(st.z - S.z) <= S.d / 2, name .. " stall on the square")
end
check(math.abs(Village.WELL.x - S.x) <= S.w / 2 and math.abs(Village.WELL.z - S.z) <= S.d / 2, "well on the square")
check(Village.SPAWN.z < S.z - S.d / 2 and Village.SPAWN.z > Village.GUILD.z - 30, "spawn between the guild yard and the square")

-- Four gates at the ends of their roads, each road starting at the square's edge.
local names = {}
for _, g in Village.GATES do
	names[g.name] = true
	local road = roads[g.name]
	check(road ~= nil and math.abs(road.to.x - g.x) < 0.01 and math.abs(road.to.z - g.z) < 0.01, `{g.name} gate at the end of its road`)
	check(fromCentre(g) <= V.r, `{g.name} gate on the village edge, inside the flat ground`)
	check(type(g.dest) == "string" and #g.dest > 0, `{g.name} gate points somewhere`)
	local f = road.from
	local onEdge = math.abs(math.abs(f.x - S.x) - S.w / 2) <= 1 or math.abs(math.abs(f.z - S.z) - S.d / 2) <= 1
	check(onEdge, `{g.name} road starts at the square's edge`)
end
for _, n in { "Woods", "Lake", "Mine", "Coast" } do
	check(names[n], `gate {n} exists`)
end
check(Village.LEDGER == nil, "no ledger board in the square (v6: the ledger is a pop-up)")
print("Village.spec passed")
