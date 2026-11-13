--!strict
-- Market Ledger pop-up (Ledger button in the HUD or L): the market at a glance, from the server's GetLedger view
-- (shared/LedgerView.luau, same public API as the web dashboard).
--   header: title, market day + restock timer, Close
--   three merchant cards: per item an icon, name (tier colour, trend arrow), stock bar, Buy and Sell stamps
--   bottom: Recent deals (icon + sentence, newest first) and Top traders (coin + goods)
-- Refreshes every 10 s while open.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Theme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Theme"))
local Ui = require(script.Parent.Ui)

local LedgerPanel = {}

local CATEGORY_COLOR = { woodcutter = Theme.wood, fishmonger = Theme.fish, smith = Theme.iron }
local TREND = { up = " ▲", down = " ▼", flat = "" }
local W, H = 760, 470

export type Handlers = { fetch: () -> any, onOpen: () -> () }

local function card(parent: Instance, props: { [string]: any }): Frame
	local base = { Parent = parent, BackgroundColor3 = Theme.surface }
	for k, v in props do
		base[k] = v
	end
	return Ui.new("Frame", base, { Ui.corner(), Ui.stroke(), Ui.pad(10) })
end

local function stamp(parent: Instance, text: string, x: UDim): TextLabel
	return Ui.text({
		Parent = parent,
		Position = UDim2.new(x, UDim.new(0, 2)),
		Size = UDim2.fromOffset(46, 22),
		BackgroundTransparency = 0,
		BackgroundColor3 = Theme.background,
		FontFace = Theme.numeric,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = false,
		Text = text,
	})
end

