--!strict
-- Tiny helper to build UI instances with Theme tokens.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Theme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Theme"))
local Sprites = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Sprites"))

local Ui = {}

function Ui.new(class: string, props: { [string]: any }, children: { Instance }?): any
	local inst = Instance.new(class)
	for k, v in props do
		if k ~= "Parent" then
			(inst :: any)[k] = v
		end
	end
	for _, c in children or {} do
		c.Parent = inst
	end
	inst.Parent = props.Parent
	return inst
end

function Ui.corner(): UICorner
	return Ui.new("UICorner", { CornerRadius = Theme.radius })
end

function Ui.pad(px: number): UIPadding
	local u = UDim.new(0, px)
	return Ui.new("UIPadding", { PaddingLeft = u, PaddingRight = u, PaddingTop = u, PaddingBottom = u })
end

function Ui.stroke(): UIStroke
	return Ui.new("UIStroke", { Color = Theme.border, Thickness = 2 })
end

function Ui.text(props: { [string]: any }): TextLabel
	local base = {
		BackgroundTransparency = 1,
		FontFace = Theme.body,
		TextSize = 18,
		TextColor3 = Theme.text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
	}
	for k, v in props do
		base[k] = v
	end
	return Ui.new("TextLabel", base)
end

function Ui.button(text: string, primary: boolean, props: { [string]: any }): TextButton
	local base = {
		Text = text,
		FontFace = Theme.display,
		TextSize = 20,
		AutoButtonColor = true,
		BackgroundColor3 = if primary then Theme.primary else Theme.surface,
		TextColor3 = if primary then Theme.onPrimary else Theme.text,
		Size = UDim2.fromOffset(160, 44),
	}
	for k, v in props do
		base[k] = v
	end
	return Ui.new("TextButton", base, { Ui.corner(), Ui.stroke() })
end

-- Item icon: the item's 12x12 pixel sprite (shared/Sprites.luau), one Frame per same-colour run. Pixels are whole
-- offsets (px // 12) so edges stay crisp; transparent background, the caller draws the slot.
function Ui.icon(id: string, px: number, props: { [string]: any }?): Frame
	local base = { Size = UDim2.fromOffset(px, px), BackgroundTransparency = 1 }
	for k, v in props or {} do
		base[k] = v
	end
	local icon = Ui.new("Frame", base)
	local p = px // Sprites.SIZE
	local o = (px - p * Sprites.SIZE) // 2
	for _, run in Sprites.runs(id) do
		Ui.new("Frame", {
			Parent = icon,
			BorderSizePixel = 0,
			BackgroundColor3 = Color3.fromHex(run.hex),
			Position = UDim2.fromOffset(o + (run.col - 1) * p, o + (run.row - 1) * p),
			Size = UDim2.fromOffset(run.len * p, p),
		})
	end
	return icon
end

-- Tier label on the tier colour (light text, >= 5.4:1 on every tier colour).
function Ui.tierBadge(tier: string, props: { [string]: any }?): TextLabel
	local base = {
		Size = UDim2.fromOffset(120, 26),
		BackgroundTransparency = 0,
		BackgroundColor3 = Theme.tiers[tier] or Theme.muted,
		Text = string.upper(tier),
		FontFace = Theme.display,
		TextSize = 16,
		TextColor3 = Theme.onPrimary,
		TextXAlignment = Enum.TextXAlignment.Center,
	}
	for k, v in props or {} do
		base[k] = v
	end
	return Ui.new("TextLabel", base, { Ui.new("UICorner", { CornerRadius = UDim.new(0, 6) }) })
end

return Ui
