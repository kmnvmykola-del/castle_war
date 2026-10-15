# Frontier Kingdoms — Early Access 0.16

## Standard models instead of EditableMesh

On October 6, 2026, version **0.16 was published to the existing Frontier Kingdoms experience**. It includes 806 source models, variants of 25 sets, and a gray neutral army: 1,969 templates with real MeshIds in total. New armor, weapon, road, and gate models for Storm, Dragon, and Oracle were created in Blender. Building entrances face the camera. [Release status and validation](design/NEXT_SESSION_RU.md).

**No reimport is required.** Both the main `inex.rbxl` and `FrontierKingdoms-installed.rbxl` already contain the installed game. Studio checks covered Play, an AI match, building capture, previews, and editor placement/Undo. These models do not use Allow Mesh / Image APIs or document verification. PlaceId: `81963222072062`, GameId: `10769541065`.

Full feature list: [design/ALL_FEATURES_RU.md](design/ALL_FEATURES_RU.md). Transfer through GitHub and continuation on another PC: [design/TRANSFER_TO_PC_RU.md](design/TRANSFER_TO_PC_RU.md).

## English game version

All authored game text is now in English: **Frontier Kingdoms**. This includes menus, combat UI, profiles, leaderboards, shop, inventory, cases, editor and tutorials, maps, 25 sets, server messages, and errors. AutoLocalize is disabled on both root ScreenGuis so the game UI remains English. Player names and player-entered custom map names remain user data.

Ready-to-use English titles and descriptions for the game, three passes, and coin packs: [design/ROBLOX_LISTING_EN.md](design/ROBLOX_LISTING_EN.md). Translation validation: [design/QA_ENGLISH_RU.md](design/QA_ENGLISH_RU.md). Set Source Language = English in Creator Hub Localization when publishing. Roblox page text and platform dialogs are managed separately from the game UI.

## Inventory and cases 0.13

Main menu → **Inventory · Sets**. Inventory shows only owned sets; prices and purchases are in **Shop · Skins**. The shop contains 24 offers, coin/Robux and ownership filters, and a separate mythical section. Inventory has rarity filters and one Equip Set button. Each set includes four troop types, every building and level, crests, roof decorations, and its own roads. **Army / Buildings / Roads** switches open 3D previews. The entire set is equipped at once, starting with the next match. Cosmetics do not change statistics.

The shop sells 21 sets for coins: common sets cost 400, rare sets 800, and epic sets 1,200. Mythical sets are available directly for Robux or from a case:

| Set | Planned price | Case probability |
| --- | --- | --- |
| Storm Knights | 199 Robux | 0.5% |
| Dragon Order | 399 Robux | 0.3% |
| Star Keepers | 699 Robux | 0.2% |

A case costs 300 coins. Rarity probabilities are common 60%, rare 30%, epic 9%, and mythical 1%. Probabilities are fixed and do not increase as the collection grows. Duplicates refund 100/150/200/250 coins by rarity. All 24 outcomes, exact probabilities, and compensation are visible before purchase. Owning the full collection disables case purchases. Repeated requests and UpdateAsync retries do not charge coins twice.

