# Version 0.9 validation — October 5, 2026

All 12 `qa_v09` checks passed. Archers stay behind the front melee row through turns, are not column-bound, and continue without escorts. A real attack was checked: all 12 swordsmen died, four archers kept firing, killed remaining hidden defenders, and captured the village. Archers retained health.

Hidden swordsmen in an ordinary building exchanged casualties with three attacking rows of four, four pairs per second. Archers behind the building stayed protected until capture, then died. Checks covered protected firing, returning inside when threats disappear, archer-only building capture, internal swordsmen hitting nearby field archers, and protected archers leaving again through the front door on orders.

Checked tower-internal counter-casualties, subsequent destruction/durability restoration, no production in ruins, and reinforcement attacks resuming after loss of the building where they waited outside.

Previous `qa_gameplay`, `qa_v06`, `qa_v07`, `qa_v08`, and `qa_full` passed. Garrison-exit and overtaking expectations were updated to agreed new rules. Nine three-minute AI matches across all maps/difficulties validated capacity, unit states, ownership, food, and snapshots.

Real Play checked entrance combat: 15 hidden melee defenders, eight protected archers behind the model, eight field archers, and four retaliatory garrison swings. No console errors. Graphics/device changes were unnecessary; screen resolutions were not cycled. Stopping Play removed the temporary test scene.

Detailed results: `build/qa-v09-report.json`. Single main game: `inex.rbxl`; previous copy: `build/pre-v09.bin`. Published-server and physical-phone checks are outside this local validation.
