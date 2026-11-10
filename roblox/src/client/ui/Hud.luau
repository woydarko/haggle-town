--!strict
-- Top-left balances + toast line + offline banner (DESIGN_SYSTEM W2).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Theme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Theme"))
local Ui = require(script.Parent.Ui)

local Hud = {}

function Hud.mount(gui: ScreenGui)
	local bar = Ui.new("Frame", {
		Name = "Hud",
		Parent = gui,
		Position = UDim2.fromOffset(16, 16),
		Size = UDim2.fromOffset(440, 48),
		BackgroundColor3 = Theme.background,
	}, { Ui.corner(), Ui.stroke(), Ui.pad(8), Ui.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 16), VerticalAlignment = Enum.VerticalAlignment.Center }) })

	local labels: { [string]: TextLabel } = {}
	for _, item in { { "coin", "Coin", Theme.primary }, { "wood", "Wood", Theme.wood }, { "fish", "Fish", Theme.fish }, { "iron", "Iron", Theme.iron } } do
		local key, name, color = item[1], item[2], item[3]
		labels[key] = Ui.text({
			Parent = bar,
			Size = UDim2.fromOffset(if key == "coin" then 130 else 80, 32),
			Font = Theme.numeric,
			TextSize = 20,
			TextColor3 = color,
			Text = name .. " ...",
		})
	end

	local toast = Ui.text({ Parent = gui, Position = UDim2.fromOffset(16, 72), Size = UDim2.fromOffset(440, 28), TextColor3 = Theme.muted, Text = "", TextStrokeTransparency = 0.8 })
	local offline = Ui.text({
		Parent = gui,
		Visible = false,
		Position = UDim2.new(0.5, -220, 0, 16),
		Size = UDim2.fromOffset(440, 40),
		BackgroundTransparency = 0,
		BackgroundColor3 = Theme.error,
		TextColor3 = Theme.onPrimary,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "Market offline - your goods are safe",
	})

	local api = {}

	function api.balances(b: { [string]: number })
		for key, label in labels do
			local name = if key == "coin" then "Coin" else key:sub(1, 1):upper() .. key:sub(2)
			label.Text = if key == "coin" then `{name} {b[key] or 0} C` else `{name} {b[key] or 0}`
		end
	end

	function api.offline(on: boolean)
		offline.Visible = on
	end

	function api.toast(text: string)
		toast.Text = text
		toast.TextTransparency = 0
		task.delay(2.5, function()
			if toast.Text == text then
				TweenService:Create(toast, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
			end
		end)
	end

	return api
end

return Hud
