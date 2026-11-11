--!strict
-- Builds the market town at runtime so the whole place lives in git (no binary .rbxl needed).
-- Contract with Main.server: build() returns nodes/merchants as BaseParts that carry a ProximityPrompt,
-- placed where players stand within 12 studs of them.
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Theme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Theme"))
local Terrain = require(script.Parent.Terrain)

local World = {}

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
	t.Font = Theme.display
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
	t.Font = Theme.display
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

local function house(pos: Vector3, yaw: number, wall: Color3)
	local cf = CFrame.new(pos) * CFrame.Angles(0, math.rad(yaw), 0)
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

local function woodNode(pos: Vector3): Part
	local stump = part({ Name = "Wood", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2, 3, 3), CFrame = CFrame.new(pos + Vector3.new(0, 1, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = WOOD_LIGHT, Material = Enum.Material.Wood })
	part({ Name = "AxeHandle", Size = Vector3.new(0.3, 2.6, 0.3), CFrame = CFrame.new(pos + Vector3.new(0.4, 2.8, 0)) * CFrame.Angles(0, 0, math.rad(-20)), Color = WOOD_DARK, Material = Enum.Material.Wood })
	part({ Name = "AxeHead", Size = Vector3.new(1, 0.7, 0.15), CFrame = CFrame.new(pos + Vector3.new(0.05, 2.1, 0)) * CFrame.Angles(0, 0, math.rad(-20)), Color = Color3.fromHex("8A9199"), Material = Enum.Material.Metal })
	prompt(stump, "Chop", "Wood")
	label(stump, "Wood", Theme.wood)
	return stump
end

local function fishNode(pos: Vector3): Part
	-- Pier from the shore out over the water; the fishing spot is at its end.
	for i = 0, 7 do
		part({ Name = "PierPlank", Size = Vector3.new(6, 0.4, 1.8), Position = Vector3.new(pos.X, 0.8, 50 + i * 2), Color = WOOD_LIGHT, Material = Enum.Material.WoodPlanks })
	end
	for _, x in { -2.7, 2.7 } do
		for _, z in { 52, 58, 64 } do
			part({ Name = "PierPost", Size = Vector3.new(0.6, 4, 0.6), Position = Vector3.new(pos.X + x, -1, z), Color = WOOD_DARK, Material = Enum.Material.Wood })
		end
	end
	local spot = part({ Name = "Fish", Size = Vector3.new(6, 0.4, 4), Position = pos + Vector3.new(0, 0.8, 0), Color = WOOD_LIGHT, Material = Enum.Material.WoodPlanks })
	part({ Name = "Bucket", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.2, 1.2, 1.2), CFrame = CFrame.new(pos + Vector3.new(2, 1.6, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = Theme.fish, Material = Enum.Material.Metal })
	prompt(spot, "Fish", "Fish")
	label(spot, "Fish", Theme.fish)
	return spot
end

-- Ore rock in a cave chamber; glow tints the ore specks (deep cave = crystal purple). A lantern lights the chamber.
local function oreNode(pos: Vector3, glow: Color3, title: string): Part
	for i, off in { Vector3.new(-3, 0, -2), Vector3.new(3, 0, -1), Vector3.new(0, 0, -4), Vector3.new(-2, 0, 2.5) } do
		part({ Name = "Rock", Size = Vector3.new(5, 4 + i, 4), CFrame = CFrame.new(pos + off + Vector3.new(0, (4 + i) / 2, 0)) * CFrame.Angles(0, math.rad(i * 37), math.rad(i * 7)), Color = STONE, Material = Enum.Material.Slate })
	end
	local core = part({ Name = "Iron", Size = Vector3.new(4, 3, 3), Position = pos + Vector3.new(0, 1.5, 1), Color = Theme.iron, Material = Enum.Material.Slate })
	for i = 1, 5 do
		part({ Name = "Ore", Size = Vector3.new(0.5, 0.5, 0.5), Position = pos + Vector3.new(-1.5 + i * 0.6, 1 + (i % 3) * 0.6, 2.55), Color = glow, Material = Enum.Material.Neon })
	end
	lamp(pos + Vector3.new(7, 0, 7))
	prompt(core, "Mine", title)
	label(core, title, Theme.iron)
	return core
end

local function spot(name: string): Vector3
	local p = Terrain.SPOTS[name]
	return Vector3.new(p.x, p.y, p.z)
end

-- kind: 0 pine, 1 oak, 2 maple, 3 ancient redwood
local function tree(pos: Vector3, kind: number)
	local tall = if kind == 3 then 18 else 9
	part({ Name = "Trunk", Size = Vector3.new(if kind == 3 then 2.8 else 1.6, tall, if kind == 3 then 2.8 else 1.6), Position = pos + Vector3.new(0, tall / 2, 0), Color = WOOD_DARK, Material = Enum.Material.Wood })
	if kind == 0 then
		for i, w in { 7, 5, 3 } do
			part({ Name = "Needles", Shape = Enum.PartType.Ball, Size = Vector3.new(w, 4, w), Position = pos + Vector3.new(0, 6 + i * 2.5, 0), Color = Color3.fromHex("2F5E35"), Material = Enum.Material.Grass })
		end
	else
		local color = ({ "4F8F45", "C8642A", "35603A" })[kind]
		local size = if kind == 3 then Vector3.new(11, 8, 11) else Vector3.new(8, 7, 8)
		part({ Name = "Leaves", Shape = Enum.PartType.Ball, Size = size, Position = pos + Vector3.new(0, tall + 1.5, 0), Color = Color3.fromHex(color), Material = Enum.Material.Grass })
	end
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

export type Built = {
	nodes: { [string]: BasePart },
	merchants: { [string]: BasePart },
	priceBoard: Part,
	leaderBoard: Part,
}

function World.build(): Built
	root = Instance.new("Folder")
	root.Name = "HaggleTown"
	root.Parent = workspace
	ambience()

	Terrain.build() -- valley, lake, mountain ring, cave hill
	part({ Name = "Square", Size = Vector3.new(60, 0.2, 50), Position = Vector3.new(0, 0.1, 5), Color = Color3.fromHex("CDBB9A"), Material = Enum.Material.Cobblestone })
	part({ Name = "Fountain", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.2, 8, 8), CFrame = CFrame.new(0, 0.6, 14) * CFrame.Angles(0, 0, math.rad(90)), Color = STONE, Material = Enum.Material.Cobblestone })
	part({ Name = "FountainWater", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 7, 7), CFrame = CFrame.new(0, 1.15, 14) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromHex("5FA8C9"), Material = Enum.Material.Glass, Transparency = 0.3 })

	-- The spawn lives in the lobby (Lobby.luau).

	-- Forest west of town, one of each wood type in turn (pine, oak, maple, ancient redwood).
	for c = 0, 3 do
		for r = 0, 3 do
			tree(Vector3.new(-78 + c * 8, 0, -50 + r * 9), (c + r) % 4)
		end
	end

	house(Vector3.new(-40, 0, -8), 90, Color3.fromHex("EADBC3"))
	house(Vector3.new(-40, 0, 16), 90, Color3.fromHex("E2CDA8"))
	house(Vector3.new(40, 0, 16), -90, Color3.fromHex("EADBC3"))
	house(Vector3.new(-20, 0, -32), 0, Color3.fromHex("E2CDA8"))
	house(Vector3.new(22, 0, -32), 0, Color3.fromHex("EADBC3"))
	for _, p in { Vector3.new(-28, 0, -18), Vector3.new(28, 0, -18), Vector3.new(-28, 0, 28), Vector3.new(28, 0, 28) } do
		lamp(p)
	end
	path(Vector3.new(-30, 0, -10), Vector3.new(-45, 0, -28))
	path(Vector3.new(30, 0, -10), Vector3.new(66, 0, -30)) -- to the cave mouth
	path(Vector3.new(9, 0, 24), Vector3.new(2, 0, 50))

	return {
		nodes = {
			-- keys are backend gather nodes; positions come from Terrain.SPOTS (checked by Terrain.spec)
			wood = woodNode(spot("wood")),
			fish = fishNode(spot("fish")),
			ore_mouth = oreNode(spot("ore_mouth"), Color3.fromHex("E07A3F"), "Ore"),
			ore_deep = oreNode(spot("ore_deep"), Color3.fromHex("B07CFF"), "Deep ore"),
		},
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
World.kit = { part = part, wedge = wedge, prompt = prompt, label = label, npc = npc, board = board, path = path, lamp = lamp }

return World
