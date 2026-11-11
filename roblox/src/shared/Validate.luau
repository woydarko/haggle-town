--!strict
-- Pure checks the Roblox server runs on every RemoteEvent before calling the backend.
-- No Roblox globals here so roblox/tests/Validate.spec.luau can run outside Studio.

local NODES = { wood = true, fish = true, ore_mouth = true, ore_deep = true }
local MERCHANTS = { woodcutter = true, fishmonger = true, smith = true }
local MAX_DISTANCE = 12
local MAX_TEXT = 200

local Validate = {}

function Validate.node(node: any): boolean
	return type(node) == "string" and NODES[node] == true
end

-- Minigame score from the client; NaN fails both comparisons.
function Validate.quality(q: any): boolean
	return type(q) == "number" and q >= 0 and q <= 1
end

function Validate.merchant(name: any): boolean
	return type(name) == "string" and MERCHANTS[name] == true
end

local CLASSES = { fisher = true, logger = true, miner = true }

function Validate.class(name: any): boolean
	return type(name) == "string" and CLASSES[name] == true
end

function Validate.near(distance: any): boolean
	return type(distance) == "number" and distance <= MAX_DISTANCE
end

function Validate.text(text: any): boolean
	if type(text) ~= "string" then
		return false
	end
	local trimmed = string.match(text, "^%s*(.-)%s*$") :: string
	return #trimmed > 0 and #text <= MAX_TEXT
end

function Validate.deal(issued: { [string]: boolean }, dealId: any): boolean
	return type(dealId) == "string" and issued[dealId] == true
end

return Validate
