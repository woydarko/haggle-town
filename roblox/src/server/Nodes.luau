--!strict
-- Gather nodes in the world: ~80 trees, 32 rocks, 12 fishing spots, plus the Axe / Pickaxe / Rod tools.
-- The server owns every node's state (shared/NodeState.luau): one player claims it, a felled tree or broken rock
-- disappears and grows back after 30 s. Fishing spots never run out. Models carry attributes NodeId, Node
-- (backend gather node id) and State so clients can animate them later.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local StarterPack = game:GetService("StarterPack")
local ServerStorage = game:GetService("ServerStorage")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local NodeState = require(Shared:WaitForChild("NodeState"))
local Tools = require(Shared:WaitForChild("Tools"))
local Regions = require(Shared:WaitForChild("Regions"))
local Theme = require(Shared:WaitForChild("Theme"))
local Terrain = require(script.Parent.Terrain)
local World = require(script.Parent.World)

export type Node = { id: string, node: string, tag: string, model: Model, hit: BasePart, st: NodeState.NodeState }

local Nodes = {}
local byId: { [string]: Node } = {}
local all: { Node } = {}
local folder: Folder
local kit = World.kit
local V = Vector3.new
local STONE = Color3.fromHex("8E8A82")

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include
params.FilterDescendantsInstances = { workspace.Terrain }

-- Dry, gentle ground at (x, z), or nil.
local function ground(x: number, z: number): Vector3?
	local hit = workspace:Raycast(V(x, 400, z), V(0, -800, 0), params)
	if hit and hit.Material ~= Enum.Material.Water and hit.Normal.Y > 0.85 and not Regions.isWater(x, z) then
		return hit.Position
	end
	return nil
end

