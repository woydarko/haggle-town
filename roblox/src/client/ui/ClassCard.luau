--!strict
-- Trade conversation with the guild mentor (the lobby's one mentor opens it). The mentor speaks in a bubble; the player
-- picks Fisher, Logger or Miner from three choices, hears how that trade works and its perks (spec s4), then becomes it
-- or asks about another.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Theme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Theme"))
local Ui = require(script.Parent.Ui)

local ORDER = { "fisher", "logger", "miner" }
local INFO = {
	fisher = {
		color = Theme.fish, icon = "fish_trout", hook = "Fish at the piers", field = "fish", game = "catch zone when reeling", buyer = "Fishmonger",
		talk = "Fishers work the lake pier and the sea pier. Take out your rod (key 3), cast into the water, then keep the fish inside the catch zone while you reel it in.",
	},
	logger = {
		color = Theme.wood, icon = "wood_oak", hook = "Chop in the woods", field = "wood", game = "sweet spot when chopping", buyer = "Woodcutter",
		talk = "Loggers work the woods past the west gate. Take out your axe (key 1), click a tree and stop the swing in the sweet spot. The old grove far west has the rarest wood.",
	},
	miner = {
		color = Theme.iron, icon = "ore_iron", hook = "Mine the mountain cave", field = "ore", game = "weak spots when mining", buyer = "Smith",
		talk = "Miners work the mountain cave past the east gate. Take out your pickaxe (key 2), click a rock and hit the glowing weak spots before they fade. Deep caverns hold crystal.",
	},
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
		Size = UDim2.fromOffset(460, 430),
		BackgroundColor3 = Theme.background,
	}, { Ui.corner(), Ui.stroke(), Ui.pad(16) })
	Ui.text({ Parent = card, Size = UDim2.new(1, 0, 0, 24), Style = "label", TextColor3 = Theme.muted, Text = "Guild mentor" })
	local bubble = Ui.new("Frame", { Parent = card, Position = UDim2.fromOffset(0, 28), Size = UDim2.new(1, 0, 0, 112), BackgroundColor3 = Theme.surface }, { Ui.corner(), Ui.stroke(), Ui.pad(12) })
	local speech = Ui.text({ Parent = bubble, Size = UDim2.fromScale(1, 1), Style = "body", TextYAlignment = Enum.TextYAlignment.Top, Text = "" })
	local body = Ui.new("Frame", { Parent = card, Position = UDim2.fromOffset(0, 152), Size = UDim2.new(1, 0, 1, -152), BackgroundTransparency = 1 })

	local busy = false
	local showIntro: () -> ()

	local function clear()
		body:ClearAllChildren()
	end

	local function showClass(cls: string)
		clear()
		local info, name, current = INFO[cls], Theme.classNames[cls], h.current()
		speech.Text = info.talk
		Ui.icon(info.icon, 36, { Parent = body })
		Ui.text({ Parent = body, Position = UDim2.fromOffset(44, 2), Size = UDim2.new(1, -44, 0, 32), Style = "heading", TextColor3 = info.color, Text = name })
		Ui.text({ Parent = body, Position = UDim2.fromOffset(0, 42), Size = UDim2.new(1, 0, 0, 84), Style = "small", TextYAlignment = Enum.TextYAlignment.Top, Text = table.concat({
			`- Bigger {info.game}`,
			`- Better odds of rare {info.field}`,
			"- 15% chance to get two at once",
			`- The {info.buyer} pays you up to 10% more`,
		}, "\n") })
		local status = Ui.text({ Parent = body, Position = UDim2.fromOffset(0, 128), Size = UDim2.new(1, 0, 0, 22), Style = "small", TextColor3 = Theme.muted, Text = if current == nil
			then "Your first pick is free."
			elseif current == cls then "This is already your trade."
			else "Switching costs 100 C, once every 5 minutes." })
		local become = Ui.button(if current == cls then "Your trade" else `Become a {name}`, true, { Parent = body, Position = UDim2.new(0, 0, 1, -48), Size = UDim2.fromOffset(220, 48) })
		become.Active, become.AutoButtonColor = current ~= cls, current ~= cls
		become.BackgroundTransparency = if current == cls then 0.6 else 0
		local back = Ui.button("Ask about another", false, { Parent = body, Position = UDim2.new(1, -196, 1, -48), Size = UDim2.fromOffset(196, 48), Style = "label" })
		back.Activated:Connect(function()
			showIntro()
		end)
		become.Activated:Connect(function()
			if busy or h.current() == cls then
				return
			end
			busy = true
			status.TextColor3, status.Text = Theme.muted, "..."
			local ok, r = pcall(h.choose, cls)
			busy = false
			if ok and r and r.class then
				card.Visible = false
			else
				status.TextColor3 = Theme.error
				status.Text = if ok and r and r.message then r.message else "Could not reach the market. Try again."
			end
		end)
	end

	function showIntro()
		clear()
		local current = h.current()
		speech.Text = if current
			then `Back again! You work as a {Theme.classNames[current]} now. You can switch trades, but it costs 100 C and only once every 5 minutes.`
			else "Welcome to Haggle Town! Every trader here picks a trade. It decides what you gather best and who pays you most. Which one sounds like you?"
		for i, cls in ORDER do
			local info = INFO[cls]
			local row = Ui.new("TextButton", { Parent = body, Text = "", AutoButtonColor = true, Position = UDim2.fromOffset(0, (i - 1) * 62), Size = UDim2.new(1, 0, 0, 56), BackgroundColor3 = Theme.surface }, { Ui.corner(), Ui.stroke() })
			Ui.icon(info.icon, 36, { Parent = row, Position = UDim2.fromOffset(10, 10) })
			Ui.text({ Parent = row, Position = UDim2.fromOffset(56, 4), Size = UDim2.new(1, -64, 0, 26), Style = "heading", TextColor3 = info.color, Text = Theme.classNames[cls] .. (if current == cls then "  (your trade)" else "") })
			Ui.text({ Parent = row, Position = UDim2.fromOffset(56, 30), Size = UDim2.new(1, -64, 0, 20), Style = "small", TextColor3 = Theme.muted, Text = info.hook })
			row.Activated:Connect(function()
				showClass(cls)
			end)
		end
		local close = Ui.button("Close", false, { Parent = body, Position = UDim2.new(1, -120, 1, -48), Size = UDim2.fromOffset(120, 48) })
		close.Activated:Connect(function()
			card.Visible = false
		end)
	end

	local api = {}
	-- No class: start the conversation with the three choices; a class jumps straight to it.
	function api.open(cls: string?)
		if cls and INFO[cls] then
			showClass(cls)
		else
			showIntro()
		end
		card.Visible = true
	end
	return api
end

return ClassCard
