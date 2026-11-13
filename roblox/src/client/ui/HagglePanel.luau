--!strict
-- Bottom-center haggle panel (DESIGN_SYSTEM W3), kept short so a player reads it at a glance:
--   header: merchant name, mood tag, patience as three dots
--   bubble: the merchant's line, then the offer (item icon + stamped price); "Why?" swaps in the reasoning
--   chips: before a counter, one per bag item this merchant buys (icon + count); after a counter, two price chips
--          (fair = meet in the middle, bold = push back, shared/Suggest.luau) that send a sentence in one tap
--   input + Send for free text, Accept / Leave.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Theme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Theme"))
local Ui = require(script.Parent.Ui)
local Items = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Items"))
local Suggest = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Suggest"))

local HagglePanel = {}

local EXAMPLES = { woodcutter = "e.g. 2 oak for 90", fishmonger = "e.g. 2 sardine for 40", smith = "e.g. 3 copper for 90" }
local MOOD_COLOR = { pleased = Theme.success, annoyed = Theme.warning, angry = Theme.error }

export type Handlers = {
	send: (merchant: string, text: string) -> any,
	accept: (dealId: string) -> any,
	onBalances: (b: any) -> (),
	bag: () -> { [string]: number },
}

local WIDTH, HEIGHT = 520, 304

