--!strict
-- Builds the market town at runtime so the whole place lives in git (no binary .rbxl needed).
-- Contract with Main.server: build() returns nodes/merchants as BaseParts that carry a ProximityPrompt,
-- placed where players stand within 12 studs of them.
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Theme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Theme"))
local Terrain = require(script.Parent.Terrain)
local ServerStorage = game:GetService("ServerStorage")

local World = {}

-- Creator Store models curated into ServerStorage.Assets (roblox/assets, credits in roblox/ASSETS.md).
-- Every model has its pivot at the base; builders fall back to greybox parts when a folder is missing.
local function variants(folder: string, prefix: string): { Model }
	local f = ServerStorage:FindFirstChild("Assets") and (ServerStorage :: any).Assets:FindFirstChild(folder)
	local out = {}
	if f then
		for _, m in f:GetChildren() do
			if m:IsA("Model") and string.sub(m.Name, 1, #prefix) == prefix then
				table.insert(out, m)
			end
		end
		table.sort(out, function(a, b)
			return a.Name < b.Name
		end)
	end
	return out
end
-- Deterministic pick + yaw from the position, so the same tree looks the same every server start.
local function pick(list: { Model }, pos: Vector3): (Model?, number)
	if #list == 0 then
		return nil, 0
	end
	local h = math.abs(math.floor(pos.X * 7.13 + pos.Z * 3.71))
	return list[h % #list + 1], (h % 360)
end

local root: Folder

local WOOD_DARK = Color3.fromHex("6B4A2B")
local WOOD_LIGHT = Color3.fromHex("A9824F")
local STONE = Color3.fromHex("9C9488")
local CLOTH = Color3.fromHex("F3E6CC")

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		if k ~= "Parent" then
			(p :: any)[k] = v
		end
	end
	p.Parent = props.Parent or root
	return p
end

local function wedge(props: { [string]: any }): WedgePart
	local w = Instance.new("WedgePart")
	w.Anchored = true
	for k, v in props do
		if k ~= "Parent" then
			(w :: any)[k] = v
		end
	end
	w.Parent = props.Parent or root
	return w
end

local function prompt(parent: Instance, action: string, object: string)
	local pp = Instance.new("ProximityPrompt")
	pp.ActionText = action
	pp.ObjectText = object
	pp.HoldDuration = 0
	pp.MaxActivationDistance = 10
	pp.RequiresLineOfSight = false
	pp.Style = Enum.ProximityPromptStyle.Custom -- drawn by client/ui/Prompt.luau in the game's style
	pp.Parent = parent
end

local function label(parent: BasePart, text: string, color: Color3, height: number?)
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(200, 40)
	bb.StudsOffset = Vector3.new(0, height or 4, 0)
	bb.AlwaysOnTop = true
	bb.MaxDistance = 80
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.FontFace = Theme.display
	t.TextSize = 24
	t.TextColor3 = color
	t.TextStrokeTransparency = 0.4
	t.TextStrokeColor3 = Color3.new(1, 1, 1)
	t.Text = text
	t.Parent = bb
	bb.Parent = parent
end

local function signText(p: BasePart, text: string, color: Color3)
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Front
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 40
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundColor3 = CLOTH
	t.FontFace = Theme.display
	t.TextScaled = true
	t.TextColor3 = color
	t.Text = text
	t.Parent = sg
	sg.Parent = p
end

local function lamp(pos: Vector3)
	part({ Name = "LampPost", Size = Vector3.new(0.5, 9, 0.5), Position = pos + Vector3.new(0, 4.5, 0), Color = Color3.fromHex("2E2A26"), Material = Enum.Material.Metal })
	local bulb = part({ Name = "LampBulb", Shape = Enum.PartType.Ball, Size = Vector3.new(1.4, 1.4, 1.4), Position = pos + Vector3.new(0, 9.4, 0), Color = Color3.fromHex("FFD089"), Material = Enum.Material.Neon })
	local light = Instance.new("PointLight")
	light.Range = 18
	light.Brightness = 1.2
	light.Color = Color3.fromHex("FFC879")
	light.Parent = bulb
end

-- Places a copy of a curated asset model (pivot at its base) and returns it, or nil when the folder is empty.
local function place(folder: string, prefix: string, cf: CFrame, index: number?): Model?
	local list = variants(folder, prefix)
	if #list == 0 then
		return nil
	end
	local m = list[((index or 1) - 1) % #list + 1]:Clone()
	m:PivotTo(cf)
	m.Parent = root
	return m
end

local houseCount = 0
local function house(pos: Vector3, yaw: number, wall: Color3)
	local cf = CFrame.new(pos) * CFrame.Angles(0, math.rad(yaw), 0)
	houseCount += 1
	if place("Village", "House", cf, houseCount) then
		return
	end
	part({ Name = "HouseWall", Size = Vector3.new(12, 8, 10), CFrame = cf * CFrame.new(0, 4, 0), Color = wall, Material = Enum.Material.Plaster })
	part({ Name = "HouseBeam", Size = Vector3.new(12.4, 0.6, 10.4), CFrame = cf * CFrame.new(0, 8, 0), Color = WOOD_DARK, Material = Enum.Material.Wood })
	wedge({ Name = "Roof", Size = Vector3.new(13, 4, 6), CFrame = cf * CFrame.new(0, 10.3, 2.6), Color = Theme.primary, Material = Enum.Material.Slate })
	wedge({ Name = "Roof", Size = Vector3.new(13, 4, 6), CFrame = cf * CFrame.new(0, 10.3, -2.6) * CFrame.Angles(0, math.rad(180), 0), Color = Theme.primary, Material = Enum.Material.Slate })
	part({ Name = "Door", Size = Vector3.new(2.4, 4.4, 0.3), CFrame = cf * CFrame.new(0, 2.2, 5.05), Color = WOOD_DARK, Material = Enum.Material.Wood })
	for _, x in { -3.6, 3.6 } do
		part({ Name = "Window", Size = Vector3.new(2, 2, 0.3), CFrame = cf * CFrame.new(x, 4.6, 5.05), Color = Color3.fromHex("FFE2A8"), Material = Enum.Material.Neon, Transparency = 0.2 })
	end
end

local function path(from: Vector3, to: Vector3)
	local mid = (from + to) / 2
	local len = (to - from).Magnitude
	part({ Name = "Path", Size = Vector3.new(5, 0.25, len), CFrame = CFrame.lookAt(mid + Vector3.new(0, 0.12, 0), to + Vector3.new(0, 0.12, 0)), Color = Color3.fromHex("B8A88A"), Material = Enum.Material.Cobblestone })
end

-- title/action default to the merchant's name and "Haggle"; facing defaults to +Z.
local function npc(name: string, pos: Vector3, shirt: Color3, title: string?, action: string?, facing: Vector3?): BasePart
	local tag, verb, dir = title or Theme.merchantNames[name], action or "Haggle", facing or Vector3.new(0, 0, 1)
	local ok, model = pcall(function()
		local d = Instance.new("HumanoidDescription")
		local skin = Color3.fromHex("E8C39E")
		d.HeadColor, d.LeftArmColor, d.RightArmColor = skin, skin, skin
		d.TorsoColor = shirt
		d.LeftLegColor, d.RightLegColor = Color3.fromHex("4A3A2C"), Color3.fromHex("4A3A2C")
		return Players:CreateHumanoidModelFromDescription(d, Enum.HumanoidRigType.R15)
	end)
	if ok and model then
		local m = model :: Model
		m.Name = name
		local hum = m:FindFirstChildOfClass("Humanoid") :: Humanoid
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		local hrp = m:WaitForChild("HumanoidRootPart") :: BasePart
		m:PivotTo(CFrame.lookAt(pos + Vector3.new(0, 3, 0), pos + Vector3.new(0, 3, 0) + dir))
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
			end
		end
		m.Parent = root
		label(hrp, tag, shirt, 4.5)
		prompt(hrp, verb, tag)
		return hrp
	end
	-- Fallback if the rig cannot be created (e.g. offline Studio): the original simple figure.
	local body = part({ Name = name, Shape = Enum.PartType.Cylinder, Size = Vector3.new(4, 2.2, 2.2), CFrame = CFrame.new(pos + Vector3.new(0, 2, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = shirt })
	part({ Name = name .. "Head", Shape = Enum.PartType.Ball, Size = Vector3.new(1.8, 1.8, 1.8), Position = pos + Vector3.new(0, 4.9, 0), Color = Color3.fromHex("E8C39E") })
	label(body, tag, shirt)
	prompt(body, verb, tag)
	return body
end

local function goods(kind: string, top: Vector3)
	if kind == "wood" then
		for i = 0, 2 do
			for j = 0, 2 - i do
				part({ Name = "Log", Shape = Enum.PartType.Cylinder, Size = Vector3.new(3, 0.9, 0.9), CFrame = CFrame.new(top + Vector3.new(-2 + j * 0.95 + i * 0.47, 0.45 + i * 0.8, 0)), Color = WOOD_LIGHT, Material = Enum.Material.Wood })
			end
		end
	elseif kind == "fish" then
		part({ Name = "Crate", Size = Vector3.new(3, 0.9, 1.8), Position = top + Vector3.new(-1.5, 0.45, 0), Color = WOOD_LIGHT, Material = Enum.Material.WoodPlanks })
		part({ Name = "Ice", Size = Vector3.new(2.8, 0.2, 1.6), Position = top + Vector3.new(-1.5, 0.95, 0), Color = Color3.fromHex("DDEFF5"), Material = Enum.Material.Ice })
		for i = 0, 2 do
			wedge({ Name = "Fish", Size = Vector3.new(0.3, 0.4, 1.4), CFrame = CFrame.new(top + Vector3.new(-2.4 + i * 0.9, 1.2, 0)) * CFrame.Angles(0, math.rad(90), math.rad(90)), Color = Theme.fish, Material = Enum.Material.SmoothPlastic })
		end
	else
		for i = 0, 3 do
			part({ Name = "Ingot", Size = Vector3.new(1, 0.4, 0.5), Position = top + Vector3.new(-2.6 + (i % 2) * 1.1, 0.2 + math.floor(i / 2) * 0.4, (i % 2) * 0.1), Color = Color3.fromHex("8A9199"), Material = Enum.Material.Metal })
		end
	end
end

local function stall(name: string, kind: string, pos: Vector3, color: Color3): BasePart
	part({ Name = name .. "Counter", Size = Vector3.new(8, 3, 2.4), Position = pos + Vector3.new(0, 1.5, 3.4), Color = WOOD_DARK, Material = Enum.Material.WoodPlanks })
	part({ Name = name .. "CounterTop", Size = Vector3.new(8.4, 0.3, 2.8), Position = pos + Vector3.new(0, 3.15, 3.4), Color = WOOD_LIGHT, Material = Enum.Material.Wood })
	for _, x in { -4.2, 4.2 } do
		for _, z in { -1.2, 4.6 } do
			part({ Name = "Post", Size = Vector3.new(0.5, 7.4, 0.5), Position = pos + Vector3.new(x, 3.7, z), Color = WOOD_DARK, Material = Enum.Material.Wood })
		end
	end
	for i = 0, 5 do
		local stripe = if i % 2 == 0 then color else CLOTH
		part({ Name = "Awning", Size = Vector3.new(1.5, 0.25, 7.2), CFrame = CFrame.new(pos + Vector3.new(-3.75 + i * 1.5, 7.6, 1.7)) * CFrame.Angles(math.rad(-12), 0, 0), Color = stripe, Material = Enum.Material.Fabric })
	end
	local sign = part({ Name = name .. "Sign", Size = Vector3.new(6, 1.2, 0.3), Position = pos + Vector3.new(0, 6.5, 4.75), Color = CLOTH })
	signText(sign, Theme.merchantNames[name], color)
	goods(kind, pos + Vector3.new(0, 3.3, 3.4))
	if kind == "iron" then
		part({ Name = "AnvilBase", Size = Vector3.new(1.2, 1.4, 1), Position = pos + Vector3.new(3, 0.7, 0.5), Color = Color3.fromHex("3A3F45"), Material = Enum.Material.Metal })
		part({ Name = "AnvilTop", Size = Vector3.new(2.4, 0.6, 1.1), Position = pos + Vector3.new(3, 1.7, 0.5), Color = Color3.fromHex("3A3F45"), Material = Enum.Material.Metal })
	end
	return npc(name, pos, color)
end

local function board(name: string, cframe: CFrame): Part
	local b = part({ Name = name, Size = Vector3.new(14, 8, 0.6), CFrame = cframe, Color = WOOD_DARK, Material = Enum.Material.Wood })
	for _, x in { -6.5, 6.5 } do
		part({ Name = "BoardLeg", Size = Vector3.new(0.6, 5, 0.6), CFrame = cframe * CFrame.new(x, -5.5, 0), Color = WOOD_DARK, Material = Enum.Material.Wood })
	end
	local sg = Instance.new("SurfaceGui")
	sg.Name = "Gui"
	sg.Face = Enum.NormalId.Front
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 40
	sg.Parent = b
	return b
end

local function pier(pos: Vector3, shore: Vector3)
	-- Pier from the shore spot out over the water; a fishing spot (Nodes.luau) floats at its end.
	local a, b = shore + Vector3.new(0, 0.4, 0), Vector3.new(pos.X, pos.Y + 1.2, pos.Z)
	local len = (b - a).Magnitude
	local deck = CFrame.lookAt((a + b) / 2, b)
	part({ Name = "Pier", Size = Vector3.new(6, 0.4, len), CFrame = deck, Color = WOOD_LIGHT, Material = Enum.Material.WoodPlanks })
	for d = 4, len - 2, 8 do
		for _, x in { -2.7, 2.7 } do
			local top = (deck * CFrame.new(x, 0, len / 2 - d)).Position
			part({ Name = "PierPost", Size = Vector3.new(0.6, 8, 0.6), Position = top - Vector3.new(0, 4, 0), Color = WOOD_DARK, Material = Enum.Material.Wood })
		end
	end
	part({ Name = "Bucket", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.2, 1.2, 1.2), CFrame = CFrame.new(b + Vector3.new(2, 0.6, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = Theme.fish, Material = Enum.Material.Metal })
end

-- Spot snapped to the built terrain (voxel caverns can sit a few studs off the pure plan).
local function spot(name: string): Vector3
	local p = Terrain.SPOTS[name]
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.Terrain }
	local hit = workspace:Raycast(Vector3.new(p.x, p.y + 6, p.z), Vector3.new(0, -14, 0), params)
	return if hit then hit.Position else Vector3.new(p.x, p.y, p.z)
end

-- Greybox tree (Creator Store models replace it in Task 8). kind: 0 pine, 1 oak, 2 maple, 3 ancient redwood.
-- Returns the trunk (the part players hit); leaves never collide so nobody gets stuck in a canopy.
local TREE_PREFIX = { [0] = "Pine", [1] = "Oak", [2] = "Maple", [3] = "Redwood" }
local function tree(pos: Vector3, kind: number, parent: Instance?): Part
	local asset, yaw = pick(variants("Trees", TREE_PREFIX[kind] or "Oak"), pos)
	if asset then
		-- Model visuals never collide; an invisible trunk is the collider and the part players hit.
		local m = asset:Clone()
		m:PivotTo(CFrame.new(pos) * CFrame.Angles(0, math.rad(yaw), 0))
		local _, size = m:GetBoundingBox()
		for _, d in m:GetChildren() do
			d.Parent = parent or root
		end
		local w = if kind == 3 then 3.2 else 1.8
		return part({ Name = "Trunk", Size = Vector3.new(w, size.Y * 0.55, w), Position = pos + Vector3.new(0, size.Y * 0.275, 0), Color = WOOD_DARK, Material = Enum.Material.Wood, Transparency = 1, Parent = parent })
	end
	local tall = if kind == 3 then 18 else 9
	local trunk = part({ Name = "Trunk", Size = Vector3.new(if kind == 3 then 2.8 else 1.6, tall, if kind == 3 then 2.8 else 1.6), Position = pos + Vector3.new(0, tall / 2, 0), Color = WOOD_DARK, Material = Enum.Material.Wood, Parent = parent })
	if kind == 0 then
		for i, w in { 7, 5, 3 } do
			part({ Name = "Needles", Shape = Enum.PartType.Ball, Size = Vector3.new(w, 4, w), Position = pos + Vector3.new(0, 6 + i * 2.5, 0), Color = Color3.fromHex("2F5E35"), Material = Enum.Material.Grass, CanCollide = false, Parent = parent })
		end
	else
		local color = ({ "4F8F45", "C8642A", "35603A" })[kind]
		local size = if kind == 3 then Vector3.new(11, 8, 11) else Vector3.new(8, 7, 8)
		part({ Name = "Leaves", Shape = Enum.PartType.Ball, Size = size, Position = pos + Vector3.new(0, tall + 1.5, 0), Color = Color3.fromHex(color), Material = Enum.Material.Grass, CanCollide = false, Parent = parent })
	end
	return trunk
end

local function ambience()
	Lighting.ClockTime = 16.2
	Lighting.Brightness = 2.2
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.4
	Lighting.OutdoorAmbient = Color3.fromHex("8C8070")
	if not Lighting:FindFirstChildOfClass("Atmosphere") then
		local a = Instance.new("Atmosphere")
		a.Density = 0.3
		a.Haze = 1.2
		a.Color = Color3.fromHex("F2D9B0")
		a.Decay = Color3.fromHex("C9A37A")
		a.Parent = Lighting
	end
	if not Lighting:FindFirstChildOfClass("ColorCorrectionEffect") then
		local cc = Instance.new("ColorCorrectionEffect")
		cc.Saturation = 0.1
		cc.TintColor = Color3.fromHex("FFF4E4")
		cc.Parent = Lighting
	end
end

-- Mine mouth: timber frame with a sign, rails along the tunnel, a cart, lanterns; glowing crystals deep inside.
local function mineDecor()
	local mouth = spot("mine_mouth")
	local y, z = mouth.Y, mouth.Z
	local x0 = mouth.X + 16 -- where the tunnel enters the hill
	for _, dz in { -7.5, 7.5 } do
		part({ Name = "MinePost", Size = Vector3.new(1.4, 13, 1.4), Position = Vector3.new(x0, y + 6.5, z + dz), Color = WOOD_DARK, Material = Enum.Material.Wood })
	end
	local beam = part({ Name = "MineBeam", Size = Vector3.new(1.6, 1.6, 17), Position = Vector3.new(x0, y + 13.2, z), Color = WOOD_DARK, Material = Enum.Material.Wood })
	label(beam, "Mine", Theme.iron, 3)
	for _, dz in { -9.5, 9.5 } do
		lamp(Vector3.new(x0 - 2, y, z + dz))
	end
	-- Rails: two steel strips on sleepers from the mouth to the first cavern.
	local x1 = spot("ore_mouth").X - 12
	local len = x1 - (mouth.X + 4)
	local mid = (x1 + mouth.X + 4) / 2
	for _, dz in { -1.4, 1.4 } do
		part({ Name = "Rail", Size = Vector3.new(len, 0.3, 0.3), Position = Vector3.new(mid, y + 0.45, z + dz), Color = Color3.fromHex("6E6A66"), Material = Enum.Material.Metal })
	end
	for x = mouth.X + 5, x1, 4 do
		part({ Name = "Sleeper", Size = Vector3.new(0.8, 0.3, 4.2), Position = Vector3.new(x, y + 0.15, z), Color = WOOD_DARK, Material = Enum.Material.Wood })
	end
	-- Ore cart parked at the mouth.
	local c = CFrame.new(mouth.X + 8, y + 1.9, z)
	part({ Name = "CartBody", Size = Vector3.new(4, 2.4, 3.2), CFrame = c, Color = Color3.fromHex("5A4632"), Material = Enum.Material.WoodPlanks })
	part({ Name = "CartOre", Size = Vector3.new(3.4, 0.8, 2.6), CFrame = c * CFrame.new(0, 1.3, 0), Color = Color3.fromHex("8E8A82"), Material = Enum.Material.Slate })
	for _, w in { { -1.3, -1.7 }, { 1.3, -1.7 }, { -1.3, 1.7 }, { 1.3, 1.7 } } do
		part({ Name = "CartWheel", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 1.2, 1.2), CFrame = c * CFrame.new(w[1], -1.2, w[2]) * CFrame.Angles(0, math.rad(90), 0), Color = Color3.fromHex("3A3F45"), Material = Enum.Material.Metal })
	end
	-- Crystals glow along the deep and crystal cavern walls.
	for i, at in { { "ore_deep", 8, 7 }, { "ore_deep", -8, 6 }, { "ore_crystal", 8, -6 }, { "ore_crystal", -8, 5 }, { "ore_crystal", 2, 9 } } do
		local p = spot(at[1]) + Vector3.new(at[2], 0, at[3])
		local m = place("Mine", "Crystal", CFrame.new(p) * CFrame.Angles(0, math.rad(i * 70), math.rad(10)), i)
		if m then
			local light = Instance.new("PointLight")
			light.Color = Color3.fromHex("B07CFF")
			light.Range = 14
			light.Brightness = 1.4
			light.Parent = m:FindFirstChildWhichIsA("BasePart", true)
		end
	end
end

export type Built = {
	merchants: { [string]: BasePart },
	priceBoard: Part,
	leaderBoard: Part,
}

function World.build(onProgress: ((number) -> ())?): Built
	root = Instance.new("Folder")
	root.Name = "HaggleTown"
	root.Parent = workspace
	ambience()

	Terrain.build(onProgress) -- big map: village, lake, woods, mine mountain + caverns, coast, mountain ring
	part({ Name = "Square", Size = Vector3.new(60, 0.2, 50), Position = Vector3.new(0, 0.1, 5), Color = Color3.fromHex("CDBB9A"), Material = Enum.Material.Cobblestone })
	part({ Name = "Fountain", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.2, 8, 8), CFrame = CFrame.new(0, 0.6, 14) * CFrame.Angles(0, 0, math.rad(90)), Color = STONE, Material = Enum.Material.Cobblestone })
	part({ Name = "FountainWater", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 7, 7), CFrame = CFrame.new(0, 1.15, 14) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromHex("5FA8C9"), Material = Enum.Material.Glass, Transparency = 0.3 })

	-- The spawn lives in the lobby (Lobby.luau).

	house(Vector3.new(-40, 0, -8), 90, Color3.fromHex("EADBC3"))
	house(Vector3.new(-40, 0, 16), 90, Color3.fromHex("E2CDA8"))
	house(Vector3.new(40, 0, 16), -90, Color3.fromHex("EADBC3"))
	house(Vector3.new(-20, 0, -32), 0, Color3.fromHex("E2CDA8"))
	house(Vector3.new(22, 0, -32), 0, Color3.fromHex("EADBC3"))
	for _, p in { Vector3.new(-28, 0, -18), Vector3.new(28, 0, -18), Vector3.new(-28, 0, 28), Vector3.new(28, 0, 28) } do
		lamp(p)
	end
	path(Vector3.new(-30, 0, -10), Vector3.new(-45, 0, -28))
	path(Vector3.new(9, 0, 24), Vector3.new(2, 0, 50))
	-- Piers; trees, rocks and fishing spots are gather nodes (Nodes.luau). Lanterns light the caverns.
	pier(spot("fish"), spot("lake_pier"))
	pier(spot("fish_deep"), spot("sea_pier"))
	for _, name in { "ore_mouth", "ore_deep", "ore_crystal" } do
		lamp(spot(name) + Vector3.new(5, 0, 4))
	end
	place("Village", "Well", CFrame.new(-14, 0, 22))
	mineDecor()

	return {
		merchants = {
			woodcutter = stall("woodcutter", "wood", Vector3.new(-22, 0, 8), Theme.wood),
			fishmonger = stall("fishmonger", "fish", Vector3.new(0, 0, 30), Theme.fish),
			smith = stall("smith", "iron", Vector3.new(22, 0, 8), Theme.iron),
		},
		priceBoard = board("PriceBoard", CFrame.new(-9, 8, -14)),
		leaderBoard = board("LeaderBoard", CFrame.new(9, 8, -14)),
	}
end

-- Builders shared with Lobby.luau (call after World.build so parts land in the town folder).
World.kit = { tree = tree, spot = spot, variants = variants, pick = pick, part = part, wedge = wedge, prompt = prompt, label = label, npc = npc, board = board, path = path, lamp = lamp }

return World
