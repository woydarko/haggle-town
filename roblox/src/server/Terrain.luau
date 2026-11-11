--!strict
-- Deterministic big map (~2000 studs across), generated at server start so git stays the source of truth.
-- height(), material() and materialAt() are pure (math.noise only) so roblox/tests/Terrain.spec.luau checks the layout;
-- build() writes them with chunked WriteVoxels and carves the mine caverns.
-- Layout lives in shared/Regions.luau (village at the origin, lake north, mine east, coast south-east, ring around).

local Regions: any = if script
	then require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Regions"))
	else (require :: any)("../shared/Regions") -- lute specs

export type V = { x: number, y: number, z: number }

local Terrain = {}

Terrain.WATER_Y = 0 -- lake and sea surface
local WATER_Y = Terrain.WATER_Y
local MINE_FLOOR = 6 -- flat ground around the mine mountain foot = tunnel floor at the mouth
local VOX, CH = 4, 64 -- voxel size, chunk size (16 voxels)
local LAKE, MINE, VILLAGE, CENTER = Regions.LAKE, Regions.MINE, Regions.VILLAGE, Regions.CENTER
local dist = Regions.dist

local function smooth(t: number): number
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end
local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

function Terrain.height(x: number, z: number): number
	local h = math.max(2, 14 + math.noise(x / 350, z / 350, 0.37) * 20 + math.noise(x / 80, z / 80, 1.7) * 4)
	h = lerp(0, h, smooth((dist(x, z, VILLAGE) - VILLAGE.r) / 160)) -- village flat at y 0
	local dm = dist(x, z, MINE)
	h = lerp(MINE_FLOOR, h, smooth((dm - 380) / 160))
	local mt = 1 - smooth(dm / MINE.r)
	if mt > 0 then
		h = math.max(h, mt * (150 + math.noise(x / 60, z / 60, 3.3) * 15))
	end
	local rt = smooth((dist(x, z, CENTER) - Regions.RING_IN) / (Regions.RING_OUT - Regions.RING_IN))
	if rt > 0 then
		h = math.max(h, rt * (250 + math.noise(x / 150, z / 150, 5.1) * 40))
	end
	-- Lake basin with a 120-stud beach ramp.
	local dl = dist(x, z, LAKE)
	if dl < LAKE.r then
		h = WATER_Y - 1 - 13 * (1 - (dl / LAKE.r) ^ 2)
	elseif dl < LAKE.r + 120 then
		h = lerp(WATER_Y + 0.5, h, smooth((dl - LAKE.r) / 120))
	end
	-- Sea past the coast line, inside the ring; 140-stud beach ramp.
	if dist(x, z, CENTER) < Regions.RING_IN then
		local cd = Regions.coastD(x, z)
		if cd > Regions.SEA_D then
			h = WATER_Y - 1 - math.min(22, (cd - Regions.SEA_D) * 0.25)
		elseif cd > Regions.SEA_D - 140 then
			h = lerp(WATER_Y + 0.5, h, smooth((Regions.SEA_D - cd) / 140))
		end
	end
	return h
end

-- Surface material from height and slope (studs of rise per stud).
local function surface(x: number, z: number, h: number, slope: number): string
	if h < WATER_Y - 0.25 then
		return if h < WATER_Y - 8 then "Mud" else "Sand"
	elseif h < WATER_Y + 3 and (dist(x, z, LAKE) < LAKE.r + 120 or Regions.coastD(x, z) > Regions.SEA_D - 140) then
		return "Sand"
	elseif h >= 170 then
		return "Snow"
	elseif slope > 0.9 then
		return "Rock"
	elseif slope > 0.55 then
		return "Ground"
	end
	local region = Regions.regionAt(x, z)
	return if region == "pine" or region == "grove" then "LeafyGrass" else "Grass"
end

-- Below the surface: a thin soil layer, then rock.
local function layer(top: string, depth: number): string
	if depth > 6 then
		return "Rock"
	elseif depth > 4 and top ~= "Sand" and top ~= "Mud" and top ~= "Snow" then -- one full voxel of surface material
		return "Ground"
	end
	return top
end

function Terrain.material(x: number, y: number, z: number): string
	local H = Terrain.height
	local h = H(x, z)
	local slope = math.max(math.abs(H(x + 2, z) - H(x - 2, z)), math.abs(H(x, z + 2) - H(x, z - 2))) / 4
	return layer(surface(x, z, h, slope), h - y)
end

