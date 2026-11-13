--!strict
-- Full-screen "Building the valley..." cover with a progress bar, shown until the server spawns our character.
-- Progress comes from workspace attribute WorldProgress (0..1) set by the server while it writes the terrain.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Theme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Theme"))

local Loading = {}

function Loading.show()
	local player = Players.LocalPlayer
	if player.Character then
		return
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "Loading"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 100

	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Theme.background
	bg.BorderSizePixel = 0
	bg.Parent = gui

	local title = Instance.new("TextLabel")
	title.AnchorPoint = Vector2.new(0.5, 1)
	title.Position = UDim2.fromScale(0.5, 0.48)
	title.Size = UDim2.new(0.8, 0, 0, 48)
	title.BackgroundTransparency = 1
	title.FontFace = Theme.display
	title.TextScaled = true
	title.TextColor3 = Theme.text
	title.Text = "Building the valley..."
	title.Parent = bg

	local track = Instance.new("Frame")
	track.AnchorPoint = Vector2.new(0.5, 0)
	track.Position = UDim2.fromScale(0.5, 0.52)
	track.Size = UDim2.new(0, 320, 0, 14)
	track.BackgroundColor3 = Theme.border
	track.BorderSizePixel = 0
	track.Parent = bg
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = track
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = Theme.primary
	fill.BorderSizePixel = 0
	fill.Parent = track
	corner:Clone().Parent = fill

	local function update()
		local f = tonumber(workspace:GetAttribute("WorldProgress")) or 0
		fill.Size = UDim2.fromScale(math.clamp(f, 0, 1), 1)
	end
	update()
	local conn = workspace:GetAttributeChangedSignal("WorldProgress"):Connect(update)
	gui.Parent = player:WaitForChild("PlayerGui")
	player.CharacterAdded:Once(function()
		conn:Disconnect()
		gui:Destroy()
	end)
end

return Loading
