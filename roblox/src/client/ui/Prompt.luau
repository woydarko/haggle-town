--!strict
-- Custom ProximityPrompt look (merchants, mentors): a small Theme card over the target with the key, the action
-- and the object. Keyboard/gamepad keys still trigger the prompt natively; the card itself is a button for mouse
-- and touch.
local ProximityPromptService = game:GetService("ProximityPromptService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Theme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Theme"))
local Ui = require(script.Parent.Ui)

local Prompt = {}

local function keyText(prompt: ProximityPrompt, input: Enum.ProximityPromptInputType): string
	if input == Enum.ProximityPromptInputType.Touch then
		return "Tap"
	elseif input == Enum.ProximityPromptInputType.Gamepad then
		return (string.gsub(prompt.GamepadKeyCode.Name, "Button", ""))
	end
	return prompt.KeyboardKeyCode.Name
end

function Prompt.start()
	local open: { [ProximityPrompt]: BillboardGui } = {}
	ProximityPromptService.PromptShown:Connect(function(prompt: ProximityPrompt, input: Enum.ProximityPromptInputType)
		if prompt.Style ~= Enum.ProximityPromptStyle.Custom or open[prompt] then
			return
		end
		local bb = Instance.new("BillboardGui")
		bb.Name = "PromptCard"
		bb.Adornee = prompt.Parent :: Instance
		bb.AlwaysOnTop = true
		bb.Active = true
		bb.Size = UDim2.fromOffset(230, 56)
		bb.StudsOffset = Vector3.new(0, 3, 0)
		local card = Ui.new("TextButton", { Parent = bb, Text = "", AutoButtonColor = true, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Theme.surface }, { Ui.corner(), Ui.stroke() })
		Ui.new("TextLabel", {
			Parent = card,
			Position = UDim2.fromOffset(8, 8),
			Size = UDim2.fromOffset(44, 40),
			BackgroundColor3 = Theme.primary,
			Text = keyText(prompt, input),
			TextScaled = true,
			Font = Theme.display,
			TextColor3 = Theme.onPrimary,
		}, { Ui.corner(), Ui.pad(6) })
		Ui.text({ Parent = card, Position = UDim2.fromOffset(60, 6), Size = UDim2.new(1, -66, 0, 24), Font = Theme.display, TextSize = 20, Text = prompt.ActionText })
		Ui.text({ Parent = card, Position = UDim2.fromOffset(60, 30), Size = UDim2.new(1, -66, 0, 20), TextSize = 15, TextColor3 = Theme.muted, Text = prompt.ObjectText })
		card.Activated:Connect(function()
			prompt:InputHoldBegin()
			task.wait()
			prompt:InputHoldEnd()
		end)
		bb.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
		open[prompt] = bb
	end)
	ProximityPromptService.PromptHidden:Connect(function(prompt: ProximityPrompt)
		local bb = open[prompt]
		if bb then
			open[prompt] = nil
			bb:Destroy()
		end
	end)
end

return Prompt
