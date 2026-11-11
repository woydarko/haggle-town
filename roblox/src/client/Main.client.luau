--!strict
-- Client entry: renders HUD, haggle panel, class card, stats panel and minigames; talks to the server only through Remotes.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local Theme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Theme"))
local Hud = require(script.Parent.ui.Hud)
local HagglePanel = require(script.Parent.ui.HagglePanel)
local ClassCard = require(script.Parent.ui.ClassCard)
local StatsPanel = require(script.Parent.ui.StatsPanel)
local Run = require(script.Parent.minigames.Run)

local remotes = ReplicatedStorage:WaitForChild("Remotes")
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
PlayMinigame.OnClientEvent:Connect(function(node, params)
	local quality = Run.play(gui, node, params)
	local r = GatherFinish:InvokeServer(quality)
	if r and r.catch then
		local c = r.catch
		hud.toast(`Caught {c.name} ({c.tier})` .. (if c.qty > 1 then ` x{c.qty}` else "") .. "!")
	elseif r and r.message then
		hud.toast(r.message)
	end
end)
