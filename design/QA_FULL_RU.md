# General version 0.8 validation — October 5, 2026

Five gameplay suites passed: `qa_gameplay`, `qa_v06`, `qa_v07`, `qa_v08`, and `qa_full`. The last adds six behavioral checks, including nine matches: three base maps × three AI difficulties, each lasting three game minutes.

Validated four combat pairs, two bridge pairs, incomplete/unequal rows, mixed melee units, ranged fire, tower siege/capture, 300-person door exits, and no stuck units on tested routes. Checked explicit road links, intermediate-building ownership gates, alternative routes, and peasants passing military buildings but training only at the final destination.

Validated food, starvation, training resumption, strict capacity, upgrades, hidden garrisons, army composition, building ownership, snapshots, and rejection of invalid maps/orders. In all nine matches, AI captured four villages; no negative food, invalid owners, or missing people were found.

UI checks covered settings, volume, grid/population display, map/difficulty selection, random maps, match start/end, left/right click, WASD, wheel zoom, matchmaking, and cancellation. A map was built from scratch in the editor: buildings placed, roads connected, code saved, and the custom map played against AI. Phone checks covered touch selection, order button/target tap, camera dragging, information opening, and settings scrolling. Screen testing ended at the user's request.

All 51 meshes and 44,504 triangles loaded. Checked 60 building/level combinations on the full map: only the correct level model is visible, and buildings stand on the ground. Checked second-side colors, tower ruins, and four unit types. Music loads and plays.

UI overlap fixes: the building panel no longer touches the information button on narrow phones; notifications reposition after leaving the menu for a match; small PC windows place information above orders, freeing the bottom slider. The emulator was restored to normal view; temporary checks were not embedded in the game file.

Opponent matching, cross-lobby queues, cancellation, reservation failures, timeouts, disconnects, and side assignment were tested with simulated Roblox services. Real cross-server teleports, cloud persistence, and model permissions require published-game testing in the Roblox app. Physical phones and two-finger pinch zoom were not separately tested.

Detailed results: `build/full-qa-report.json`. Final embedded-source comparison: `build/save-report.json`. Main file: `inex.rbxl`; prevalidation backup: `build/pre-full-qa.bin`.
