--!strict
-- First-session guide: a "next step" card top-left under the Roblox menu buttons and a marker (arrow + distance)
-- over the target in the world. Steps come from shared/Quest.luau; it guides, it never blocks.
local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared:WaitForChild("Theme"))
local Quest = require(Shared:WaitForChild("Quest"))
local Village = require(Shared:WaitForChild("Village"))
local Ui = require(script.Parent.Ui)

local QuestTracker = {}

local function targetPos(step: any): Vector3?
	if step.target == "guild" then
		return Vector3.new(Village.GUILD.x, 8, Village.GUILD.z)
	elseif step.target == "gather" then
		for _, g in Village.GATES do
			if g.name == step.gate then
				return Vector3.new(g.x, 8, g.z)
			end
		end
	elseif step.target == "market" and step.stall then
		local st = Village.STALLS[step.stall]
		return st and Vector3.new(st.x, 10, st.z)
	end
	return nil
end

-- getState returns { class, bagCount, deals } as the client knows them.
-- Returns { ledgerOpened } for the Ledger pop-up: the guide's last step completes when the player opens it.
-- forge: shared/ForgeView.hint for the trade tool. point(stall) aims the marker at a stall for 90 s (Forge's Find seller).
function QuestTracker.mount(gui: ScreenGui, getState: () -> { class: string?, bagCount: number, deals: number, forge: any? })
	local player = Players.LocalPlayer
	local card = Ui.new("Frame", { Name = "QuestCard", Parent = gui, Position = UDim2.fromOffset(16, 64), Size = UDim2.fromOffset(300, 108), BackgroundColor3 = Theme.surface }, { Ui.corner(), Ui.stroke(), Ui.pad(10) })
	local count = Ui.text({ Parent = card, Size = UDim2.new(1, 0, 0, 16), TextSize = 14, TextColor3 = Theme.muted, Text = "" })
	local title = Ui.text({ Parent = card, Position = UDim2.fromOffset(0, 16), Size = UDim2.new(1, 0, 0, 26), FontFace = Theme.display, TextSize = 22, Text = "" })
	local detail = Ui.text({ Parent = card, Position = UDim2.fromOffset(0, 44), Size = UDim2.new(1, 0, 0, 44), TextSize = 15, TextYAlignment = Enum.TextYAlignment.Top, Text = "" })
	local toggle = Ui.button("Guide", false, { Name = "GuideToggle", Parent = gui, Position = UDim2.fromOffset(16, 64), Size = UDim2.fromOffset(88, 44), TextSize = 18, Visible = false })

	local anchor = Instance.new("Attachment")
	anchor.Name = "QuestMarker"
	anchor.Parent = workspace.Terrain
	local marker = Instance.new("BillboardGui")
	marker.Name = "QuestMarker"
	marker.Adornee = anchor
	marker.AlwaysOnTop = true
	marker.Size = UDim2.fromOffset(140, 60)
	marker.Parent = player:WaitForChild("PlayerGui")
	Ui.text({ Parent = marker, Size = UDim2.new(1, 0, 0, 32), FontFace = Theme.display, TextSize = 30, TextColor3 = Theme.primary, TextStrokeTransparency = 0.6, TextXAlignment = Enum.TextXAlignment.Center, Text = "▼" })
	local dist = Ui.text({ Parent = marker, Position = UDim2.fromOffset(0, 32), Size = UDim2.new(1, 0, 0, 22), FontFace = Theme.numeric, TextSize = 16, TextStrokeTransparency = 0.4, TextStrokeColor3 = Theme.surface, TextXAlignment = Enum.TextXAlignment.Center, Text = "" })

	local ledgerSeen, folded, doneAt = false, false, nil :: number?
	local override: { stall: string, untilT: number }? = nil
	toggle.Activated:Connect(function()
		folded = false
		doneAt = os.clock() -- show the final card again for a while
	end)

	task.spawn(function()
		while gui.Parent do
			local s = getState()
			local step = Quest.step({ class = s.class, bagCount = s.bagCount, deals = s.deals, ledgerSeen = ledgerSeen, forge = s.forge })
			count.Text = if step.index <= Quest.COUNT then `Step {step.index} of {Quest.COUNT}` else "Guide"
			title.Text, detail.Text = step.title, step.detail
			local at = targetPos(step)
			local o = override
			if o and os.clock() < o.untilT then
				at = targetPos({ target = "market", stall = o.stall })
			end
			local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if at and hrp then
				local d = ((hrp.Position - at) * Vector3.new(1, 0, 1)).Magnitude
				anchor.WorldPosition = at
				dist.Text = `{math.floor(d)} studs`
				marker.Enabled = d > 14
			else
				marker.Enabled = false
			end
			-- After the last step the card stays 10 s, then folds into the Guide button.
			if step.index > Quest.COUNT then
				doneAt = doneAt or os.clock()
				folded = os.clock() - (doneAt :: number) > 10
			end
			-- Step aside while a panel (haggle, trade, stats) is open so it never peeks out from behind it.
			local busy = false
			for _, n in { "HagglePanel", "ClassCard", "StatsPanel", "LedgerPanel", "ForgePanel" } do
				local f = gui:FindFirstChild(n) :: GuiObject?
				busy = busy or (f ~= nil and f.Visible)
			end
			card.Visible, toggle.Visible = not folded and not busy, folded and not busy
			-- Sit under Roblox's chat window (top-left) while it is shown; it is hidden on phones until opened.
			local chat = player.PlayerGui:FindFirstChild("Chat")
			local frame = chat and chat:FindFirstChild("Frame") :: GuiObject?
			local y = 64
			if frame and frame.Visible and (chat :: ScreenGui).Enabled then
				y = math.max(y, frame.AbsolutePosition.Y + frame.AbsoluteSize.Y + GuiService:GetGuiInset().Y + 8)
			end
			card.Position, toggle.Position = UDim2.fromOffset(16, y), UDim2.fromOffset(16, y)
			task.wait(0.25)
		end
	end)
	return {
		ledgerOpened = function()
			ledgerSeen = true
		end,
		point = function(stall: string)
			override = { stall = stall, untilT = os.clock() + 90 }
			folded, doneAt = false, os.clock()
		end,
	}
end

return QuestTracker
