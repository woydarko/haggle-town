--!strict
-- Class card opened by a lobby mentor: the class perks in plain words (spec s4) and a Become button.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Theme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Theme"))
local Ui = require(script.Parent.Ui)

local INFO = {
	fisher = { color = Theme.fish, field = "fish", game = "catch zone when reeling", place = "the pier" },
	logger = { color = Theme.wood, field = "wood", game = "sweet spot when chopping", place = "the forest" },
	miner = { color = Theme.iron, field = "ore", game = "weak spots when mining", place = "the cave" },
}

local ClassCard = {}

export type Handlers = { choose: (cls: string) -> any, current: () -> string? }

function ClassCard.mount(gui: ScreenGui, h: Handlers)
	local card = Ui.new("Frame", {
		Name = "ClassCard",
		Parent = gui,
		Visible = false,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(420, 360),
		BackgroundColor3 = Theme.background,
	}, { Ui.corner(), Ui.stroke(), Ui.pad(16) })
	local title = Ui.text({ Parent = card, Size = UDim2.new(1, 0, 0, 36), FontFace = Theme.display, TextSize = 30 })
	local perks = Ui.text({ Parent = card, Position = UDim2.fromOffset(0, 44), Size = UDim2.new(1, 0, 0, 170), TextSize = 18, TextYAlignment = Enum.TextYAlignment.Top })
	local cost = Ui.text({ Parent = card, Position = UDim2.fromOffset(0, 220), Size = UDim2.new(1, 0, 0, 44), TextSize = 16, TextColor3 = Theme.muted })
	local become = Ui.button("Become", true, { Parent = card, Position = UDim2.fromOffset(0, 272), Size = UDim2.fromOffset(240, 48) })
	local close = Ui.button("Close", false, { Parent = card, Position = UDim2.new(1, -120, 0, 272), Size = UDim2.fromOffset(120, 48) })
	local status = Ui.text({ Parent = card, Position = UDim2.fromOffset(0, 324), Size = UDim2.new(1, 0, 0, 20), TextSize = 16 })

	local shown: string? = nil
	local busy = false

	local function render(cls: string)
		local info = INFO[cls]
		local name = Theme.classNames[cls]
		local current = h.current()
		title.Text = name
		title.TextColor3 = info.color
		perks.Text = table.concat({
			`Best at {info.place}. With {info.field}:`,
			`  - Bigger {info.game}`,
			`  - Better odds of rare {info.field}`,
			`  - 15% chance to get two at once`,
			`  - Merchants pay up to 10% more for your {info.field}`,
			"Everything else works as normal.",
		}, "\n")
		cost.Text = if current == nil
			then "Your first pick is free."
			elseif current == cls then "This is your class."
			else "Switching costs 100 C and works once every 5 minutes."
		become.Text = `Become a {name}`
		become.Active = current ~= cls
		become.AutoButtonColor = current ~= cls
		become.BackgroundTransparency = if current == cls then 0.6 else 0
		status.Text = ""
	end

	become.Activated:Connect(function()
		if busy or not shown or h.current() == shown then
			return
		end
		busy = true
		status.TextColor3, status.Text = Theme.muted, "..."
		local ok, r = pcall(h.choose, shown :: string)
		busy = false
		if ok and r and r.class then
			card.Visible = false
		else
			status.TextColor3 = Theme.error
			status.Text = if ok and r and r.message then r.message else "Could not reach the market. Try again."
		end
	end)
	close.Activated:Connect(function()
		card.Visible = false
	end)

	local api = {}
	function api.open(cls: string)
		if not INFO[cls] then
			return
		end
		shown = cls
		render(cls)
		card.Visible = true
	end
	return api
end

return ClassCard
