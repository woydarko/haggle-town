# Haggle Town

A Roblox market town where you gather wood, fish and ore and **haggle in plain chat with AI merchants who run their own NEAR wallets**. Prices follow supply and demand by themselves. No developer patches the economy. Players never see a wallet, seed phrase, popup or gas fee. Inside the game everything is just "Coin".

NEAR HACKATHON tracks: **Games With Real Economies** (main), **Agent Economy** and **Memecoins With Mechanics**.

- Play: Roblox experience link _(added at publish)_
- Dashboard (on-chain side: prices, merchant purses, deals with explorer links, guardrail, fast-forward week): https://backend-production-fccb03fb.up.railway.app
- Contract: [`haggletown-v2.testnet`](https://testnet.nearblocks.io/address/haggletown-v2.testnet) (NEAR testnet, NEP-245 multi-token)

## Why it is different: AI agents you can't sweet-talk into ruin

Each merchant is an AI agent with its own NEAR account and its own signing key. It chats, bluffs and counters freely. But it cannot agree to a price outside the room that its stock and purse allow.

1. **The LLM writes the words and suggests a price.** The backend pulls any price outside the rules back into range and logs it. The dashboard "Guardrail" panel shows every time it happened.
2. **The merchant signs the deal** with its own ed25519 key.
3. **The contract checks the price again at settle time** with the same rules (`economy/src/pricing.rs`) and rejects anything outside them, even with a valid merchant signature. Proof on testnet: a deal the Woodcutter really signed, pine for 1 coin, refused with `PriceOutOfRoom`: [FLb7YA38…](https://testnet.nearblocks.io/txns/FLb7YA38r3r1ESFuHoapirMX5bFsbGteK8mTVfVgN2zN). Re-run it with `server/scripts/guardrail-proof.ts`.

The rules only protect the merchant. If you sell under its bid or pay over its ask, it gladly takes your price. That is your call, so haggling has a real downside.

## The game loop

- **30 s:** walk to a tree, rock or lake and play a short minigame (chop, mine, fish). Catches roll a tier: common, uncommon, rare, legendary.
- **5 min:** take your goods to the Woodcutter, Fishmonger or Smith. Type an offer in any words ("I'll give 40 for 5 iron"). The merchant counters in character. Lowball it three times and it stops talking to you until tomorrow. Accept, and the deal settles on chain in the background.
- **Tools:** you start with none. Picking a trade gives you its tool for free (Logger: Axe, Miner: Pickaxe, Fisher: Rod); any other tool costs 150 C, paid on chain to that trade's merchant (`buy_tool`), so new tools also refill merchant purses.
- **Forge (why you buy):** upgrade your Axe, Pickaxe or Rod from Worn to Sturdy to Master for a 25% / 50% chance of a second item per catch. Every recipe uses goods from the *other* two trades (axe = copper + sardine, pickaxe = pine + sardine, rod = pine + copper; Master needs iron, oak, trout). So a Logger buys from the Smith and the Fishmonger. The haggle panel's Buy tab marks exactly what your forge still needs. Forged goods are burned on chain (`use_items`), a real sink next to the merchants' daily restock and burn.
- **Session:** pick a class (Fisher, Logger, Miner) for a better sell room on your goods. Climb the richest-traders board. Each game day (5 minutes) merchants restock toward their target and use up stock. Prices drift, and a merchant with an empty purse closes for buying until players buy from it.

Pricing in one readable file: `economy/src/pricing.rs` (ask = base × target / stock, clamped to 0.5–3× base; bid = 80% of ask; up to 40% discount when overstocked, up to 40% premium when short). The contract, the simulator and the backend's TypeScript port (tested against 768 Rust vectors) all use it.

## The merchants as agents (Agent Economy)

What the three merchant agents do, mapped to the track's asks, and what they do not do yet:

| Ask | Haggle Town |
| --- | --- |
| An agent with its own wallet that earns and spends | Each merchant has its own NEAR account, holds Coin and stock in the market contract, buys from and sells to players, and signs every deal with its own ed25519 key; the contract checks that signature. |
| Negotiation: counter with reasoning, then accept or walk away | Players haggle in plain chat; the merchant counters in character with a reasoning line ("Why?"), accepts in-range offers, and stops talking after three lowballs that day. |
| Spending stays inside a policy | The price room from `pricing.rs` is the agent's policy: the backend pulls the LLM's prices back into it (Guardrail panel) and the contract refuses anything outside it, even when signed ([proof](https://testnet.nearblocks.io/txns/FLb7YA38r3r1ESFuHoapirMX5bFsbGteK8mTVfVgN2zN)). |
| A receipt for every task | Every deal is a settled transaction listed on the dashboard with the merchant's line and reasoning; every Forge burn and tool purchase too. |
| Hiring other agents, paying for APIs, NEAR Intents, USDC | **Not built.** Merchants trade only with players, the LLM bill is paid by the backend, and payments are in-game Coin. Next step: merchant-to-merchant restock deals signed by both agents, and paying the model per call from the merchant's own purse. |

Custody is covered under "How it works" below: one backend holds all three keys today.

## Backer coins: $WOOD, $FISH, $SMITH (Memecoins With Mechanics)

Every AI merchant has an NEP-141 memecoin whose supply follows that merchant's on-chain net worth (purse + stock at its own bid), rebased for every holder once per market day, capped at 5% a day (chosen with a 60-day simulation). Anyone can call `tick()`; the coin reads the market contract directly, so no backend can switch it off. Parameters are fixed at launch with no admin method. Back the house, or bet on the hagglers. Web dashboard only (tab "Backer coins"), never inside Roblox. Details, simulation table and sybil limits: [docs/hackathon/MEMECOIN.md](docs/hackathon/MEMECOIN.md).

## How it works

```
Roblox server ──HMAC──▶ Backend (Fastify, Railway) ──▶ NEAR testnet contract (Rust, NEP-245)
                          │  haggle engine + LLM           merchants' purses + stock, players' items
                          │  game relayer signs txs        settle_deal checks merchant signature + price rules
Web dashboard ◀── /api ───┘                                day_tick: restock + burn
```

- **Chain invisible:** players are contract-internal ids (`roblox:<UserId>`). A game relayer account pays gas and submits transactions. Inside Roblox there are no chain words at all.
- **Merchants:** `woodcutter|fishmonger|smith.haggletown-v2.testnet`. Each signs its own deals. The contract verifies the signature against the merchant's registered key.
- **LLM:** OpenAI-compatible endpoint (currently `deepseek-v4.1-flash` through a gateway, about 0.5–0.9 s). If it is slow or down, a deterministic merchant with the same personas takes over, so the game never stalls.

Custody, honestly: in this hackathon build all merchant keys live as environment variables on one backend, so the separation is per-key, not per-machine. Production path: each merchant agent signs inside its own TEE or through NEAR chain signatures, so no single server can sign for all of them. The contract-side rules stay as they are.

## Run it

Hosted demo above. To check the code locally (no keys needed):

```bash
cargo test -p economy -p haggle-contract          # pricing rules + contract (51 tests)
cd server && npm ci && npm test && npm run typecheck   # backend (139 tests)
cd web && npm ci && npm run build                  # dashboard
cargo run -p sim -- --days 7 --bots 10 --seed 42 --out web/public/sim/week.json   # fast-forward week
```

All four were run on 2026-11-14 and pass. Running the full backend needs NEAR testnet keys: `scripts/deploy.sh` and `scripts/seed.sh` create the accounts and fill `.env` from `.env.example`. Then run `cd server && npm start`. For the Roblox place: `bash scripts/roblox-local.sh` builds `roblox/build-local.rbxl` for Studio (needs Rojo).

## Repository map

| Path | What |
| --- | --- |
| `economy/` | Pricing, tiers, drop odds: the one rules file + test vectors |
| `contract/` | NEAR contract: NEP-245 tokens, merchants, `settle_deal`, `day_tick`, classes |
| `server/` | Backend: Roblox API (HMAC), haggle engine, LLM client, relayer queue, dashboard API |
| `web/` | Dashboard (React + Vite) |
| `roblox/` | Roblox place (Luau, Rojo) |
| `sim/` | Fast-forward simulator using the same pricing crate (`--compare` Forge, `--coins` 60-day memecoin scenarios) |
| `coin/` | Backer coin contract: NEP-141 memecoin that rebases on its merchant's on-chain worth |
| `docs/` | PRD, architecture, security, design spec and plans |

## AI tools and third-party code (disclosure)

- Code written with **Claude Code** (Anthropic) as a pair programmer. Design, plans and reviews are in `docs/superpowers/`.
- Merchant dialogue at runtime: an OpenAI-compatible LLM (`deepseek-v4.1-flash`). Evaluated with `server/eval/`.
- Coin icon generated with ForgeGUI. Trees, rocks and houses come from the Roblox Creator Store (see `roblox/ASSETS.md`).
- Libraries: near-sdk 5.30 (Rust), near-api-js 7, Fastify 5 (+ rate-limit, static), React 19, Vite 8, uPlot, TypeScript 7, ed25519-dalek (tests), Rojo.

## Roblox policy

Coin cannot be exchanged for Robux or money. Testnet only. No crypto wording inside the experience.

## License

MIT, see `LICENSE`.
