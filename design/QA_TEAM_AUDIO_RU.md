# Team colors and local audio — October 6, 2026

`tools/run_local_qa.py` completed: 827 sources compile and all 61 scenarios pass, including seven new `tools/qa_team_audio.luau` scenarios. Results are saved in `build/inventory-qa-report.json` and individual suite outputs.

New checks use real `Art`, `Music`, `UI`, `Config`, and `SkinStyles` modules. Real exported model palettes load for each of 25 collections and four army types. For both viewers, friendly fabric/team markings must be blue, enemies red, while skin/weapon/armor shades remain unchanged. Geometry color variants reuse the cache; heads without team fabric remain shared, and deleting models frees unused variants.

Audio checks confirm separate music/interface volumes, repeated-click rate limits, silent disabled buttons, and menu/combat context changes without restarting tracks on every snapshot. Two independent client environments do not share interface sound events or volume settings. The module uses `SoundService:PlayLocalSound` and rejects server-side audio creation. Replacing a temporary ID with an uploaded Roblox ID was checked.

Validation found an inaccurate mock `Instance`: `model.Torso` failed to find a child renamed after parenting. The mock now searches current child names, like Roblox. This fix affects tests only.

Limits: CLI mocks Roblox APIs, mesh creation, volume-transition animation, and audio playback. Allocation-test geometry is simplified, while palettes come from real exports. Results do not establish FPS, actual Roblox sound loading, published-game EditableMesh permissions, or listening by two real players.

Originals in `src/AudioCatalog.luau` still have `Id=0`; the game uses prepared temporary Roblox assets. Original WAVs are in `assets/audio/original`; connecting them requires Roblox uploads and ID replacement. Disk WAVs or website playback alone do not connect recordings to the game.