function HagglePanel.mount(gui: ScreenGui, h: Handlers)
	local panel = Ui.new("Frame", {
		Name = "HagglePanel",
		Parent = gui,
		Visible = false,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -24),
		Size = UDim2.fromOffset(WIDTH, HEIGHT),
		BackgroundColor3 = Theme.background,
		ClipsDescendants = true,
	}, { Ui.corner(), Ui.stroke(), Ui.pad(14), Ui.new("UIScale", { Name = "Scale" }) })

	-- Header
	local title = Ui.text({ Parent = panel, Size = UDim2.fromOffset(170, 30), FontFace = Theme.display, TextSize = 26 })
	local mood = Ui.text({ Parent = panel, Position = UDim2.fromOffset(176, 6), Size = UDim2.fromOffset(110, 20), FontFace = Theme.display, TextSize = 17, TextColor3 = Theme.muted })
	Ui.text({ Parent = panel, Position = UDim2.new(1, -150, 0, 6), Size = UDim2.fromOffset(90, 20), TextSize = 14, TextColor3 = Theme.muted, TextXAlignment = Enum.TextXAlignment.Right, Text = "patience" })
	local dots = {}
	for i = 1, 3 do
		dots[i] = Ui.new("Frame", { Parent = panel, Position = UDim2.new(1, -52 + (i - 1) * 18, 0, 9), Size = UDim2.fromOffset(12, 12), BackgroundColor3 = Theme.warning }, {
			Ui.new("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
			Ui.new("UIStroke", { Color = Theme.warning, Thickness = 1.5 }),
		})
	end

	-- Bubble: line, then the offer row
	local bubble = Ui.new("Frame", { Parent = panel, Position = UDim2.fromOffset(0, 38), Size = UDim2.new(1, 0, 0, 92), BackgroundColor3 = Theme.surface }, { Ui.corner(), Ui.pad(10) })
	local line = Ui.text({ Parent = bubble, Size = UDim2.new(1, 0, 0, 44), TextSize = 18, TextYAlignment = Enum.TextYAlignment.Top, TextTruncate = Enum.TextTruncate.AtEnd })
	local offer = Ui.new("Frame", { Parent = bubble, Position = UDim2.fromOffset(0, 44), Size = UDim2.new(1, 0, 0, 28), BackgroundTransparency = 1, Visible = false })
	local offerIcon = Ui.new("Frame", { Parent = offer, Size = UDim2.fromOffset(28, 28), BackgroundTransparency = 1 })
	local price = Ui.text({ Parent = offer, Position = UDim2.fromOffset(36, 0), Size = UDim2.fromOffset(110, 28), FontFace = Theme.numeric, TextSize = 24, TextColor3 = Theme.primary })
	local qtyNote = Ui.text({ Parent = offer, Position = UDim2.fromOffset(150, 4), Size = UDim2.fromOffset(170, 22), FontFace = Theme.numeric, TextSize = 16, TextColor3 = Theme.muted })
	local why = Ui.button("Why?", false, { Parent = offer, Position = UDim2.new(1, -64, 0, 0), Size = UDim2.fromOffset(64, 28), TextSize = 15, Visible = false })

	local chips = Ui.new("Frame", { Parent = panel, Position = UDim2.fromOffset(0, 138), Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1 }, {
		Ui.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local input = Ui.new("TextBox", {
		Parent = panel,
		Position = UDim2.fromOffset(0, 186),
		Size = UDim2.new(1, -100, 0, 40),
		BackgroundColor3 = Theme.surface,
		FontFace = Theme.body,
		TextSize = 17,
		TextColor3 = Theme.text,
		PlaceholderText = "Type an offer",
		PlaceholderColor3 = Theme.muted,
		ClearTextOnFocus = false,
		Text = "",
		TextXAlignment = Enum.TextXAlignment.Left,
	}, { Ui.corner(), Ui.stroke(), Ui.pad(8) })
	local send = Ui.button("Send", false, { Parent = panel, Position = UDim2.new(1, -90, 0, 186), Size = UDim2.fromOffset(90, 40) })
	local accept = Ui.button("Accept", true, { Parent = panel, Position = UDim2.fromOffset(0, 234), Size = UDim2.fromOffset(220, 42) })
	local leave = Ui.button("Leave", false, { Parent = panel, Position = UDim2.new(1, -120, 0, 234), Size = UDim2.fromOffset(120, 42) })
	local status = Ui.text({ Parent = panel, Position = UDim2.new(0, 228, 0, 234), Size = UDim2.new(1, -356, 0, 42), TextSize = 14, TextColor3 = Theme.muted, TextXAlignment = Enum.TextXAlignment.Center }) -- two lines between Accept and Leave

	local merchant: string? = nil
	local deal: any = nil
	local busy = false
	local saidLine, reason, showingWhy = "", "", false
	local submit: () -> ()

	local function setCounter(c: any)
		deal = c
		offer.Visible = c ~= nil
		offerIcon:ClearAllChildren()
		if c then
			Ui.icon(c.item, 28, { Parent = offerIcon })
			price.Text = `{c.unitPrice} C`
			qtyNote.Text = if c.qty > 1 then `x{c.qty} = {c.total} C` else ""
			qtyNote.Position = UDim2.fromOffset(36 + price.TextBounds.X + 10, 4) -- sits right after the price
			accept.Text = `Accept {c.total} C`
		else
			accept.Text = "Accept"
		end
		accept.Active, accept.AutoButtonColor = c ~= nil, c ~= nil
		accept.BackgroundTransparency = if c then 0 else 0.6
	end

	local function setPatience(n: number?)
		local p = n or 3
		for i, d in dots do
			d.BackgroundTransparency = if i <= p then 0 else 1
		end
	end

	local function setMood(m: string?)
		local word = m or "neutral"
		mood.Text = word
		mood.TextColor3 = MOOD_COLOR[word] or Theme.muted
		mood.Position = UDim2.fromOffset(title.TextBounds.X + 12, 7) -- right after the merchant name
	end

	local function setBusy(on: boolean, text: string?)
		busy = on
		send.Active = not on
		input.TextEditable = not on
		status.TextColor3 = Theme.muted
		status.Text = text or ""
	end

	local function clearChips()
		for _, c in chips:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
	end

	-- Before a counter: one chip per item of this merchant's category in the bag; tap fills "sell 1 <item> for ".
	local function renderChips()
		clearChips()
		local b = h.bag()
		local count = 0
		for i, item in Items.ofCategory(Items.MERCHANT_CATEGORY[merchant :: string] or "") do
			local qty = b[item.id] or 0
			if qty > 0 then
				count += 1
				local chip = Ui.button("", false, { Parent = chips, LayoutOrder = i, Size = UDim2.fromOffset(84, 40) })
				Ui.icon(item.id, 28, { Parent = chip, Position = UDim2.fromOffset(8, 6) })
				Ui.text({ Parent = chip, Position = UDim2.fromOffset(40, 0), Size = UDim2.new(1, -44, 1, 0), FontFace = Theme.numeric, TextSize = 16, Text = `x{qty}` })
				chip.Activated:Connect(function()
					input.Text = `sell 1 {string.lower(item.name)} for `
					input:CaptureFocus()
					input.CursorPosition = #input.Text + 1
				end)
			end
		end
		if count == 0 then
			Ui.text({ Parent = chips, Size = UDim2.fromScale(1, 1), TextSize = 15, TextColor3 = Theme.muted, Text = "Nothing to sell here yet. You can still buy." })
		end
	end

	-- After a counter: two price chips, each sends a full sentence in the player's voice (wording rotates per round).
	local round, shown = 0, {}
	local function renderSuggestions(c: any)
		clearChips()
		round += 1
		local item = Items.byId[c.item]
		local ctx = { side = c.side, unitPrice = c.unitPrice, itemName = c.itemName or (item and item.name) or "goods", qty = c.qty, round = round }
		shown = Suggest.lines(ctx, shown)
		local p = Suggest.prices(ctx)
		for i, opt in { { p.meet, "fair", shown[1] }, { p.firm, "bold", shown[3] } } do
			local chip = Ui.button("", false, { Parent = chips, LayoutOrder = i, Size = UDim2.fromOffset(120, 40) })
			Ui.text({ Parent = chip, Position = UDim2.fromOffset(12, 0), Size = UDim2.new(0, 60, 1, 0), FontFace = Theme.numeric, TextSize = 18, Text = `{opt[1]} C` })
			Ui.text({ Parent = chip, Position = UDim2.new(1, -52, 0, 0), Size = UDim2.new(0, 44, 1, 0), TextSize = 14, TextColor3 = Theme.muted, TextXAlignment = Enum.TextXAlignment.Right, Text = opt[2] })
			chip.Activated:Connect(function()
				input.Text = opt[3]
				submit()
			end)
		end
		Ui.text({ Parent = chips, LayoutOrder = 3, Size = UDim2.new(1, -256, 1, 0), TextSize = 14, TextColor3 = Theme.muted, Text = "or type your own" })
	end

	local function showError(text: string)
		status.TextColor3 = Theme.error
		status.Text = text
	end

	local function say(text: string, why_: string?)
		saidLine, reason, showingWhy = text, why_ or "", false
		line.Text, line.TextColor3 = `"{text}"`, Theme.text
		why.Visible = reason ~= ""
		why.Text = "Why?"
	end
	why.Activated:Connect(function()
		showingWhy = not showingWhy
		line.Text = if showingWhy then reason else `"{saidLine}"`
		line.TextColor3 = if showingWhy then Theme.muted else Theme.text
		why.Text = if showingWhy then "Back" else "Why?"
	end)

	local function render(r: any)
		if r.error then
			showError(r.message or "Could not reach the market. Try again.")
			return
		end
		say(r.line, r.reasoning)
		setMood(r.mood)
		setPatience(r.patience)
		if r.refused then
			setCounter(nil)
			local secs = math.max(0, math.floor((r.refused["until"] - DateTime.now().UnixTimestampMillis) / 1000))
			showError(string.format("Come back in %d:%02d.", secs // 60, secs % 60))
		else
			setCounter(r.counter)
			if r.counter then
				renderSuggestions(r.counter)
			end
		end
	end

	function submit()
		if busy or not merchant then
			return
		end
		local text = input.Text
		if #string.gsub(text, "%s", "") == 0 then
			return
		end
		setBusy(true, "thinking...")
		local ok, r = pcall(h.send, merchant :: string, text)
		setBusy(false)
		if ok then
			input.Text = ""
			render(r)
		else
			showError("Offline. Try again.")
		end
	end

	send.Activated:Connect(submit)
	input.FocusLost:Connect(function(enter)
		if enter then
			submit()
		end
	end)

	accept.Activated:Connect(function()
		if busy or not deal then
			return
		end
		setBusy(true, "settling...")
		local ok, r = pcall(h.accept, deal.dealId)
		setBusy(false)
		if not ok then
			showError("Failed. Goods untouched.")
			return
		end
		if r.status == "settled" then
			setCounter(nil)
			status.TextColor3 = Theme.success
			status.Text = "Deal done!"
			if r.balances then
				h.onBalances(r.balances)
			end
			renderChips()
		elseif r.status == "requoted" then
			say(r.line, r.reasoning)
			setCounter(r.counter)
			renderSuggestions(r.counter)
			status.TextColor3 = Theme.warning
			status.Text = "Price moved"
		else
			setCounter(nil)
			showError("Failed. Goods untouched.")
		end
	end)

	leave.Activated:Connect(function()
		panel.Visible = false
		merchant = nil
	end)

	local api = {}

	function api.open(name: string)
		merchant = name
		title.Text = Theme.merchantNames[name]
		say("Welcome! What can I do for you?")
		setMood("neutral")
		input.Text = ""
		input.PlaceholderText = EXAMPLES[name] or "Type an offer"
		setCounter(nil)
		setPatience(3)
		setBusy(false)
		round, shown = 0, {}
		renderChips()
		panel.Visible = true
		panel.Size = UDim2.fromOffset(WIDTH, 0)
		TweenService:Create(panel, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = UDim2.fromOffset(WIDTH, HEIGHT) }):Play()
		input:CaptureFocus()
	end

	return api
end

return HagglePanel
