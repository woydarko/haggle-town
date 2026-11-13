-- Run: lute run roblox/tests/Suggest.spec.luau
-- Three sentence suggestions under the haggle input, built from the merchant's live counter.
local Suggest = require("../src/shared/Suggest")

local function check(cond, name)
	if not cond then
		error("FAIL " .. name)
	end
	print("ok", name)
end
local function price(line)
	return tonumber(string.match(line, "%d+"))
end
local BANNED = { "crypto", "blockchain", "nft", "token", "wallet", "near", "gas", "transaction" }

for _, side in { "buy", "sell" } do
	for _, c in { 5, 12, 47, 150 } do
		local s = Suggest.lines({ side = side, unitPrice = c, itemName = "Pine", qty = 2, round = 1 }, {})
		check(#s == 3, `{side} {c}: three lines`)
		local m, a, f = price(s[1]), price(s[2]), price(s[3])
		if side == "buy" then
			check(m and m < c and m >= math.floor(c * 0.8), `{side} {c}: meet-in-the-middle is a bit lower ({s[1]})`)
			check(f and f < c, `{side} {c}: push back asks for less ({s[3]})`)
		else
			check(m and m > c and m <= math.ceil(c * 1.2), `{side} {c}: meet-in-the-middle is a bit higher ({s[1]})`)
			check(f and f > c, `{side} {c}: push back asks for more ({s[3]})`)
		end
		check(a == c, `{side} {c}: accept names the counter ({s[2]})`)
	end
end

-- Rounds rotate the wording and never repeat a line the player was just shown.
local recent, all = {}, {}
for round = 1, 6 do
	local s = Suggest.lines({ side = "sell", unitPrice = 20, itemName = "Trout", qty = 1, round = round }, recent)
	for _, l in s do
		check(table.find(recent, l) == nil, `round {round}: "{l}" is new`)
		all[l] = true
		local lower = string.lower(l)
		for _, w in BANNED do
			check(not string.find(lower, "%f[%a]" .. w .. "%f[%A]"), `no "{w}" in "{l}"`)
		end
		check(not string.find(l, "\u{2014}", 1, true), `no em dash in "{l}"`)
	end
	recent = s
end
local n = 0
for _ in all do
	n += 1
end
check(n >= 10, `six rounds show at least 10 different lines ({n})`)
-- Chip prices (haggle panel buttons) are the same numbers the sentences use.
local sell = Suggest.prices({ side = "sell", unitPrice = 25, itemName = "Sardine", qty = 1, round = 1 })
check(sell.meet == 28 and sell.counter == 25 and sell.firm == 30, "sell chips: meet 28, counter 25, firm 30")
local buy = Suggest.prices({ side = "buy", unitPrice = 50, itemName = "Oak", qty = 2, round = 1 })
check(buy.meet == 45 and buy.firm == 40, "buy chips: meet 45, firm 40")
local tiny = Suggest.prices({ side = "buy", unitPrice = 2, itemName = "Pine", qty = 1, round = 1 })
check(tiny.meet == 1 and tiny.firm >= 1, "buy chips never go below 1")
local l = Suggest.lines({ side = "sell", unitPrice = 25, itemName = "Sardine", qty = 1, round = 1 }, {})
check(string.find(l[1], "28", 1, true) ~= nil and string.find(l[3], "30", 1, true) ~= nil, "sentences carry the chip prices")
print("Suggest.spec passed")
