# Haggle Town - Roblox place

All game code lives here and is synced into Roblox Studio with [Rojo](https://rojo.space) 7.7. The town (ground, stalls, merchants, gather spots, boards) is built by `src/server/World.luau` at runtime, so there is no binary place file to keep in sync.

## Live sync (recommended)

1. Once: `rojo plugin install` (adds the Rojo plugin to Studio) and `bash scripts/roblox-local.sh` (writes the gitignored `roblox/local.project.json` with the server config).
2. `rojo serve roblox/local.project.json` and keep it running.
3. Open `roblox/build-local.rbxl` in Studio once, Plugins tab > **Rojo** > **Connect** (localhost:34872).
4. From then on every code change appears in Studio immediately. Stop and press Play again to run the new code.

## Run in Studio (manual)

1. Start the backend (see the root README) and note its URL, e.g. `http://localhost:8080` for Studio Play or the Railway URL.
2. `rojo serve roblox/default.project.json`, open Studio, connect with the Rojo plugin.
3. Game Settings > Security > **Allow HTTP Requests**: on.
4. In **ServerStorage** create a Folder `Config` with two StringValues (server-only, never replicated to players):
   - `BackendUrl` = the backend URL
   - `HmacSecret` = the same value as `RBX_HMAC_SECRET` in the backend `.env`
   Do not put these in ReplicatedStorage or commit them.
5. Press Play. You spawn in the lobby with 1000 C: pick a class from a mentor, walk through the gate to Wood / Fish / Ore and play the gather minigame, then to a merchant and press **Haggle**.

Why a StringValue and not Roblox Secrets: Secrets are opaque values that can only be placed into HTTP headers, so the server cannot compute the HMAC over the request body with them.

## Layout

| Path | Runs on | Purpose |
| --- | --- | --- |
| `src/server/Main.server.luau` | server | builds town, validates every RemoteEvent, calls backend, filters merchant lines, polls state |
| `src/server/Backend.luau` | server | HMAC-signed HTTP to the backend |
| `src/server/Hmac.luau` | server | pure-Luau SHA-256 / HMAC |
| `src/server/World.luau` | server | greybox town |
| `src/shared/Validate.luau` | both | pure input checks |
| `src/shared/Theme.luau` | both | design tokens |
| `src/client/*` | client | HUD and haggle panel |

## Tests

```bash
lute run roblox/tests/Hmac.spec.luau
lute run roblox/tests/Validate.spec.luau
lute run roblox/tests/Minigame.spec.luau
lute run roblox/tests/Items.spec.luau
```

`Hmac.spec` uses the same fixed vector as `server/test/hmac.test.ts`, so both sides sign identically.

Inside Roblox, user-facing text never mentions crypto, blockchain, NFT, token, wallet, NEAR, gas or transaction. Players only see Coin.
