--!strict
-- Tiny helper to build UI instances with Theme tokens.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Theme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Theme"))

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
		Font = Theme.body,
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
		Font = Theme.display,
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

return Ui
