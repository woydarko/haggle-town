# Asset credits

Every model in `roblox/assets/` comes from the Roblox Creator Store (free). Scripts are stripped on insert
(see the v3 plan, "Tool usage"). One row per asset.

| Name in `ServerStorage.Assets` | Creator Store id | Creator | License | Used in |
| --- | --- | --- | --- | --- |

Pipeline: Studio MCP `insert_asset` into `ServerStorage.Assets._Staging` (gitignored) -> strip scripts, anchor,
scale, rename, move to `Assets/<Category>` -> save place -> `rojo syncback roblox/assets.project.json --input
roblox/build-local.rbxl --non-interactive` -> review `git diff --stat roblox/assets`.
