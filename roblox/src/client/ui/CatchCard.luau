--!strict
-- Catch reveal: a card slides down under the HUD with the item icon, name, tier banner and quantity.
-- Epic and legendary get a glowing outline with a moving shine; the sound depends on the tier.
-- Hides after 3 s, or on Space / click.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared:WaitForChild("Theme"))
local Sfx = require(Shared:WaitForChild("Sfx"))
local Ui = require(script.Parent.Ui)

local CatchCard = {}
local SHOWN = UDim2.new(0.5, 0, 0, 64)
local HIDDEN = UDim2.new(0.5, 0, 0, -160)

export type Catch = { item: string, name: string, tier: string, qty: number, bonus: string? }

function CatchCard.mount(gui: ScreenGui)
	local card = Ui.new("TextButton", {
		Name = "CatchCard",
		Parent = gui,
		Text = "",
		AutoButtonColor = false,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = HIDDEN,
		Size = UDim2.fromOffset(340, 104),
		BackgroundColor3 = Theme.surface,
		Visible = false,
	}, { Ui.corner(), Ui.pad(12) })
	local stroke = Ui.new("UIStroke", { Parent = card, Thickness = 2, Color = Theme.border, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
	local shine = Ui.new("UIGradient", {
		Parent = stroke,
		Color = ColorSequence.new(Color3.new(1, 1, 1)),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 0.6) }),
		Enabled = false,
	})
	local holder = Ui.new("Frame", { Parent = card, BackgroundColor3 = Theme.background, Size = UDim2.fromOffset(80, 80) }, { Ui.corner() })
	local name = Ui.text({ Parent = card, Position = UDim2.fromOffset(92, 0), Size = UDim2.new(1, -92, 0, 32), FontFace = Theme.display, TextSize = 26, Text = "" })
	local qty = Ui.text({ Parent = card, Position = UDim2.fromOffset(92, 62), Size = UDim2.new(1, -92, 0, 18), TextSize = 16, TextColor3 = Theme.muted, Text = "" })
	local badge: TextLabel? = nil
	local shownId = 0

	local function hide()
		shownId += 1
		local t = TweenService:Create(card, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = HIDDEN })
		t:Play()
		t.Completed:Once(function()
			card.Visible = false
		end)
	end
	card.Activated:Connect(hide)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.Space and card.Visible then
			hide()
		end
	end)

	local api = {}
	function api.show(c: Catch)
		shownId += 1
		local mine = shownId
		holder:ClearAllChildren()
		Ui.icon(c.item, 72, { Parent = holder, Position = UDim2.fromOffset(4, 4) })
		name.Text = c.name
		qty.Text = if c.qty > 1 and c.bonus == "trade" then `x{c.qty} - your trade's bonus`
			elseif c.qty > 1 and c.bonus then `x{c.qty} - {c.bonus} bonus!`
			elseif c.qty > 1 then `x{c.qty} - added to your bag`
			else "Added to your bag"
		if badge then
			badge:Destroy()
		end
		badge = Ui.tierBadge(c.tier, { Parent = card, Position = UDim2.fromOffset(92, 34) })
		local fancy = c.tier == "epic" or c.tier == "legendary"
		stroke.Color = if fancy then Theme.tiers[c.tier] else Theme.border
		stroke.Thickness = if fancy then 4 else 2
		shine.Enabled = fancy
		Sfx.ui(if fancy then "sparkle" elseif c.tier == "rare" then "chopPerfect" else "respawn")
		card.Position = HIDDEN
		card.Visible = true
		TweenService:Create(card, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = SHOWN }):Play()
		if fancy then
			task.spawn(function() -- the shine sweeps round the outline while the card is up
				while shownId == mine and card.Visible do
					shine.Rotation = (shine.Rotation + 4) % 360
					task.wait()
				end
			end)
		end
		task.delay(3, function()
			if shownId == mine then
				hide()
			end
		end)
	end
	return api
end

return CatchCard
