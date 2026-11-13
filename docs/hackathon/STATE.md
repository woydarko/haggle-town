# Hackathon State

Single source of truth for `/hackaton`. Update at every phase change and checkpoint. Read this first when resuming a session.

## Event
- Name: NEAR HACKATHON (online) - https://nearhackathon.com/
- Lead (sole editor of this file in team mode): nabil (solo - assumed, confirm)
- Tracks / prizes targeted: `games` (Games With Real Economies: 1st $10K / 2nd $3K / 3rd $2K, grand prize $55K eligible) + `agents` (Agent Economy)
- Deadline: 2026-11-14 23:59 UTC = 2026-11-15 06:59 +0700
- Internal submit target: 2026-11-15 06:29 +0700
- Submission format: form https://nearhackathon.com/#apply (or POST /api/applications): public repo link + X demo post (tag @NEARProtocol #NEARHackathon, demo video attached) + "What did you build?" 20-2000 chars + mainnet NEAR payout wallet. Edits only via /request-changes.

## Judging criteria
| Criterion | Weight (if known) | Feature / evidence that covers it |
| --- | --- | --- |
| Game loop (track: "judged on the game loop, not the token") | Primary | TBD after idea lock |
| Chain invisible to players (track bonus) | Bonus | Relayer + Roblox UserId -> sub-account, meta-tx |
| Technical implementation | Unknown (past NEAR criteria) | Contract + tests, relayer, Roblox client |
| Design | Unknown | Roblox UX + web dashboard |
| Impact | Unknown | PITCH.md |
| Originality | Unknown | NPC agents with wallets, economy evolves without patch |
| Sustainability | Unknown | PITCH.md business model |
| AI pre-screen (Claude Code / Codex): reproducibility, feature verification | Screening only | README run in <5 commands, headless tests + web fallback |

## Hackathon rules (binding points from the official rules page)
- Rules page: https://nearhackathon.com/HACKATHON.md
- Code origin: code written since 2026-10-19 counts; earlier commits are baseline (Q-001)
- AI tools / models allowed and disclosure required: allowed; libraries and AI-generated code must be listed in README (Q-005)
- Team size, tracks per project, eligibility: solo or team; max 2 projects per person (disclose in README); multiple tracks per submission allowed
- License / open-source requirement, IP ownership: any license, add LICENSE (Q-014); team keeps rights, organizers get non-exclusive promo rights (Q-013)
- Required or forbidden APIs / SDKs: no mandatory integrations; own NEAR contract fitting track is enough (Q-011). Testnet OK (Q-010). NEAR Intents has no testnet (Q-007)
- Submission language and limits: repo public by deadline; one submission per repo; local-only demo OK if README reproducible (Q-012); hosted demo is a plus, keep up until 2026-11-18 (ideally 11-25)
- Platform risk (Roblox): Community Standards bar real-money / Robux exchange and target NFTs -> user decided 2026-11-10: **publish publicly**, with no chain wording inside Roblox (only "Coin"), testnet only, Coin never exchangeable; chain shown only on web dashboard

## Environment readiness
- check-env.sh run at: 2026-11-10 19:26 +0700 - missing then: near CLI, rojo, cloudflared. Now: near-cli-rs 0.31.1 OK (install via PowerShell; Git Bash tar breaks npm install), Rojo 7.7.1 OK, cloudflared installed via winget (on PATH after new shell)
- Rust: wasm32 target added; host toolchain override stable-x86_64-pc-windows-gnu (no MSVC Build Tools). cargo-near: source build failed (OpenSSL needs perl); prebuilt installer pending user OK
- Server deps: fastify 5.12.8, @fastify/rate-limit, @fastify/static 10.1.10, near-api-js 7.4.0, typescript 7.0.2, @types/node 26.6.6
- Roblox Studio: installed (detected in %LOCALAPPDATA%\Roblox\Versions)
- Accounts, keys (names only), hosting, repo access: Open - NEAR testnet account, NEAR mainnet payout account, NEAR AI Cloud key (`NEAR_AI_API_KEY`), Railway (backend), Vercel (web), GitHub repo
- Web3: faucet funds requested at [pending - after near CLI install], balances in DEPLOYMENTS.md: Open
- AI: provider ai.sumopod.com OpenAI-compatible gateway, model deepseek-v4.1-flash-1017 (~0.5-0.9 s; LLM_TIMEOUT_MS 6000, LLM_THINKING on; glm-5.3-flash took 6-11 s), key from user, set in .env + Railway 2026-11-14 (kenari.id minimax-m2-7-highspeed returned 503 all_providers_failed on 2026-11-13). NEAR AI Cloud not used (sign-in failed); switchable via env.