-- Mine: walkable floor polyline from the mouth through three caverns (mouth, deep, crystal).
local function v(x: number, y: number, z: number): V
	return { x = x, y = y, z = z }
end
Terrain.TUNNEL = { v(350, 6, 300), v(490, 6, 300), v(520, 6, 300), v(606, -22, 300), v(606, -40, 412) }
local CAVERNS = { { at = 2, r = 14 }, { at = 4, r = 16 }, { at = 5, r = 16 } }
-- Air balls carved after the heightmap: radius 7 every 3 studs along the floor, plus the caverns.
local BALLS: { { c: V, r: number } } = {}
do
	local T = Terrain.TUNNEL
	for i = 1, #T - 1 do
		local a, b = T[i], T[i + 1]
		local n = math.ceil(math.sqrt((b.x - a.x) ^ 2 + (b.y - a.y) ^ 2 + (b.z - a.z) ^ 2) / 3)
		for s = 0, n do
			local t = s / n
			table.insert(BALLS, { c = v(lerp(a.x, b.x, t), lerp(a.y, b.y, t) + 7, lerp(a.z, b.z, t)), r = 7 })
		end
	end
	for _, cv in CAVERNS do
		local p = T[cv.at]
		table.insert(BALLS, { c = v(p.x, p.y + cv.r, p.z), r = cv.r })
	end
end

local function carved(p: V): boolean
	for _, b in BALLS do
		if (p.x - b.c.x) ^ 2 + (p.y - b.c.y) ^ 2 + (p.z - b.c.z) ^ 2 <= b.r * b.r then
			return true
		end
	end
	return false
end

-- Material at a point of the finished map (build() only writes a crust under open ground; the spec treats it as solid).
function Terrain.materialAt(p: V): string
	if carved(p) then
		return "Air"
	end
	if p.y < Terrain.height(p.x, p.z) then
		return Terrain.material(p.x, p.y, p.z)
	elseif p.y < WATER_Y and Regions.isWater(p.x, p.z) then
		return "Water"
	end
	return "Air"
end

local function ground(x: number, z: number): V
	return v(x, Terrain.height(x, z), z)
end
local seaPier, seaSpot = Regions.along(Regions.SEA_D - 30), Regions.along(Regions.SEA_D + 40)
local T = Terrain.TUNNEL
-- Where things stand. World/Lobby/Nodes place parts here; y is the ground (water surface for fishing spots).
Terrain.SPOTS = {
	lobby = v(0, 0, -80),
	square = v(0, 0, 5),
	wood = v(-45, 0, -30),
	fish = v(0, WATER_Y, LAKE.z - LAKE.r + 32), -- end of the lake pier
	fish_deep = v(seaSpot.x, WATER_Y, seaSpot.z), -- end of the sea pier
	lake_pier = ground(0, LAKE.z - LAKE.r - 20),
	sea_pier = ground(seaPier.x, seaPier.z),
	mine_mouth = ground(340, 300),
	ore_mouth = T[2],
	ore_deep = T[4],
	ore_crystal = T[5],
	pine = ground(-550, 760),
	woods = ground(-450, 200),
	grove = ground(Regions.GROVE.x, Regions.GROVE.z),
}

