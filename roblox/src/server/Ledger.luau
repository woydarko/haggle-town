--!strict
-- Market Ledger: the in-world dashboard on the square. Polls the same public API the web dashboard uses every
-- 10 s, shapes it with shared/LedgerView.luau and draws it on the board's SurfaceGui.
-- Layout (1200 x 640 px): header row; prices per merchant (left, the focal point); recent deals; top traders.
-- The "stamped price" (bold number on a light tile with an ink outline) is the shared motif with the haggle panel.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared:WaitForChild("Theme"))
local LedgerView = require(Shared:WaitForChild("LedgerView"))
local SpriteGui = require(Shared:WaitForChild("SpriteGui"))
local Backend = require(script.Parent.Backend)

local Ledger = {}
local POLL_S = 10
local CATEGORY_COLOR = { woodcutter = Theme.wood, fishmonger = Theme.fish, smith = Theme.iron }
local TREND = { up = "▲", down = "▼", flat = "" }

local function label(parent: Instance, props: { [string]: any }): TextLabel
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.FontFace = Theme.body
	t.TextColor3 = Theme.text
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.TextTruncate = Enum.TextTruncate.AtEnd
	for k, v in props do
		(t :: any)[k] = v
	end
	t.Parent = parent
	return t
end

local function frame(parent: Instance, props: { [string]: any }): Frame
	local f = Instance.new("Frame")
	f.BackgroundTransparency = 1
	f.BorderSizePixel = 0
	for k, v in props do
		(f :: any)[k] = v
	end
	f.Parent = parent
	return f
end

