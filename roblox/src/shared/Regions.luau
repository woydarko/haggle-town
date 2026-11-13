--!strict
-- Map layout shared by server (terrain shaping, fishing check) and client (fishing cast, compass).
-- Pure data: no Roblox globals, checked by roblox/tests/Regions.spec.luau.
-- Frame: the village is the origin (all v2 town code stands at y 0 around it); the map centre is 300 north (+Z).
-- +X is east. The playable disc is ~500 studs around CENTER (about 1000 across), closed by a mountain ring.

type P = { x: number, z: number }

local Regions = {}

Regions.CENTER = { x = 0, z = 150 }
Regions.VILLAGE = { x = 0, z = -20, r = 120 } -- flat; blends to hills by r + 100
Regions.LAKE = { x = 0, z = 300, r = 130 }
Regions.MINE = { x = 325, z = 150, r = 150 } -- mountain with the caverns
Regions.GROVE = { x = -440, z = 150, r = 80 } -- ancient grove, far west
Regions.RING_IN = 480 -- ring starts rising here (from CENTER)
Regions.RING_OUT = 560 -- ring top
-- Sea: past SEA_D along the south-east diagonal from CENTER, inside RING_IN.
Regions.SEA_D = 340
local DIAG = { x = math.sqrt(0.5), z = -math.sqrt(0.5) } -- south-east (+X, -Z)

local function dist(x: number, z: number, p: P): number
	return math.sqrt((x - p.x) ^ 2 + (z - p.z) ^ 2)
end
Regions.dist = dist

-- Distance along the coast diagonal from CENTER (the sea is where this passes SEA_D).
function Regions.coastD(x: number, z: number): number
	return (x - Regions.CENTER.x) * DIAG.x + (z - Regions.CENTER.z) * DIAG.z
end

-- Point `d` studs along the coast diagonal, `s` studs sideways.
function Regions.along(d: number, s: number?): P
	local side = s or 0
	return { x = Regions.CENTER.x + DIAG.x * d - DIAG.z * side, z = Regions.CENTER.z + DIAG.z * d + DIAG.x * side }
end

function Regions.inLake(x: number, z: number): boolean
	return dist(x, z, Regions.LAKE) < Regions.LAKE.r
end

function Regions.inSea(x: number, z: number): boolean
	return Regions.coastD(x, z) > Regions.SEA_D and dist(x, z, Regions.CENTER) < Regions.RING_IN
end

function Regions.isWater(x: number, z: number): boolean
	return Regions.inLake(x, z) or Regions.inSea(x, z)
end

-- Backend gather node for a cast landing at (x, z): lake -> fish, sea -> fish_deep, land -> nil.
-- The lake edge keeps a 6-stud margin so a cast onto the beach never counts.
function Regions.fishNodeAt(x: number, z: number): string?
	if dist(x, z, Regions.LAKE) < Regions.LAKE.r - 6 then
		return "fish"
	elseif Regions.inSea(x, z) and Regions.coastD(x, z) > Regions.SEA_D + 6 then
		return "fish_deep"
	end
	return nil
end

-- Server check of a bobber landing point cast from (fx, fz): the backend node, or nil + "bad" (not a number),
-- "far" (beyond maxDist) or "land" (not fishable water).
function Regions.castNode(fx: number, fz: number, tx: number, tz: number, maxDist: number): (string?, string?)
	local d = math.sqrt((tx - fx) ^ 2 + (tz - fz) ^ 2)
	if d ~= d or math.abs(tx) == math.huge or math.abs(tz) == math.huge then
		return nil, "bad"
	elseif d > maxDist then
		return nil, "far"
	end
	local node = Regions.fishNodeAt(tx, tz)
	if not node then
		return nil, "land"
	end
	return node, nil
end

function Regions.regionAt(x: number, z: number): string
	if dist(x, z, Regions.CENTER) > Regions.RING_IN + 30 then
		return "peaks"
	elseif Regions.coastD(x, z) > Regions.SEA_D - 30 then
		return "coast"
	elseif Regions.inLake(x, z) then
		return "lake"
	elseif dist(x, z, Regions.VILLAGE) < Regions.VILLAGE.r + 60 then
		return "village"
	elseif dist(x, z, Regions.MINE) < Regions.MINE.r + 10 then
		return "mine"
	elseif dist(x, z, Regions.GROVE) < Regions.GROVE.r then
		return "grove"
	elseif x < -100 and z > 250 then
		return "pine"
	elseif x < -100 then
		return "woods"
	end
	return "meadow"
end

return Regions
