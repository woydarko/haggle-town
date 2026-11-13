--!strict
-- Client-side fishing visuals for the local player: the bobber flies along an arc from the rod, a line (Beam)
-- joins rod tip and bobber, the bobber bobs with ripples, a "!" pops over it on a bite, and a catch splashes
-- with a burst in the tier colour.
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Sfx = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Sfx"))

local FishFx = {}
local WATER = Color3.fromHex("CFE9F2")

export type Cast = { bobber: Part, landing: Vector3, clear: () -> () }

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include
params.FilterDescendantsInstances = { workspace.Terrain }

local function burst(at: Vector3, color: Color3, count: number, speed: number, size: number, light: number?)
	local a = Instance.new("Attachment")
	a.WorldPosition = at
	a.Parent = workspace.Terrain
	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new(color)
	e.Size = NumberSequence.new(size, size * 0.2)
	e.Transparency = NumberSequence.new(0.1, 1)
	e.Lifetime = NumberRange.new(0.4, 0.8)
	e.Speed = NumberRange.new(speed * 0.5, speed)
	e.SpreadAngle = Vector2.new(35, 35)
	e.EmissionDirection = Enum.NormalId.Top
	e.Acceleration = Vector3.new(0, -40, 0)
	e.LightEmission = light or 0
	e.Rate = 0
	e.Parent = a
	e:Emit(count)
	Debris:AddItem(a, 1.5)
end

-- Expanding, fading ring on the water.
function FishFx.ripple(at: Vector3, size: number?)
	local r = Instance.new("Part")
	r.Name = "Ripple"
	r.Anchored, r.CanCollide, r.CanQuery, r.CanTouch, r.CastShadow = true, false, false, false, false
	r.Shape = Enum.PartType.Cylinder
	r.Color = WATER
	r.Material = Enum.Material.SmoothPlastic
	r.Transparency = 0.4
	r.CFrame = CFrame.new(at + Vector3.new(0, 0.05, 0)) * CFrame.Angles(0, 0, math.rad(90))
	r.Size = Vector3.new(0.05, 1, 1)
	r.Parent = workspace
	local max = size or 6
	task.spawn(function()
		local t = 0
		while t < 0.9 do
			t += RunService.RenderStepped:Wait()
			local a = t / 0.9
			r.Size = Vector3.new(0.05, 1 + a * max, 1 + a * max)
			r.Transparency = 0.4 + a * 0.6
		end
		r:Destroy()
	end)
end

local function rodTip(char: Model): Attachment?
	local rod = char:FindFirstChild("Rod")
	if not rod then
		return nil
	end
	local tip: BasePart? = nil
	for _, h in rod:GetChildren() do
		if h:IsA("BasePart") and h.Material == Enum.Material.Neon then
			tip = h -- the bright tip of the greybox rod
		end
	end
	tip = tip or rod:FindFirstChild("Handle") :: BasePart?
	if not tip then
		return nil
	end
	local a = tip:FindFirstChild("LineTip") :: Attachment? or Instance.new("Attachment")
	a.Name = "LineTip"
	a.Parent = tip
	return a
end

-- Throws the bobber `8 + power * 32` studs along `dir` (flattened) and returns where it landed (terrain or water surface).
function FishFx.cast(char: Model, power: number, dir: Vector3): Cast
	local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart
	local flat = dir * Vector3.new(1, 0, 1)
	flat = if flat.Magnitude > 0.1 then flat.Unit else (hrp.CFrame.LookVector * Vector3.new(1, 0, 1)).Unit
	local dist = 8 + math.clamp(power, 0, 1) * 32
	local target = hrp.Position + flat * dist
	local hit = workspace:Raycast(Vector3.new(target.X, hrp.Position.Y + 80, target.Z), Vector3.new(0, -200, 0), params)
	local landing = if hit then hit.Position else Vector3.new(target.X, 0, target.Z)

	local bobber = Instance.new("Part")
	bobber.Name = "Bobber"
	bobber.Anchored, bobber.CanCollide, bobber.CanQuery, bobber.CanTouch = true, false, false, false
	bobber.Shape = Enum.PartType.Ball
	bobber.Size = Vector3.new(0.7, 0.7, 0.7)
	bobber.Color = Color3.fromHex("D8402A")
	bobber.Material = Enum.Material.SmoothPlastic
	local from = hrp.Position + Vector3.new(0, 2, 0) + flat * 2
	bobber.Position = from
	bobber.Parent = workspace
	local tip = rodTip(char)
	local beam: Beam? = nil
	if tip then
		local end_ = Instance.new("Attachment")
		end_.Parent = bobber
		local b = Instance.new("Beam")
		b.Attachment0, b.Attachment1 = tip, end_
		b.Width0, b.Width1 = 0.06, 0.06
		b.Color = ColorSequence.new(Color3.fromHex("F4F1EA"))
		b.FaceCamera = true
		b.Segments = 12
		b.CurveSize0 = 2
		b.Parent = bobber
		beam = b
	end
	Sfx.at("reel", from, 0.4, 1.4)
	local height = 5 + dist * 0.15
	local t = 0
	while t < 0.6 do
		t += RunService.RenderStepped:Wait()
		local a = math.min(t / 0.6, 1)
		bobber.Position = from:Lerp(landing, a) + Vector3.new(0, 4 * height * a * (1 - a), 0)
	end
	bobber.Position = landing
	if hit and hit.Material == Enum.Material.Water then
		Sfx.at("splash", landing, 0.6)
		burst(landing, WATER, 10, 10, 0.4)
		FishFx.ripple(landing)
	end

	-- Gentle bob until cleared.
	local alive = true
	task.spawn(function()
		local clock = 0
		while alive and bobber.Parent do
			clock += RunService.RenderStepped:Wait()
			bobber.Position = landing + Vector3.new(0, 0.1 + math.sin(clock * 3) * 0.08, 0)
		end
	end)
	return {
		bobber = bobber,
		landing = landing,
		clear = function()
			alive = false
			if beam then
				beam:Destroy()
			end
			bobber:Destroy()
		end,
	}
end

-- Bite: the bobber dips, a "!" pops over it, a plink.
function FishFx.bite(c: Cast)
	local bb = Instance.new("BillboardGui")
	bb.Name = "Bite"
	bb.Adornee = c.bobber
	bb.AlwaysOnTop = true
	bb.Size = UDim2.fromOffset(60, 60)
	bb.StudsOffset = Vector3.new(0, 2.5, 0)
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Text = "!"
	t.TextScaled = true
	t.FontFace = Font.fromName("Fondamento")
	t.TextColor3 = Color3.fromHex("FFD089")
	t.TextStrokeTransparency = 0
	t.Parent = bb
	bb.Parent = c.bobber
	Debris:AddItem(bb, 1.2)
	Sfx.at("splash", c.landing, 0.8, 1.5)
	burst(c.landing, WATER, 6, 8, 0.3)
	FishFx.ripple(c.landing, 4)
end

-- Catch: big splash, and a burst in the tier colour for rare and above.
function FishFx.catch(c: Cast, tierColor: Color3?, rare: boolean)
	Sfx.at("bigSplash", c.landing, 0.9)
	burst(c.landing, WATER, 24, 18, 0.6)
	FishFx.ripple(c.landing, 10)
	if rare and tierColor then
		burst(c.landing + Vector3.new(0, 1, 0), tierColor, 30, 20, 0.35, 1)
	end
end

return FishFx
