import { randomUUID } from "node:crypto";
import type { Db } from "../db/db.ts";
import { ChainError, type Chain } from "../chain/near.ts";
import type { Queue } from "../chain/queue.ts";
import type { MarketCache } from "../chain/market.ts";
import type { Players } from "../game/players.ts";
import type { Balances, MarketView } from "../types.ts";
import { HttpError } from "../errors.ts";
import { buyRoom, priceOk, sellRoom } from "./pricing.ts";
import { parseOffer, type Offer } from "./offer.ts";
import { signDeal, newNonce, type ChainDeal } from "./deal.ts";
import { reasoningLine } from "./reasoning.ts";
import { fallbackReply, pickLine, PERSONAS } from "./fallback.ts";
import { CLASS_CATEGORY, ITEMS, MERCHANT_CATEGORY, itemById, itemOf, type Tier } from "../items.ts";

export const MERCHANTS = MERCHANT_CATEGORY;
const WHO: Record<string, string> = { fish: "Fishmonger", wood: "Woodcutter", ore: "Smith" };
const QUOTE_TTL_MS = 30_000;
const MIN_GAP_MS = 2_000;
const MAX_ROUNDS = 5;
const PATIENCE = 3;

export type Side = "buy" | "sell";
export type LlmReply = { line: string; mood: string; unitPrice: number; accept: boolean; source?: "llm" | "replay" };
export type HaggleContext = {
  merchant: string;
  persona: string;
  item: string;
  itemName: string;
  tier: Tier;
  side: Side;
  qty: number;
  stock: number;
  target: number;
  purse: number;
  room: [number, number];
  currentCounter: number;
  offer: Offer;
  patience: number;
  history: { role: string; text: string }[];
  /** This merchant's last lines to this player (any session), so the reply can avoid repeating them. */
  recentLines: string[];
  message: string;
};
export interface LlmLike {
  reply(ctx: HaggleContext): Promise<LlmReply>;
}
export type Counter = { side: Side; item: string; itemName: string; qty: number; unitPrice: number; total: number; dealId: string; expiresAt: number };
export type HaggleReply = {
  line: string;
  mood: string;
  patience: number;
  reasoning: string;
  source: "llm" | "fallback" | "replay";
  counter?: Counter;
  refused?: { until: number };
};
export type AcceptResult =
  | { status: "settled"; balances: Balances; txHash: string }
  | { status: "requoted"; counter: Counter; line: string }
  | { status: "failed"; reason: string };

type DealRow = {
  id: string;
  session_id: string;
  merchant: string;
  player_id: string;
  good: string; // item id
  side: Side;
  qty: number;
  unit_price: number;
  nonce: number;
  expires_at: number;
  status: string;
};

export interface EngineDeps {
  db: Db;
  chain: Chain;
  queue: Queue;
  market: MarketCache;
  players: Players;
  contractId: string;
  merchantKeys: Record<string, string>;
  dayLengthMs: number;
  llm?: LlmLike;
  now?: () => number;
  /** Player class (fisher/logger/miner) for the specialist sell room. */
  classOf?: (playerId: string) => string | null;
}

export class HaggleEngine {
  private d: EngineDeps;
  private now: () => number;
  private lastMsg = new Map<string, number>();

  constructor(d: EngineDeps) {
    this.d = d;
    this.now = d.now ?? Date.now;
  }

