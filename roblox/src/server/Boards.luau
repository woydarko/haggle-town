--!strict
-- Renders the price board and leaderboard SurfaceGuis in the square from /rbx/state (server-side, replicated).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Theme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Theme"))

local Boards = {}

local lastAsk: { [string]: number } = {}

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
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 8)
	list.Parent = f
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingTop, pad.PaddingRight = UDim.new(0, 24), UDim.new(0, 16), UDim.new(0, 24)
	pad.Parent = f
	local t = Instance.new("TextLabel")
	t.Size = UDim2.new(1, 0, 0, 56)
	t.BackgroundTransparency = 1
	t.Font = Theme.display
	t.TextSize = 44
	t.TextColor3 = Theme.text
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.Text = title
	t.Parent = f
	f.Parent = gui
	return f
end

local function row(parent: Frame, left: string, right: string, color: Color3)
	local r = Instance.new("TextLabel")
	r.Size = UDim2.new(1, 0, 0, 44)
	r.BackgroundTransparency = 1
	r.Font = Theme.numeric
	r.TextSize = 34
	r.TextColor3 = color
	r.TextXAlignment = Enum.TextXAlignment.Left
	r.Text = string.format("%-12s %s", left, right)
	r.Parent = parent
end

function Boards.renderPrices(board: BasePart, market: { any }?)
	local f = canvas(board, "Today's prices")
	if not market or #market == 0 then
		row(f, "Opening soon", "", Theme.muted)
		return
	end
	for _, m in market do
		local prev = lastAsk[m.good]
		local arrow = if prev == nil or prev == m.ask then "=" elseif m.ask > prev then "up" else "down"
		lastAsk[m.good] = m.ask
		local name = (m.good :: string):sub(1, 1):upper() .. (m.good :: string):sub(2)
		row(f, name, `buy {m.ask} C  sell {m.bid} C  {arrow}`, (Theme :: any)[m.good] or Theme.text)
	end
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

return Boards
