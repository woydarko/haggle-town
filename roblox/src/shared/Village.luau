--!strict
-- Village layout as data (pure, checked by roblox/tests/Village.spec.luau); World.luau and Lobby.luau place parts
-- from it. Frame: origin = village centre area, +Z north, +X east, ground at y 0 (flat village ground r 120).
--
--                  Lake gate (0, 98)
--                        |
--        house  house    |    house  house
--   Woods gate ---- [  SQUARE  ] ---- Mine gate
--        house  house  ledger \   house  house
--                        |     \ Coast gate (84, -60)
--                   guild yard + spawn
--
-- yaw: CFrame.Angles(0, rad(yaw), 0); the house front (LookVector) faces its street.

type P = { x: number, z: number }

local Village = {}

Village.SQUARE = { x = 0, z = 10, w = 60, d = 44 } -- x -30..30, z -12..32
Village.STALLS = {
	woodcutter = { x = -22, z = 8 },
	fishmonger = { x = 0, z = 30 },
	smith = { x = 22, z = 8 },
}
Village.WELL = { x = 0, z = 12 }
Village.LEDGER = { x = 0, z = -14, yaw = 180 } -- on the square's south edge, facing the spawn road
Village.GUILD = { x = 0, z = -80 } -- guild yard with the mentors (Lobby.luau builds it here)
Village.SPAWN = { x = 0, z = -72 }

local function road(name: string, from: P, to: P)
	return { name = name, from = from, to = to }
end
Village.ROADS = {
	road("Lake", { x = 0, z = 32 }, { x = 0, z = 98 }),
	road("Woods", { x = -30, z = 10 }, { x = -110, z = 10 }),
	road("Mine", { x = 30, z = 10 }, { x = 110, z = 10 }),
	road("Coast", { x = 26, z = -12 }, { x = 84, z = -60 }),
	road("Guild", { x = 0, z = -12 }, { x = 0, z = -56 }),
}

-- Gates sit at the road ends; dest = Terrain.SPOTS name the signpost points to.
Village.GATES = {
	{ name = "Lake", x = 0, z = 98, dest = "lake_pier", label = "Lake and pier" },
	{ name = "Woods", x = -110, z = 10, dest = "woods", label = "Oak woods, pine forest" },
	{ name = "Mine", x = 110, z = 10, dest = "mine_mouth", label = "Mine" },
	{ name = "Coast", x = 84, z = -60, dest = "sea_pier", label = "Coast and sea pier" },
}

-- House plots (26 x 26 footprint: the largest scaled house is ~26 x 24), each facing its own street.
-- kind picks the house model (3 = the large one).
local function plot(x: number, z: number, yaw: number, roadName: string, kind: number)
	return { x = x, z = z, yaw = yaw, w = 26, d = 26, road = roadName, kind = kind }
end
Village.PLOTS = {
	plot(-22, 56, -90, "Lake", 3),
	plot(22, 56, 90, "Lake", 1),
	plot(-22, 82, -90, "Lake", 2),
	plot(22, 82, 90, "Lake", 2),
	plot(-56, 34, 0, "Woods", 1),
	plot(-84, 34, 0, "Woods", 2),
	plot(-56, -14, 180, "Woods", 2),
	plot(-84, -14, 180, "Woods", 1),
	plot(56, 34, 0, "Mine", 2),
	plot(84, 34, 0, "Mine", 1),
	plot(56, -14, 180, "Mine", 1),
	plot(84, -14, 180, "Mine", 2),
}

return Village
