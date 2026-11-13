--!strict
-- Bottom-center haggle panel (DESIGN_SYSTEM W3): merchant bubble, counter, reasoning, patience,
-- quick-sell chips for bag items this merchant buys, input, Accept/Leave.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Theme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Theme"))
local Ui = require(script.Parent.Ui)
local Items = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Items"))

local HagglePanel = {}

local EXAMPLES = {
	woodcutter = "e.g. sell 2 oak for 90, or 3 pine at 15",
	fishmonger = "e.g. sell 1 trout for 60, or 2 sardine for 40",
	smith = "e.g. sell 3 copper for 90, or 1 iron at 100",
}

export type Handlers = {
	send: (merchant: string, text: string) -> any,
	accept: (dealId: string) -> any,
	onBalances: (b: any) -> (),
	bag: () -> { [string]: number },
}

local HEIGHT = 336

function HagglePanel.mount(gui: ScreenGui, h: Handlers)
	local panel = Ui.new("Frame", {
		Name = "HagglePanel",
		Parent = gui,
		Visible = false,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -24),
		Size = UDim2.fromOffset(560, HEIGHT),
		BackgroundColor3 = Theme.background,
	}, { Ui.corner(), Ui.stroke(), Ui.pad(16), Ui.new("UIScale", { Name = "Scale" }) })

	local title = Ui.text({ Parent = panel, Size = UDim2.new(1, -140, 0, 32), FontFace = Theme.display, TextSize = 28 })
	local patience = Ui.text({ Parent = panel, Position = UDim2.new(1, -140, 0, 4), Size = UDim2.fromOffset(140, 24), TextColor3 = Theme.warning, TextXAlignment = Enum.TextXAlignment.Right })
	local bubble = Ui.new("Frame", { Parent = panel, Position = UDim2.fromOffset(0, 40), Size = UDim2.new(1, 0, 0, 96), BackgroundColor3 = Theme.surface }, { Ui.corner(), Ui.pad(10) })
	local line = Ui.text({ Parent = bubble, Size = UDim2.new(1, 0, 0, 48), TextSize = 20 })
	local counter = Ui.text({ Parent = bubble, Position = UDim2.fromOffset(0, 50), Size = UDim2.new(0.5, 0, 0, 26), FontFace = Theme.numeric, TextSize = 20, TextColor3 = Theme.primary })
	local reasoning = Ui.text({ Parent = bubble, Position = UDim2.new(0.5, 0, 0, 50), Size = UDim2.new(0.5, 0, 0, 26), TextSize = 16, TextColor3 = Theme.muted, TextXAlignment = Enum.TextXAlignment.Right })
	local chips = Ui.new("Frame", { Parent = panel, Position = UDim2.fromOffset(0, 146), Size = UDim2.new(1, 0, 0, 32), BackgroundTransparency = 1 }, {
		Ui.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local input = Ui.new("TextBox", {
		Parent = panel,
		Position = UDim2.fromOffset(0, 188),
		Size = UDim2.new(1, -110, 0, 44),
		BackgroundColor3 = Theme.surface,
		FontFace = Theme.body,
		TextSize = 18,
		TextColor3 = Theme.text,
		PlaceholderText = "Make an offer, e.g. 40 for 5 wood",
		PlaceholderColor3 = Theme.muted,
		ClearTextOnFocus = false,
		Text = "",
		TextXAlignment = Enum.TextXAlignment.Left,
	}, { Ui.corner(), Ui.stroke(), Ui.pad(8) })
	local send = Ui.button("Send", false, { Parent = panel, Position = UDim2.new(1, -100, 0, 188), Size = UDim2.fromOffset(100, 44) })
	local accept = Ui.button("Accept", true, { Parent = panel, Position = UDim2.fromOffset(0, 244), Size = UDim2.fromOffset(240, 48) })
	local leave = Ui.button("Leave", false, { Parent = panel, Position = UDim2.new(1, -140, 0, 244), Size = UDim2.fromOffset(140, 48) })
	local status = Ui.text({ Parent = panel, Position = UDim2.fromOffset(0, 298), Size = UDim2.new(1, 0, 0, 22), TextSize = 16, TextColor3 = Theme.muted })

	local merchant: string? = nil
	local deal: any = nil
	local busy = false

	local function setCounter(c: any)
		deal = c
		if c then
			counter.Text = `Counter: {c.unitPrice} C x {c.qty} = {c.total} C`
			accept.Text = `Accept {c.total} C`
			accept.Active = true
			accept.AutoButtonColor = true
			accept.BackgroundTransparency = 0
		else
			counter.Text = ""
			accept.Text = "Accept"
			accept.Active = false
			accept.AutoButtonColor = false
			accept.BackgroundTransparency = 0.6
		end
	end

	local function setPatience(n: number?)
		local p = n or 3
		patience.Text = "patience " .. string.rep("o ", p) .. string.rep("- ", 3 - p)
	end

	local function setBusy(on: boolean, text: string?)
		busy = on
		send.Active = not on
		input.TextEditable = not on
		status.TextColor3 = Theme.muted
		status.Text = text or ""
	end

	-- One chip per item of this merchant's category in the bag; click fills "sell 1 <item> for ".
	local function renderChips()
		for _, c in chips:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		local b = h.bag()
		local count = 0
		for i, item in Items.ofCategory(Items.MERCHANT_CATEGORY[merchant :: string] or "") do
			local qty = b[item.id] or 0
			if qty > 0 then
				count += 1
				local chip = Ui.button(`{item.name} x{qty}`, false, { Parent = chips, LayoutOrder = i, Size = UDim2.fromOffset(128, 32), TextSize = 16, TextColor3 = Theme.tiers[item.tier] })
				chip.Activated:Connect(function()
					input.Text = `sell 1 {string.lower(item.name)} for `
					input:CaptureFocus()
					input.CursorPosition = #input.Text + 1
				end)
			end
		end
		if count == 0 then
			Ui.text({ Parent = chips, Size = UDim2.new(1, 0, 1, 0), TextSize = 16, TextColor3 = Theme.muted, Text = "Nothing to sell here yet. You can still buy." })
		end
	end

	local function showError(text: string)
		status.TextColor3 = Theme.error
		status.Text = text
	end

	local function render(r: any)
		if r.error then
			showError(r.message or "Could not reach the market. Try again.")
			return
		end
		line.Text = `"{r.line}"`
		title.Text = `{Theme.merchantNames[merchant :: string]}  ({r.mood or "neutral"})`
		reasoning.Text = r.reasoning or ""
		setPatience(r.patience)
		if r.refused then
			setCounter(nil)
			local secs = math.max(0, math.floor((r.refused["until"] - DateTime.now().UnixTimestampMillis) / 1000))
			showError(string.format("Come back tomorrow (in %d:%02d).", secs // 60, secs % 60))
		else
			setCounter(r.counter)
		end
	end

	local function submit()
		if busy or not merchant then
			return
		end
		local text = input.Text
		if #string.gsub(text, "%s", "") == 0 then
			return
		end
		setBusy(true, `{Theme.merchantNames[merchant :: string]} is thinking...`)
		local ok, r = pcall(h.send, merchant :: string, text)
		setBusy(false)
		if ok then
			input.Text = ""
			render(r)
		else
			showError("Could not reach the market. Try again.")
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
		setBusy(true, "Settling...")
		local ok, r = pcall(h.accept, deal.dealId)
		setBusy(false)
		if not ok then
			showError("Deal failed, try again. Your goods are untouched.")
			return
		end
		if r.status == "settled" then
			setCounter(nil)
			status.TextColor3 = Theme.success
			status.Text = "Deal done"
			if r.balances then
				h.onBalances(r.balances)
			end
			renderChips()
		elseif r.status == "requoted" then
			line.Text = `"{r.line}"`
			setCounter(r.counter)
			status.TextColor3 = Theme.warning
			status.Text = "Prices just moved. Accept the new price or leave."
		else
			setCounter(nil)
			showError("Deal failed, try again. Your goods are untouched.")
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
		line.Text = `"Welcome! What can I do for you?"`
		reasoning.Text = ""
		input.Text = ""
		input.PlaceholderText = EXAMPLES[name] or "Make an offer"
		setCounter(nil)
		setPatience(3)
		setBusy(false)
		renderChips()
		panel.Visible = true
		panel.Size = UDim2.fromOffset(560, 0)
		TweenService:Create(panel, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = UDim2.fromOffset(560, HEIGHT) }):Play()
		input:CaptureFocus()
	end

	return api
end

return HagglePanel
