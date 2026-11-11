--!strict
-- Mining minigame (spec s5): 5 weak points glow one at a time on the rock; click each before it fades.
-- Fade is 0.9 s at the cave mouth, 0.7 s deep inside; Miner gets bigger points. Accuracy = quality.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared:WaitForChild("Theme"))
local M = require(Shared:WaitForChild("Minigame"))
local Ui = require(script.Parent.Parent.ui.Ui)

local GLOW = Color3.fromHex("FFD089") -- same warm glow as the town lamps
local Mining = {}

function Mining.play(ctx: any, params: any): number?
	local panel: Frame = ctx.panel
	local fade = M.mineFade(ctx.node)
	local size = math.floor(56 * math.clamp(tonumber(params.zoneScale) or 1, 0.5, 2))
	local rock = Ui.new("Frame", { Parent = panel, Position = UDim2.fromOffset(0, 56), Size = UDim2.new(1, 0, 1, -56), BackgroundColor3 = Theme.iron }, { Ui.corner() })
	ctx.hint("Click the glowing spots before they fade")
	task.wait(0.8)

	local hit = 0
	for i = 1, M.MINE_POINTS do
		local area = rock.AbsoluteSize
		local got = false
		local point = Ui.new("TextButton", {
			Parent = rock,
			Text = "",
			AutoButtonColor = false,
			Position = UDim2.fromOffset(math.random() * math.max(area.X - size, 0), math.random() * math.max(area.Y - size, 0)),
			Size = UDim2.fromOffset(size, size),
			BackgroundColor3 = GLOW,
		}, { Ui.new("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
		point.Activated:Connect(function()
			got = true
		end)
		local t = 0
		while t < fade and not got do
			t += ctx.step()
			-- Fallback if Run's input sink swallowed the button click: same click, checked by position.
			-- Screen coords match because the ScreenGui sets IgnoreGuiInset.
			if ctx.consume() then
				local m, p, s = UserInputService:GetMouseLocation(), point.AbsolutePosition, point.AbsoluteSize
				got = got or (m.X >= p.X and m.X <= p.X + s.X and m.Y >= p.Y and m.Y <= p.Y + s.Y)
			end
			point.BackgroundTransparency = 0.8 * t / fade
		end
		point:Destroy()
		hit += if got then 1 else 0
		ctx.hint(`Weak spots {hit}/{i}`)
		task.wait(0.25)
	end
	if hit == 0 then
		return ctx.fail("The rock did not crack.")
	end
	ctx.hint("Ore chunk out!")
	return M.mineQuality(hit, M.MINE_POINTS)
end

return Mining
