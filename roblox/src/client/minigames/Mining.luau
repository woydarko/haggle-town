--!strict
-- Mining minigame (spec s5): 5 weak points glow one at a time on the rock; click each before it fades.
-- Fade is 0.9 s at the cave mouth, 0.7 s deep inside; Miner gets bigger points. Accuracy = quality.
-- The points sit on the rock itself (BillboardGui on the face toward the player); every click swings the pickaxe.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared:WaitForChild("Theme"))
local M = require(Shared:WaitForChild("Minigame"))
local Anims = require(Shared:WaitForChild("Anims"))
local Ui = require(script.Parent.Parent.ui.Ui)

local GLOW = Color3.fromHex("FFD089") -- same warm glow as the town lamps
local Mining = {}

-- A weak spot reads as a glowing ore vein: a cut gem (rotated square, lamp-glow gradient, ember outline, light fleck)
-- and a ring that closes in on it as time runs out, so the timer is visible instead of a plain fade.
type Spot = { button: TextButton, update: (frac: number) -> (), burst: (got: boolean) -> () }
local function weakSpot(parent: Instance, size: number): Spot
	local button = Ui.new("TextButton", { Parent = parent, Text = "", AutoButtonColor = false, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(size, size) })
	local stroke = Ui.new("UIStroke", { Color = Color3.fromHex("5A240C"), Thickness = 3 })
	local gem = Ui.new("Frame", { Parent = button, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.68, 0.68), Rotation = 45, BorderSizePixel = 0, BackgroundColor3 = Color3.new(1, 1, 1) }, {
		Ui.new("UICorner", { CornerRadius = UDim.new(0.18, 0) }),
		-- Rotation 45 on a 45-degree frame runs the gradient top (bright) to bottom (ember) on screen.
		Ui.new("UIGradient", { Rotation = 45, Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromHex("FFF3C4")), ColorSequenceKeypoint.new(0.4, Color3.fromHex("FFB52E")), ColorSequenceKeypoint.new(1, Color3.fromHex("E0561B")) }) }),
		stroke,
	})
	Ui.new("Frame", { Parent = gem, Position = UDim2.fromScale(0.16, 0.16), Size = UDim2.fromScale(0.24, 0.24), BorderSizePixel = 0, BackgroundColor3 = Color3.new(1, 1, 1) }, { Ui.new("UICorner", { CornerRadius = UDim.new(0.3, 0) }) })
	local ringStroke = Ui.new("UIStroke", { Color = GLOW, Thickness = 3 })
	local ring = Ui.new("Frame", { Parent = button, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1.7, 1.7), BackgroundTransparency = 1 }, { Ui.new("UICorner", { CornerRadius = UDim.new(0.5, 0) }), ringStroke })
	return {
		button = button,
		-- frac: share of the fade time used (0..1). The ring reaches the gem's tips (~0.96) at the end.
		update = function(frac: number)
			local s = 1.7 - 0.74 * frac
			ring.Size = UDim2.fromScale(s, s)
			ringStroke.Transparency = 0.6 * frac
			local fade = math.max(0, frac - 0.6) * 1.5 -- the gem dims only in the last 40%
			gem.BackgroundTransparency, stroke.Transparency = fade, fade
		end,
		burst = function(got: boolean)
			ring.Visible = false
			local to = if got then 1.05 else 0.3
			TweenService:Create(gem, TweenInfo.new(0.15), { Size = UDim2.fromScale(to, to), BackgroundTransparency = 1 }):Play()
			TweenService:Create(stroke, TweenInfo.new(0.15), { Transparency = 1 }):Play()
		end,
	}
end

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
		a.Parent = c -- parent first: WorldPosition on an unparented attachment becomes a local offset
		a.WorldPosition = c.Position + front * (c.Size.X / 2) + right * ((math.random() - 0.5) * c.Size.X * 0.8) + Vector3.new(0, (math.random() - 0.4) * c.Size.Y * 0.7, 0)
		return a
	end

	local hit = 0
	for i = 1, M.MINE_POINTS do
		local got, clicked = false, false
		local holder: Instance
		local spot: Spot
		if core then
			local a = spotOnRock(core)
			local bb = Instance.new("BillboardGui")
			bb.Name = "WeakSpot"
			bb.Adornee = a
			bb.AlwaysOnTop = true
			bb.Active = true
			bb.Size = UDim2.fromOffset(size * 1.8, size * 1.8) -- room for the closing ring around the gem
			bb.Parent = player:WaitForChild("PlayerGui")
			spot = weakSpot(bb, size)
			holder = a
			a.Destroying:Once(function()
				bb:Destroy()
			end)
		else
			local area = (rock :: Frame).AbsoluteSize
			spot = weakSpot(rock :: Frame, size)
			spot.button.Position = UDim2.fromOffset(size / 2 + math.random() * math.max(area.X - size, 0), size / 2 + math.random() * math.max(area.Y - size, 0))
			holder = spot.button
		end
		local point = spot.button
		point.Activated:Connect(function()
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
			spot.update(math.min(t / fade, 1))
		end
		if clicked then -- a click on the button itself ended the wait before the loop body ran
			if hum then
				Anims.play(hum, "MineSwing")
			end
			ctx.fx("good")
		end
		spot.burst(got)
		task.delay(0.18, function()
			holder:Destroy()
		end)
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
