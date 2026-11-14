--!strict
-- Forge pop-up (Forge button in the HUD or F): one row per tool.
--   row: tool icon in its level colours, name + level, what it does now and what the next level gives,
--        the next recipe as item icon + have/need, then Forge (all goods there) or Find seller (points the guide marker)
-- The recipe comes from the backend (/rbx/state "forge"); have-counts from the live balances.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared:WaitForChild("Theme"))
local Sfx = require(Shared:WaitForChild("Sfx"))
local ForgeView = require(Shared:WaitForChild("ForgeView"))
local Ui = require(script.Parent.Ui)

local ForgePanel = {}

local W, H = 560, 448 -- three 94 px rows + header + the status line under them
local MERCHANT = Theme.merchantNames

export type Handlers = {
	state: () -> { forge: { any }?, balances: { [string]: number }, class: string? },
	forge: (tool: string) -> any,
	onFind: (stall: string, text: string) -> (),
	onForged: (r: any) -> (),
}

local function effect(tool: string, bonus: number): string
	return if bonus > 0 then `{ForgeView.pct(bonus)} chance of a second {ForgeView.CATCH[tool]}` else "no bonus yet"
end

function ForgePanel.mount(gui: ScreenGui, h: Handlers)
	local panel = Ui.new("Frame", {
		Name = "ForgePanel",
		Parent = gui,
		Visible = false,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromOffset(W, H),
		BackgroundColor3 = Theme.background,
	}, { Ui.corner(), Ui.stroke(), Ui.pad(16) })

	Ui.icon("anvil", 34, { Parent = panel, Position = UDim2.fromOffset(0, 0) })
	Ui.text({ Parent = panel, Position = UDim2.fromOffset(42, 0), Size = UDim2.fromOffset(200, 36), FontFace = Theme.display, TextSize = 30, Text = "Forge" })
	local close = Ui.button("Close", false, { Parent = panel, Position = UDim2.new(1, -96, 0, 0), Size = UDim2.fromOffset(96, 34), TextSize = 18 })
	Ui.text({
		Parent = panel,
		Position = UDim2.fromOffset(0, 40),
		Size = UDim2.new(1, 0, 0, 38),
		TextSize = 14,
		TextColor3 = Theme.muted,
		Text = "Better tools catch more. Each one is made from the other trades' goods: buy what you lack at their stalls.",
	})
	local rows = Ui.new("Frame", { Parent = panel, Position = UDim2.fromOffset(0, 84), Size = UDim2.new(1, 0, 1, -112), BackgroundTransparency = 1 }, {
		Ui.new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local status = Ui.text({ Parent = panel, Position = UDim2.new(0, 0, 1, -22), Size = UDim2.new(1, 0, 0, 22), TextSize = 15, TextColor3 = Theme.muted, TextXAlignment = Enum.TextXAlignment.Center, Text = "" })

	local open, busy = false, false
	local render: () -> ()

	local function say(text: string, color: Color3?)
		status.Text = text
		status.TextColor3 = color or Theme.muted
	end

	local function doForge(tool: string)
		if busy then
			return
		end
		busy = true
		say("Forging...")
		local ok, r = pcall(h.forge, tool)
		busy = false
		if ok and type(r) == "table" and r.name then
			Sfx.ui("pick")
			task.delay(0.18, Sfx.ui, "sparkle")
			say(`{r.name} forged! {effect(r.tool, r.bonus)}.`, Theme.success)
			h.onForged(r)
		else
			say(if ok and type(r) == "table" and r.message then r.message else "The forge is cold. Try again.", Theme.error)
		end
		render()
	end

	function render()
		for _, c in rows:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		local s = h.state()
		if not s.forge then
			Ui.text({ Parent = rows, Size = UDim2.new(1, 0, 0, 60), TextSize = 18, TextColor3 = Theme.muted, TextXAlignment = Enum.TextXAlignment.Center, Text = "Lighting the forge..." })
			return
		end
		for i, t in s.forge do
			local row = Ui.new("Frame", { Parent = rows, LayoutOrder = i, Size = UDim2.new(1, 0, 0, 94), BackgroundColor3 = Theme.surface }, { Ui.corner(), Ui.stroke(), Ui.pad(10) })
			local slot = Ui.new("Frame", { Parent = row, Size = UDim2.fromOffset(72, 72), BackgroundColor3 = Theme.background }, { Ui.corner() })
			Ui.icon(`{t.tool}_{t.level}`, 64, { Parent = slot, Position = UDim2.fromOffset(4, 4) })
			local name = Ui.text({ Parent = row, Position = UDim2.fromOffset(84, -2), Size = UDim2.fromOffset(250, 26), FontFace = Theme.display, TextSize = 22, Text = t.name })
			Ui.text({ Parent = row, Position = UDim2.fromOffset(84 + name.TextBounds.X + 8, 3), Size = UDim2.fromOffset(60, 20), FontFace = Theme.numeric, TextSize = 13, TextColor3 = Theme.muted, Text = `Lv {t.level}/3` })
			local nxt = t.next
			Ui.text({
				Parent = row,
				Position = UDim2.fromOffset(84, 24),
				Size = UDim2.new(1, -230, 0, 20),
				TextSize = 13,
				TextColor3 = Theme.muted,
				Text = if not nxt then `{ForgeView.pct(t.bonus)} chance of a second {ForgeView.CATCH[t.tool]}. The best there is.`
					elseif t.bonus > 0 then `Now {ForgeView.pct(t.bonus)}. {nxt.name}: {effect(t.tool, nxt.bonus)}.`
					else `{nxt.name}: {effect(t.tool, nxt.bonus)}.`,
			})
			if nxt then
				local costs = Ui.new("Frame", { Parent = row, Position = UDim2.fromOffset(84, 46), Size = UDim2.new(1, -230, 0, 26), BackgroundTransparency = 1 }, {
					Ui.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 12), VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }),
				})
				for j, c in nxt.cost do
					local have = s.balances[c.item] or 0
					local cell = Ui.new("Frame", { Parent = costs, LayoutOrder = j, Size = UDim2.fromOffset(84, 26), BackgroundTransparency = 1 })
					Ui.icon(c.item, 24, { Parent = cell, Position = UDim2.fromOffset(0, 1) })
					Ui.text({
						Parent = cell,
						Position = UDim2.fromOffset(28, 0),
						Size = UDim2.fromOffset(56, 26),
						FontFace = Theme.numeric,
						TextSize = 15,
						TextColor3 = if have >= c.qty then Theme.success else Theme.error,
						Text = `{math.min(have, c.qty)}/{c.qty}`,
					})
				end
				local missing = ForgeView.missing(t, s.balances)
				if #missing == 0 then
					local b = Ui.button("Forge", true, { Parent = row, Position = UDim2.new(1, -132, 0, 16), Size = UDim2.fromOffset(132, 40), TextSize = 20 })
					b.Activated:Connect(function()
						doForge(t.tool)
					end)
				else
					local m = missing[1]
					local b = Ui.button("Find seller", false, { Parent = row, Position = UDim2.new(1, -132, 0, 16), Size = UDim2.fromOffset(132, 40), TextSize = 17, BackgroundColor3 = Theme.background })
					Ui.text({ Parent = row, Position = UDim2.new(1, -140, 0, 58), Size = UDim2.fromOffset(148, 18), TextSize = 12, TextColor3 = Theme.muted, TextXAlignment = Enum.TextXAlignment.Center, Text = `{m.qty} {m.name} at the {MERCHANT[m.merchant]}` })
					b.Activated:Connect(function()
						h.onFind(m.merchant, `Buy {m.qty} {m.name} from the {MERCHANT[m.merchant]} (Buy tab)`)
						open = false
						panel.Visible = false
					end)
				end
			else
				Ui.text({ Parent = row, Position = UDim2.new(1, -132, 0, 26), Size = UDim2.fromOffset(132, 22), FontFace = Theme.display, TextSize = 18, TextColor3 = Theme.tiers.legendary, TextXAlignment = Enum.TextXAlignment.Center, Text = "Master tool" })
			end
		end
	end

	close.Activated:Connect(function()
		open = false
		panel.Visible = false
	end)

	local api = {}
	function api.toggle()
		open = not open
		panel.Visible = open
		if open then
			say("")
			render()
		end
	end
	-- New balances or tool levels: redraw while open (not mid-forge, the result redraws it).
	function api.refresh()
		if open and not busy then
			render()
		end
	end
	return api
end

return ForgePanel
