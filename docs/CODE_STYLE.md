# Code Style

## Languages and conventions
- Language/version: Rust stable 1.97 (contract, economy, sim; contract target wasm32 via cargo-near), TypeScript on Node 24 (server), TypeScript + React 18 (web), Luau (Roblox, Rojo 7.7.1).
- Naming:
  - Rust: `snake_case` functions/modules, `PascalCase` types, `SCREAMING_SNAKE` constants; error enum variants named as in ARCHITECTURE.md (`PriceOutOfRoom`, ...).
  - TypeScript: `camelCase` functions/variables, `PascalCase` types and React components, files `kebab-case.ts` (components `PascalCase.tsx`).
  - Luau: `PascalCase` ModuleScripts and services, `camelCase` locals; server scripts end with `.server.luau`, client with `.client.luau` (Rojo conventions).
  - SQLite: `snake_case` tables and columns.
  - Token ids and goods: lowercase strings `coin`, `wood`, `fish`, `iron` everywhere.
- Formatting/linting: rustfmt + clippy (Rust); Prettier + ESLint or tsc only for TS (decided at scaffold; record the real config here); StyLua + selene for Luau if installed (otherwise none).
- Type safety: Rust no `unwrap()` in contract code paths reachable by callers (use `require!`/named panics); TS `strict: true`, no `any` at trust boundaries; Luau `--!strict` in shared modules.

## Organization
- Directory responsibilities: as in ARCHITECTURE.md "Project structure".
- Shared logic: pricing rules only in `economy/src/pricing.rs`; the server's TS port lives in `server/src/haggle/pricing.ts` and is tested against `economy/test-vectors.json`. Roblox UI theme in `roblox/src/shared/Theme.luau`; web tokens in `web/src/theme.css`.
- Business logic placement: value rules in the contract (+ pricing.rs); orchestration in `server/src/haggle`; chain I/O only in `server/src/chain`; LLM I/O only in `server/src/llm`; Roblox server Scripts only validate and forward; Roblox client only renders.
- Import boundaries: `economy` has no NEAR deps; `web` never imports from `server` (talks over HTTP); Roblox client never requires server modules.

## Coding rules
- Keep functions focused; follow established repository patterns.
- Validate external inputs at the trust boundary (Fastify schemas, Roblox server checks, contract `require!`).
- Handle loading, empty, error, and success states explicitly (DESIGN_SYSTEM.md screen states).
- Avoid silent failures and undocumented magic values (constants named in `pricing.rs` / config).
- Reuse existing components before introducing new abstractions.
- Integer Coin math only (u128 on chain, number <= 2^53 in TS); round down for the player when converting.
- Never put chain words in Roblox-facing strings.

## Errors and logging
- Error shape: HTTP `{error: code, message}`; contract named panics; Roblox shows the DESIGN_SYSTEM copy for each code.
- Logging: Fastify/pino JSON, levels info (requests, settles), warn (re-quotes, LLM fallback), error (chain failures); redact keys, HMAC, `LLM_API_KEY`, headers.

## Dependencies
- New packages: only those named in ARCHITECTURE.md; anything else needs a one-line reason in the PR/commit and the user's OK if it is large.
- Versioning/lockfile practice: commit `Cargo.lock` and `package-lock.json`; pin exact versions for near-sdk and near-api-js.

## Review checklist
- Implementation matches the approved feature acceptance criteria.
- Types, format, and lint checks use confirmed repository commands.
- No credentials or unrelated files in the diff.
- Tests cover meaningful changed behavior.
- No chain words in Roblox strings; tokens only for colors.

## Verified commands
- Web build + typecheck: `cd web && npm run build` (tsc --noEmit + vite build)
- Format: Not configured
- Lint: Not configured
- Type check: `cd server && npm run typecheck` (tsc 7, strict, noEmit)
Never invent commands or claim checks passed without running them.
