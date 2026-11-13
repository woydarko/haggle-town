--!strict
-- Client entry: renders HUD, haggle panel, class card, stats panel and minigames; talks to the server only through Remotes.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local Theme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Theme"))
local Items = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Items"))
require(script.Parent.ui.Loading).show() -- before waiting on Remotes: the server builds the map first
local Hud = require(script.Parent.ui.Hud)
local HagglePanel = require(script.Parent.ui.HagglePanel)
local ClassCard = require(script.Parent.ui.ClassCard)
local StatsPanel = require(script.Parent.ui.StatsPanel)
local Run = require(script.Parent.minigames.Run)

local remotes = ReplicatedStorage:WaitForChild("Remotes", math.huge) -- created after the map build (a few seconds)
local Haggle = remotes:WaitForChild("Haggle") :: RemoteFunction
local Accept = remotes:WaitForChild("Accept") :: RemoteFunction
local StateChanged = remotes:WaitForChild("StateChanged") :: RemoteEvent
local OpenHaggle = remotes:WaitForChild("OpenHaggle") :: RemoteEvent
local Toast = remotes:WaitForChild("Toast") :: RemoteEvent
local PlayMinigame = remotes:WaitForChild("PlayMinigame") :: RemoteEvent
local GatherFinish = remotes:WaitForChild("GatherFinish") :: RemoteFunction
local ChooseClass = remotes:WaitForChild("ChooseClass") :: RemoteFunction
local GetStats = remotes:WaitForChild("GetStats") :: RemoteFunction
local OpenClassCard = remotes:WaitForChild("OpenClassCard") :: RemoteEvent
local GatherFx = remotes:WaitForChild("GatherFx") :: RemoteEvent
local CastAt = remotes:WaitForChild("CastAt") :: RemoteFunction
local Anims = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Anims"))
local Regions = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Regions"))
local FishFx = require(script.Parent.fx.FishFx)
local CollectionService = game:GetService("CollectionService")
require(script.Parent.fx.TreeFx).start()
require(script.Parent.fx.RockFx).start()

local gui = Instance.new("ScreenGui")
gui.Name = "HaggleTownUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true -- HUD sits in the topbar row, clear of the chat window
gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

-- Tab opens our stats; the default player list also uses Tab and our boards already rank players.
pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
end)

local balances: { [string]: number } = {}
local class: string? = nil

local stats = StatsPanel.mount(gui, {
	fetch = function()
		return GetStats:InvokeServer()
	end,
})
local hud = Hud.mount(gui, stats.toggle)
local catchCard = require(script.Parent.ui.CatchCard).mount(gui)
-- Guide: the tracker needs class, bag and deal count; deals come from the stats remote every 8 s.
local dealCount = 0
task.spawn(function()
	while true do
		local ok, s = pcall(function()
			return GetStats:InvokeServer()
		end)
		if ok and type(s) == "table" and type(s.deals) == "number" then
			dealCount = s.deals
		end
		task.wait(8)
	end
end)
require(script.Parent.ui.QuestTracker).mount(gui, function()
	return { class = class, bagCount = Items.bagCount(balances), deals = dealCount }
end)
require(script.Parent.ui.Prompt).start()

local function setBalances(b: { [string]: number })
	balances = b
	hud.balances(b)
end

local panel = HagglePanel.mount(gui, {
	send = function(merchant, text)
		return Haggle:InvokeServer(merchant, text)
	end,
	accept = function(dealId)
		return Accept:InvokeServer(dealId)
	end,
	onBalances = setBalances,
	bag = function()
		return balances
	end,
})

local card = ClassCard.mount(gui, {
	choose = function(cls)
		local r = ChooseClass:InvokeServer(cls)
		if r and r.class then
			local name = Theme.classNames[r.class]
			hud.toast(if r.fee and r.fee > 0 then `You are now a {name} (-{r.fee} C)` else `You are now a {name}!`)
		end
		return r
	end,
	current = function()
		return class
	end,
})

