--!strict
-- Chopping minigame (spec s5): a needle sweeps a bar; click when it is on the green spot.
-- 4 good hits fell the tree; the amber center is a perfect hit; too many misses and the axe gets stuck.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared:WaitForChild("Theme"))
local M = require(Shared:WaitForChild("Minigame"))
local Ui = require(script.Parent.Parent.ui.Ui)

local Chopping = {}

function Chopping.play(ctx: any, params: any): number?
	local panel: Frame = ctx.panel
	local width = math.min(M.CHOP_SPOT * (tonumber(params.zoneScale) or 1), 0.4)
	local bar = Ui.new("Frame", { Parent = panel, Position = UDim2.fromOffset(0, 150), Size = UDim2.new(1, 0, 0, 36), BackgroundColor3 = Theme.border }, { Ui.corner() })
	local spot = Ui.new("Frame", { Parent = bar, AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromScale(width, 1), BackgroundColor3 = Theme.success })
	Ui.new("Frame", { Parent = spot, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromScale(0.3, 1), BackgroundColor3 = Theme.warning })
	local needle = Ui.new("Frame", { Parent = bar, Position = UDim2.new(0, -3, 0, -6), Size = UDim2.new(0, 6, 1, 12), BackgroundColor3 = Theme.text })
	local status = Ui.text({ Parent = panel, Position = UDim2.fromOffset(0, 210), Size = UDim2.new(1, 0, 0, 60), TextXAlignment = Enum.TextXAlignment.Center, Font = Theme.display, TextSize = 30, Text = "" })

	local function newSpot(): number
		local c = width / 2 + math.random() * (1 - width)
		spot.Position = UDim2.fromScale(c, 0)
		return c
	end

	local center = newSpot()
	local hits, swings, perfects, combo, t, idle = 0, 0, 0, 0, 0, 0
	ctx.hint(`Click or Space on the green  0/{M.CHOP_HITS}`)
	ctx.consume()
	while hits < M.CHOP_HITS do
		local dt = ctx.step()
		t += dt
		idle += dt
		local x = M.pingPong(t, M.CHOP_PERIOD)
		needle.Position = UDim2.new(x, -3, 0, -6)
		if ctx.consume() then
			idle = 0
			swings += 1
			local r = M.chopHit(x, center, width)
			if r == "miss" then
				combo = 0
				status.TextColor3, status.Text = Theme.error, "Miss!"
			else
				hits += 1
				combo = if r == "perfect" then combo + 1 else 0
				perfects += if r == "perfect" then 1 else 0
				status.TextColor3 = if r == "perfect" then Theme.warning else Theme.success
				status.Text = (if r == "perfect" then "Perfect!" else "Good") .. (if combo > 1 then ` x{combo}` else "")
				center = newSpot()
			end
			ctx.hint(`Click or Space on the green  {hits}/{M.CHOP_HITS}`)
			if hits < M.CHOP_HITS and swings >= M.CHOP_MAX_SWINGS then
				return ctx.fail("The axe got stuck...")
			end
		elseif idle > 20 then
			return ctx.fail("You stopped chopping.")
		end
	end
	ctx.hint("Timber!")
	return M.chopQuality(swings, perfects)
end

return Chopping