local function stamp(parent: Instance, text: string, x: number, w: number): TextLabel
	local t = label(parent, {
		Position = UDim2.fromOffset(x, 2),
		Size = UDim2.fromOffset(w, 26),
		BackgroundTransparency = 0,
		BackgroundColor3 = Theme.surface,
		FontFace = Theme.numeric,
		TextSize = 20,
		Text = text,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 4)
	c.Parent = t
	local s = Instance.new("UIStroke")
	s.Color = Theme.text
	s.Thickness = 1
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = t
	return t
end

local COL = { item = 0, buy = 262, sell = 364, stock = 470 }

local function draw(gui: SurfaceGui, v: any)
	gui:ClearAllChildren()
	local root = frame(gui, { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 0, BackgroundColor3 = Theme.background })
	local pad = Instance.new("UIPadding")
	for _, k in { "PaddingLeft", "PaddingRight", "PaddingTop", "PaddingBottom" } do
		(pad :: any)[k] = UDim.new(0, 20)
	end
	pad.Parent = root

	label(root, { Size = UDim2.new(0.5, 0, 0, 52), FontFace = Theme.display, TextSize = 46, Text = "Market Ledger" })
	label(root, { Position = UDim2.new(0.5, 0, 0, 8), Size = UDim2.new(0.5, 0, 0, 36), TextSize = 24, TextColor3 = Theme.muted, Text = v.header, TextXAlignment = Enum.TextXAlignment.Right })
	if v.note then
		label(root, { Position = UDim2.fromOffset(0, 52), Size = UDim2.new(1, 0, 0, 26), TextSize = 20, TextColor3 = Theme.error, Text = v.note })
	end
	if v.state == "loading" then
		label(root, { Position = UDim2.fromOffset(0, 200), Size = UDim2.new(1, 0, 0, 60), TextSize = 32, TextColor3 = Theme.muted, Text = "Fetching prices from the market...", TextXAlignment = Enum.TextXAlignment.Center })
		return
	end

	local top = 84
	-- Prices: one block per merchant, the reason people walk up to the board.
	local prices = frame(root, { Position = UDim2.fromOffset(0, top), Size = UDim2.new(0.58, -16, 1, -top) })
	for name, x in { Item = COL.item, ["You buy"] = COL.buy, ["You sell"] = COL.sell, Stock = COL.stock } do
		label(prices, { Position = UDim2.fromOffset(x, 0), Size = UDim2.fromOffset(100, 22), TextSize = 18, TextColor3 = Theme.muted, Text = name })
	end
	local y = 26
	for _, m in v.merchants do
		label(prices, { Position = UDim2.fromOffset(0, y), Size = UDim2.new(0.6, 0, 0, 30), FontFace = Theme.display, TextSize = 26, TextColor3 = CATEGORY_COLOR[m.id] or Theme.text, Text = m.name })
		label(prices, { Position = UDim2.new(0.6, 0, 0, y + 4), Size = UDim2.new(0.4, 0, 0, 24), FontFace = Theme.numeric, TextSize = 18, TextColor3 = Theme.muted, Text = `purse {m.purse} C`, TextXAlignment = Enum.TextXAlignment.Right })
		y += 32
		for _, it in m.items do
			local row = frame(prices, { Position = UDim2.fromOffset(0, y), Size = UDim2.new(1, 0, 0, 30) })
			local icon = SpriteGui.new(it.id, 24)
			icon.Position = UDim2.fromOffset(0, 3)
			icon.Parent = row
			label(row, { Position = UDim2.fromOffset(30, 0), Size = UDim2.fromOffset(220, 30), TextSize = 20, TextColor3 = Theme.tiers[it.tier] or Theme.text, Text = `{it.name} {TREND[it.trend] or ""}` })
			stamp(row, `{it.buy} C`, COL.buy, 90)
			stamp(row, `{it.sell} C`, COL.sell, 90)
			local bar = frame(row, { Position = UDim2.fromOffset(COL.stock, 10), Size = UDim2.fromOffset(160, 10), BackgroundTransparency = 0, BackgroundColor3 = Theme.border })
			frame(bar, { Size = UDim2.fromScale(math.clamp(it.stockPct / 200, 0, 1), 1), BackgroundTransparency = 0, BackgroundColor3 = CATEGORY_COLOR[m.id] or Theme.muted })
			y += 30
		end
		y += 8
	end

	-- Recent deals.
	local deals = frame(root, { Position = UDim2.new(0.58, 0, 0, top), Size = UDim2.new(0.25, -12, 1, -top) })
	label(deals, { Size = UDim2.new(1, 0, 0, 30), FontFace = Theme.display, TextSize = 26, Text = "Recent deals" })
	for i, line in v.deals do
		label(deals, { Position = UDim2.fromOffset(0, 34 + (i - 1) * 62), Size = UDim2.new(1, 0, 0, 58), TextSize = 18, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, TextTruncate = Enum.TextTruncate.None, Text = line })
	end

	-- Top traders.
	local lead = frame(root, { Position = UDim2.new(0.83, 0, 0, top), Size = UDim2.new(0.17, 0, 1, -top) })
	label(lead, { Size = UDim2.new(1, 0, 0, 30), FontFace = Theme.display, TextSize = 26, Text = "Top traders" })
	if #v.leaders == 0 then
		label(lead, { Position = UDim2.fromOffset(0, 34), Size = UDim2.new(1, 0, 0, 24), TextSize = 18, TextColor3 = Theme.muted, Text = "No traders yet" })
	end
	for i, l in v.leaders do
		label(lead, { Position = UDim2.fromOffset(0, 34 + (i - 1) * 46), Size = UDim2.new(1, 0, 0, 22), TextSize = 18, Text = `{i}. {l.name}` })
		label(lead, { Position = UDim2.fromOffset(0, 56 + (i - 1) * 46), Size = UDim2.new(1, 0, 0, 20), FontFace = Theme.numeric, TextSize = 16, TextColor3 = Theme.muted, Text = `{l.worth} C` })
	end
end

function Ledger.start(board: BasePart)
	local gui = board:FindFirstChild("Gui") :: SurfaceGui
	local s = { market = nil :: any, feed = nil :: any, leaders = nil :: any, config = nil :: any, lastOk = nil :: number?, ok = false }
	local lastAsk: { [string]: number } = {}
	local prev: { [string]: number } = {}
	local function now()
		return DateTime.now().UnixTimestampMillis
	end
	draw(gui, LedgerView.build({ now = now(), ok = false }))
	task.spawn(function()
		while true do
			if not (s.config and s.config.dayLengthMs) then -- older backends have no day length yet; keep asking
				local okC, cfg = Backend.get("/api/config")
				s.config = if okC then cfg else nil
			end
			local okM, market = Backend.get("/api/market")
			local okF, feed = Backend.get("/api/feed")
			local okL, leaders = Backend.get("/api/leaderboard")
			s.ok = okM and type(market) == "table" and #market > 0
			if s.ok then
				for _, r in market do
					if lastAsk[r.item] and lastAsk[r.item] ~= r.ask then
						prev[r.item] = lastAsk[r.item] -- trend arrow = direction of the last price change
					end
					lastAsk[r.item] = r.ask
				end
				s.market, s.lastOk = market, now()
			end
			if okF then
				s.feed = feed
			end
			if okL then
				s.leaders = leaders
			end
			local okDraw, err = pcall(draw, gui, LedgerView.build({ market = s.market, feed = s.feed, leaders = s.leaders, config = s.config, now = now(), ok = s.ok, lastOk = s.lastOk, prev = prev }))
			if not okDraw then
				warn("[Ledger] draw failed: " .. tostring(err))
			end
			task.wait(POLL_S)
		end
	end)
end

return Ledger
