--!strict
-- Client-side rock effects, driven by server attributes on GatherRock models (everyone nearby sees them):
--   Hit + HitKind -> rock dust, ore sparks, pick sound, and a dark crack on good hits
--   State "felled" -> the rock breaks into chunks that tumble and fade, ore sparkle
--   State "ready" after felled -> regrows with a pop, cracks cleared
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Sfx = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Sfx"))

local RockFx = {}
local DUST = Color3.fromHex("B8B0A2")

local function burst(at: Vector3, color: Color3, count: number, speed: number, size: number, light: number?)
	local a = Instance.new("Attachment")
	a.WorldPosition = at
	a.Parent = workspace.Terrain
	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new(color)
	e.Size = NumberSequence.new(size, size * 0.2)
	e.Transparency = NumberSequence.new(0, 1)
	e.Lifetime = NumberRange.new(0.4, 0.9)
	e.Speed = NumberRange.new(speed * 0.5, speed)
	e.SpreadAngle = Vector2.new(80, 80)
	e.Acceleration = Vector3.new(0, -25, 0)
	e.LightEmission = light or 0
	e.Rate = 0
	e.Parent = a
	e:Emit(count)
	Debris:AddItem(a, 1.5)
end

local function oreColor(m: Model): Color3
	local ore = m:FindFirstChild("Ore")
	return if ore and ore:IsA("BasePart") then ore.Color else Color3.fromHex("E07A3F")
end

local function watch(m: Model)
	local core = m.PrimaryPart
	if not core then
		return
	end
	local cracks: { BasePart } = {}
	local broken = false

	m:GetAttributeChangedSignal("Hit"):Connect(function()
		local kind = m:GetAttribute("HitKind")
		local at = core.Position + Vector3.new(0, 1, 0)
		Sfx.at("pick", at, if kind == "miss" then 0.35 else 0.7, if kind == "miss" then 0.8 else nil)
		burst(at, DUST, if kind == "miss" then 4 else 10, 10, 0.9)
		if kind ~= "miss" then
			burst(at, oreColor(m), if kind == "perfect" then 14 else 7, 18, 0.25, 1)
			-- A thin dark crack on a random face (local only; cleared on regrow).
			local c = Instance.new("Part")
			c.Name = "Crack"
			c.Anchored, c.CanCollide, c.CanQuery, c.CastShadow = true, false, false, false
			c.Color = Color3.fromHex("2B2724")
			c.Size = Vector3.new(0.15, 1.6 + math.random() * 1.4, 0.3)
			c.CFrame = core.CFrame * CFrame.Angles(0, math.random() * 2 * math.pi, 0) * CFrame.new(0, (math.random() - 0.5) * 2, -2.45) * CFrame.Angles(0, 0, math.rad(math.random(-40, 40)))
			c.Parent = m
			table.insert(cracks, c)
			if #cracks > 1 then
				Sfx.at("crack", at, 0.5)
			end
		end
	end)

	m:GetAttributeChangedSignal("State"):Connect(function()
		local state = m:GetAttribute("State")
		if state == "felled" and not broken then
			broken = true
			local at, size = core.Position, core.Size
			for _, c in cracks do
				c:Destroy()
			end
			table.clear(cracks)
			Sfx.at("rockBreak", at, 0.9)
			Sfx.at("sparkle", at, 0.6)
			burst(at, DUST, 30, 16, 1.6)
			burst(at, oreColor(m), 24, 22, 0.3, 1)
			-- Chunks tumble out and fade (client-only physics, never collide with players).
			for _ = 1, 5 do
				local ch = Instance.new("Part")
				ch.Name = "RockChunk"
				ch.CanCollide, ch.CanQuery, ch.CanTouch = true, false, false
				ch.Color, ch.Material = core.Color, core.Material
				ch.Size = size * (0.3 + math.random() * 0.15)
				ch.CFrame = CFrame.new(at + Vector3.new(math.random() - 0.5, 0.5, math.random() - 0.5) * 2) * CFrame.Angles(math.random() * 6, math.random() * 6, 0)
				ch.AssemblyLinearVelocity = Vector3.new(math.random() - 0.5, 0.8, math.random() - 0.5) * 22
				ch.Parent = workspace
				task.delay(0.8, function()
					local t = 0
					while t < 0.8 and ch.Parent do
						t += RunService.RenderStepped:Wait()
						ch.Transparency = t / 0.8
					end
					ch:Destroy()
				end)
			end
		elseif state == "ready" and broken then
			broken = false
			Sfx.at("respawn", core.Position, 0.6)
			local t = 0
			while t < 0.45 do
				t += RunService.RenderStepped:Wait()
				m:ScaleTo(math.max(0.05, 1 - (1 - math.min(t / 0.45, 1)) ^ 3))
			end
			m:ScaleTo(1)
		end
	end)
end

-- Caves are darker: when there is rock overhead the outdoor light fades out and the lanterns carry the scene.
local function caveLight()
	local Lighting = game:GetService("Lighting")
	local TweenService = game:GetService("TweenService")
	local player = game:GetService("Players").LocalPlayer
	local outside = { Brightness = Lighting.Brightness, OutdoorAmbient = Lighting.OutdoorAmbient, Ambient = Lighting.Ambient }
	local inside = { Brightness = 1, OutdoorAmbient = Color3.fromHex("4A4038"), Ambient = Color3.fromHex("3A322B") }
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.Terrain }
	local under = false
	while true do
		task.wait(0.5)
		local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local now = hrp ~= nil and workspace:Raycast(hrp.Position, Vector3.new(0, 60, 0), params) ~= nil
		if now ~= under then
			under = now
			TweenService:Create(Lighting, TweenInfo.new(1.2), if now then inside else outside):Play()
		end
	end
end

function RockFx.start()
	task.spawn(caveLight)
	local bound: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any
	local function add(m: Instance)
		if m:IsA("Model") and not bound[m] then
			bound[m] = true
			task.spawn(watch, m)
		end
	end
	for _, m in CollectionService:GetTagged("GatherRock") do
		add(m)
	end
	CollectionService:GetInstanceAddedSignal("GatherRock"):Connect(add)
end

return RockFx
