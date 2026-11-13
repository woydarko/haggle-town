--!strict
-- First-session guide (pure, checked by roblox/tests/Quest.spec.luau). The next step is the first one the player has
-- not done yet, so doing things out of order never locks anyone out. client/ui/QuestTracker.luau shows it and puts a
-- marker on the target (positions from shared/Village.luau).

export type State = { class: string?, bagCount: number, deals: number, ledgerSeen: boolean }
export type Step = { index: number, title: string, detail: string, target: string?, gate: string?, stall: string? }

local Quest = {}
Quest.COUNT = 4

local BY_CLASS = {
	logger = { gate = "Woods", stall = "woodcutter", detail = "Take the west gate to the woods. Press 1 for the axe and click a tree." },
	miner = { gate = "Mine", stall = "smith", detail = "Take the east gate to the mine. Press 2 for the pickaxe and click a rock." },
	fisher = { gate = "Lake", stall = "fishmonger", detail = "Take the north gate to the lake. Press 3 for the rod, hold and release to cast." },
}
local MERCHANT = { woodcutter = "Woodcutter", smith = "Smith", fishmonger = "Fishmonger" }

function Quest.step(s: State): Step
	local trade = s.class and BY_CLASS[s.class]
	if not trade then
		return { index = 1, title = "Pick a trade", detail = "Talk to the mentor in the guild yard behind you. A trade sets what you gather best.", target = "guild" }
	end
	if s.deals == 0 and s.bagCount == 0 then
		return { index = 2, title = "Gather something to sell", detail = trade.detail, target = "gather", gate = trade.gate }
	end
	if s.deals == 0 then
		return {
			index = 3,
			title = "Sell it at the market",
			detail = `Walk to the {MERCHANT[trade.stall]} in the square and name your price. They haggle back.`,
			target = "market",
			stall = trade.stall,
		}
	end
	if not s.ledgerSeen then
		return { index = 4, title = "Check the Market Ledger", detail = "The big board in the square shows every price. Your deal just moved one.", target = "ledger" }
	end
	return { index = 5, title = "You know the market", detail = "Gather rarer goods, sell where the price is high, climb the top traders.", target = nil }
end

return Quest