Robux sales are connected to the created passes: Storm `2006883740`, Dragon `2005989756`, and Oracle `2005239786`, priced at 199/399/699 Robux. The UI retrieves the actual Roblox price. The server verifies pass ownership before granting a set and restores purchases on login or profile refresh. Unknown passes and unconfirmed purchases grant no set. Purchase buttons are disabled in Studio. No actual Robux charge was performed. [Roblox passes](https://create.roblox.com/docs/production/monetization/passes), [paid random item requirements](https://create.roblox.com/docs/production/monetization/paid-random-items).

`inex.rbxl` was saved from the installed Studio game: all 26 active sources match `src/`. Previous Geometry modules and code are retained in disabled backup folders in ServerStorage. `tools/sync_place.py` updates only active game roots and preserves archives, MeshIds, properties, and references. Current validation: `tools/run_local_qa.py`, 90 scenarios; `tools/verify_installed_place.py inex.rbxl` validates the saved game. Previous-version economy and UI results: [design/QA_INVENTORY_RU.md](design/QA_INVENTORY_RU.md).

## Models 0.12

25 complete cosmetic sets for armies, bases, and owned roads. All previous models, 21 building variants, environment assets, and the chest were updated. The shop has 3D previews of armies, bases, and roads. Gallery: `assets/blender/v012/gallery.html`.

Set acquisition rules were updated in version 0.13 above. The server observes Roblox random purchase restrictions through PolicyService.

Blender models: `assets/blender/v012/base/kingdoms_v012.blend`, `collection/collection_v012.blend`, and `decor/kingdom_decor_v012.blend`. When rebuilding the base assets, run `tools/limit_meshes_v012.py` after `build_art_v012.py`, then `optimize_castles_v012.py`, `geometry_to_luau.py`, and `validate_art_v012.py`.

## How to run

1. Open `inex.rbxl` in Roblox Studio through **File → Open from File**.
2. Press **Play / F5**. The map and models load when the game starts.
3. Select **Play → Vs AI**, choose a map or a random map, then select difficulty.

If this project is already open in Studio, stop the current test and reopen the saved file to load the version from disk.

## Profile, ranked mode, and shop

The main menu provides **Profile**, **Inventory · Sets**, **Shop · Skins**, and **Leaderboards**. **Play** provides **Vs AI**, **Casual · 1v1**, and **Ranked**. Regular level and ranked points are tracked separately.

An AI win grants 20/35/50 XP depending on difficulty; a loss grants 0. PvP grants 100 XP for a win and 40 for a completed loss. Leaving a match counts as a loss and grants no XP. Every 200 XP advances a level and grants 100 coins. The starting level is 1.

The starting rank is 0. During the first ten ranked matches, a win grants +100 and a loss −25. Afterward, a win grants +25; the third consecutive win grants +35, the fourth +45, and the fifth and later wins +50. A loss subtracts 25 and resets the streak; rank cannot fall below zero. AI matches do not affect rank or the PvP wins leaderboard.

Ranked matchmaking spans all lobbies and finds the opponent closest in points: a difference of up to 100 initially, up to 200 after 30 seconds, and up to 300 after 60 seconds. Lobbies are divided by regular level: 1–9, 10–24, 25–49, and 50+. Casual PvP selects a player in the same level bracket. Leaderboards show the global top 100 by rank and PvP wins, along with the player's own position.

The game has 25 Blender sets: the base set and 24 obtainable sets. Inventory contains only owned sets; the shop has 24 offers. Previous set prices are retained: **Veterans — 400**, **Royal Guard — 800**, and **Dark Knights — 1,200 coins**. A set changes the army, buildings, and owned roads. Friendly markings remain blue and enemy markings red.

The 500/1,500/3,500 coin packs are connected to Developer Products `3716851182` / `3716851330` / `3716851499` at 49/129/249 Robux. The UI requests the actual price from Roblox. The server grants coins only after successfully saving the confirmed purchase and never grants them twice for the same receipt. No actual Robux charge was performed.

In Studio, profiles, coins, and coin purchases last until Play stops. Cross-server profiles, live rankings, and transfers are prepared but must be tested in the published game. Local validation does not charge Robux.

## Army controls

**PC:** Left-click selects a building; right-clicking a target sends the selected percentage of troops. Shift + left-click adds or removes an owned building from the group; drag a selection box to select several buildings. WASD moves the camera, the wheel zooms, and the middle button pans the map. Esc clears selection, then opens the match menu.

**Phone:** Tap selects a building; tap **Order →**, then tap a target to send troops. Holding selects a building without issuing an order. Dragging pans and pinching zooms. The panel and menus adapt to portrait and landscape screens.

The local player's side is always blue, the opponent red, and neutrals gray, regardless of the player's assigned side. Color appears on flags, platforms and their outlines, troops, and population labels.

The three-line button is at the top left. Resources, peasants, time, and bridge status appear at the bottom left; the total army counter was removed. On phones, **i** toggles information. On PC, the large send slider appears at the bottom center; on phones, it remains in the selected building panel.

Swordsmen and fast fighters march in rows of four. Peasants in mixed groups form rows behind all melee fighters, including an incomplete last row. Archers move freely through rear rows but stay one row behind their group's front melee fighters. Without melee fighters, or after they die, archers march independently. Before a bridge, the group reforms into two columns; after the entire group passes, it reforms into four. Reforming uses normal movement speed without jumps. Swordsmen approach enemies at near-contact range; a field archer dies to the first sword strike. An arrow deals 25 damage every 2 seconds and does not kill a healthy fighter in one hit.

During combat, rear rows follow the actual front row and fill casualties' positions. Swordsmen swing every **1 second**, with casualties applied after **0.25 seconds**; archer timing is unchanged. Large armies and garrison defenders leave through doors gradually. Units waiting to leave remain inside, occupy capacity, and consume food under the previous rules; repeated orders do not send them twice.

During combat, the group continues in rows along the road and follows its turns: four columns, or two on a bridge. The army does not straighten across the map when attacking. At a corner, front rows align opposite each other; the nearest two rows smoothly connect the front to the rest of the formation on the road. All four sword pairs fight simultaneously, or two pairs on a bridge. Swings occur every second, casualties after 0.25 seconds, and the following fighters fill empty positions. When attacking a tower, the entire group closes on the siege location. Survivors continue their route after combat.

When defending a building, swordsmen, fast fighters, and peasants remain inside. At the entrance, attackers and melee defenders exchange casualties using the same four-pair rules. A visible garrison-side swing represents the building's counterattack. Archers in ordinary buildings appear behind the model, and tower archers on the roof; they are protected until the building falls. After other defenders die, an approaching enemy occupies an ordinary building, and its remaining archers die on capture. Towers must first be destroyed: their durability and previous rebuilding rules are retained. Field archers can hit hidden defenders in ordinary buildings; arrows damage the structure of a tower. Protected archers given an order leave through the front door as an ordinary group.

Routes through an intermediate building's approaches are available only after that building is captured by the same side. The game first searches the entire visible road network, including intersections and shared segments, for an alternative. If none exists, the order is rejected with an explanation that the intermediate building must be captured. A street passing alongside a building remains accessible. The final target itself can be attacked; road junctions do not require capture. AI and route highlighting use the same rule.

On river maps, central bridges are closed for the first 60 seconds: capture villages on your own bank. Peasants become warriors when they arrive at their final military building. Upgrades consume 50, then 100, people from the local garrison and replace the whole building model. Farms provide food; without it, new warriors are not produced, while existing ones remain alive.

Arriving people disappear into the garrison if capacity is available. Capacity is strict: others wait outside and enter as places become available. Waiting peasants are not trained yet. The panel separately shows the composition inside and the number waiting.

## Map editor

Open **Map Editor** in the main menu. Choose a building type and side, then an empty cell. Each building occupies one cell; the river channel stays clear. **Roads** connects two selected points, automatically routing around other buildings and creating bridge approaches. **Road Junction** adds intermediate connections. Move, delete, undo, and a new blank map are available.

Instructions appear on first opening; **?** reopens them. Visible intersections, T-junctions, and shared road segments connect automatically: a continuous road is traversable. For example, barracks and an archery range can share a street formed by two roads from a castle without entering the castle itself. **Road Junction** helps shape a fork; other roads no longer route around this point as an obstacle. Buildings without a connected visible road remain inaccessible. Old disconnected wooden crossings were removed.

**River: yes / no** changes the field type. Without a river, the central column becomes ordinary cells. Move objects out of that column before enabling the river again. A new blank map retains the selected field type; river type is also included in the map code and undo history.

Before saving and playing, validation requires exactly one castle per side and road connections to all buildings. **Play** starts the created map against AI. Map selection includes Two Crossings, the riverless Land Frontiers, River Passage with one bridge, a random base map, and a saved map. All three base maps use the same buildings and starting garrisons.

In a local unpublished Studio file, map saves last until Play stops. **Map Code** lets the user copy a map into a text file; **Load** restores it from this code. The code opens automatically after saving in local Studio. Published-game map and settings persistence is prepared through DataStore but has not yet been tested on a published server.

## Settings and music

Settings provide music volume, camera and zoom speeds, grid visibility, and troop counts. The calm instrumental **Medieval_Ambient_Lute** by DistrokidOfficial comes from the [Roblox Creator Store](https://create.roblox.com/store/asset/93176902923482) and is embedded as a Sound asset. Music starts and loops automatically.

## Included features

A map with connected roads and two bridges; castles, villages, barracks, archery ranges, camps, towers, and farms; mixed armies, four-wide formations, melee combat, ranged attacks, tower destruction and capture; food economy, three building levels, three AI difficulties, a start menu, and camera controls.

**Play → With Player** enables global matchmaking across all lobbies. A matched pair transfers to a separate reserved server; the map is always randomly selected from the three base maps. An AI match also gets a separate reserved server for one player. The same published place serves as both lobby and match server; a second game file is unnecessary. Spells have not been added yet.

The global queue uses MemoryStore and atomic pair assignment; match servers use ReserveServerAsync and TeleportAsync. PvP waits for both participants to load. Other visitors are not admitted to reserved matches. A participant leaving ends the match with the opponent winning; returning leads to the lobby for the current level bracket. Public entry distributes players across these lobbies. Search cancellation, reconnection, and queue recovery after server creation failures are implemented.

Cross-server transfers are unavailable in Studio: AI runs locally for testing, and PvP uses two test players. Real lobbies and transfers must be tested after publication in the Roblox app; this is a [TeleportService limitation](https://create.roblox.com/docs/projects/teleport). The public lobby size is set by the place's player limit when publishing. The lobby uses one shared stationary simulation; it does not create an army for each waiting player.

## Development files

- `inex.rbxl` — the single main game file. Game scripts and geometry data are embedded in it.
- `design/CONCEPT_RU.md` — current agreed rules.
- `design/CONCEPT_V02_ARCHIVE.md` — the previous concept retained as project history.
- `src/` — sources of the embedded Luau scripts.
- `src/Progression.luau`, `PlayerData.luau`, and `AccountServer.luau` — progression rules, atomic persistence, rewards, shop, and receipt processing; `MetaUI.luau` — profile, shop, and leaderboard pages; `LobbyDirectory.luau` — level-bracket lobbies.
- `assets/blender/skins/army_skins.blend` — three new army sets; FBX, geometry, and `skins.png` are alongside it. Build script: `tools/build_skins.py`.
- `tools/qa_v011.luau` — 17 progression, purchase, persistence, ranked matchmaking, and lobby checks. Results: `design/QA_V011_RU.md` and `build/qa-v011-report.json`.
- `design/CONCEPT_V010_ARCHIVE.md` and `build/pre-v011.bin` — rules and game file from before version 0.11.
- `src/MapNetwork.luau` — grid, schema validation, roads, and routing; `MapEditor.luau` — editor.
- `design/CONCEPT_V03_ARCHIVE.md` — the previous prototype's concept.
- `assets/blender/kingdoms_models.blend` — original Blender models, with FBX exports and images alongside.
- `tools/build_models.py` and `tools/geometry_to_luau.py` — model generation and geometry conversion to Luau.
- `tools/qa_gameplay.luau` — agreed-rule validation in Studio.
- `tools/qa_v06.luau` — bridge formations, new maps, melee contact, and the global queue with simulated lobbies and Roblox service failures.
- `tools/qa_v07.luau` — ownership route gates, alternative paths, 300 people leaving through doors, rear-row closing, and garrison defenders leaving buildings.
- `tools/qa_v08.luau` — four simultaneous pairs on straight and corner roads, two bridge pairs, row width and spacing, a lone archer, village defenders, and a 300-person siege.
- `tools/qa_full.luau` — nine matches across all maps and AI difficulties, training only at the final building, starvation, incomplete and mixed rows, invalid maps, and invalid orders.
- `tools/qa_v09.luau` — twelve checks of archer movement, hidden building defense, retaliatory casualties, capture, and protected archers leaving through doors.
- `design/QA_V09_RU.md` — version 0.9 validation; detailed data: `build/qa-v09-report.json`.
- `tools/qa_v010.luau` — eight checks covering shared streets, intersections, junctions, overlapping roads, capture of intermediate bases, and routes on all base maps.
- `design/QA_V010_RU.md` — version 0.10 validation; results: `build/qa-v010-report.json`.
- `design/QA_FULL_RU.md` — general validation from October 5; detailed results are saved in `build/full-qa-report.json`.
- `src/MapCatalog.luau` — base maps; `GlobalMatchmaker.luau` and `ServerNetwork.luau` — queue and reserved-server transfers; `MatchLobby.luau` — participants and matches.
- `design/CONCEPT_V05_ARCHIVE.md` — rules from the previous version.
- `design/CONCEPT_V06_ARCHIVE.md` — rules before the movement and combat pacing fixes.
- `design/CONCEPT_V07_ARCHIVE.md` — rules before the combat formation-width fix.
- `design/CONCEPT_V08_ARCHIVE.md` — rules before changes to archer movement and garrison defense.
- `design/CONCEPT_V09_ARCHIVE.md` — rules before visible roads and routing were unified; previous game file: `build/pre-v010.bin`.
- `build/original-place.bin` — backup of the original Roblox file before the game was added.

## Models and validation

Models were created in Blender. Each of the seven building types has three complete level models; only the appropriate model is shown after an upgrade. Every variant is aligned to ground level. Flags, labels, and arrows on the tower roof follow its level. The client clones ordinary imported MeshParts; EditableMesh is not used during Play. Version 0.16 contains 806 source models and team/neutral variants: 1,969 templates. Roblox reuses geometry between clones, and old previews are released. The complete new export contains 593,392 source faces; detailed originals remain in Blender.

The game is published and Public access is enabled; Roblox restricts the audience to users aged 16+ and trusted friends. Studio Play, two clients, new premium models, the editor, and shop scrolling in the phone emulator were checked. A physical phone and actual payment transaction have not yet been tested. Original music and effects are uploaded to Roblox. Gallery: https://frontier-kingdoms-sound-library.kmnv-mykola.chatgpt.site (owner access). Shorts/TikTok video: `build/release/Frontier-Kingdoms-Shorts.mp4`; Roblox trailer: `build/release/Frontier-Kingdoms-Roblox-Trailer.mp4`.

General validation passed all five gameplay suites and nine AI matches of three game minutes each. UI checks covered menus, settings, controls, editor, and playing a custom map; all models and music loaded. Fixes addressed the panel overlapping the phone information button, notification positioning after match start, and information overlapping the bottom slider in a small PC window. Testing additional resolutions stopped at the user's request. The last small-PC-window fix was checked in source without another resolution run.

Version 0.11 passed 17 new checks and repeated queue and gameplay validation, including nine AI matches. On one ordinary PC screen, checks covered the shop, rewards, purchasing and equipping Veterans, their marching appearance, ranked search/cancellation, and leaderboards. Details and validation limits are in `design/QA_V011_RU.md`.
