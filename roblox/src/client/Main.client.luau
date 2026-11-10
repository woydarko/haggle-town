--!strict
-- Client entry: renders HUD + haggle panel and talks to the server only through Remotes.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Hud = require(script.Parent.ui.Hud)
local HagglePanel = require(script.Parent.ui.HagglePanel)

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local Haggle = remotes:WaitForChild("Haggle") :: RemoteFunction
local Accept = remotes:WaitForChild("Accept") :: RemoteFunction
local StateChanged = remotes:WaitForChild("StateChanged") :: RemoteEvent
local OpenHaggle = remotes:WaitForChild("OpenHaggle") :: RemoteEvent
local Toast = remotes:WaitForChild("Toast") :: RemoteEvent

local gui = Instance.new("ScreenGui")
gui.Name = "HaggleTownUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

local hud = Hud.mount(gui)
local panel = HagglePanel.mount(gui, {
	send = function(merchant, text)
		return Haggle:InvokeServer(merchant, text)
	end,
	accept = function(dealId)
		return Accept:InvokeServer(dealId)
	end,
	onBalances = function(b)
		hud.balances(b)
	end,
})

StateChanged.OnClientEvent:Connect(function(state)
	hud.offline(state.offline == true)
	if state.balances then
		hud.balances(state.balances)
	end
end)

OpenHaggle.OnClientEvent:Connect(function(merchant)
	panel.open(merchant)
end)

Toast.OnClientEvent:Connect(function(text)
	hud.toast(text)
end)
