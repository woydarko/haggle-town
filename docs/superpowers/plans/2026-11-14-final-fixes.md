# Haggle Town - final fixes + submission (2026-11-14)

Status: draft, awaiting user approval. Clock: start 18:00 +0700, internal submit 2026-11-15 06:29 +0700 (~12.5 h).
Rule: feature freeze. Only the items below. No new visuals, map, animation or asset work.

## Weak points -> fix

| # | Weak point | Fix | Cost | Keep? |
| --- | --- | --- | --- | --- |
| W1 | Looks like the official market-town template | Make the guardrail visible and provable: log every LLM price the backend had to clamp, show it on the dashboard, and record one on-chain `PriceOutOfRoom` rejection | ~1.5 h | Must |
| W2 | Agents track thin (agents decide nothing economic, all keys on one backend) | Reframe, no new mechanic: "bounded-autonomy agents" - each merchant holds its own key and signs its own deals, negotiates freely, and the contract is the constitution it cannot break (W1 is the proof). State custody honestly in README with the production path (TEE / chain signatures) | ~0.5 h (in README) | Must |
| W3 | Haggle has no downside (selling at 10c still pays bid) | Merchant takes a better-than-room offer at the player's price; contract checks only the side that protects the merchant | ~1.5 h + contract redeploy on prod chain | Proposed cut: low judge impact, risky redeploy on the last day |
| W4 | Scope creep, submission missing | Freeze + Tasks 3-6 below | - | Must |

## Tasks

### 1. Guardrail log (W1, server + web) - 18:00-19:15
- `server/src/haggle/engine.ts` `haggle()`: when `reply.unitPrice` is outside `room`, record `{at, merchant, item, side, wanted, room, sent}`. In-memory ring of last 50 + total count (`shortcut: lost on restart, fine for demo`).
- Expose on the existing market API response (`guard: {count, recent}`); no new route if the market payload can carry it.
- `web/src/App.tsx`: small "Guardrail" panel: "AI wanted 1c, rules allow 540-720, sent 540" + count.
- Test: `server/test/engine.test.ts` - fake LLM returns price outside room -> guard count 1, quoted price clamped.

### 2. On-chain proof (W1) - 19:15-19:45
- `scripts/guardrail-proof.ts`: build a correctly signed merchant deal with an out-of-room price using existing `signDeal`, call `settle_deal` on `haggletown-v2.testnet`, expect `PriceOutOfRoom`.
- Put the failed tx link in `docs/hackathon/DEPLOYMENTS.md` ("Reference transactions") and the README. Demo money shot: "even with a valid merchant signature, the chain refuses."

### 3. README + LICENSE (W2, screening) - 19:45-21:00
- `README.md`: pitch (3 lines), how to play (Roblox link + dashboard link), architecture (one diagram), why it matters = guardrail + invisible chain, run locally in <5 commands, verified test commands (run them for real: `cargo test`, server tests, web build), contract + explorer links, custody note, AI tools + libraries disclosure, 2-projects disclosure if relevant.
- `LICENSE` (MIT unless user picks another).
- Update `docs/hackathon/STATE.md` phase cursor -> 5/6.

### 4. Deploy + publish (user OK needed) - 21:00-22:00
- Railway redeploy with Task 1. Prod smoke: haggle -> accept -> settled tx.
- Roblox publish public (user approval). Check no banned words in client strings.

### 5. Demo video (user records, agent writes script) - 22:00-00:30
- 2 min. 0:00 hook "AI merchants with real wallets that you can't sweet-talk into ruin". 0:10 gather. 0:30 haggle in chat. 0:50 accept -> dashboard tx. 1:10 prompt-injection attempt in chat -> merchant holds price, Guardrail panel ticks. 1:25 forged deal rejected on explorer. 1:40 fast-forward week, prices move. 1:55 close.

### 6. X post + form (user submits) - 00:30-01:30
- Agent drafts post text and "What did you build?" (<= 2000 chars). User posts with @NEARProtocol #NEARHackathon + video, submits form with repo link + mainnet payout account.
- Buffer 01:30-06:29.

## Open decisions (user)
1. W3: cut (proposed) or do it (~1.5 h + contract redeploy)?
2. License: MIT?
3. Mainnet payout account name.
4. OK to publish Roblox experience at Task 4.
