--!strict
-- Builds the greybox market town at runtime so the whole place lives in git (no binary .rbxl needed).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Theme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Theme"))

local World = {}

local root: Folder

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		(p :: any)[k] = v
	end
	p.Parent = props.Parent or root
	return p
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

local function label(parent: BasePart, text: string, color: Color3)
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(200, 40)
	bb.StudsOffset = Vector3.new(0, 4, 0)
	bb.AlwaysOnTop = true
	bb.MaxDistance = 80
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Font = Theme.display
	t.TextSize = 24
	t.TextColor3 = color
	t.TextStrokeTransparency = 0.6
	t.Text = text
	t.Parent = bb
	bb.Parent = parent
end

local function board(name: string, cframe: CFrame): Part
	local b = part({ Name = name, Size = Vector3.new(14, 8, 0.6), CFrame = cframe, Color = Color3.fromHex("6B4A2B"), Material = Enum.Material.Wood })
	local sg = Instance.new("SurfaceGui")
	sg.Name = "Gui"
	sg.Face = Enum.NormalId.Front
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 40
	sg.Parent = b
	return b
end

local function merchant(name: string, pos: Vector3, color: Color3): Part
	part({ Name = name .. "Counter", Size = Vector3.new(8, 3, 3), Position = pos + Vector3.new(0, 1.5, 3), Color = Theme.border, Material = Enum.Material.WoodPlanks })
	part({ Name = name .. "Awning", Size = Vector3.new(9, 0.4, 6), Position = pos + Vector3.new(0, 7, 1.5), Color = color, Material = Enum.Material.Fabric })
	local body = part({ Name = name, Shape = Enum.PartType.Cylinder, Size = Vector3.new(4, 2.2, 2.2), CFrame = CFrame.new(pos + Vector3.new(0, 2, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = color })
	part({ Name = name .. "Head", Shape = Enum.PartType.Ball, Size = Vector3.new(1.8, 1.8, 1.8), Position = pos + Vector3.new(0, 4.9, 0), Color = Color3.fromHex("E8C39E") })
	label(body, Theme.merchantNames[name], color)
	prompt(body, "Haggle", Theme.merchantNames[name])
	return body
end

local function node(name: string, action: string, pos: Vector3, color: Color3, material: Enum.Material, size: Vector3): Part
	local p = part({ Name = name, Size = size, Position = pos + Vector3.new(0, size.Y / 2, 0), Color = color, Material = material })
	prompt(p, action, name)
	label(p, name, color)
	return p
end

export type Built = {
	nodes: { [string]: Part },
	merchants: { [string]: Part },
	priceBoard: Part,
	leaderBoard: Part,
}

function World.build(): Built
	root = Instance.new("Folder")
	root.Name = "HaggleTown"
	root.Parent = workspace

	part({ Name = "Ground", Size = Vector3.new(220, 2, 220), Position = Vector3.new(0, -1, 0), Color = Color3.fromHex("7FA35B"), Material = Enum.Material.Grass })
	part({ Name = "Square", Size = Vector3.new(60, 0.2, 50), Position = Vector3.new(0, 0.1, 5), Color = Color3.fromHex("CDBB9A"), Material = Enum.Material.Cobblestone })
	part({ Name = "Water", Size = Vector3.new(60, 0.4, 30), Position = Vector3.new(0, 0.2, 75), Color = Color3.fromHex("3C7FA6"), Material = Enum.Material.Glass, Transparency = 0.2 })
	local spawn = Instance.new("SpawnLocation")
	spawn.Anchored = true
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Position = Vector3.new(0, 0.5, 0)
	spawn.Neutral = true
	spawn.Color = Theme.border
	spawn.Parent = root

	for i = 1, 6 do
		local x, z = -55 + (i % 3) * 7, -40 + math.floor(i / 3) * 8
		part({ Name = "Trunk", Size = Vector3.new(1.5, 8, 1.5), Position = Vector3.new(x, 4, z), Color = Color3.fromHex("6B4A2B"), Material = Enum.Material.Wood })
		part({ Name = "Leaves", Shape = Enum.PartType.Ball, Size = Vector3.new(7, 7, 7), Position = Vector3.new(x, 9.5, z), Color = Color3.fromHex("3E7D3A"), Material = Enum.Material.Grass })
	end

	local built: Built = {
		nodes = {
			wood = node("Wood", "Chop", Vector3.new(-45, 0, -30), Theme.wood, Enum.Material.Wood, Vector3.new(3, 2, 3)),
			fish = node("Fish", "Fish", Vector3.new(0, 0, 58), Theme.fish, Enum.Material.WoodPlanks, Vector3.new(10, 1, 6)),
			iron = node("Iron", "Dig", Vector3.new(48, 0, -30), Theme.iron, Enum.Material.Slate, Vector3.new(6, 5, 6)),
		},
		merchants = {
			woodcutter = merchant("woodcutter", Vector3.new(-22, 0, 8), Theme.wood),
			fishmonger = merchant("fishmonger", Vector3.new(0, 0, 30), Theme.fish),
			smith = merchant("smith", Vector3.new(22, 0, 8), Theme.iron),
		},
		priceBoard = board("PriceBoard", CFrame.new(-9, 5, -14)),
		leaderBoard = board("LeaderBoard", CFrame.new(9, 5, -14)),
	}
	return built
end

return World
