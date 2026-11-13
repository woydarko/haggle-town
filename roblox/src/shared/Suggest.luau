--!strict
-- Sentence suggestions for the haggle panel (pure, checked by roblox/tests/Suggest.spec.luau).
-- After each counter the player gets three ready lines in their own voice: meet in the middle, accept, push back.
-- Wording rotates with the round and skips anything the player was just shown, so it reads like a conversation.

export type Ctx = { side: string, unitPrice: number, itemName: string, qty: number, round: number }

local Suggest = {}

-- {m} meet price, {c} counter, {f} firm price, {item} item name, {q} quantity.
local MEET = {
	buy = {
		"Meet me at {m} each and we have a deal.",
		"How about {m} each? I'm buying {q}.",
		"{m} each and I'll take them now.",
		"Split the difference: {m} a piece?",
		"I can do {m} each. Fair?",
		"Come down to {m} and it's done.",
	},
	sell = {
		"Make it {m} each and they're yours.",
		"{m} each, and I'll bring more tomorrow.",
		"Meet me at {m} a piece?",
		"I'd let them go for {m} each.",
		"{m} each is fair for {item} this good.",
		"Go up to {m} and we shake on it.",
	},
}
local ACCEPT = {
	"Deal at {c}.",
	"{c} each works for me.",
	"Fine, {c} it is.",
	"You've got yourself a deal at {c}.",
	"Alright, {c} each. Done.",
	"{c} it is, let's trade.",
}
local PUSH = {
	buy = {
		"That's steep for {item}. {f}?",
		"Too rich for me. {f} each?",
		"I've seen {item} cheaper. {f}?",
		"Come on, {f} each is plenty.",
		"{f}, and I'll buy again tomorrow.",
		"My purse says {f}. Take it?",
	},
	sell = {
		"That's low for good {item}. {f} each.",
		"I can't sell under {f}.",
		"These took work. {f} each.",
		"{f} each or I'll try again tomorrow.",
		"Fresh {item}, {f} a piece. Fair?",
		"Not below {f}, sorry.",
	},
}

local function fill(template: string, v: { [string]: string }): string
	return (string.gsub(template, "{(%w+)}", function(k)
		return v[k] or k
	end))
end

-- Template for this round, skipping ones whose text the player saw last round.
local function pick(bank: { string }, round: number, v: { [string]: string }, recent: { string }): string
	for step = 0, #bank - 1 do
		local line = fill(bank[(round - 1 + step) % #bank + 1], v)
		if not table.find(recent, line) then
			return line
		end
	end
	return fill(bank[1], v)
end

function Suggest.lines(ctx: Ctx, recent: { string }): { string }
	local c = math.max(1, math.floor(ctx.unitPrice))
	local buying = ctx.side == "buy"
	-- Player buying wants lower prices, selling wants higher; small prices still move by at least 1.
	local m = if buying then math.max(1, math.min(c - 1, math.floor(c * 0.9 + 0.5))) else math.max(c + 1, math.floor(c * 1.1 + 0.5))
	local f = if buying then math.max(1, math.min(m - 1, math.floor(c * 0.8 + 0.5))) else math.max(m + 1, math.floor(c * 1.2 + 0.5))
	local v = { m = tostring(m), c = tostring(c), f = tostring(f), item = string.lower(ctx.itemName), q = tostring(ctx.qty) }
	local side = if buying then "buy" else "sell"
	return {
		pick(MEET[side], ctx.round, v, recent),
		pick(ACCEPT, ctx.round, v, recent),
		pick(PUSH[side], ctx.round, v, recent),
	}
end

return Suggest
