--!strict
-- Top bar: coin, class badge, bag count, Ledger, Stats and Forge buttons; toast line + offline banner (DESIGN_SYSTEM W2).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Theme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Theme"))
local Ui = require(script.Parent.Ui)
local Items = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Items"))
local Icons = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Icons"))

local Hud = {}

function Hud.mount(gui: ScreenGui, onStats: () -> (), onLedger: () -> (), onForge: () -> ())
	local bar = Ui.new("Frame", {
		Name = "Hud",
		Parent = gui,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.fromOffset(700, 44), -- 130+90+80+94+100+100 + 5x16 gaps + padding
		BackgroundColor3 = Theme.background,
	}, { Ui.corner(), Ui.stroke(), Ui.pad(8), Ui.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 16), VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }) })

	local coin = Ui.text({ Parent = bar, LayoutOrder = 1, Size = UDim2.fromOffset(130, 32), FontFace = Theme.numeric, TextSize = 20, TextColor3 = Theme.primary, Text = "..." })
	Ui.new("UIPadding", { Parent = coin, PaddingLeft = UDim.new(0, 34) })
	Ui.new("ImageLabel", { Parent = coin, Name = "CoinIcon", Position = UDim2.fromOffset(-34, 2), Size = UDim2.fromOffset(28, 28), BackgroundTransparency = 1, Image = Icons.coin })
	local badge = Ui.text({ Parent = bar, LayoutOrder = 2, Size = UDim2.fromOffset(90, 32), FontFace = Theme.display, TextSize = 20, TextColor3 = Theme.muted, Text = "No class" })
	local bag = Ui.text({ Parent = bar, LayoutOrder = 3, Size = UDim2.fromOffset(80, 32), FontFace = Theme.numeric, TextSize = 20, Text = "Bag 0" })
	local ledger = Ui.button("Ledger (L)", false, { Parent = bar, LayoutOrder = 4, Size = UDim2.fromOffset(94, 30), TextSize = 16 })
	ledger.Activated:Connect(onLedger)
	local stats = Ui.button("Stats (Tab)", false, { Parent = bar, LayoutOrder = 5, Size = UDim2.fromOffset(100, 30), TextSize = 16 })
	stats.Activated:Connect(onStats)
	local forge = Ui.button("Forge (F)", false, { Parent = bar, LayoutOrder = 6, Size = UDim2.fromOffset(100, 30), TextSize = 16 })
	forge.Activated:Connect(onForge)
	local CLASS_COLOR = { fisher = Theme.fish, logger = Theme.wood, miner = Theme.iron }

	local toast = Ui.text({ Parent = gui, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 58), Size = UDim2.fromOffset(440, 28), TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = Theme.muted, Text = "", TextStrokeTransparency = 0.8 })
	local offline = Ui.text({
		Parent = gui,
		Visible = false,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 90),
		Size = UDim2.fromOffset(440, 40),
		BackgroundTransparency = 0,
		BackgroundColor3 = Theme.error,
		TextColor3 = Theme.onPrimary,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "Market offline - your goods are safe",
	})

	local api = {}

	function api.balances(b: { [string]: number })
		coin.Text = `{b.coin or 0} C`
		bag.Text = `Bag {Items.bagCount(b)}`
	end

	function api.class(cls: string?)
		badge.Text = if cls then Theme.classNames[cls] else "No class"
		badge.TextColor3 = if cls then CLASS_COLOR[cls] else Theme.muted
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
