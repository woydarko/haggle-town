--!strict
-- Deterministic terrain: grass valley, lake with a sand beach north of town, a closed mountain ring with snow caps,
-- and an east hill with a cave (tunnel -> mouth chamber -> deep chamber).
-- plan() and materialAt() are pure data (no Roblox globals) so roblox/tests/Terrain.spec.luau checks the layout.

export type V = { x: number, y: number, z: number }
export type Op = { kind: string, mat: string, c: V, size: V?, r: number? }

local function v(x: number, y: number, z: number): V
	return { x = x, y = y, z = z }
end

local Terrain = {}

-- Where things stand (ground level y = 0). World/Lobby place their parts here.
Terrain.SPOTS = {
	lobby = v(0, 0, -80),
	square = v(0, 0, 5),
	fish = v(0, 0, 66),
	wood = v(-45, 0, -30),
	ore_mouth = v(88, 0, -30),
	ore_deep = v(124, 0, -30),
}

local RING_R, PEAK_R = 230, 70 -- ring of 18 peaks; inner foot at ~160 studs from the town
local HILL = v(130, 0, -30) -- cave hill, its west face at x ~70

function Terrain.plan(): { Op }
	local ops: { Op } = {}
	local function block(mat: string, c: V, size: V)
		table.insert(ops, { kind = "block", mat = mat, c = c, size = size })
	end
	local function ball(mat: string, c: V, r: number)
		table.insert(ops, { kind = "ball", mat = mat, c = c, r = r })
	end
	block("Grass", v(0, -4, 0), v(520, 8, 520)) -- valley floor, top at y 0 (voxel aligned)
	block("Water", v(0, -6, 112), v(300, 12, 116)) -- lake, z 54..170
	block("Sand", v(0, -1, 55), v(300, 2, 6)) -- beach under the pier start, z 52..58
	for i = 0, 17 do
		local a = math.rad(i * 20)
		local x, z = RING_R * math.cos(a), RING_R * math.sin(a)
		ball("Rock", v(x, 10, z), PEAK_R)
		ball("Snow", v(x, 62, z), 24) -- only pokes out above the peak: a cap
	end
	ball("Rock", HILL, 60)
	ball("Snow", v(HILL.x, 52, HILL.z), 18)
	-- Cave, carved last: tunnel x 64..140 (12 wide, 12 high), then two chambers on the same line.
	block("Air", v(102, 6, HILL.z), v(76, 12, 12))
	block("Air", v(Terrain.SPOTS.ore_mouth.x, 8, HILL.z), v(28, 16, 28))
	block("Air", v(Terrain.SPOTS.ore_deep.x, 10, HILL.z), v(32, 20, 32))
	return ops
end

local function inside(op: Op, p: V): boolean
	if op.kind == "ball" then
		local r = op.r :: number
		return (p.x - op.c.x) ^ 2 + (p.y - op.c.y) ^ 2 + (p.z - op.c.z) ^ 2 <= r * r
	end
	local s = op.size :: V
	return math.abs(p.x - op.c.x) <= s.x / 2 and math.abs(p.y - op.c.y) <= s.y / 2 and math.abs(p.z - op.c.z) <= s.z / 2
end

-- Material at a point after all ops (later ops overwrite earlier ones, like Terrain fills).
function Terrain.materialAt(p: V): string
	local mat = "Air"
	for _, op in Terrain.plan() do
		if inside(op, p) then
			mat = op.mat
		end
	end
	return mat
end

function Terrain.build()
	local t = workspace.Terrain
	t:Clear()
	t.WaterColor = Color3.fromHex("3E8FA8")
	t:SetMaterialColor(Enum.Material.Grass, Color3.fromHex("7FA35B"))
	for _, op in Terrain.plan() do
		local mat = (Enum.Material :: any)[op.mat]
		local c = Vector3.new(op.c.x, op.c.y, op.c.z)
		if op.kind == "ball" then
			t:FillBall(c, op.r :: number, mat)
		else
			local s = op.size :: V
			t:FillBlock(CFrame.new(c), Vector3.new(s.x, s.y, s.z), mat)
		end
	end
end

return Terrain
