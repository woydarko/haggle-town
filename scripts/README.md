# Scripts

Testnet only.

```bash
CONTRACT_ID=haggletown.testnet bash scripts/deploy.sh   # create accounts via faucet (idempotent), build, deploy + init
CONTRACT_ID=haggletown.testnet bash scripts/seed.sh     # register 3 merchants, write keys to .env
```

- Needs near-cli-rs 0.31+ and Rust with the `wasm32-unknown-unknown` target.
- Keys are stored by near-cli-rs in `~/.near-credentials/testnet/` (legacy keychain) and copied into `.env` (gitignored). They are never printed.
- The wasm is built with plain `cargo build --target wasm32-unknown-unknown --release` (NEAR testnet accepted it on 2026-11-10). `cargo near build` works too where cargo-near is installed.
- To use a different account name, set `CONTRACT_ID` for both scripts.

Check the market:

```bash
near contract call-function as-read-only haggletown.testnet get_market json-args '{}' network-config testnet now
```