StateChanged.OnClientEvent:Connect(function(state)
	hud.offline(state.offline == true)
	if state.balances then
		setBalances(state.balances)
	end
	if state.class then
		class = state.class
		hud.class(class)
	end
end)

OpenHaggle.OnClientEvent:Connect(function(merchant)
	panel.open(merchant)
end)

OpenClassCard.OnClientEvent:Connect(function(cls)
	card.open(cls)
end)

Toast.OnClientEvent:Connect(function(text)
	hud.toast(text)
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.Tab then
		stats.toggle()
	end
end)

-- The server only fires this after it opened a session, so one minigame runs at a time.
local function reportCatch(r: any)
	if r and r.catch then
		catchCard.show(r.catch)
	elseif r and r.message then
		hud.toast(r.message)
	end
end

-- The server names the node it claimed for us; its model (streamed in, we are next to it) anchors in-world UI and fx.
local function nodeModel(id: any): Model?
	for _, tag in { "GatherTree", "GatherRock", "GatherWater" } do
		for _, m in CollectionService:GetTagged(tag) do
			if m:GetAttribute("NodeId") == id then
				return m :: Model
			end
		end
	end
	return nil
end

PlayMinigame.OnClientEvent:Connect(function(node, params, nodeId)
	local quality = Run.play(gui, node, params, {
		target = nodeModel(nodeId),
		fx = function(kind: string)
			GatherFx:FireServer(kind)
		end,
	})
	reportCatch(GatherFinish:InvokeServer(quality))
end)

-- Fishing: click with the Rod -> charge the cast -> the bobber flies where the camera looks; only a landing in
-- the lake or the sea asks the server (CastAt), which re-checks it and opens the session.
local fishing = false
local function fish()
	local char = Players.LocalPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if fishing or not (char and hum) or gui:FindFirstChild("Minigame") then
		return
	end
	fishing = true
	local cast: FishFx.Cast? = nil
	local ok, err = pcall(function()
		local power = Run.play(gui, "cast", { zoneScale = 1, fishSpeed = 1, minMs = 0 }, { strip = true })
		if not power then
			return
		end
		Anims.play(hum, "Cast")
		task.wait(0.25)
		local c = FishFx.cast(char, power, workspace.CurrentCamera.CFrame.LookVector)
		cast = c
		if not Regions.fishNodeAt(c.landing.X, c.landing.Z) then
			hud.toast("Cast into the water")
			task.wait(0.8)
			return
		end
		local r = CastAt:InvokeServer(c.landing)
		if not (r and r.params) then
			hud.toast(r and r.message or "Cast into the water")
			return
		end
		local quality = Run.play(gui, r.node, r.params, { bobber = c, cast = power })
		local res = GatherFinish:InvokeServer(quality)
		reportCatch(res)
		if res and res.catch then
			Anims.play(hum, "CatchLift")
			FishFx.catch(c, Theme.tiers[res.catch.tier], res.catch.tier ~= "common")
			task.wait(0.8)
		end
	end)
	if cast then
		cast.clear()
	end
	if not ok then
		warn("fishing error", err)
	end
	fishing = false
end

local hookedRods: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local function hookRod(t: Instance)
	if t:IsA("Tool") and t.Name == "Rod" and not hookedRods[t] then
		hookedRods[t] = true
		t.Activated:Connect(function()
			task.spawn(fish)
		end)
	end
end
local function watchBackpack()
	local bp = Players.LocalPlayer:WaitForChild("Backpack")
	for _, t in bp:GetChildren() do
		hookRod(t)
	end
	bp.ChildAdded:Connect(hookRod)
end
Players.LocalPlayer.CharacterAdded:Connect(function()
	task.spawn(watchBackpack)
end)
if Players.LocalPlayer.Character then
	task.spawn(watchBackpack)
end
