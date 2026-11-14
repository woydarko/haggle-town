-- Run: lute run roblox/tests/LedgerView.spec.luau
-- The Market Ledger board's content, built from the web API payloads (/api/market, /api/feed, /api/leaderboard,
-- /api/config). Pure so the wording and every state are checked here.
local LedgerView = require("../src/shared/LedgerView")

local function check(cond, name)
	if not cond then
		error("FAIL " .. name)
	end
	print("ok", name)
end

local NOW = 1_800_000_000_000
local function row(merchant, item, ask, bid, stock)
	return { merchant = merchant .. ".haggletown-v2.testnet", item = item, ask = ask, bid = bid, stock = stock, target = 120, purse = 9000, day = 251, last_tick_ns = tostring((NOW - 108_000) * 1_000_000) }
end
local market = {
	row("woodcutter", "wood_oak", 20, 16, 100), row("woodcutter", "wood_pine", 12, 9, 150), row("woodcutter", "wood_maple", 40, 32, 60), row("woodcutter", "wood_redwood", 90, 72, 10),
	row("fishmonger", "fish_sardine", 18, 14, 120), row("fishmonger", "fish_trout", 30, 24, 80), row("fishmonger", "fish_salmon", 60, 48, 40), row("fishmonger", "fish_koi", 200, 160, 5),
	row("smith", "ore_copper", 29, 23, 110), row("smith", "ore_iron", 50, 40, 90), row("smith", "ore_gold", 120, 96, 30), row("smith", "ore_crystal", 300, 240, 4),
}
local feed = { deals = {
	{ at = NOW - 120_000, player = "Darko", merchant = "woodcutter", good = "wood_pine", qty = 1, unitPrice = 12, side = "sell" },
	{ at = NOW - 20_000, player = "Mia", merchant = "fishmonger", good = "fish_trout", qty = 2, unitPrice = 30, side = "buy" },
} }
local leaders = { { name = "Mia", netWorth = 3100, userId = "77" }, { name = "Darko", netWorth = 2949 }, { name = "A", netWorth = 10 }, { name = "B", netWorth = 9 }, { name = "C", netWorth = 8 }, { name = "D", netWorth = 7 } }
local config = { dayLengthMs = 300_000 }

-- Loading: nothing fetched yet.
local v = LedgerView.build({ now = NOW, ok = false })
check(v.state == "loading" and v.header == "Opening the ledger...", "no data yet -> loading")

-- Live data.
v = LedgerView.build({ market = market, feed = feed, leaders = leaders, config = config, now = NOW, ok = true, prev = { wood_pine = 14, fish_trout = 28 } })
check(v.state == "ok" and v.note == nil, "fresh data -> ok, no note")
check(v.header == "Market day 251, restock in 3:12", `header: {v.header}`)
check(#v.merchants == 3 and v.merchants[1].name == "Woodcutter" and v.merchants[2].name == "Fishmonger" and v.merchants[3].name == "Smith", "three merchants in town order")
local wood = v.merchants[1]
check(wood.purse == 9000 and #wood.items == 4, "purse and four items")
check(wood.items[1].name == "Pine" and wood.items[2].name == "Oak" and wood.items[4].name == "Ancient Redwood", "items in tier order")
check(wood.items[1].buy == 12 and wood.items[1].sell == 9, "buy = ask, sell = bid")
check(wood.items[1].trend == "down" and wood.items[2].trend == "flat", "trend vs the previous ask")
check(v.merchants[2].items[2].trend == "up", "trout went up")
check(math.abs(wood.items[1].stockPct - 125) < 0.5, "stock as percent of normal")
check(v.deals[1] == "Mia bought 2 Trout from the Fishmonger for 60 C, just now", `newest deal first: {v.deals[1]}`)
check(v.deals[2] == "Darko sold 1 Pine to the Woodcutter for 12 C, 2 min ago", `deal line: {v.deals[2]}`)
-- Each deal line has its item id alongside (the pop-up draws the item icon next to it).
check(v.dealItems[1] == "fish_trout" and v.dealItems[2] == "wood_pine", "deal items line up with the lines")
check(#v.leaders == 5 and v.leaders[1].name == "Mia" and v.leaders[1].worth == 3100, "top 5 traders")
check(v.leaders[1].userId == "77" and v.leaders[2].userId == nil, "headshot id passes through")

-- The API may list deals newest first; the board still shows newest first.
local reversed = { deals = { feed.deals[2], feed.deals[1] } }
v = LedgerView.build({ market = market, feed = reversed, leaders = leaders, config = config, now = NOW, ok = true })
check(string.find(v.deals[1], "^Mia") ~= nil, "newest first whatever the API order")

-- Empty feed.
v = LedgerView.build({ market = market, feed = { deals = {} }, leaders = {}, config = config, now = NOW, ok = true })
check(#v.deals == 1 and v.deals[1] == "No deals yet today. Be the first.", "empty feed message")
check(#v.dealItems == 0, "no deal items when the feed is empty")

-- Backend down after a good fetch: keep the last data and say how old it is.
v = LedgerView.build({ market = market, feed = feed, leaders = leaders, config = config, now = NOW, ok = false, lastOk = NOW - 5 * 60_000 })
check(v.state == "stale" and #v.merchants == 3, "offline -> stale, last prices kept")
check(v.note == "Can't reach the market. Prices from 5 min ago.", `stale note: {tostring(v.note)}`)

-- Missing config: header without the restock clock.
v = LedgerView.build({ market = market, now = NOW, ok = true })
check(v.header == "Market day 251", `header without config: {v.header}`)
print("LedgerView.spec passed")
