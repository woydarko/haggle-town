--!strict
-- Market Ledger data: polls the same public API the web dashboard uses every 10 s and shapes it with
-- shared/LedgerView.luau. Clients read the latest view through the GetLedger remote (Main.server) and draw it in
-- the Ledger pop-up (client/ui/LedgerPanel.luau). v6: there is no ledger board in the square any more.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local LedgerView = require(Shared:WaitForChild("LedgerView"))
local Backend = require(script.Parent.Backend)

local Ledger = {}
local POLL_S = 10

function Ledger.start()
	local s = { market = nil :: any, feed = nil :: any, leaders = nil :: any, config = nil :: any, lastOk = nil :: number?, ok = false }
	local lastAsk: { [string]: number } = {}
	local prev: { [string]: number } = {}
	local function now()
		return DateTime.now().UnixTimestampMillis
	end
	local latest = LedgerView.build({ now = now(), ok = false })
	task.spawn(function()
		while true do
			if not (s.config and s.config.dayLengthMs) then -- older backends have no day length yet; keep asking
				local okC, cfg = Backend.get("/api/config")
				s.config = if okC then cfg else nil
			end
			local okM, market = Backend.get("/api/market")
			local okF, feed = Backend.get("/api/feed")
			local okL, leaders = Backend.get("/api/leaderboard")
			s.ok = okM and type(market) == "table" and #market > 0
			if s.ok then
				for _, r in market do
					if lastAsk[r.item] and lastAsk[r.item] ~= r.ask then
						prev[r.item] = lastAsk[r.item] -- trend arrow = direction of the last price change
					end
					lastAsk[r.item] = r.ask
				end
				s.market, s.lastOk = market, now()
			end
			if okF then
				s.feed = feed
			end
			if okL then
				s.leaders = leaders
			end
			local okBuild, view = pcall(LedgerView.build, { market = s.market, feed = s.feed, leaders = s.leaders, config = s.config, now = now(), ok = s.ok, lastOk = s.lastOk, prev = prev })
			if okBuild then
				latest = view
			else
				warn("[Ledger] build failed: " .. tostring(view))
			end
			task.wait(POLL_S)
		end
	end)
	return {
		latest = function()
			return latest
		end,
	}
end

return Ledger