  async haggle(playerId: string, merchant: string, message: string): Promise<HaggleReply> {
    const text = message.replace(/[\u0000-\u001f\u007f]/g, " ").trim();
    if (!text || text.length > 200) throw new HttpError(400, "bad_message", "Say something (1-200 characters).");
    const category = MERCHANTS[merchant];
    if (!category) throw new HttpError(400, "bad_merchant", "No such merchant.");
    const offer = parseOffer(text);
    const asked = offer.item ? itemById(offer.item)! : undefined;
    if (asked && asked.category !== category) {
      throw new HttpError(400, "wrong_merchant", `I don't trade ${asked.name}. Try the ${WHO[asked.category]}.`);
    }
    const t = this.now();
    if (t - (this.lastMsg.get(playerId) ?? -Infinity) < MIN_GAP_MS) throw new HttpError(429, "slow_down", "One message every 2 seconds.");
    this.lastMsg.set(playerId, t);

    const persona = PERSONAS[merchant];
    let session = this.session(playerId, merchant);
    // All rounds used and the last quote lapsed: that haggle is over, so this message opens a new one.
    // Without this a player would be stuck on "settle or part ways" with this merchant for good.
    if (session.rounds >= MAX_ROUNDS && !this.lastCounter(session.id)) {
      this.closeSession(session.id);
      session = this.session(playerId, merchant);
    }
    // Side, quantity and item: from this message, else the deal being haggled in this session (follow-ups such as
    // "Make it 15 each" name none of them), else buy x1 / (selling) the rarest item held / the common item.
    const last = this.lastDeal(session.id);
    const side: Side = offer.side ?? last?.side ?? "buy";
    const qty = Math.min(Math.max(offer.qty ?? last?.qty ?? 1, 1), 10);
    const itemId = asked?.id ?? last?.good ?? (side === "sell" ? await this.rarestHeld(playerId, category) : itemOf(category, "common").id);
    const item = itemById(itemId)!;
    const view = this.view(merchant, itemId);
    let patience = this.patience(playerId, merchant, view.day);
    const room = this.room(view, side, qty, playerId);
    const reasoning = reasoningLine(view, side, room);

    const recent = this.recentLines(playerId, merchant);
    if (patience <= 0) {
      const line = pickLine(persona.refuse, recent);
      this.chat(session.id, text, line, "annoyed", "fallback", reasoning);
      return { line, mood: "annoyed", patience: 0, reasoning, source: "fallback", refused: { until: this.nextDay(view) } };
    }
    if (!room) {
      const line = pickLine(persona.broke, recent);
      this.chat(session.id, text, line, "neutral", "fallback", reasoning);
      return { line, mood: "neutral", patience, reasoning, source: "fallback" };
    }
    if (session.rounds >= MAX_ROUNDS) {
      const line = pickLine(persona.wrapUp, recent);
      this.chat(session.id, text, line, "neutral", "fallback", reasoning);
      return { line, mood: "neutral", patience, reasoning, source: "fallback", counter: this.lastCounter(session.id) };
    }

    const offerUnit = offer.unitPrice ?? (offer.total !== undefined ? Math.floor(offer.total / qty) : undefined);
    const lowball = offerUnit !== undefined && (side === "buy" ? offerUnit < 0.8 * room[0] : offerUnit > 1.2 * room[1]);
    if (lowball) patience = this.losePatience(playerId, merchant, view.day);
    // An offer better for the merchant than its room (pay above ask, sell under bid) is taken as is: the player's call.
    if (offerUnit !== undefined && (offerUnit < room[0] || offerUnit > room[1]) && priceOk(side === "buy", offerUnit, room)) {
      const line = pickLine(persona.accept, recent);
      this.chat(session.id, text, line, "pleased", "fallback", reasoning);
      this.d.db.prepare("UPDATE haggle_session SET rounds = rounds + 1 WHERE id = ?").run(session.id);
      const counter = this.quote(session.id, playerId, merchant, item.id, side, qty, offerUnit);
      return { line, mood: "pleased", patience, reasoning, source: "fallback", counter };
    }
    const prev = this.lastQuoted(session.id, side);
    const current = prev ? clamp(prev, room) : side === "buy" ? room[1] : room[0];

    let reply: Omit<LlmReply, "source"> & { source: "llm" | "fallback" | "replay" };
    try {
      if (!this.d.llm) throw new Error("no llm");
      const r = await this.d.llm.reply({
        merchant,
        persona: persona.style,
        item: item.id,
        itemName: item.name,
        tier: item.tier,
        side,
        qty,
        stock: view.stock,
        target: view.target,
        purse: view.purse,
        room,
        currentCounter: current,
        offer,
        patience,
        history: this.history(session.id),
        recentLines: recent,
        message: text,
      });
      reply = { ...r, source: r.source ?? "llm" };
    } catch {
      reply = { ...fallbackReply({ merchant, room, current, offerUnit, lowball }, recent), source: "fallback" };
    }

    const wanted = Number.isFinite(reply.unitPrice) ? Math.round(reply.unitPrice) : undefined;
    let price = wanted !== undefined ? clamp(wanted, room) : current;
    const guarded = wanted !== undefined && price !== wanted;
    if (reply.accept && offerUnit !== undefined && offerUnit >= room[0] && offerUnit <= room[1]) price = offerUnit;
    if (guarded) {
      this.d.db
        .prepare("INSERT INTO guard_event (merchant, item, side, wanted, lo, hi, sent, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)")
        .run(merchant, item.id, side, wanted, room[0], room[1], price, this.now());
    }

    this.chat(session.id, text, reply.line, reply.mood, reply.source, reasoning);
    this.d.db.prepare("UPDATE haggle_session SET rounds = rounds + 1 WHERE id = ?").run(session.id);
    const counter = this.quote(session.id, playerId, merchant, item.id, side, qty, price);
    return { line: reply.line, mood: reply.mood, patience, reasoning, source: reply.source, counter };
  }

