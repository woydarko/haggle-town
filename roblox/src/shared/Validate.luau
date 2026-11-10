--!strict
-- Pure checks the Roblox server runs on every RemoteEvent before calling the backend.
-- No Roblox globals here so roblox/tests/Validate.spec.luau can run outside Studio.

local GOODS = { wood = true, fish = true, iron = true }
local MERCHANTS = { woodcutter = true, fishmonger = true, smith = true }
local MAX_DISTANCE = 12
local MAX_TEXT = 200

local Validate = {}

function Validate.good(good: any): boolean
	return type(good) == "string" and GOODS[good] == true
end

function Validate.merchant(name: any): boolean
	return type(name) == "string" and MERCHANTS[name] == true
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
