--!strict
-- Fishing minigame, three phases (spec s5): cast bar -> wait for the bite -> reel the fish inside the green zone.
-- Called by Run.play with its ctx (input + panel); returns quality 0..1 or nil if the fish escapes.
-- In the world flow the cast runs first on its own (Fishing.cast), the bobber flies, the server checks the water,
-- then play() runs with ctx.cast (power) and ctx.bobber: the bite shows over the bobber and the reel bar sits
-- at the right edge so the water stays visible.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared:WaitForChild("Theme"))
local M = require(Shared:WaitForChild("Minigame"))
local Anims = require(Shared:WaitForChild("Anims"))
local Sfx = require(Shared:WaitForChild("Sfx"))
local Ui = require(script.Parent.Parent.ui.Ui)
local FishFx = require(script.Parent.Parent.fx.FishFx)

local CENTER = Enum.TextXAlignment.Center
local REEL_LIMIT = 40 -- seconds; the server session lives 60 s

local Fishing = {}

local function escaped(ctx: any): nil
	return ctx.fail("It got away...")
end

-- 1. Cast: hold to charge, release inside the green band for a long cast. Returns power 0..1, or nil if idle.
local function castPhase(ctx: any): (number?, Frame?)
	local panel: Frame = ctx.panel
	local castBar = Ui.new("Frame", { Parent = panel, Position = UDim2.fromOffset(0, if ctx.inWorld then 28 else 70), Size = UDim2.new(1, 0, 0, if ctx.inWorld then 18 else 28), BackgroundColor3 = Theme.border }, { Ui.corner() })
	Ui.new("Frame", { Parent = castBar, Position = UDim2.fromScale(M.TOP_BAND, 0), Size = UDim2.fromScale(1 - M.TOP_BAND, 1), BackgroundColor3 = Theme.success })
	local needle = Ui.new("Frame", { Parent = castBar, Position = UDim2.new(0, -3, 0, -4), Size = UDim2.new(0, 6, 1, 8), BackgroundColor3 = Theme.text })
	ctx.hint("Hold click or Space, release in the green")
	local idle = 0
	while not ctx.held() do
		idle += ctx.step()
		if idle > 20 then
			return escaped(ctx), nil
		end
	end
	local t, cast = 0, 0
	while ctx.held() do
		t += ctx.step()
		cast = M.castPower(t)
		needle.Position = UDim2.new(cast, -3, 0, -4)
	end
	ctx.consume()
	ctx.hint(if cast >= M.TOP_BAND then "Long cast!" else "Short cast")
	return cast, castBar
end

-- Cast on its own (world flow): the bobber is thrown with the returned power.
function Fishing.cast(ctx: any, _params: any): number?
	return (castPhase(ctx))
end

