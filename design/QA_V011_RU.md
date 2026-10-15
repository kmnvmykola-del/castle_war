# Version 0.11 validation — October 5, 2026

Main `inex.rbxl` saved: **2,054,358 bytes**, 155 embedded sources, 135 geometry modules. All sources match `src`; service references/parents were checked. Previous copy: `build/pre-v011.bin`; rules: `design/CONCEPT_V010_ARCHIVE.md`.

## New validation

`tools/qa_v011.luau`: **17 of 17**, no failures.

- AI/PvP XP, separate rank, coins for crossing levels, and duplicate result rewards.
- First ten ranked games, stable points/streak acceleration, negative rank, and leaving matches.
- Repeated UpdateAsync callbacks, save/load failures, and preservation of old maps/settings.
- Exact-price purchases, repeated purchases, equipping only owned sets, and no combat bonuses.
- Repeated paid receipts across servers; real Account.ProcessReceipt confirms only known products and saved fulfillment for a loaded player.
- Pending reward restoration on login; stale lobby cache refresh after playing on another server.
- Leaderboard projections protected from late writes; own position #251 while showing the first 100.
- Ranked 100/200/300 range, independence from XP level, and separate search modes.
- Closest-rank selection across lobbies, one reservation per pair, 50+ lobbies, capacity, and stale-entry expiry.
- Each match result processes once, including disconnects; participant records remain for rewards. Army sets are fixed for the match.
- Local waiting players start ranked matches after range expansion at 60 seconds without a third queue entry.

## Gameplay checks

`qa_v06` passed again: local matches, global queue, assignment races, reservation failure, cancellation, timeout, one stationary simulation for 100 waiting players, bridges, and formations. `qa_full`: **6 of 6**, including nine three-minute AI matches on all three maps/difficulties. Checks covered economy, capacity, final-destination training, unit lifecycle, and invalid positions. All eight `qa_v010` road checks passed earlier in this update.

Real Studio Play UI on one ordinary PC screen validated main menu, profile, shop 3D previews, ranked search/cancellation, leaderboard switching, and own position. The latest guard preview shows models from the front at increased scale.

The full reward loop was tested in a game session: a temporary scenario completed 16 hard-AI matches using ordinary Engine victory rules and MatchLobby completion handling. This yielded 800 XP, level 5, and 400 coins; rank/PvP wins stayed zero. Buttons purchased/equipped Veterans, leaving balance 0. In the next match, left/right clicks sent a group showing new models and blue friendly markings. Accelerated wins were temporary validation only, removed when Play stopped.

Three sets for four unit types were created in Blender: 84 additional meshes, 19,880 triangles. `assets/blender/skins/army_skins.blend`, FBX, and `skins.png` are saved. All 135 geometry modules loaded in Play; catalog total is 64,384 triangles.

## Validation limits

Final Play showed no game-script console errors. Additional resolutions and a physical phone were not tested at the user's request. Studio was left in Edit; temporary scenarios and the export attribute were cleared.

DataStore, MemoryStore, ordered stores, failures, and repeated receipts were tested through injectable service simulations. Real reserved-server transfers and persistence across published servers cannot be tested in Studio. Robux product IDs are 0 and buttons disabled; no real paid purchases occurred. Publication, owned Developer Products, and published-game validation are required.

Detailed results: `build/qa-v011-report.json`; save validation: `build/save-report.json`.
