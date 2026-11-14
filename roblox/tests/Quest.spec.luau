-- Run: lute run roblox/tests/Quest.spec.luau
-- First-session guide: the next step is always the first one the player has not done. It guides, never blocks.
local Quest = require("../src/shared/Quest")

local function check(cond, name)
	if not cond then
		error("FAIL " .. name)
	end
	print("ok", name)
end

local s = Quest.step({ class = nil, bagCount = 0, deals = 0, ledgerSeen = false })
check(s.index == 1 and s.target == "guild", "no trade yet -> guild")
s = Quest.step({ class = "logger", bagCount = 0, deals = 0, ledgerSeen = false })
check(s.index == 2 and s.target == "gather", "trade picked, empty bag -> gather")
s = Quest.step({ class = "logger", bagCount = 3, deals = 0, ledgerSeen = false })
check(s.index == 3 and s.target == "market", "something in the bag -> market")
s = Quest.step({ class = "logger", bagCount = 0, deals = 1, ledgerSeen = false })
check(s.index == 4 and s.target == "ledger", "first deal done -> ledger")
s = Quest.step({ class = "logger", bagCount = 0, deals = 2, ledgerSeen = true })
check(s.index == 6 and s.target == nil, "forge state unknown -> all done (never blocks)")
local need = { name = "Copper", qty = 2, stall = "smith" }
s = Quest.step({ class = "logger", bagCount = 0, deals = 2, ledgerSeen = true, forge = { tool = "Axe", level = 1, need = need } })
check(s.index == 5 and s.target == "market" and s.stall == "smith", "Worn axe, copper missing -> go to the smith")
check(string.find(s.detail, "2 more Copper", 1, true) ~= nil, "forge step names what to buy")
s = Quest.step({ class = "logger", bagCount = 0, deals = 2, ledgerSeen = true, forge = { tool = "Axe", level = 1 } })
check(s.index == 5 and s.target == nil, "goods ready -> forge it")
s = Quest.step({ class = "logger", bagCount = 0, deals = 2, ledgerSeen = true, forge = { tool = "Axe", level = 2 } })
check(s.index == 6, "Sturdy axe -> all done")
s = Quest.step({ class = nil, bagCount = 5, deals = 3, ledgerSeen = true })
check(s.index == 1 and s.target == "guild", "out of order: first unmet step, never blocks")

-- Every step has a title and a detail; the gather detail names where the player's trade gathers.
for _, cls in { "logger", "miner", "fisher" } do
	local g = Quest.step({ class = cls, bagCount = 0, deals = 0, ledgerSeen = false })
	check(#g.title > 0 and #g.detail > 0, `{cls}: gather step has text`)
	check(g.gate ~= nil, `{cls}: gather step names a gate`)
end
check(Quest.step({ class = "logger", bagCount = 0, deals = 0, ledgerSeen = false }).gate == "Woods", "logger -> Woods gate")
check(Quest.step({ class = "miner", bagCount = 0, deals = 0, ledgerSeen = false }).gate == "Mine", "miner -> Mine gate")
check(Quest.step({ class = "fisher", bagCount = 0, deals = 0, ledgerSeen = false }).gate == "Lake", "fisher -> Lake gate")
check(Quest.step({ class = "miner", bagCount = 2, deals = 0, ledgerSeen = false }).stall == "smith", "miner sells to the smith")

local BANNED = { "crypto", "blockchain", "nft", "token", "wallet", "near", "gas", "transaction" }
for i = 1, 6 do
	local st = Quest.step({ class = if i > 1 then "fisher" else nil, bagCount = if i == 3 then 1 else 0, deals = if i >= 4 then 1 else 0, ledgerSeen = i >= 5, forge = if i == 5 then { tool = "Rod", level = 1, need = { name = "Pine", qty = 3, stall = "woodcutter" } } else nil })
	for _, text in { st.title, st.detail } do
		local lower = string.lower(text)
		for _, w in BANNED do
			check(not string.find(lower, "%f[%a]" .. w .. "%f[%A]"), `step {i}: no "{w}"`)
		end
		check(not string.find(text, "\u{2014}", 1, true), `step {i}: no em dash`)
	end
end
print("Quest.spec passed")
