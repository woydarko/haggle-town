// Forge: players upgrade their gathering tools with goods from the other trades
// (design: docs/superpowers/specs/2026-11-14-forge-design.md). Levels live here; the goods are burned on chain (use_items).
import type { Db } from "../db/db.ts";
import { ChainError, type Chain } from "../chain/near.ts";
import type { Queue } from "../chain/queue.ts";
import type { Players } from "./players.ts";
import type { Gather } from "./gather.ts";
import { HttpError } from "../errors.ts";
import { itemById, type Category } from "../items.ts";

export type Tool = "axe" | "pickaxe" | "rod";
export const TOOLS: Record<Tool, Category> = { axe: "wood", pickaxe: "ore", rod: "fish" };
const TOOL_OF: Record<Category, Tool> = { wood: "axe", ore: "pickaxe", fish: "rod" };
export const MAX_LEVEL = 3;
/** Chance of a second item per catch, by tool level (index = level). */
export const TOOL_BONUS = [0, 0, 0.25, 0.5];
const LEVEL_NAME = ["", "Worn", "Sturdy", "Master"];
const TOOL_NAME: Record<Tool, string> = { axe: "Axe", pickaxe: "Pickaxe", rod: "Rod" };
/** Next-level recipe: metal heads (ore), wooden handles and poles (wood), blades quenched in fish oil (fish). */
export const RECIPES: Record<Tool, Record<number, Record<string, number>>> = {
  axe: { 2: { ore_copper: 3, fish_sardine: 3 }, 3: { ore_iron: 2, fish_trout: 2 } },
  pickaxe: { 2: { wood_pine: 3, fish_sardine: 3 }, 3: { wood_oak: 2, fish_trout: 2 } },
  rod: { 2: { wood_pine: 3, ore_copper: 3 }, 3: { wood_oak: 2, ore_iron: 2 } },
};
const SELLER: Record<Category, string> = { wood: "woodcutter", ore: "smith", fish: "fishmonger" };

export type Cost = { item: string; name: string; qty: number; merchant: string };
export type ToolView = { tool: Tool; level: number; name: string; bonus: number; next: { level: number; name: string; bonus: number; cost: Cost[] } | null };

export const toolName = (t: Tool, level: number) => `${LEVEL_NAME[level]} ${TOOL_NAME[t]}`;

export class Forge {
  private db: Db;
  private chain: Chain;
  private queue: Queue;
  private players: Players;
  private gather: Gather;
  private now: () => number;
  private busy = new Set<string>();

  constructor(db: Db, chain: Chain, queue: Queue, players: Players, gather: Gather, now: () => number = Date.now) {
    this.db = db;
    this.chain = chain;
    this.queue = queue;
    this.players = players;
    this.gather = gather;
    this.now = now;
  }

  level(playerId: string, tool: Tool): number {
    const r = this.db.prepare("SELECT level FROM player_tool WHERE player_id = ? AND tool = ?").get(playerId, tool) as { level: number } | undefined;
    return r?.level ?? 1;
  }

  /** Extra-catch chance of the tool that gathers this category (Gather asks at every catch). */
  bonus(playerId: string, category: Category): { chance: number; name: string } {
    const t = TOOL_OF[category];
    const level = this.level(playerId, t);
    return { chance: TOOL_BONUS[level], name: toolName(t, level) };
  }

  /** Every tool's level and the next recipe; the client counts what the player holds from its live balances. */
  view(playerId: string): ToolView[] {
    const cost = (r: Record<string, number>): Cost[] =>
      Object.entries(r).map(([item, qty]) => {
        const it = itemById(item)!;
        return { item, name: it.name, qty, merchant: SELLER[it.category] };
      });
    return (Object.keys(TOOLS) as Tool[]).map((tool) => {
      const level = this.level(playerId, tool);
      const recipe = RECIPES[tool][level + 1];
      return {
        tool,
        level,
        name: toolName(tool, level),
        bonus: TOOL_BONUS[level],
        next: recipe ? { level: level + 1, name: toolName(tool, level + 1), bonus: TOOL_BONUS[level + 1], cost: cost(recipe) } : null,
      };
    });
  }

  /** Burns the next recipe's goods on chain, then raises the level. One upgrade per player at a time. */
  async upgrade(playerId: string, tool: string): Promise<{ tool: Tool; level: number; name: string; bonus: number; txHash: string }> {
    if (!Object.hasOwn(TOOLS, tool)) throw new HttpError(400, "bad_tool", "No such tool.");
    const t = tool as Tool;
    const level = this.level(playerId, t);
    if (level >= MAX_LEVEL) throw new HttpError(409, "max_level", `Your ${toolName(t, level)} is as good as it gets.`);
    if (this.busy.has(playerId)) throw new HttpError(429, "busy", "The forge is still hot. One moment.");
    this.busy.add(playerId);
    try {
      const recipe = RECIPES[t][level + 1];
      await this.gather.flush().catch(() => undefined); // fresh catches must be on chain before they can be burned
      const v = await this.players.view(playerId);
      if (!v) throw new HttpError(409, "not_joined", "Join the game first.");
      const pending = this.gather.pending(playerId);
      for (const [id, qty] of Object.entries(recipe)) {
        const held = Number(v.balances?.[id] ?? 0);
        if (held >= qty) continue;
        const name = itemById(id)!.name;
        if (held + (pending[id] ?? 0) >= qty) throw new HttpError(409, "packing", `Your fresh ${name} is still being packed. Try again in a few seconds.`);
        throw new HttpError(409, "missing", `You need ${qty - held} more ${name}.`);
      }
      let txHash: string;
      try {
        ({ txHash } = await this.queue(() =>
          this.chain.call("use_items", { player_id: playerId, items: Object.entries(recipe).map(([id, n]) => [id, String(n)]) }),
        ));
      } catch (e) {
        if (e instanceof ChainError && e.code === "InsufficientGoods") throw new HttpError(409, "missing", "Some of those goods are gone. Check your bag.");
        throw e;
      }
      const next = level + 1;
      this.db
        .prepare(
          "INSERT INTO player_tool (player_id, tool, level, updated_at) VALUES (?, ?, ?, ?) ON CONFLICT DO UPDATE SET level = excluded.level, updated_at = excluded.updated_at",
        )
        .run(playerId, t, next, this.now());
      this.db
        .prepare("INSERT INTO forge_event (player_id, tool, level, cost, tx_hash, created_at) VALUES (?, ?, ?, ?, ?, ?)")
        .run(playerId, t, next, JSON.stringify(recipe), txHash, this.now());
      return { tool: t, level: next, name: toolName(t, next), bonus: TOOL_BONUS[next], txHash };
    } finally {
      this.busy.delete(playerId);
    }
  }
}