function LedgerPanel.mount(gui: ScreenGui, h: Handlers)
	local panel = Ui.new("Frame", {
		Name = "LedgerPanel",
		Parent = gui,
		Visible = false,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromOffset(W, H),
		BackgroundColor3 = Theme.background,
	}, { Ui.corner(), Ui.stroke(), Ui.pad(16) })

	Ui.text({ Parent = panel, Size = UDim2.fromOffset(300, 36), FontFace = Theme.display, TextSize = 30, Text = "Market Ledger" })
	local header = Ui.text({ Parent = panel, Position = UDim2.fromOffset(300, 8), Size = UDim2.new(1, -410, 0, 22), TextSize = 16, TextColor3 = Theme.muted, TextXAlignment = Enum.TextXAlignment.Right, Text = "" })
	local close = Ui.button("Close", false, { Parent = panel, Position = UDim2.new(1, -96, 0, 0), Size = UDim2.fromOffset(96, 34), TextSize = 18 })
	local note = Ui.text({ Parent = panel, Position = UDim2.fromOffset(0, 40), Size = UDim2.new(1, 0, 0, 18), TextSize = 14, TextColor3 = Theme.error, Text = "" })
	local body = Ui.new("Frame", { Parent = panel, Position = UDim2.fromOffset(0, 62), Size = UDim2.new(1, 0, 1, -62), BackgroundTransparency = 1 })

	local function render(v: any)
		body:ClearAllChildren()
		header.Text = if v then v.header or "" else ""
		note.Text = if v and v.note then v.note else ""
		if not v or v.state == "loading" or #(v.merchants or {}) == 0 then
			Ui.text({ Parent = body, Size = UDim2.fromScale(1, 1), TextSize = 20, TextColor3 = Theme.muted, TextXAlignment = Enum.TextXAlignment.Center, Text = if v then "Opening the ledger..." else "Can't reach the market. Try again soon." })
			return
		end

		-- Merchant cards
		local row = Ui.new("Frame", { Parent = body, Size = UDim2.new(1, 0, 0, 174), BackgroundTransparency = 1 }, {
			Ui.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder }),
		})
		for i, m in v.merchants do
			local color = CATEGORY_COLOR[m.id] or Theme.text
			local c = card(row, { LayoutOrder = i, Size = UDim2.new(1 / 3, -8, 1, 0) })
			Ui.text({ Parent = c, Size = UDim2.new(1, 0, 0, 24), FontFace = Theme.display, TextSize = 20, TextColor3 = color, Text = m.name })
			Ui.text({ Parent = c, Size = UDim2.new(1, 0, 0, 24), FontFace = Theme.numeric, TextSize = 13, TextColor3 = Theme.muted, TextXAlignment = Enum.TextXAlignment.Right, Text = `purse {m.purse} C` })
			for j, label in { "Buy", "Sell" } do
				Ui.text({ Parent = c, Position = UDim2.new(1, -98 + (j - 1) * 50, 0, 24), Size = UDim2.fromOffset(46, 16), TextSize = 12, TextColor3 = Theme.muted, TextXAlignment = Enum.TextXAlignment.Center, Text = label })
			end
			for k, it in m.items do
				local y = 42 + (k - 1) * 28
				local r = Ui.new("Frame", { Parent = c, Position = UDim2.fromOffset(0, y), Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1 })
				Ui.icon(it.id, 20, { Parent = r, Position = UDim2.fromOffset(0, 3) })
				Ui.text({ Parent = r, Position = UDim2.fromOffset(26, 0), Size = UDim2.new(1, -128, 0, 18), TextSize = 13, TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd, TextColor3 = Theme.tiers[it.tier] or Theme.text, Text = it.name .. (TREND[it.trend] or "") })
				local bar = Ui.new("Frame", { Parent = r, Position = UDim2.fromOffset(26, 20), Size = UDim2.new(1, -128, 0, 3), BorderSizePixel = 0, BackgroundColor3 = Theme.border })
				Ui.new("Frame", { Parent = bar, Size = UDim2.fromScale(math.clamp((it.stockPct or 0) / 200, 0, 1), 1), BorderSizePixel = 0, BackgroundColor3 = color })
				stamp(r, `{it.buy}`, UDim.new(1, -98))
				stamp(r, `{it.sell}`, UDim.new(1, -48))
			end
		end

		-- Recent deals
		local deals = card(body, { Position = UDim2.fromOffset(0, 186), Size = UDim2.new(0.62, -6, 1, -186) })
		Ui.text({ Parent = deals, Size = UDim2.new(1, 0, 0, 22), FontFace = Theme.display, TextSize = 18, Text = "Recent deals" })
		for i, line in v.deals do
			if i > 5 then
				break
			end
			local y = 26 + (i - 1) * 30
			local id = v.dealItems and v.dealItems[i]
			local x = 0
			if id then
				Ui.icon(id, 20, { Parent = deals, Position = UDim2.fromOffset(0, y + 4) })
				x = 26
			end
			Ui.text({ Parent = deals, Position = UDim2.fromOffset(x, y), Size = UDim2.new(1, -x, 0, 28), TextSize = 13, TextColor3 = if i == 1 then Theme.text else Theme.muted, Text = line })
		end

		-- Top traders
		local top = card(body, { Position = UDim2.new(0.62, 6, 0, 186), Size = UDim2.new(0.38, -6, 1, -186) })
		Ui.text({ Parent = top, Size = UDim2.new(1, 0, 0, 22), FontFace = Theme.display, TextSize = 18, Text = "Top traders" })
		Ui.text({ Parent = top, Size = UDim2.new(1, 0, 0, 22), TextSize = 12, TextColor3 = Theme.muted, TextXAlignment = Enum.TextXAlignment.Right, Text = "coin + goods" })
		if #v.leaders == 0 then
			Ui.text({ Parent = top, Position = UDim2.fromOffset(0, 30), Size = UDim2.new(1, 0, 0, 22), TextSize = 14, TextColor3 = Theme.muted, Text = "No traders yet" })
		end
		for i, l in v.leaders do
			local y = 28 + (i - 1) * 28
			Ui.text({ Parent = top, Position = UDim2.fromOffset(0, y), Size = UDim2.new(1, -80, 0, 26), TextSize = 15, TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd, Text = `{i}. {l.name}` })
			Ui.text({ Parent = top, Position = UDim2.new(1, -80, 0, y), Size = UDim2.fromOffset(80, 26), FontFace = Theme.numeric, TextSize = 15, TextColor3 = Theme.primary, TextXAlignment = Enum.TextXAlignment.Right, Text = `{l.worth} C` })
		end
	end

	local open = false
	local function refresh()
		local ok, v = pcall(h.fetch)
		if open then
			render(if ok then v else nil)
		end
	end
	close.Activated:Connect(function()
		open = false
		panel.Visible = false
	end)
	task.spawn(function()
		while gui.Parent do
			task.wait(10)
			if open then
				refresh()
			end
		end
	end)

	local api = {}
	function api.toggle()
		open = not open
		panel.Visible = open
		if open then
			h.onOpen()
			render({ state = "loading", header = "", merchants = {}, deals = {}, leaders = {} })
			refresh()
		end
	end
	return api
end

return LedgerPanel
