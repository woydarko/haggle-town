# Asset credits

Every model in `roblox/assets/` comes from the Roblox Creator Store (free). Scripts are stripped on insert
(see the v3 plan, "Tool usage"). One row per asset.

| Name in `ServerStorage.Assets` | Creator Store id | Creator | License | Used in |
| --- | --- | --- | --- | --- |
| Trees/Pine1-5 | 8559395722 (Low-Poly Pine Trees Asset Pack) | Cliosow | Free model (Creator Store) | Pine forest, starter copse (wood) |
| Trees/Oak1-4 | 5456451653 (temperate deciduous trees, first 4 trees) | FIorentius | Free model (Creator Store) | West woods (wood) |
| Trees/Maple1-2 | 17524061589 (Deciduous Tree, leaves tinted orange) | Poundland19 | Free model (Creator Store) | West woods, starter copse (wood) |
| Trees/Redwood1-2 | 5456451653 (temperate deciduous trees, two tallest) | FIorentius | Free model (Creator Store) | Ancient grove (wood_old) |
| Rocks/Rock1 | 78478095782349 (Rock Boulder Stone Low Poly Pack) | Leezcr1065 | Free model (Creator Store) | Mine foot + caverns (ore) |
| Rocks/Rock2-3 | 120851078616869 (Stylized Rock pack) | Frosw5825 | Free model (Creator Store) | Mine foot + caverns (ore) |

Pipeline: Studio MCP `insert_asset` into `ServerStorage.Assets._Staging` (gitignored) -> strip scripts, anchor,
scale, rename, move to `Assets/<Category>` -> save place -> `rojo syncback roblox/assets.project.json --input
roblox/build-local.rbxl --non-interactive` -> review `git diff --stat roblox/assets`.

Rejected: 109229726983571 (mesh names match a paid third-party low-poly pack, likely re-uploaded without rights),
121575291347417 (re-upload of Cliosow's pines; the original 8559395722 is used). Every inserted model had its scripts
deleted (some packs listed as "No scripts" still carried 2-4). Tools stay greybox: tool searches returned only gear
kits with scripts.