## Phase cursor and clock
Current phase: 4 build v2 (plan docs/superpowers/plans/2026-11-11-haggle-town-v2.md, ledger .superpowers/sdd/2026-11-11-haggle-town-v2/progress.md)
Last updated: 2026-11-10 20:14 +0700 (design + docs approved by user)

| Phase | Status | Budget | Planned start -> end | Actual end | Notes |
| --- | --- | --- | --- | --- | --- |
| 1 Intake | Done | 1h | 11-10 19:26 -> 11-10 20:30 | 11-10 19:35 | Rumor Mill locked |
| 2 Design + docs | Done | 10h | 11-10 20:30 -> 11-11 06:30 | 11-10 20:14 | started early 19:35; spec + 8 docs + DEPLOYMENTS drafted 20:10 |
| 3 Plan | Done | 5h | 11-11 06:30 -> 11-11 11:30 | | |
| 4 Build | In progress | 54h | 11-11 11:30 -> 11-13 17:30 | | |
| 5 Verify + audit | Not started | 16h | 11-13 17:30 -> 11-14 09:30 | | |
| 6 Demo and submit | Not started | 21h | 11-14 09:30 -> 11-15 06:29 | | |

All times +0700. Split: web3 mode 15/50/15/20 of ~107h.

Over-budget warnings sent: none

## Idea filter result
- Chosen idea: **Haggle Town** (user, 2026-11-10 ~19:55 +0700; pivot from Rumor Mill, which the user found too complex). History: Rumor Mill picked 19:35, rejected for complexity; Hungry Hollow and Hostile Takeover rejected earlier.
- One-sentence pitch: In-game economies feel dead because NPC prices are static tables devs must patch -> Haggle Town makes merchants AI agents with their own NEAR wallets whose prices follow supply and demand and who haggle with players in plain chat, inside on-chain limits -> for Roblox players (fun) and game devs who want living economies.
- Measurable impact claim (estimate): 0 dev patches over a simulated week while every good's price changes on >= 3 of 7 days; 0 deals outside the pricing room (contract-enforced).
- Existing APIs/tools combined: Roblox (HttpService, public experience), NEAR (NEP-245 contract, merchant sub-accounts, ed25519 deal signatures), NEAR AI Cloud (merchant replies).
- Visible output for judges: public Roblox game link + web dashboard (prices, merchant purses, deal feed with explorer links, fast-forward week).
- Not a wrapper: LLM only writes the merchant's line and proposes a number; price room comes from pricing.rs and is enforced on-chain; merchant signs each deal.
- Hair on fire: devs hand-tune and patch economies; players exploit static NPC prices; web3 games show wallets and gas. Why now: cheap fast LLM inference + NEAR relayer pattern make per-NPC wallets invisible to players.
- Fits the clock: golden path = join -> gather -> haggle -> accept -> settles on testnet -> prices move. Yes.
- Passed filter: Yes

## Web3 (if applicable)
- Ecosystem / chain: NEAR
- Network: testnet
- Testnet deploys pre-approved: Yes (user, 2026-11-10) (mainnet always needs per-action approval)
- Sponsor protocols or bounty tracks: none required; hints AGENT NPCS, SOCIAL LOGIN, NEAR INTENTS, NEP-245
- Contract language: Rust (near-sdk-rs)
- Audit gate: x-ray Not run | solidity-auditor n/a (Rust) | fizz Not run | tests Not run
- Deployments file: docs/hackathon/DEPLOYMENTS.md

## Scope
- Product: **Haggle Town** (spec: docs/superpowers/specs/2026-11-10-haggle-town-design.md)
- Plan: docs/superpowers/plans/2026-11-10-haggle-town.md
- Ship now (core): Tasks 1-13 (economy, contract core, deals+tick, testnet deploy, server scaffold, chain module, haggle engine, LLM, Roblox place, Roblox polish, skeleton deploy, dashboard, sim/fast-forward)
- Walking skeleton (Tasks 1-7, 9, 11, fallback-only haggle) deployed by 2026-11-12 09:00 +0700
- Stretch (auto-cut if behind, in this order): 1. Task 15 web playable fallback, 2. Task 14 player stalls (P2P)
- v2 scope (user, 2026-11-11): spec docs/superpowers/specs/2026-11-11-haggle-town-v2-design.md - economy tiers + classes, gather minigames, lobby, mountain-lake map with cave. Build order: economy v2 -> minigames -> classes+lobby -> map -> sim/docs. Cut first: legendary visuals/double drop, second cave zone, chopping combo, free assets, per-item fast-forward. Roblox publish postponed by user until map is done.
- v3 scope (user, 2026-11-11 22:40): plan docs/superpowers/plans/2026-11-11-haggle-town-v3-world.md - real chop/mine/fish with animations + 30 s respawn, 2048-stud generated map, Creator Store remodel, SFX/VFX, UI kit + catch card. Cut first: ambience, exploration extras, river, rock physics chunks, custom animations (Motor6D fallback), map down to 1024. Checkpoint 2026-11-13 18:00 +0700. Deploy + publish (v2 Task 12, user OK) stays mandatory before deadline.
- Post-hackathon: real social/email login, player-owned NEAR accounts (claim), NPC-to-NPC trading, multisig/timelock for keys, NEAR Intents

