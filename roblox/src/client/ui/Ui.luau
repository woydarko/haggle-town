--!strict
-- Tiny helper to build UI instances with Theme tokens.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Theme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Theme"))
local SpriteGui = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SpriteGui"))

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

-- Style = a Theme.type name ("body" when absent); it sets FontFace and TextSize together.
local function styled(base: { [string]: any }, props: { [string]: any }, default: string): { [string]: any }
	local st = Theme.type[props.Style or default]
	assert(st, `unknown text style {props.Style}`)
	base.FontFace, base.TextSize = st.font, st.size
	for k, v in props do
		if k ~= "Style" then
			base[k] = v
		end
	end
	return base
end

function Ui.text(props: { [string]: any }): TextLabel
	local base = {
		BackgroundTransparency = 1,
		TextColor3 = Theme.text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
	}
	return Ui.new("TextLabel", styled(base, props, "body"))
end

function Ui.button(text: string, primary: boolean, props: { [string]: any }): TextButton
	local base = {
		Text = text,
		AutoButtonColor = true,
		BackgroundColor3 = if primary then Theme.primary else Theme.surface,
		TextColor3 = if primary then Theme.onPrimary else Theme.text,
		Size = UDim2.fromOffset(160, 44),
	}
	return Ui.new("TextButton", styled(base, props, "label"), { Ui.corner(), Ui.stroke() })
end

-- Item icon: the item's 12x12 pixel sprite (shared/SpriteGui.luau); transparent background, the caller draws the slot.
function Ui.icon(id: string, px: number, props: { [string]: any }?): Frame
	local icon = SpriteGui.new(id, px)
	for k, v in props or {} do
		if k ~= "Parent" then
			(icon :: any)[k] = v
		end
	end
	icon.Parent = props and props.Parent
	return icon
end

-- Tier label on the tier colour (light text, >= 5.4:1 on every tier colour).
function Ui.tierBadge(tier: string, props: { [string]: any }?): TextLabel
	local base = {
		Size = UDim2.fromOffset(120, 26),
		BackgroundTransparency = 0,
		BackgroundColor3 = Theme.tiers[tier] or Theme.muted,
		Text = string.upper(tier),
		FontFace = Theme.type.label.font,
		TextSize = Theme.type.small.size, -- caps tier word inside a 26 px badge
		TextColor3 = Theme.onPrimary,
		TextXAlignment = Enum.TextXAlignment.Center,
	}
	for k, v in props or {} do
		base[k] = v
	end
	return Ui.new("TextLabel", base, { Ui.new("UICorner", { CornerRadius = UDim.new(0, 6) }) })
end

return Ui
