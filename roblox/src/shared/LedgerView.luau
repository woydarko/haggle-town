--!strict
-- Content of the Market Ledger board in the square, from the same API the web dashboard uses
-- (/api/market, /api/feed, /api/leaderboard, /api/config). Pure, checked by roblox/tests/LedgerView.spec.luau;
-- server/Ledger.luau fetches and draws it.
local Items: any = if script then require(script.Parent.Items) else (require :: any)("./Items")

local LedgerView = {}

local ORDER = { "woodcutter", "fishmonger", "smith" }
local NAMES = { woodcutter = "Woodcutter", fishmonger = "Fishmonger", smith = "Smith" }

export type Input = {
	market: { any }?,
	feed: any?,
	leaders: { any }?,
	config: any?,
	now: number, -- ms
	ok: boolean, -- the latest fetch succeeded
	lastOk: number?, -- ms of the last successful fetch
	prev: { [string]: number }?, -- item -> ask at the previous price change
}

local function shortMerchant(m: string): string
	return (string.match(m, "^([^%.]+)") or m)
end

local function ago(ms: number): string
	local s = math.max(0, ms) // 1000
	if s < 60 then
		return "just now"
	elseif s < 3600 then
		return `{s // 60} min ago`
	end
	return `{s // 3600} h ago`
end

local function header(market: { any }, config: any?, now: number): string
	local first = market[1]
	local day = first and first.day
	local text = if day then `Market day {day}` else "Market"
	local len = config and tonumber(config.dayLengthMs)
	local tick = first and tonumber(first.last_tick_ns)
	if len and tick then
		local left = math.max(0, (tick / 1e6 + len - now) // 1000)
		text ..= string.format(", restock in %d:%02d", left // 60, left % 60)
	end
	return text
end

function LedgerView.build(input: Input)
	local market = input.market
	if not market then
		return { state = "loading", header = "Opening the ledger...", merchants = {}, deals = {}, leaders = {}, note = nil }
	end
	local byItem: { [string]: any } = {}
	for _, r in market do
		byItem[r.item] = r
	end
	local prev = input.prev or {}
	local merchants = {}
	for _, m in ORDER do
		local items, purse = {}, 0
		for _, item in Items.list do
			if item.category == Items.MERCHANT_CATEGORY[m] then
				local r = byItem[item.id]
				if r then
					purse = r.purse
					local before = prev[item.id]
					table.insert(items, {
						id = item.id,
						name = item.name,
						tier = item.tier,
						buy = r.ask,
						sell = r.bid,
						trend = if before == nil or before == r.ask then "flat" elseif r.ask > before then "up" else "down",
						stockPct = if r.target and r.target > 0 then r.stock / r.target * 100 else 0,
					})
				end
			end
		end
		table.insert(merchants, { id = m, name = NAMES[m], purse = purse, items = items })
	end

	local deals = {}
	local list = table.clone((input.feed and input.feed.deals) or {})
	table.sort(list, function(a, b)
		return (a.at or 0) > (b.at or 0)
	end)
	for i = 1, math.min(#list, 6) do
		local d = list[i]
		local item = Items.byId[d.good]
		local who = NAMES[shortMerchant(d.merchant)] or d.merchant
		local what = `{d.qty} {item and item.name or d.good}`
		local verb = if d.side == "sell" then `sold {what} to the {who}` else `bought {what} from the {who}`
		table.insert(deals, `{d.player} {verb} for {d.qty * d.unitPrice} C, {ago(input.now - d.at)}`)
	end
	if #deals == 0 then
		deals = { "No deals yet today. Be the first." }
	end

	local leaders = {}
	for i, l in input.leaders or {} do
		if i > 5 then
			break
		end
		table.insert(leaders, { name = l.name, worth = l.netWorth })
	end

	local stale = not input.ok
	return {
		state = if stale then "stale" else "ok",
		header = header(market, input.config, input.now),
		merchants = merchants,
		deals = deals,
		leaders = leaders,
		note = if stale then `Can't reach the market. Prices from {if input.lastOk then ago(input.now - input.lastOk) else "earlier"}.` else nil,
	}
end

return LedgerView
