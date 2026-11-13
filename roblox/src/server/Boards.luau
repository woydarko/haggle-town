--!strict
-- Renders the price board, leaderboards and lobby info boards as SurfaceGuis (server-side, replicated).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared:WaitForChild("Theme"))
local Items = require(Shared:WaitForChild("Items"))

local Boards = {}

local lastAsk: { [string]: number } = {}

local function label(parent: Instance, text: string, color: Color3, size: number, height: number, font: Font?): TextLabel
	local t = Instance.new("TextLabel")
	t.Size = UDim2.new(1, 0, 0, height)
	t.BackgroundTransparency = 1
	t.FontFace = font or Theme.body
	t.TextSize = size
	t.TextColor3 = color
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.TextWrapped = true
	t.Text = text
	t.Parent = parent
	return t
end

local function list(parent: Instance, padding: number)
	local l = Instance.new("UIListLayout")
	l.Padding = UDim.new(0, padding)
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.Parent = parent
end

local function canvas(board: BasePart, title: string): Frame
	local gui = board:FindFirstChild("Gui") :: SurfaceGui
	local old = gui:FindFirstChild("Canvas")
	if old then
		old:Destroy()
	end
	local f = Instance.new("Frame")
	f.Name = "Canvas"
	f.Size = UDim2.fromScale(1, 1)
	f.BackgroundColor3 = Theme.background
	list(f, 8)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingTop, pad.PaddingRight = UDim.new(0, 24), UDim.new(0, 16), UDim.new(0, 24)
	pad.Parent = f
	label(f, title, Theme.text, 44, 56, Theme.display)
	f.Parent = gui
	return f
end

local function row(parent: Frame, left: string, right: string, color: Color3)
	label(parent, string.format("%-12s %s", left, right), color, 34, 44, Theme.numeric)
end

-- Three columns (fish, wood, ore), each item: name in its tier color, then buy/sell and the move since last refresh.
function Boards.renderPrices(board: BasePart, market: { any }?)
	local f = canvas(board, "Today's prices")
	if not market or #market == 0 then
		row(f, "Opening soon", "", Theme.muted)
		return
	end
	local byItem: { [string]: any } = {}
	for _, m in market do
		byItem[m.item] = m
	end
	local cols = Instance.new("Frame")
	cols.BackgroundTransparency = 1
	cols.Size = UDim2.new(1, 0, 1, -72)
	local h = Instance.new("UIListLayout")
	h.FillDirection = Enum.FillDirection.Horizontal
	h.Padding = UDim.new(0, 16)
	h.SortOrder = Enum.SortOrder.LayoutOrder
	h.Parent = cols
	for i, cat in Items.CATEGORIES do
		local col = Instance.new("Frame")
		col.BackgroundTransparency = 1
		col.LayoutOrder = i
		col.Size = UDim2.new(1 / 3, -11, 1, 0)
		list(col, 0)
		label(col, Theme.categoryNames[cat], (Theme :: any)[cat], 28, 34, Theme.display)
		for _, item in Items.ofCategory(cat) do
			local m = byItem[item.id]
			if m then
				local prev = lastAsk[item.id]
				local move = if prev == nil or prev == m.ask then "" elseif m.ask > prev then " up" else " down"
				lastAsk[item.id] = m.ask
				-- 34 + 4 x 48 px fits the 8-stud board (320 px) under the title
				label(col, item.name, Theme.tiers[item.tier], 22, 26, Theme.display)
				label(col, `{m.ask} / {m.bid} C{move}`, Theme.muted, 18, 22, Theme.numeric)
			end
		end
		col.Parent = cols
	end
	cols.Parent = f
end

function Boards.renderLeaders(board: BasePart, leaders: { any }?)
	local f = canvas(board, "Richest traders")
	if not leaders or #leaders == 0 then
		row(f, "No trades yet", "", Theme.muted)
		return
	end
	for i, r in leaders do
		if i > 6 then
			break
		end
		row(f, `{i}. {string.sub(r.name, 1, 12)}`, `{r.netWorth} C`, Theme.text)
	end
end

-- Static info board: lines are { text, color? }.
function Boards.renderText(board: BasePart, title: string, lines: { { any } })
	local f = canvas(board, title)
	for _, l in lines do
		label(f, l[1], l[2] or Theme.text, 26, 32).AutomaticSize = Enum.AutomaticSize.Y -- long lines wrap instead of clipping
	end
end

return Boards
