--!strict
-- Client-side tree effects, driven by attributes the server sets on GatherTree models (everyone nearby sees them):
--   Hit (counter) + HitKind -> trunk shake, wood chips, chop sound
--   State "felled" + FellDir -> the tree tips over away from the chopper, timber crash, leaf burst, a stump
--   State "ready" after felled -> grows back with a pop
-- Only local CFrame/scale changes; the server hides the felled tree after the fall and shows it again on respawn.
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Sfx = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Sfx"))

local TreeFx = {}
local WOOD = Color3.fromHex("C9A26B")

local function burst(at: Vector3, color: Color3, count: number, speed: number, size: number)
	local a = Instance.new("Attachment")
	a.WorldPosition = at
	a.Parent = workspace.Terrain
	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new(color)
	e.Size = NumberSequence.new(size, size * 0.3)
	e.Lifetime = NumberRange.new(0.5, 1)
	e.Speed = NumberRange.new(speed * 0.6, speed)
	e.SpreadAngle = Vector2.new(70, 70)
	e.Acceleration = Vector3.new(0, -35, 0)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-240, 240)
	e.Rate = 0
	e.Parent = a
	e:Emit(count)
	task.delay(1.5, function()
		a:Destroy()
	end)
end

-- Runs f(alpha 0..1) every frame for `seconds`.
local function animate(seconds: number, f: (number) -> ())
	local t = 0
	while t < seconds do
		t += RunService.RenderStepped:Wait()
		f(math.min(t / seconds, 1))
	end
end

local function leafColor(m: Model): Color3
	local leaf = m:FindFirstChild("Leaves") or m:FindFirstChild("Needles")
	return if leaf and leaf:IsA("BasePart") then leaf.Color else Color3.fromHex("4F8F45")
end

local function watch(m: Model)
	local trunk = m.PrimaryPart
	if not trunk then
		return
	end
	local base = m:GetPivot()
	local bottom = trunk.Position - Vector3.new(0, trunk.Size.Y / 2, 0)
	local busy = false
	local stump: BasePart? = nil

	m:GetAttributeChangedSignal("Hit"):Connect(function()
		local kind = m:GetAttribute("HitKind")
		local at = bottom + Vector3.new(0, 3, 0)
		if kind == "miss" then
			Sfx.at("chop", at, 0.35, 0.7)
			return
		end
		Sfx.at(if kind == "perfect" then "chopPerfect" else "chop", at)
		burst(at, WOOD, if kind == "perfect" then 16 else 9, 16, 0.4)
		if busy then
			return
		end
		busy = true
		animate(0.25, function(a) -- quick decaying wobble
			local w = math.sin(a * math.pi * 5) * (1 - a) * math.rad(3)
			m:PivotTo(CFrame.new(bottom) * CFrame.Angles(w, 0, w * 0.6) * CFrame.new(-bottom) * base)
		end)
		m:PivotTo(base)
		busy = false
	end)

	m:GetAttributeChangedSignal("State"):Connect(function()
		local state = m:GetAttribute("State")
		if state == "felled" then
			local dir = m:GetAttribute("FellDir")
			local flat = if typeof(dir) == "Vector3" and dir.Magnitude > 0.1 then dir.Unit else Vector3.new(1, 0, 0)
			local axis = Vector3.yAxis:Cross(flat)
			Sfx.at("leaves", trunk.Position, 0.5)
			animate(1.3, function(a)
				local angle = math.rad(86) * a * a -- slow start, fast finish
				m:PivotTo(CFrame.new(bottom) * CFrame.fromAxisAngle(axis, angle) * CFrame.new(-bottom) * base)
			end)
			local top = bottom + flat * (trunk.Size.Y + 4)
			Sfx.at("timber", top, 0.9)
			burst(top + Vector3.new(0, 2, 0), leafColor(m), 30, 22, 0.8)
			burst(top, WOOD, 12, 12, 0.5)
			local s = Instance.new("Part")
			s.Name = "Stump"
			s.Anchored, s.CanCollide, s.CanQuery = true, true, false
			s.Shape = Enum.PartType.Cylinder
			s.Size = Vector3.new(1.2, trunk.Size.X * 1.05, trunk.Size.Z * 1.05)
			s.CFrame = CFrame.new(bottom + Vector3.new(0, 0.6, 0)) * CFrame.Angles(0, 0, math.rad(90))
			s.Color, s.Material = trunk.Color, trunk.Material
			s.Parent = workspace
			stump = s
		elseif state == "ready" and stump then
			stump:Destroy()
			stump = nil
			m:PivotTo(base)
			Sfx.at("respawn", trunk.Position, 0.6)
			animate(0.5, function(a)
				m:ScaleTo(math.max(0.05, 1 - (1 - a) ^ 3))
			end)
			m:ScaleTo(1)
		end
	end)
end

function TreeFx.start()
	local bound: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any
	local function add(m: Instance)
		if m:IsA("Model") and not bound[m] then
			bound[m] = true
			task.spawn(watch, m)
		end
	end
	for _, m in CollectionService:GetTagged("GatherTree") do
		add(m)
	end
	CollectionService:GetInstanceAddedSignal("GatherTree"):Connect(add) -- streamed in later
end

return TreeFx
