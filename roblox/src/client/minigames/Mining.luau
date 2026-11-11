--!strict
-- Mining minigame (spec s5): 5 weak points glow one at a time on the rock; click each before it fades.
-- Fade is 0.9 s at the cave mouth, 0.7 s deep inside; Miner gets bigger points. Accuracy = quality.
-- The points sit on the rock itself (BillboardGui on the face toward the player); every click swings the pickaxe.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared:WaitForChild("Theme"))
local M = require(Shared:WaitForChild("Minigame"))
local Anims = require(Shared:WaitForChild("Anims"))
local Ui = require(script.Parent.Parent.ui.Ui)

local GLOW = Color3.fromHex("FFD089") -- same warm glow as the town lamps
local Mining = {}

function Mining.play(ctx: any, params: any): number?
	local panel: Frame = ctx.panel
	local fade = M.mineFade(ctx.node)
	local size = math.floor(56 * math.clamp(tonumber(params.zoneScale) or 1, 0.5, 2))
	local player = Players.LocalPlayer
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local core: BasePart? = ctx.target and ctx.target.PrimaryPart
	-- Fallback when the rock is not streamed in: the old panel rock.
	local rock = if core then nil else Ui.new("Frame", { Parent = panel, Position = UDim2.fromOffset(0, 56), Size = UDim2.new(1, 0, 1, -56), BackgroundColor3 = Theme.iron }, { Ui.corner() })
	ctx.hint("Click the glowing spots before they fade")
	task.wait(0.8)

	-- A point on the rock face toward the player, spread across that face.
	local function spotOnRock(c: BasePart): Attachment
		local toward = if hrp then (hrp.Position - c.Position) * Vector3.new(1, 0, 1) else Vector3.new(0, 0, 1)
		local front = if toward.Magnitude > 0.1 then toward.Unit else Vector3.new(0, 0, 1)
		local right = Vector3.yAxis:Cross(front)
		local a = Instance.new("Attachment")
		a.WorldPosition = c.Position + front * (c.Size.X / 2) + right * ((math.random() - 0.5) * c.Size.X * 0.8) + Vector3.new(0, (math.random() - 0.4) * c.Size.Y * 0.7, 0)
		a.Parent = c
		return a
	end

	local hit = 0
	for i = 1, M.MINE_POINTS do
		local got, clicked = false, false
		local holder: Instance
		local point: GuiObject
		if core then
			local a = spotOnRock(core)
			local bb = Instance.new("BillboardGui")
			bb.Name = "WeakSpot"
			bb.Adornee = a
			bb.AlwaysOnTop = true
			bb.Active = true
			bb.Size = UDim2.fromOffset(size, size)
			bb.Parent = player:WaitForChild("PlayerGui")
			point = Ui.new("TextButton", { Parent = bb, Text = "", AutoButtonColor = false, Size = UDim2.fromScale(1, 1), BackgroundColor3 = GLOW }, { Ui.new("UICorner", { CornerRadius = UDim.new(0.5, 0) }), Ui.stroke() })
			holder = a
			a.Destroying:Once(function()
				bb:Destroy()
			end)
		else
			local area = (rock :: Frame).AbsoluteSize
			point = Ui.new("TextButton", {
				Parent = rock,
				Text = "",
				AutoButtonColor = false,
				Position = UDim2.fromOffset(math.random() * math.max(area.X - size, 0), math.random() * math.max(area.Y - size, 0)),
				Size = UDim2.fromOffset(size, size),
				BackgroundColor3 = GLOW,
			}, { Ui.new("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
			holder = point
		end
		;(point :: any).Activated:Connect(function()
			got, clicked = true, true
		end)
		local t = 0
		while t < fade and not got do
			t += ctx.step()
			-- Fallback if Run's input sink swallowed the button click: same click, checked by position.
			-- Screen coords match because the ScreenGui sets IgnoreGuiInset (BillboardGui children report screen coords too).
			if ctx.consume() then
				clicked = true
				local m, p, s = UserInputService:GetMouseLocation(), point.AbsolutePosition, point.AbsoluteSize
				got = got or (m.X >= p.X and m.X <= p.X + s.X and m.Y >= p.Y and m.Y <= p.Y + s.Y)
			end
			if clicked then
				clicked = false
				if hum then
					Anims.play(hum, "MineSwing")
				end
				ctx.fx(if got then "good" else "miss")
			end
			point.BackgroundTransparency = 0.8 * t / fade
		end
		if clicked then -- a click on the button itself ended the wait before the loop body ran
			if hum then
				Anims.play(hum, "MineSwing")
			end
			ctx.fx("good")
		end
		holder:Destroy()
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