  async accept(playerId: string, dealId: string): Promise<AcceptResult> {
    const row = this.d.db.prepare("SELECT * FROM deal WHERE id = ?").get(dealId) as DealRow | undefined;
    if (!row) throw new HttpError(404, "no_deal", "That offer does not exist.");
    if (row.player_id !== playerId) throw new HttpError(403, "not_your_deal", "That offer was made to someone else.");
    if (row.status !== "quoted") throw new HttpError(409, "deal_closed", "That offer is already closed.");
    if (this.now() > row.expires_at) return this.requote(row, "expired");

    const deal: ChainDeal = {
      merchant: this.account(row.merchant),
      player: row.player_id,
      good: row.good,
      qty: row.qty,
      unit_price: String(row.unit_price),
      side: row.side,
      nonce: String(row.nonce),
      expires_at_ns: (BigInt(row.expires_at) * 1_000_000n).toString(),
    };
    const merchant_sig = signDeal(deal, this.d.merchantKeys[row.merchant]);
    this.setStatus(row.id, "settling");
    try {
      const { txHash } = await this.d.queue(() => this.d.chain.call("settle_deal", { deal, merchant_sig }));
      this.d.db.prepare("UPDATE deal SET status = 'settled', tx_hash = ? WHERE id = ?").run(txHash, row.id);
      this.closeSession(row.session_id); // a deal ends the haggle; the next message starts with fresh rounds
      await this.d.market.refresh().catch(() => undefined);
      return { status: "settled", balances: await this.d.players.balances(playerId), txHash };
    } catch (e) {
      const code = e instanceof ChainError ? e.code : "network";
      if (code === "PriceOutOfRoom" || code === "Expired") {
        await this.d.market.refresh().catch(() => undefined);
        return this.requote(row, code);
      }
      this.d.db.prepare("UPDATE deal SET status = 'failed', error = ? WHERE id = ?").run(code, row.id);
      return { status: "failed", reason: code };
    }
  }

  private requote(row: DealRow, reason: string): AcceptResult {
    this.d.db.prepare("UPDATE deal SET status = 'requoted', error = ? WHERE id = ?").run(reason, row.id);
    const room = this.room(this.view(row.merchant, row.good), row.side, row.qty, row.player_id);
    if (!room) return { status: "failed", reason: "MerchantPurseEmpty" };
    const price = clamp(row.unit_price, room);
    const counter = this.quote(row.session_id, row.player_id, row.merchant, row.good, row.side, row.qty, price);
    return { status: "requoted", counter, line: `Prices just moved. New price ${price} C.` };
  }

  private quote(sessionId: string, playerId: string, merchant: string, good: string, side: Side, qty: number, price: number): Counter {
    const id = randomUUID();
    const expiresAt = this.now() + QUOTE_TTL_MS;
    this.d.db
      .prepare(
        "INSERT INTO deal (id, session_id, merchant, player_id, good, side, qty, unit_price, nonce, expires_at, status, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'quoted', ?)",
      )
      .run(id, sessionId, merchant, playerId, good, side, qty, price, newNonce(), expiresAt, this.now());
    return counterOf({ side, good, qty, unit_price: price, id, expires_at: expiresAt });
  }

  private room(v: MarketView, side: Side, qty: number, playerId: string): [number, number] | null {
    if (side === "buy") return buyRoom(v.item, v.stock);
    const cls = this.d.classOf?.(playerId) ?? null;
    return sellRoom(v.item, v.stock, v.purse, qty, cls !== null && CLASS_CATEGORY[cls] === v.category);
  }

  private account(merchant: string) {
    return `${merchant}.${this.d.contractId}`;
  }

  private view(merchant: string, item: string): MarketView {
    const v = this.d.market.byItem(item);
    if (!v || v.merchant !== this.account(merchant)) throw new HttpError(503, "market_unavailable", "The market is closed right now.");
    return v;
  }

  private lastDeal(sessionId: string): { good: string; side: Side; qty: number } | undefined {
    const r = this.d.db
      .prepare("SELECT good, side, qty FROM deal WHERE session_id = ? ORDER BY created_at DESC, rowid DESC LIMIT 1")
      .get(sessionId) as { good: string; side: Side; qty: number } | undefined;
    return r && itemById(r.good) ? r : undefined;
  }

