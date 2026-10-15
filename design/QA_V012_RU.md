# Version 0.12 validation

Date: October 5, 2026. Roblox Studio and Blender/Python validation on one ordinary PC screen. Additional resolutions were not tested at the user's request.

## Passed

- 12 new server checks: 25-set catalog, retained prices, 21 new chest sets, equal selection intervals, full collection without duplicates, request/UpdateAsync retries, insufficient coins, changed odds, save failures, old-profile migration, PolicyService restrictions, and road ownership.
- 17 previous progression/online checks: XP/coins/rank, placements/streaks, AI rewards, purchases/equipment, receipts, reward recovery, fresh profiles on return, leaderboards/own position, global matchmaking, lobby brackets, match completion, and participant departure.
- 25 army and 25 road variants loaded in real client 3D previews. Each army has four unit types, each with seven model parts.
- 25 base variants and all 21 building-level variants loaded in the client. Bounded cache size was checked while browsing the collection.
- A chest was opened using real shop buttons: balance 10,000 → 9,700; Order of the Sun awarded; 23 rewards remained with probability 1/23. The awarded set was equipped.
- In a real Royal match, 71 people left the castle, captured a neutral village, and created 38 owned road tiles. Later snapshots show 51 and 126 complete seven-part people, with no incomplete models and 47 templates in the final cache. Bridges/environment persist. No new game-script errors appeared after the validation marker.
- Geometry validation covered finite values, indices, colors, cell bounds, animation pivots, shape differences, and polygon limits. 803 meshes, 598,272 game triangles.
- The main `.rbxl` was checked by the binary assembler: all 826 sources match `src/`, preserving original services/references.

## Fixes discovered during validation

Loading all high levels simultaneously exceeded EditableMesh budgets. Added loading only used models, shared normals, and release of old previews/unneeded templates. Live clones retain strong references until removed so cache cleanup cannot destroy visible bridges, trees, or roads. Cosmetic building sets share geometry with separate tint/crests/ornaments instead of duplicating heavy meshes per color. Partially created armies are removed on loading failure.

Castle III exceeded the MeshPart limit; its detailed Blender original was reduced to 18,000 triangles. Separate 8,000-triangle LODs were exported for game castles II/III. Detailed `.blend` and FBX sources remain; game exports do not replace them. Network snapshots apply sequentially while model creation awaits Roblox APIs to avoid duplicate groups/buildings.

## Validation limits

AI matches, selected skins, and owned roads are checked locally in Studio. Global online play, teleports, DataStores, and leaderboards were service simulations, not published-game tests. Coin-pack ProductIds are 0; no Robux sales occurred. PolicyService server scenarios covered pending / restricted / allowed; real regional responses require publication. Physical phones remain untested.

Exact server/model results: `build/qa-v012-report.json` (local report; `build/` is Git-ignored). This document's conclusions remain in the repository with the project.