local function add(tag: string, node: string, model: Model, hit: BasePart, respawnS: number?)
	local id = string.sub(tag, 7, 7) .. tostring(#all + 1) -- T12, R130, W160
	model:SetAttribute("NodeId", id)
	model:SetAttribute("Node", node)
	model:SetAttribute("State", "ready")
	model.PrimaryPart = hit
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	CollectionService:AddTag(model, tag)
	model.Parent = folder
	local n: Node = { id = id, node = node, tag = tag, model = model, hit = hit, st = NodeState.new(tag, respawnS) }
	byId[id] = n
	table.insert(all, n)
end

-- Deterministic scatter in a disc on dry, gentle ground, at least `gap` studs from every other node.
local rng = Random.new(20261112)
local placed: { Vector3 } = {}
local function scatter(cx: number, cz: number, r: number, count: number, gap: number, keep: ((number, number) -> boolean)?): { Vector3 }
	local out = {}
	local tries = 0
	while #out < count and tries < count * 40 do
		tries += 1
		local a, d = rng:NextNumber() * 2 * math.pi, r * math.sqrt(rng:NextNumber())
		local x, z = cx + d * math.cos(a), cz + d * math.sin(a)
		local p = (keep == nil or keep(x, z)) and ground(x, z)
		if p then
			local free = true
			for _, q in placed do
				if (q - p).Magnitude < gap then
					free = false
					break
				end
			end
			if free then
				table.insert(out, p)
				table.insert(placed, p)
			end
		end
	end
	return out
end

local function treeNode(pos: Vector3, kind: number, node: string)
	local m = Instance.new("Model")
	m.Name = if kind == 3 then "AncientTree" else "Tree"
	local trunk = kit.tree(pos, kind, m)
	add("GatherTree", node, m, trunk)
end

local function rockNode(pos: Vector3, glow: Color3, node: string)
	local m = Instance.new("Model")
	m.Name = "Rock"
	local spin = CFrame.Angles(0, rng:NextNumber() * 2 * math.pi, 0)
	local base = CFrame.new(pos + V(0, 1.6, 0)) * spin
	local asset = kit.pick(kit.variants("Rocks", "Rock"), pos)
	local core: BasePart
	if asset then
		local rock = asset:Clone()
		rock:PivotTo(CFrame.new(pos - V(0, 0.4, 0)) * spin) -- sink a little so it sits in the ground
		core = rock:FindFirstChildWhichIsA("BasePart", true) :: BasePart
		core.Name = "Boulder"
		core.CanCollide, core.CanQuery = true, true
		core.Parent = m
		rock:Destroy()
	else
		core = kit.part({ Name = "Boulder", Size = V(5, 4, 5), CFrame = base * CFrame.Angles(math.rad(8), 0, math.rad(6)), Color = STONE, Material = Enum.Material.Slate, Parent = m })
	end
	local depth = math.min(core.Size.X, core.Size.Z) / 2 * 0.85
	for i = 1, 4 do
		kit.part({ Name = "Ore", Size = V(0.6, 0.6, 0.6), CFrame = base * CFrame.new(-1.2 + i * 0.6, -0.4 + (i % 2) * 0.7, depth), Color = glow, Material = Enum.Material.Neon, CanCollide = false, Parent = m })
	end
	add("GatherRock", node, m, core)
end

local function waterNode(pos: Vector3, node: string)
	local m = Instance.new("Model")
	m.Name = "FishingSpot"
	local buoy = kit.part({ Name = "Buoy", Shape = Enum.PartType.Cylinder, Size = V(0.6, 2.4, 2.4), CFrame = CFrame.new(pos + V(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = Theme.fish, Material = Enum.Material.SmoothPlastic, CanCollide = false, Parent = m })
	kit.label(buoy, "Fishing spot", Theme.fish, 3)
	add("GatherWater", node, m, buoy)
end

-- Spawns every node. Call after World.build (needs the terrain for ground snapping).
function Nodes.build(): { trees: number, rocks: number, spots: number }
	folder = Instance.new("Folder")
	folder.Name = "GatherNodes"
	folder.Parent = workspace

	-- Trees: a starter copse by the lobby, pine forest (NW), oak/maple woods (W), ancient grove (far W).
	for i, p in scatter(-70, -62, 16, 12, 8) do -- starter copse west of the guild yard
		treeNode(p, (i - 1) % 3, "wood")
	end
	for _, p in scatter(-275, 380, 120, 30, 10) do
		treeNode(p, 0, "wood")
	end
	for i, p in scatter(-225, 100, 120, 30, 10) do
		treeNode(p, 1 + i % 2, "wood")
	end
	for _, p in scatter(Regions.GROVE.x, Regions.GROVE.z, 70, 10, 14) do
		treeNode(p, 3, "wood_old")
	end

	-- Rocks: boulders round the mine mountain foot (not in front of the tunnel), and in the three caverns.
	local M = Regions.MINE
	local foot = scatter(M.x, M.z, 195, 20, 9, function(x, z)
		return Regions.dist(x, z, M) > 160 and not (x < M.x and math.abs(z - M.z) < 25)
	end)
	for _, p in foot do
		rockNode(p, Color3.fromHex("E07A3F"), "ore_mouth")
	end
	local caverns = {
		{ "ore_mouth", Color3.fromHex("E07A3F"), { { -4, -6 }, { 4, -6 }, { -4, 6 }, { 4, 6 } } },
		{ "ore_deep", Color3.fromHex("B07CFF"), { { 6, -5 }, { -1, -7 }, { -7, -5 }, { 7, 2 } } },
		{ "ore_crystal", Color3.fromHex("B07CFF"), { { -6, -4 }, { -6, 4 }, { 6, -4 }, { 6, 4 } } },
	}
	for _, c in caverns do
		local s = Terrain.SPOTS[c[1] :: string]
		for _, off in c[3] :: { { number } } do
			local from = V(s.x + off[1], s.y + 10, s.z + off[2])
			local hit = workspace:Raycast(from, V(0, -24, 0), params)
			rockNode(if hit then hit.Position else from - V(0, 10, 0), c[2] :: Color3, if c[1] == "ore_mouth" then "ore_mouth" else "ore_deep")
		end
	end

	-- Fishing spots: lake pier end + 7 round the lake shore; sea pier end + 3 along the coast.
	local S = Terrain.SPOTS
	waterNode(V(S.fish.x, Terrain.WATER_Y, S.fish.z), "fish")
	local L = Regions.LAKE
	for i = 1, 7 do
		local a = -math.pi / 2 + i * (2 * math.pi / 8) -- skips the pier side (south)
		waterNode(V(L.x + (L.r - 9) * math.cos(a), Terrain.WATER_Y, L.z + (L.r - 9) * math.sin(a)), "fish")
	end
	waterNode(V(S.fish_deep.x, Terrain.WATER_Y, S.fish_deep.z), "fish_deep")
	for _, side in { -120, 60, 150 } do
		local p = Regions.along(Regions.SEA_D + 9, side)
		waterNode(V(p.x, Terrain.WATER_Y, p.z), "fish_deep")
	end

	local count = { trees = 0, rocks = 0, spots = 0 }
	for _, n in all do
		local k = if n.tag == "GatherTree" then "trees" elseif n.tag == "GatherRock" then "rocks" else "spots"
		count[k] += 1
	end
	return count
end

-- Tools given to everyone through StarterPack. Creator Store models from ServerStorage.Assets.Tools (credits in
-- roblox/ASSETS.md; curated upright, head up, pivot at the grip) are welded to a small invisible Handle at the grip;
-- the greybox below stays as the fallback when the folder is missing.
local function fromAsset(name: string): boolean
	local folder = ServerStorage:FindFirstChild("Assets") and (ServerStorage :: any).Assets:FindFirstChild("Tools")
	local src = folder and folder:FindFirstChild(name)
	if not src then
		return false
	end
	local t = Instance.new("Tool")
	t.Name = name
	t.ToolTip = Tools[name].tip
	t.CanBeDropped = false
	local h = kit.part({ Name = "Handle", Size = V(0.3, 0.3, 0.3), Transparency = 1, CanCollide = false, Anchored = false, Massless = true, Parent = t })
	local m = src:Clone()
	m:PivotTo(h.CFrame)
	local _, size = m:GetBoundingBox()
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored, p.CanCollide, p.CanQuery, p.Massless = false, false, false, true
			local w = Instance.new("WeldConstraint")
			w.Part0, w.Part1 = h, p
			w.Parent = p
		end
	end
	m.Parent = t
	if name == "Rod" then
		-- FishFx hangs the line from Handle.LineTip; put it at the rod's top end.
		local a = Instance.new("Attachment")
		a.Name = "LineTip"
		a.Position = V(0, size.Y * 0.88, 0)
		a.Parent = h
	end
	t.GripPos = V(0, 0, 0)
	t.Parent = StarterPack
	return true
end

function Nodes.tools()
	local wood, metal = Color3.fromHex("6B4A2B"), Color3.fromHex("8A9199")
	local function make(name: string, handleSize: Vector3, bits: { { any } })
		if fromAsset(name) then
			return
		end
		local t = Instance.new("Tool")
		t.Name = name
		t.ToolTip = Tools[name].tip
		t.CanBeDropped = false
		local h = kit.part({ Name = "Handle", Size = handleSize, Color = wood, Material = Enum.Material.Wood, CanCollide = false, Anchored = false, Massless = true, Parent = t })
		for _, b in bits do
			local p = kit.part({ Name = "Head", Size = b[1], CFrame = h.CFrame * b[2], Color = b[3], Material = b[4], CanCollide = false, Anchored = false, Massless = true, Parent = t })
			local w = Instance.new("WeldConstraint")
			w.Part0, w.Part1 = h, p
			w.Parent = p
		end
		t.GripPos = V(0, -1.2, 0)
		t.Parent = StarterPack
	end
	make("Axe", V(0.35, 4, 0.35), { { V(0.25, 1.1, 1.5), CFrame.new(0, 1.5, -0.6), metal, Enum.Material.Metal } })
	make("Pickaxe", V(0.35, 4, 0.35), { { V(0.3, 0.35, 2.8), CFrame.new(0, 1.8, 0), metal, Enum.Material.Metal } })
	make("Rod", V(0.2, 7, 0.2), { { V(0.3, 0.5, 0.3), CFrame.new(0, 3.6, 0), Theme.fish, Enum.Material.Neon }, { V(0.5, 0.5, 0.5), CFrame.new(0, -2.2, -0.3), metal, Enum.Material.Metal } })
end

function Nodes.get(id: string): Node?
	return byId[id]
end

-- Nearest node with this tag to a position (any state) and its distance; the caller checks range and claims.
function Nodes.nearest(pos: Vector3, tag: string): (Node?, number)
	local best, bd = nil, math.huge
	for _, n in all do
		if n.tag == tag then
			local d = (n.hit.Position - pos).Magnitude
			if d < bd then
				best, bd = n, d
			end
		end
	end
	return best, bd
end

local function show(n: Node, visible: boolean)
	for _, d in n.model:GetDescendants() do
		if d:IsA("BasePart") then
			if d:GetAttribute("T0") == nil then
				d:SetAttribute("T0", d.Transparency)
				d:SetAttribute("C0", d.CanCollide)
			end
			d.Transparency = if visible then d:GetAttribute("T0") :: number else 1
			d.CanCollide = if visible then d:GetAttribute("C0") :: boolean else false
		end
	end
end

-- Push anyone standing where the node grows back to the side, never stuck inside it.
local function nudge(n: Node)
	local c = n.hit.Position
	for _, p in Players:GetPlayers() do
		local char = p.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if char and hrp then
			local flat = (hrp.Position - c) * V(1, 0, 1)
			if flat.Magnitude < 5 then
				local dir = if flat.Magnitude > 0.1 then flat.Unit else V(1, 0, 0)
				char:PivotTo(hrp.CFrame + dir * (6 - flat.Magnitude) + V(0, 2, 0))
			end
		end
	end
end

local function sync(n: Node)
	n.model:SetAttribute("State", n.st.state)
end

function Nodes.claim(n: Node, who: Player): (boolean, string?)
	local ok, why = n.st:claim(who, os.clock())
	sync(n)
	return ok, why
end

function Nodes.release(n: Node, who: Player)
	n.st:release(who)
	sync(n)
end

function Nodes.hit(n: Node)
	n.st:hit(os.clock())
end

-- Felled tree / broken rock: gone for respawnS. Fishing spots never run out. `from` (the player's position)
-- sets FellDir so trees fall away from the chopper; clients animate the fall before the server hides it.
local FALL_S = 2.5
function Nodes.fell(n: Node, from: Vector3?)
	if n.tag == "GatherWater" then
		return
	end
	local flat = if from then (n.hit.Position - from) * V(1, 0, 1) else V(0, 0, 0)
	n.model:SetAttribute("FellDir", if flat.Magnitude > 0.1 then flat.Unit else V(1, 0, 0))
	n.st:fell(os.clock())
	sync(n)
	local at = n.st.at
	task.delay(if n.tag == "GatherTree" then FALL_S else 0, function()
		if n.st.state == "felled" and n.st.at == at then
			show(n, false)
		end
	end)
end

-- Respawn and claim-timeout loop.
function Nodes.start()
	task.spawn(function()
		while true do
			task.wait(0.5)
			local now = os.clock()
			for _, n in all do
				local was = n.st.state
				if n.st:tick(now) then
					if was == "felled" then
						nudge(n)
						show(n, true)
					end
					sync(n)
				end
			end
		end
	end)
end

return Nodes