local function buildChunk(t: Terrain, mats: { [string]: Enum.Material }, cx: number, cz: number)
	local N = CH // VOX
	local hs = table.create(N + 2)
	for i = 0, N + 1 do
		local row = table.create(N + 2)
		for k = 0, N + 1 do
			row[k + 1] = Terrain.height(cx + (i - 1) * VOX + 2, cz + (k - 1) * VOX + 2)
		end
		hs[i + 1] = row
	end
	local lo, hi = math.huge, -math.huge
	local bottom = table.create(N * N)
	for i = 1, N do
		for k = 1, N do
			local x, z = cx + (i - 1) * VOX + 2, cz + (k - 1) * VOX + 2
			local h = hs[i + 1][k + 1]
			-- Fill down past the lowest neighbour so steep faces have no gaps; the mine is solid for the caverns.
			local b = if dist(x, z, MINE) < MINE.r + 30
				then -64
				else math.min(h, hs[i][k + 1], hs[i + 2][k + 1], hs[i + 1][k], hs[i + 1][k + 2]) - 8
			bottom[(i - 1) * N + k] = b
			lo = math.min(lo, b)
			hi = math.max(hi, h, if Regions.isWater(x, z) then WATER_Y else h)
		end
	end
	lo, hi = math.floor(lo / VOX) * VOX, math.ceil(hi / VOX) * VOX + VOX
	local ny = (hi - lo) // VOX
	local m, o = table.create(N), table.create(N)
	for i = 1, N do
		local mi, oi = table.create(ny), table.create(ny)
		for j = 1, ny do
			mi[j], oi[j] = table.create(N, mats.Air), table.create(N, 0)
		end
		m[i], o[i] = mi, oi
		for k = 1, N do
			local x, z = cx + (i - 1) * VOX + 2, cz + (k - 1) * VOX + 2
			local h = hs[i + 1][k + 1]
			local slope = math.max(math.abs(hs[i + 2][k + 1] - hs[i][k + 1]), math.abs(hs[i + 1][k + 2] - hs[i + 1][k])) / (2 * VOX)
			local top = surface(x, z, h, slope)
			local water = h < WATER_Y and Regions.isWater(x, z)
			local b = bottom[(i - 1) * N + k]
			for j = 1, ny do
				local yb = lo + (j - 1) * VOX
				-- Smooth terrain draws the surface half a voxel above the filled fraction (measured in Studio: +2).
				local f = math.clamp((h - VOX / 2 - yb) / VOX, 0, 1)
				if f > 0 and yb + VOX > b then
					mi[j][k], oi[j][k] = mats[layer(top, h - VOX / 2 - (yb + VOX))], f
				elseif water and f == 0 and yb < WATER_Y then
					mi[j][k], oi[j][k] = mats.Water, math.clamp((WATER_Y - yb) / VOX, 0, 1)
				end
			end
		end
	end
	t:WriteVoxels(Region3.new(Vector3.new(cx, lo, cz), Vector3.new(cx + CH, hi, cz + CH)), VOX, m, o)
end

-- Invisible wall on the ring crest so nobody climbs out of the map.
local function bounds()
	local folder = Instance.new("Folder")
	folder.Name = "MapBounds"
	local n, r = 64, Regions.RING_OUT
	for i = 0, n - 1 do
		local a = i / n * 2 * math.pi
		local pos = Vector3.new(CENTER.x + r * math.cos(a), 250, CENTER.z + r * math.sin(a))
		local p = Instance.new("Part")
		p.Name = "Bound"
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, true, false, false, false
		p.Transparency = 1
		p.Size = Vector3.new(2 * math.pi * r / n + 12, 700, 4)
		p.CFrame = CFrame.lookAt(pos, Vector3.new(CENTER.x, 250, CENTER.z))
		p.Parent = folder
	end
	folder.Parent = workspace
end

-- Writes the whole map. Yields every ~30 ms; onProgress gets 0..1.
function Terrain.build(onProgress: ((number) -> ())?)
	local t = workspace.Terrain
	t:Clear()
	t.WaterColor = Color3.fromHex("3E8FA8")
	t.WaterWaveSize = 0.12
	t:SetMaterialColor(Enum.Material.Grass, Color3.fromHex("7FA35B"))
	t:SetMaterialColor(Enum.Material.LeafyGrass, Color3.fromHex("5E8A47"))
	t:SetMaterialColor(Enum.Material.Sand, Color3.fromHex("D9C79A"))
	local mats: { [string]: Enum.Material } = {}
	for _, name in { "Air", "Water", "Grass", "LeafyGrass", "Sand", "Mud", "Snow", "Rock", "Ground" } do
		mats[name] = (Enum.Material :: any)[name]
	end
	local ext = Regions.RING_OUT + 96
	local x0, x1 = math.floor((CENTER.x - ext) / CH) * CH, math.ceil((CENTER.x + ext) / CH) * CH
	local z0, z1 = math.floor((CENTER.z - ext) / CH) * CH, math.ceil((CENTER.z + ext) / CH) * CH
	local chunks = {}
	for cx = x0, x1 - CH, CH do
		for cz = z0, z1 - CH, CH do
			local nx, nz = math.clamp(CENTER.x, cx, cx + CH), math.clamp(CENTER.z, cz, cz + CH)
			if dist(nx, nz, CENTER) <= ext then
				table.insert(chunks, { cx, cz })
			end
		end
	end
	local last = os.clock()
	for i, c in chunks do
		buildChunk(t, mats, c[1], c[2])
		if os.clock() - last > 0.03 then
			if onProgress then
				onProgress(i / #chunks)
			end
			task.wait()
			last = os.clock()
		end
	end
	for _, b in BALLS do
		t:FillBall(Vector3.new(b.c.x, b.c.y, b.c.z), b.r, Enum.Material.Air)
	end
	bounds()
	if onProgress then
		onProgress(1)
	end
end

return Terrain