## Hourly checkpoints (lead consolidates from `docs/hackathon/log/*.md`; solo: write here)
| Time | Time left | Core done / total | Cut decision |
| --- | --- | --- | --- |
| 2026-11-10 21:14 +0700 | ~98 h | 6 / 13 (economy, contract core, deals+tick, testnet deploy, server scaffold, chain module) | none; ahead of plan |
| 2026-11-10 21:55 +0700 | ~97 h | 12 / 13 (all but T11 deploy/publish); T8 eval + Studio golden path wait on user | none; stretch T14/T15 possible |
| 2026-11-10 23:45 +0700 | ~91 h | 13 / 13 core done (Railway live, Studio golden path passed, LLM live, restock + personas, town dressed) | stretch T14/T15 optional; next: Phase 5 verify + Roblox publish |
| 2026-11-11 01:26 +0700 | ~86 h | v2 plan 3 / 12 (economy v2, contract v2, deployed haggletown-v2.testnet) | none; production still v1 until v2 Task 12 |
| 2026-11-11 15:11 +0700 | ~64 h | v2 plan 5 / 12 (backend v2: items, gather sessions, classes, stats, haggle items; smoke on v2 testnet) | none; Roblox v2 (Tasks 6-9) next; production still v1 |
| 2026-11-12 (v3) | ~2.5 days | v3 plan 9 / 12 (map, nodes + respawn, real chop/mine/fish with animations, sfx/vfx, Creator Store trees/rocks/houses, catch card, custom prompts); user playtested chop/mine/fish OK | stretch T10/T11 pending user call; T12 perf + full playtest, final review, then v2 Task 12 deploy + publish (user OK) |
| 2026-11-13 (v3) | ~1.7 days | v3 plan 10 / 12 core done (T1-T9 + T12); stretch T10/T11 cut by user; golden path on testnet passes; haggle lock-out bug fixed (dd2e047); 10-min soak clean, 60 fps avg focused | next: final review, then v2 Task 12 deploy (Railway v2 + publish, user OK) |
| 2026-11-13 16:40 +0700 (v4) | ~38 h | v4 plan 9 / 9 (quarter-area village map, fonts, varied merchant lines + sentence chips, in-world Market Ledger from the web API, first-session guide, ForgeGUI coin icon; items keep tier tiles after ForgeGUI credits ran out; phone scaling + contrast fixes; antislop Delivery Gate PASS) | next: final whole-branch review, then v2 Task 12 deploy (Railway v2 + Roblox publish, user OK) |

## Unresolved
- Solo or team? (assumed solo) - owner: nabil
- LLM: DONE 2026-11-10 (minimax-m2-7-highspeed via kenari.id, eval 14/15)
- Railway: DONE 2026-11-10 (https://backend-production-fccb03fb.up.railway.app); redeployed 2026-11-13 on haggletown-v2.testnet (v2-v6 backend, prod smoke settled on chain). Still open: OK to publish Roblox experience - owner: nabil
- Roblox Studio golden path not run yet (needs user in Studio) - owner: nabil
- NEAR mainnet payout account name - owner: nabil
- Roblox HttpService blocks localhost? (unverified; plan uses cloudflared tunnel anyway) - owner: agent

## Track prompt notes (09-games.md, read 2026-11-10)
- Official template idea = market-town, NPC merchants with wallets, price from stock+demand, broke merchant closes until invested. Expect many clones -> we need a distinct twist.
- Asks: items NEP-245 (one contract), social/email login with no seed/popup/gas in loop, merchant pricing rules in one readable file, merchant reasoning in tooltip, fast-forward mode (1 week in ~1 min), design 30s / 5min / session loop on paper before code.
