--!strict
-- Stats + bag panel (Tab or the HUD button): class, coin, net worth, rank, deals, best catch, items by category.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared:WaitForChild("Theme"))
local Items = require(Shared:WaitForChild("Items"))
local Ui = require(script.Parent.Ui)

local StatsPanel = {}

export type Handlers = { fetch: () -> any }

function StatsPanel.mount(gui: ScreenGui, h: Handlers)
	local panel = Ui.new("ScrollingFrame", {
		Name = "StatsPanel",
		Parent = gui,
		Visible = false,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -16, 0.5, 0),
		Size = UDim2.fromOffset(300, 440),
		BackgroundColor3 = Theme.background,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
	}, { Ui.corner(), Ui.stroke(), Ui.pad(14), Ui.new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }) })

	local n = 0
	local function line(text: string, color: Color3?, font: Enum.Font?, size: number?)
		n += 1
		Ui.text({ Parent = panel, LayoutOrder = n, Size = UDim2.new(1, 0, 0, (size or 18) + 6), Text = text, TextColor3 = color or Theme.text, Font = font or Theme.body, TextSize = size or 18 })
	end

	local function render(s: any)
		for _, c in panel:GetChildren() do
			if c:IsA("TextLabel") then
				c:Destroy()
			end
		end
		n = 0
		line("Your stats", Theme.text, Theme.display, 26)
		if s == "loading" then
			line("Loading...", Theme.muted)
			return
		end
		if not s or s.error then
			line("Market offline - try again soon.", Theme.error)
			return
		end
		local b = s.balances or {}
		line(`Class: {if s.class then Theme.classNames[s.class] else "none yet (see a mentor)"}`)
		line(`Coin: {b.coin or 0} C`, Theme.primary, Theme.numeric)
		line(`Net worth: {s.netWorth or 0} C`, Theme.text, Theme.numeric)
		line(`Rank: {if s.rank then "#" .. s.rank else "-"}   Deals: {s.deals or 0}`)
		if s.bestCatch then
			line(`Best catch: {s.bestCatch.name} ({s.bestCatch.tier})`, Theme.tiers[s.bestCatch.tier])
		end
		line("Bag", Theme.text, Theme.display, 22)
		if Items.bagCount(b) == 0 then
			line("Empty - go fish, chop or mine!", Theme.muted)
			return
		end
		for _, cat in Items.CATEGORIES do
			for _, item in Items.ofCategory(cat) do
				local qty = b[item.id] or 0
				if qty > 0 then
					line(`{item.name} x{qty}  ({item.tier})`, Theme.tiers[item.tier])
				end
			end
		end
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