  private async rarestHeld(playerId: string, category: string): Promise<string> {
    const b = await this.d.players.balances(playerId);
    const held = ITEMS.filter((i) => i.category === category && (b[i.id] ?? 0) > 0).sort((a, z) => z.base - a.base)[0];
    return (held ?? ITEMS.find((i) => i.category === category)!).id;
  }

  private nextDay(v: MarketView): number {
    const last = Number(BigInt(v.last_tick_ns || "0") / 1_000_000n);
    return Math.max(last + this.d.dayLengthMs, this.now() + 1_000);
  }

  private patience(playerId: string, merchant: string, day: number): number {
    const r = this.d.db.prepare("SELECT points FROM patience WHERE player_id = ? AND merchant = ? AND day = ?").get(playerId, merchant, day) as
      | { points: number }
      | undefined;
    return r?.points ?? PATIENCE;
  }

  private losePatience(playerId: string, merchant: string, day: number): number {
    const left = Math.max(this.patience(playerId, merchant, day) - 1, 0);
    this.d.db
      .prepare("INSERT INTO patience (player_id, merchant, day, points) VALUES (?, ?, ?, ?) ON CONFLICT DO UPDATE SET points = excluded.points")
      .run(playerId, merchant, day, left);
    return left;
  }

  private session(playerId: string, merchant: string): { id: string; rounds: number } {
    const s = this.d.db
      .prepare("SELECT id, rounds FROM haggle_session WHERE player_id = ? AND merchant = ? AND closed_at IS NULL ORDER BY opened_at DESC LIMIT 1")
      .get(playerId, merchant) as { id: string; rounds: number } | undefined;
    if (s) return s;
    const id = randomUUID();
    this.d.db.prepare("INSERT INTO haggle_session (id, player_id, merchant, opened_at) VALUES (?, ?, ?, ?)").run(id, playerId, merchant, this.now());
    return { id, rounds: 0 };
  }

  private closeSession(sessionId: string) {
    this.d.db.prepare("UPDATE haggle_session SET closed_at = ? WHERE id = ? AND closed_at IS NULL").run(this.now(), sessionId);
  }

  private lastQuoted(sessionId: string, side: Side): number | undefined {
    const r = this.d.db
      .prepare("SELECT unit_price FROM deal WHERE session_id = ? AND side = ? ORDER BY created_at DESC, rowid DESC LIMIT 1")
      .get(sessionId, side) as { unit_price: number } | undefined;
    return r?.unit_price;
  }

  private lastCounter(sessionId: string): Counter | undefined {
    const r = this.d.db
      .prepare("SELECT * FROM deal WHERE session_id = ? AND status = 'quoted' AND expires_at > ? ORDER BY created_at DESC, rowid DESC LIMIT 1")
      .get(sessionId, this.now()) as DealRow | undefined;
    return r ? counterOf(r) : undefined;
  }

  /** The merchant's last `n` lines to this player across sessions, oldest first. */
  private recentLines(playerId: string, merchant: string, n = 3): string[] {
    const rows = this.d.db
      .prepare(
        "SELECT t.text FROM chat_turn t JOIN haggle_session s ON s.id = t.session_id WHERE s.player_id = ? AND s.merchant = ? AND t.role = 'merchant' ORDER BY t.id DESC LIMIT ?",
      )
      .all(playerId, merchant, n) as { text: string }[];
    return rows.map((r) => r.text).reverse();
  }

  private history(sessionId: string) {
    const rows = this.d.db
      .prepare("SELECT role, text FROM chat_turn WHERE session_id = ? ORDER BY id DESC LIMIT 6")
      .all(sessionId) as { role: string; text: string }[];
    return rows.reverse();
  }

  private chat(sessionId: string, playerText: string, line: string, mood: string, source: string, reasoning: string) {
    const ins = this.d.db.prepare(
      "INSERT INTO chat_turn (session_id, role, text, mood, source, reasoning, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)",
    );
    ins.run(sessionId, "player", playerText, null, null, null, this.now());
    ins.run(sessionId, "merchant", line, mood, source, reasoning, this.now());
  }

  private setStatus(id: string, status: string) {
    this.d.db.prepare("UPDATE deal SET status = ? WHERE id = ?").run(status, id);
  }
}

function counterOf(r: { side: Side; good: string; qty: number; unit_price: number; id: string; expires_at: number }): Counter {
  const name = itemById(r.good)?.name ?? r.good;
  return { side: r.side, item: r.good, itemName: name, qty: r.qty, unitPrice: r.unit_price, total: r.unit_price * r.qty, dealId: r.id, expiresAt: r.expires_at };
}

function clamp(x: number, [lo, hi]: [number, number]) {
  return Math.min(Math.max(x, lo), hi);
}
