--!strict
-- Forge helpers shared by the Forge panel, the haggle panel's Buy tab and the guide (pure; roblox/tests/ForgeView.spec.luau).
-- The backend sends every tool's level and next recipe (/rbx/state "forge"); what the player holds comes from live balances.

export type Cost = { item: string, name: string, qty: number, merchant: string }
export type Tool = { tool: string, owned: boolean?, price: number?, level: number, name: string, bonus: number, next: { level: number, name: string, bonus: number, cost: { Cost } }? }
export type Need = { item: string, name: string, qty: number, merchant: string }
export type Hint = { tool: string, level: number, need: { name: string, qty: number, stall: string }? }

local ForgeView = {}

ForgeView.CLASS_TOOL = { logger = "axe", miner = "pickaxe", fisher = "rod" } :: { [string]: string }
ForgeView.LABEL = { axe = "Axe", pickaxe = "Pickaxe", rod = "Rod" } :: { [string]: string } -- also the Tool instance names
ForgeView.CATCH = { axe = "log", pickaxe = "ore", rod = "fish" } :: { [string]: string }

-- Goods still missing for this tool's next level, in recipe order.
function ForgeView.missing(t: Tool, balances: { [string]: number }): { Need }
	local out: { Need } = {}
	local nxt = t.next
	if nxt then
		for _, c in nxt.cost do
			local have = balances[c.item] or 0
			if have < c.qty then
				table.insert(out, { item = c.item, name = c.name, qty = c.qty - have, merchant = c.merchant })
			end
		end
	end
	return out
end

-- The tool to work towards: the player's trade tool while it can still be upgraded, else the first one that can.
function ForgeView.focus(forge: { Tool }?, class: string?): Tool?
	if not forge then
		return nil
	end
	local want = class and ForgeView.CLASS_TOOL[class]
	for _, t in forge do
		if t.tool == want and t.next and t.owned ~= false then
			return t
		end
	end
	for _, t in forge do
		if t.next and t.owned ~= false then
			return t
		end
	end
	return nil
end

-- Item id -> how many to buy from this merchant for the focus tool's next level (the Buy tab's badges).
function ForgeView.needsFrom(forge: { Tool }?, class: string?, balances: { [string]: number }, merchant: string): { [string]: number }
	local out: { [string]: number } = {}
	local t = ForgeView.focus(forge, class)
	if t then
		for _, n in ForgeView.missing(t, balances) do
			if n.merchant == merchant then
				out[n.item] = n.qty
			end
		end
	end
	return out
end

-- Guide hint for the trade tool: its label, level and the first good still missing (nil when ready to forge).
function ForgeView.hint(forge: { Tool }?, class: string?, balances: { [string]: number }): Hint?
	local want = class and ForgeView.CLASS_TOOL[class]
	if not (forge and want) then
		return nil
	end
	for _, t in forge do
		if t.tool == want then
			local m = ForgeView.missing(t, balances)[1]
			return { tool = ForgeView.LABEL[t.tool], level = t.level, need = if m then { name = m.name, qty = m.qty, stall = m.merchant } else nil }
		end
	end
	return nil
end

function ForgeView.pct(bonus: number): string
	return `{math.floor(bonus * 100 + 0.5)}%`
end

return ForgeView
