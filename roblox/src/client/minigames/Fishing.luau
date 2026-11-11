--!strict
-- Fishing minigame, three phases (spec s5): cast bar -> wait for the bite -> reel the fish inside the green zone.
-- Called by Run.play with its ctx (input + panel); returns quality 0..1 or nil if the fish escapes.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared:WaitForChild("Theme"))
local M = require(Shared:WaitForChild("Minigame"))
local Ui = require(script.Parent.Parent.ui.Ui)

local CENTER = Enum.TextXAlignment.Center
local REEL_LIMIT = 40 -- seconds; the server session lives 60 s

local Fishing = {}

local function escaped(ctx: any): nil
	ctx.hint("It got away...")
	task.wait(1)
	return nil
end

function Fishing.play(ctx: any, params: any): number?
	local panel: Frame = ctx.panel
	local speed = math.max(tonumber(params.fishSpeed) or 1, 0.5)
	local zoneH = math.min(M.ZONE * (tonumber(params.zoneScale) or 1), 0.6)

	-- 1. Cast: hold to charge, release inside the green band for a long cast.
	local castBar = Ui.new("Frame", { Parent = panel, Position = UDim2.fromOffset(0, 70), Size = UDim2.new(1, 0, 0, 28), BackgroundColor3 = Theme.border }, { Ui.corner() })
	Ui.new("Frame", { Parent = castBar, Position = UDim2.fromScale(M.TOP_BAND, 0), Size = UDim2.fromScale(1 - M.TOP_BAND, 1), BackgroundColor3 = Theme.success })
	local needle = Ui.new("Frame", { Parent = castBar, Position = UDim2.new(0, -3, 0, -4), Size = UDim2.new(0, 6, 1, 8), BackgroundColor3 = Theme.text })
	ctx.hint("Hold click or Space, release in the green")
	local idle = 0
	while not ctx.held() do
		idle += ctx.step()
		if idle > 20 then
			return escaped(ctx)
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

	-- 2. Wait: clicking too soon scares the fish and restarts the wait.
	local bobber = Ui.text({ Parent = panel, Position = UDim2.fromOffset(0, 120), Size = UDim2.new(1, 0, 0, 90), TextXAlignment = CENTER, Font = Theme.display, TextSize = 72, TextColor3 = Theme.muted, Text = "..." })
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
	ctx.hint("Click now!")
	local window, hooked = 0, false
	while window < M.BITE_WINDOW and not hooked do
		window += ctx.step()
		hooked = ctx.consume()
	end
	if not hooked then
		return escaped(ctx)
	end
	castBar.Visible = false
	bobber.Visible = false

	-- 3. Reel: hold to lift the zone, release to let it sink; keep the fish inside to fill the bar.
	ctx.hint("Hold to lift the green zone onto the fish")
	local bar = Ui.new("Frame", { Parent = panel, Position = UDim2.new(0.5, -70, 0, 60), Size = UDim2.fromOffset(70, 290), BackgroundColor3 = Theme.fish, BackgroundTransparency = 0.6 }, { Ui.corner() })
	local zone = Ui.new("Frame", { Parent = bar, AnchorPoint = Vector2.new(0, 1), Size = UDim2.fromScale(1, zoneH), BackgroundColor3 = Theme.success, BackgroundTransparency = 0.3 })
	local fish = Ui.text({ Parent = bar, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(60, 24), TextXAlignment = CENTER, Font = Theme.display, TextSize = 24, Text = "><>" })
	local track = Ui.new("Frame", { Parent = panel, Position = UDim2.new(0.5, 20, 0, 60), Size = UDim2.fromOffset(20, 290), BackgroundColor3 = Theme.border }, { Ui.corner() })
	local fill = Ui.new("Frame", { Parent = track, AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 0), BackgroundColor3 = Theme.success }, { Ui.corner() })

	local progress, zonePos, zoneVel = M.REEL_START, 0, 0
	local fishPos, target, retarget = 0.5, 0.5, 0
	local inTime, total = 0, 0
	while progress > 0 and progress < 1 and total < REEL_LIMIT do
		local dt = ctx.step()
		zoneVel = math.clamp(zoneVel + (if ctx.held() then 2.6 else -2.2) * dt, -1.2, 1.2)
		zonePos += zoneVel * dt
		if zonePos <= 0 or zonePos >= 1 - zoneH then
			zonePos, zoneVel = math.clamp(zonePos, 0, 1 - zoneH), 0
		end
		-- Fish darts to a new spot every 0.5-1.5 s, faster (and more often) for rarer rolls.
		retarget -= dt
		if retarget <= 0 then
			target, retarget = math.random(), (0.5 + math.random()) / speed
		end
		local d = target - fishPos
		fishPos += math.sign(d) * math.min(math.abs(d), 0.35 * speed * dt)
		local inZone = fishPos >= zonePos and fishPos <= zonePos + zoneH
		total += dt
		if inZone then
			inTime += dt
		end
		progress += M.catchProgress(inZone, dt, speed)
		zone.Position = UDim2.fromScale(0, 1 - zonePos)
		fish.Position = UDim2.fromScale(0.5, 1 - fishPos)
		fish.TextColor3 = if inZone then Theme.success else Theme.text
		fill.Size = UDim2.fromScale(1, math.clamp(progress, 0, 1))
	end
	if progress < 1 then
		return escaped(ctx)
	end
	ctx.hint("Got it!")
	return M.fishingQuality(inTime / total, cast)
end

return Fishing