function Fishing.play(ctx: any, params: any): number?
	local panel: Frame = ctx.panel
	local speed = math.max(tonumber(params.fishSpeed) or 1, 0.5)
	local zoneH = math.min(M.ZONE * (tonumber(params.zoneScale) or 1), 0.6)
	local cast, castBar = ctx.cast, nil
	if cast == nil then
		cast, castBar = castPhase(ctx)
		if cast == nil then
			return nil
		end
	end
	local bob = ctx.bobber

	-- 2. Wait: clicking too soon scares the fish and restarts the wait.
	local bobber = Ui.text({ Parent = panel, Position = UDim2.fromOffset(0, 120), Size = UDim2.new(1, 0, 0, 90), TextXAlignment = CENTER, Style = "hero", TextColor3 = Theme.muted, Text = "...", Visible = bob == nil })
	task.wait(0.6)
	ctx.hint("Wait for a bite...")
	ctx.consume()
	local delay, waited = 2 + math.random() * 4, 0
	while waited < delay do
		waited += ctx.step()
		if ctx.consume() then
			ctx.hint("Too soon! Wait for the !")
			delay, waited = 2 + math.random() * 4, 0
		end
	end
	bobber.Text = "!"
	bobber.TextColor3 = Theme.primary
	if bob then
		FishFx.bite(bob)
	end
	ctx.hint("Click now!")
	local window, hooked = 0, false
	while window < M.BITE_WINDOW and not hooked do
		window += ctx.step()
		hooked = ctx.consume()
	end
	if not hooked then
		return escaped(ctx)
	end
	if castBar then
		castBar.Visible = false
	end
	bobber.Visible = false

	-- 3. Reel: hold to lift the zone, release to let it sink; keep the fish inside to fill the bar.
	-- World flow: the bars live in their own card at the right edge (the strip is too small, the water stays visible).
	ctx.hint("Hold to lift the green zone onto the fish")
	local host: GuiObject = panel
	local top, tall = 60, 290
	if bob then
		host = Ui.new("Frame", { Parent = panel.Parent, Name = "Reel", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -24, 0.5, 0), Size = UDim2.fromOffset(140, 320), BackgroundColor3 = Theme.surface }, { Ui.corner(), Ui.stroke(), Ui.pad(10) })
		top, tall = 0, 300
	end
	local hum = Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
	if hum then
		Anims.play(hum, "ReelLoop")
	end
	Sfx.ui("reel")
	local function done<T>(v: T): T
		if host ~= panel then
			host:Destroy()
		end
		if hum then
			Anims.stop(hum, "ReelLoop")
		end
		return v
	end
	local bar = Ui.new("Frame", { Parent = host, Position = UDim2.new(0.5, -70, 0, top), Size = UDim2.fromOffset(70, tall), BackgroundColor3 = Theme.fish, BackgroundTransparency = 0.6 }, { Ui.corner() })
	local zone = Ui.new("Frame", { Parent = bar, AnchorPoint = Vector2.new(0, 1), Size = UDim2.fromScale(1, zoneH), BackgroundColor3 = Theme.success, BackgroundTransparency = 0.3 })
	local fish = Ui.icon("fish_mystery", 44, { Parent = bar, AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 2 })
	local track = Ui.new("Frame", { Parent = host, Position = UDim2.new(0.5, 20, 0, top), Size = UDim2.fromOffset(20, tall), BackgroundColor3 = Theme.border }, { Ui.corner() })
	local fill = Ui.new("Frame", { Parent = track, AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 0), BackgroundColor3 = Theme.success }, { Ui.corner() })

	local progress, zonePos, zoneVel = M.REEL_START, 0.5 - zoneH / 2, 0 -- start with the fish inside the zone
	local fishPos, target, retarget = 0.5, 0.5, 0
	local calm = 1 + (speed - 1) * 0.5
	local inTime, total = 0, 0
	while progress > 0 and progress < 1 and total < REEL_LIMIT do
		local dt = ctx.step()
		-- The zone follows the button at once (no slide): hold = up, release = down.
		zoneVel += ((if ctx.held() then 0.8 else -0.7) - zoneVel) * math.min(1, 8 * dt)
		zonePos += zoneVel * dt
		if zonePos <= 0 or zonePos >= 1 - zoneH then
			zonePos, zoneVel = math.clamp(zonePos, 0, 1 - zoneH), 0
		end
		-- The fish drifts to a nearby spot (at most 0.3 of the bar away) every 1.2-2.4 s and eases into it;
		-- rarer rolls are a little livelier, never twice as fast.
		retarget -= dt
		if retarget <= 0 then
			target = math.clamp(fishPos + (math.random() * 2 - 1) * 0.3, 0.05, 0.95)
			retarget = (1.2 + math.random() * 1.2) / calm
		end
		fishPos += (target - fishPos) * math.min(1, 2.2 * calm * dt)
		local inZone = fishPos >= zonePos and fishPos <= zonePos + zoneH
		total += dt
		if inZone then
			inTime += dt
		end
		progress += M.catchProgress(inZone, dt, speed)
		zone.Position = UDim2.fromScale(0, 1 - zonePos)
		fish.Position = UDim2.fromScale(0.5, 1 - fishPos)
		zone.BackgroundTransparency = if inZone then 0.2 else 0.55 -- the zone lights up while the fish is inside
		fill.Size = UDim2.fromScale(1, math.clamp(progress, 0, 1))
	end
	if progress < 1 then
		return done(escaped(ctx))
	end
	ctx.hint("Got it!")
	return done(M.fishingQuality(inTime / total, cast))
end

return Fishing
