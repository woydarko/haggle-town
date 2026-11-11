--!strict
-- Runs one gather minigame. Owns the input (click / Space / tap, sunk so the character does not jump),
-- the panel and cleanup, and waits out the server's minimum duration before returning the score.
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Theme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Theme"))
local Ui = require(script.Parent.Parent.ui.Ui)

export type Params = { zoneScale: number, fishSpeed: number, minMs: number }
export type Ctx = {
	node: string,
	panel: Frame,
	held: () -> boolean, -- button is down now
	consume: () -> boolean, -- button went down since the last call
	step: () -> number, -- wait one frame, returns dt
	hint: (text: string) -> (),
	fail: (text: string) -> nil, -- show why, pause, return nil (nothing caught)
}

local mine = require(script.Parent.Mining).play
local GAMES: { [string]: (Ctx, Params) -> number? } = {
	fish = require(script.Parent.Fishing).play,
	wood = require(script.Parent.Chopping).play,
	ore_mouth = mine,
	ore_deep = mine,
}

local Run = {}

-- Returns quality 0..1, or nil when the player failed (nothing is caught).
function Run.play(gui: ScreenGui, node: string, params: Params): number?
	local started = os.clock()
	local panel = Ui.new("Frame", {
		Parent = gui,
		Name = "Minigame",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -40),
		Size = UDim2.fromOffset(340, 400),
		BackgroundColor3 = Theme.surface,
	}, { Ui.corner(), Ui.stroke(), Ui.pad(12) })
	local hintLabel = Ui.text({ Parent = panel, Size = UDim2.new(1, 0, 0, 44), TextXAlignment = Enum.TextXAlignment.Center, Font = Theme.display, TextSize = 20, Text = "" })

	local held, pressed = false, false
	ContextActionService:BindActionAtPriority("HaggleMinigame", function(_, state: Enum.UserInputState)
		if state == Enum.UserInputState.Begin then
			held, pressed = true, true
		elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
			held = false
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.Space, Enum.UserInputType.MouseButton1, Enum.UserInputType.Touch)

	local ctx: Ctx
	ctx = {
		node = node,
		panel = panel,
		held = function()
			return held
		end,
		consume = function()
			local p = pressed
			pressed = false
			return p
		end,
		step = function()
			return RunService.RenderStepped:Wait()
		end,
		hint = function(text)
			hintLabel.Text = text
		end,
		fail = function(text)
			ctx.hint(text)
			task.wait(1)
			return nil
		end,
	}

	local ok, q = pcall(function(): number?
		local play = GAMES[node]
		local score = if play then play(ctx, params) else nil
		local left = params.minMs / 1000 - (os.clock() - started) + 0.2
		if score and left > 0 then
			ctx.hint("Almost done...")
			task.wait(left)
		end
		return score
	end)
	ContextActionService:UnbindAction("HaggleMinigame")
	panel:Destroy()
	if not ok then
		warn("minigame error", q)
		return nil
	end
	return q
end

return Run
