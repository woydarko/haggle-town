--!strict
-- Paints a Sprites.luau pixel sprite as Frames: one Frame per same-colour run, whole-pixel offsets (px // 12) so
-- edges stay crisp. Used by client/ui/Ui.luau (bag, catch card) and server/Boards.luau (lobby boards).
local Sprites = require(script.Parent.Sprites)

local SpriteGui = {}

-- Returns an unparented, transparent px x px Frame.
function SpriteGui.new(id: string, px: number): Frame
	local icon = Instance.new("Frame")
	icon.Size = UDim2.fromOffset(px, px)
	icon.BackgroundTransparency = 1
	local p = px // Sprites.SIZE
	local o = (px - p * Sprites.SIZE) // 2
	for _, run in Sprites.runs(id) do
		local f = Instance.new("Frame")
		f.BorderSizePixel = 0
		f.BackgroundColor3 = Color3.fromHex(run.hex)
		f.Position = UDim2.fromOffset(o + (run.col - 1) * p, o + (run.row - 1) * p)
		f.Size = UDim2.fromOffset(run.len * p, p)
		f.Parent = icon
	end
	return icon
end

return SpriteGui
