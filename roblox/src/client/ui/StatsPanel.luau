--!strict
-- Stats + bag panel (Tab or the HUD button): class, four stat tiles, best catch, then the bag as an inventory grid.
-- The grid always shows all 12 items (rows fish / wood / ore, columns common to legendary); ones not owned yet are
-- faint, so the grid doubles as a collection goal. Hover, select or tap a slot to read its name.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared:WaitForChild("Theme"))
local Items = require(Shared:WaitForChild("Items"))
local Icons = require(Shared:WaitForChild("Icons"))
local Ui = require(script.Parent.Ui)

local StatsPanel = {}
local SLOT, GAP = 54, 6

export type Handlers = { fetch: () -> any }

function StatsPanel.mount(gui: ScreenGui, h: Handlers)
	local panel = Ui.new("ScrollingFrame", {
		Name = "StatsPanel",
		Parent = gui,
		Visible = false,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -16, 0.5, 0),
		Size = UDim2.fromOffset(300, 470),
		BackgroundColor3 = Theme.background,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
	}, { Ui.corner(), Ui.stroke(), Ui.pad(14), Ui.new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }) })

	local n = 0
	local function nextOrder(): number
		n += 1
		return n
	end
	local function row(height: number): Frame
		return Ui.new("Frame", { Parent = panel, LayoutOrder = nextOrder(), BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, height) })
	end
	local function line(text: string, color: Color3?)
		Ui.text({ Parent = panel, LayoutOrder = nextOrder(), Size = UDim2.new(1, 0, 0, 24), Text = text, TextColor3 = color or Theme.text })
	end
	-- Title on the left, a right-aligned note (class, bag count) on the same row.
	local function heading(title: string, size: number, note: string?, noteColor: Color3?)
		local r = row(size + 6)
		Ui.text({ Parent = r, Size = UDim2.fromScale(1, 1), FontFace = Theme.display, TextSize = size, Text = title })
		if note then
			Ui.text({ Parent = r, Size = UDim2.fromScale(1, 1), FontFace = Theme.display, TextSize = 18, TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = noteColor or Theme.muted, Text = note })
		end
	end

	local function tile(parent: Instance, label: string, value: string, coin: boolean)
		local t = Ui.new("Frame", { Parent = parent, BackgroundColor3 = Theme.surface }, { Ui.corner(), Ui.stroke(), Ui.pad(6) })
		Ui.text({ Parent = t, Size = UDim2.new(1, 0, 0, 14), TextSize = 13, TextColor3 = Theme.muted, Text = label })
		local v = Ui.text({ Parent = t, Position = UDim2.fromOffset(0, 14), Size = UDim2.new(1, 0, 0, 20), FontFace = Theme.numeric, TextSize = 18, Text = value })
		if coin then
			v.TextColor3 = Theme.primary
			Ui.new("UIPadding", { Parent = v, PaddingLeft = UDim.new(0, 24) })
			Ui.new("ImageLabel", { Parent = v, Position = UDim2.fromOffset(-24, 1), Size = UDim2.fromOffset(20, 20), BackgroundTransparency = 1, Image = Icons.coin })
		end
	end

	local function bag(b: { [string]: number })
		local total = Items.bagCount(b)
		heading("Bag", 22, if total == 1 then "1 item" else `{total} items`)
		-- Caption above the grid so it stays on screen without scrolling.
		local caption = Ui.text({ Parent = panel, LayoutOrder = nextOrder(), Size = UDim2.new(1, 0, 0, 36), TextSize = 15, RichText = true, TextYAlignment = Enum.TextYAlignment.Top, TextColor3 = Theme.muted, Text = if total == 0 then "Empty - go fish, chop or mine to fill these slots." else "Tap a slot to see the item." })
		local grid = row(3 * SLOT + 2 * GAP)
		Ui.new("UIGridLayout", { Parent = grid, CellSize = UDim2.fromOffset(SLOT, SLOT), CellPadding = UDim2.fromOffset(GAP, GAP), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center })
		for i, item in Items.list do
			local qty = b[item.id] or 0
			local owned = qty > 0
			local slot = Ui.new("TextButton", { Parent = grid, LayoutOrder = i, Text = "", AutoButtonColor = false, BackgroundColor3 = Theme.surface, Selectable = true }, {
				Ui.corner(),
				Ui.new("UIStroke", { Color = if owned then Theme.tiers[item.tier] else Theme.border, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
			})
			local icon = Ui.icon(item.id, 48, { Parent = slot, Position = UDim2.fromOffset(3, 3) })
			if owned then
				Ui.text({ Parent = slot, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -4, 1, -1), Size = UDim2.fromOffset(44, 18), FontFace = Theme.numeric, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Right, TextStrokeColor3 = Theme.surface, TextStrokeTransparency = 0, Text = `{qty}` })
			else
				for _, px in icon:GetChildren() do
					(px :: Frame).BackgroundTransparency = 0.82 -- a faint silhouette: the item exists, you have not found it yet
				end
			end
			local function describe()
				local name = `<font color="#{Theme.tiers[item.tier]:ToHex()}"><b>{item.name}</b></font>`
				caption.Text = if owned then `{name} - {item.tier}, {qty} in your bag` else `{name} - {item.tier}, not found yet`
			end
			slot.MouseEnter:Connect(describe)
			slot.SelectionGained:Connect(describe)
			slot.Activated:Connect(describe)
		end
	end

	local function render(s: any)
		for _, c in panel:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		n = 0
		if s == "loading" or not s or s.error then
			heading("Your stats", 26)
			line(if s == "loading" then "Loading..." else "Market offline - try again soon.", if s == "loading" then Theme.muted else Theme.error)
			return
		end
		local b = s.balances or {}
		local CLASS_COLOR = { fisher = Theme.fish, logger = Theme.wood, miner = Theme.iron }
		heading("Your stats", 26, if s.class then Theme.classNames[s.class] else "No class", if s.class then CLASS_COLOR[s.class] else Theme.muted)
		if not s.class then
			line("Visit a mentor to pick a class.", Theme.muted)
		end
		local tiles = row(2 * 46 + GAP)
		Ui.new("UIGridLayout", { Parent = tiles, CellSize = UDim2.new(0.5, -GAP // 2, 0, 46), CellPadding = UDim2.fromOffset(GAP, GAP), SortOrder = Enum.SortOrder.LayoutOrder })
		tile(tiles, "Coin", `{b.coin or 0} C`, true)
		tile(tiles, "Net worth", `{s.netWorth or 0} C`, false)
		tile(tiles, "Rank", if s.rank then `#{s.rank}` else "-", false)
		tile(tiles, "Deals", `{s.deals or 0}`, false)
		if s.bestCatch then
			local r = row(32)
			local best = Items.byId[s.bestCatch.item or ""]
			local x = 0
			if best then
				Ui.icon(best.id, 24, { Parent = r, Position = UDim2.fromOffset(0, 4) })
				x = 30
			end
			Ui.text({ Parent = r, Position = UDim2.fromOffset(x, 0), Size = UDim2.new(1, -x, 1, 0), TextSize = 16, RichText = true, TextColor3 = Theme.muted, Text = `Best catch: <font color="#{(Theme.tiers[s.bestCatch.tier] or Theme.text):ToHex()}"><b>{s.bestCatch.name}</b></font> ({s.bestCatch.tier})` })
		end
		bag(b)
	end

	local api = {}
	function api.toggle()
		panel.Visible = not panel.Visible
		if panel.Visible then
			render("loading")
			local ok, s = pcall(h.fetch)
			if panel.Visible then
				render(if ok then s else nil)
			end
		end
	end
	return api
end

return StatsPanel
