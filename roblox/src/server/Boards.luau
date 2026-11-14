--!strict
-- Lobby boards as SurfaceGuis (server-side, replicated): how-to steps, rarity, richest traders.
-- Boards are 14 x 8 studs at 40 px/stud = 560 x 320 px; after padding and the title, 512 x 224 px is left, and every
-- layout below is sized to fit that box (pictures carry the meaning, text stays short).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared:WaitForChild("Theme"))
local Items = require(Shared:WaitForChild("Items"))
local Icons = require(Shared:WaitForChild("Icons"))
local SpriteGui = require(Shared:WaitForChild("SpriteGui"))

local Boards = {}

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

local function list(parent: Instance, padding: number, horizontal: boolean?, center: boolean?)
	local l = Instance.new("UIListLayout")
	l.Padding = UDim.new(0, padding)
	l.SortOrder = Enum.SortOrder.LayoutOrder
	if horizontal then
		l.FillDirection = Enum.FillDirection.Horizontal
	end
	if center then
		l.HorizontalAlignment = Enum.HorizontalAlignment.Center
		l.VerticalAlignment = Enum.VerticalAlignment.Center
	end
	l.Parent = parent
end

local function box(parent: Instance, size: UDim2, order: number?): Frame
	local f = Instance.new("Frame")
	f.BackgroundTransparency = 1
	f.Size = size
	f.LayoutOrder = order or 0
	f.Parent = parent
	return f
end

local function canvas(board: BasePart, title: string, titleSize: number?): Frame
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
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 24), UDim.new(0, 24)
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 16), UDim.new(0, 16)
	pad.Parent = f
	label(f, title, Theme.text, titleSize or 44, 56, Theme.display)
	f.Parent = gui
	return f
end

-- A sprite id from shared/Sprites.luau, or "coin" for the coin image.
local function picture(parent: Instance, id: string, px: number, order: number)
	if id == "coin" then
		local img = Instance.new("ImageLabel")
		img.BackgroundTransparency = 1
		img.Size = UDim2.fromOffset(px, px)
		img.Image = Icons.coin
		img.LayoutOrder = order
		img.Parent = parent
	else
		local s = SpriteGui.new(id, px)
		s.LayoutOrder = order
		s.Parent = parent
	end
end

export type Step = { pictures: { string }, text: string }

-- Four picture steps side by side, a short caption under each, one muted footer line.
function Boards.renderSteps(board: BasePart, title: string, steps: { Step }, footer: string)
	local f = canvas(board, title)
	local cols = box(f, UDim2.new(1, 0, 0, 168), 1)
	list(cols, 8, true)
	for i, step in steps do
		local col = box(cols, UDim2.new(1 / #steps, -8 * (#steps - 1) / #steps, 1, 0), i)
		list(col, 6)
		local pics = box(col, UDim2.new(1, 0, 0, 60), 1)
		list(pics, 2, true, true)
		local px = ({ 60, 48, 36 })[math.min(#step.pictures, 3)]
		for j, id in step.pictures do
			picture(pics, id, px, j)
		end
		local cap = label(col, step.text, Theme.text, 20, 100)
		cap.LayoutOrder = 2
		cap.TextXAlignment = Enum.TextXAlignment.Center
		cap.TextYAlignment = Enum.TextYAlignment.Top
	end
	label(f, footer, Theme.muted, 18, 48).LayoutOrder = 2
end

-- One row per tier: the tier name in its colour, then the fish, wood and ore of that tier with their names.
function Boards.renderRarity(board: BasePart)
	local f = canvas(board, "Rarity")
	for t, tier in Items.TIERS do
		local row = box(f, UDim2.new(1, 0, 0, 52), t)
		local name = label(row, tier:sub(1, 1):upper() .. tier:sub(2), Theme.tiers[tier], 24, 52, Theme.display)
		name.Size = UDim2.new(0, 110, 1, 0)
		local cells = box(row, UDim2.new(1, -110, 1, 0))
		cells.Position = UDim2.fromOffset(110, 0)
		list(cells, 0, true)
		for c, item in Items.list do
			if item.tier == tier then
				local cell = box(cells, UDim2.new(1 / 3, 0, 1, 0), c)
				local s = SpriteGui.new(item.id, 36)
				s.Position = UDim2.fromOffset(0, 8)
				s.Parent = cell
				local n = label(cell, item.name, Theme.text, 16, 52)
				n.Position = UDim2.fromOffset(40, 0)
				n.Size = UDim2.new(1, -40, 1, 0)
			end
		end
	end
end

-- Top five by net worth: name left, coin value right (two labels, so the numbers line up).
function Boards.renderLeaders(board: BasePart, leaders: { any }?)
	-- Net worth, not coin: the backend ranks coin plus every item at its merchant's bid (server/src/game/leaderboard.ts).
	local f = canvas(board, "Richest traders (coin + goods)", 34)
	if not leaders or #leaders == 0 then
		label(f, "No trades yet. Be the first!", Theme.muted, 26, 36).LayoutOrder = 1
		return
	end
	for i, r in leaders do
		if i > 5 then
			break
		end
		local row = box(f, UDim2.new(1, 0, 0, 36), i)
		local face = Instance.new("ImageLabel") -- head and shoulders; an empty circle for web players
		face.Size = UDim2.fromOffset(36, 36)
		face.BackgroundColor3 = Theme.surface
		face.Image = if r.userId then Icons.headshot(r.userId) else ""
		face.Parent = row
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = face
		local n = label(row, `{i}. {r.name}`, Theme.text, 26, 36)
		n.Position = UDim2.fromOffset(46, 0)
		n.Size = UDim2.new(1, -176, 1, 0)
		n.TextWrapped, n.TextTruncate = false, Enum.TextTruncate.AtEnd
		local v = label(row, `{r.netWorth} C`, Theme.primary, 26, 36, Theme.numeric)
		v.TextXAlignment = Enum.TextXAlignment.Right
	end
end

return Boards
