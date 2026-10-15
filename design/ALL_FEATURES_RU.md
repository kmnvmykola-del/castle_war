# Completed features — Frontier Kingdoms 0.14

The rendering code uses ordinary MeshParts. All 1,984 templates have real MeshIds, were checked in Studio, and are published in Frontier Kingdoms v12. [Installation](INSTALL_MESHPARTS_RU.md), [validation](QA_STATIC_MESHES_RU.md).

Date: October 5, 2026. The single main game file is `inex.rbxl`. This is a local Roblox Studio prototype. Sources are embedded in the game file and also saved in `src/`. Models were created in Blender; sources and FBX files are in `assets/blender/`.

## Game and world

- A medieval strategy game inspired by LandGrabbers: building capture, population production, military supply, upgrades, and combat along roads.
- Moderately stylized 3D graphics. The setting allows some magic, but spells are not implemented yet.
- Four unit types: peasants, sword-and-shield defenders, archers, and fast fighters.
- Seven buildings: castle, village, barracks, archery range, camp, tower, and farm. Each has three visually distinct levels.
- Victory occurs when the opponent has no buildings or living units left, including peasants.
- Three AI difficulties. The bot uses the same economy, upgrades buildings, captures, and attacks. Hard AI actively intercepts supply.

## Maps and roads

- Three base maps: Two Crossings, the riverless Land Frontiers, and River Passage with one bridge.
- Against AI, choose a map, a random base map, or your saved map. Against another player, the map is always random.
- The map uses a grid: each base occupies one 32-stud cell.
- Visible roads and routes are computed from the same network. Approaches reach bridges; intersections, shared segments, and junctions connect automatically.
- Nearby roads do not connect merely because they are close.
- An intermediate neutral or enemy base's controlled approach is impassable until capture. An alternative route is searched first; if none exists, an explanation is shown.
- A street passing a base without crossing its controlled approach remains accessible. Training happens only at the order's final building.
- On river maps, bridges are closed for the first 60 seconds. Once open, they carry two-wide rows; ordinary roads carry four-wide rows.

## In-game editor

- Grid-based building placement, side selection, and road junction creation.
- Road tools connect points, automatically avoiding buildings and creating bridge approaches.
- Move, delete, undo, and create a blank map.
- Fields with or without a river. Enabling the river while central cells are occupied shows a hint and does not delete objects.
- Validate bounds, cells, road endpoints, connectivity, and exactly one castle per side before saving or playing.
- Play the created map against AI, save it, and export/import its text code.
- Instructions on first opening; reopen with the **?** button.
- In Studio, saves last for the current Play session. Save the map code separately for the next run. DataStore is prepared for the published game.

## Starting units, production, and upgrades

| Building | Starting garrison |
| --- | --- |
| Each side's castle | 50 defenders and 20 peasants |
| Neutral village | 8 peasants |
| Barracks / archery range / camp | 12 warriors of the corresponding type |
| Neutral tower | 15 archers |
| Owned farm near each castle | No garrison |

- Each side has four neutral villages on its half of the map. All base maps have the same buildings and starting forces.
- Villages produce peasants every 5 / 3 / 2 seconds at levels I / II / III. Military buildings produce their warriors every 20 / 15 / 12 seconds.
- Neutral buildings do not produce units until captured.
- A peasant becomes the appropriate warrior upon entering the final owned military building. Trained warriors do not retrain.
- Level II costs 50 people and takes 6 seconds; level III costs another 100 people and takes 10 seconds. People are consumed from the local garrison, starting with peasants.
- Upgrades improve production, capacity, and defense. Towers also gain firing range and rate.
- Ordinary building capacity: 80 / 160 / 260; castle: 120 / 240 / 400; tower: 60 / 140 / 220.
- Capacity is strict: production stops when full. Reinforcements wait outside, enter when places become available, and disappear into the garrison. Waiting peasants are not trained yet.
- Production pauses during upgrades; capture cancels an unfinished upgrade but preserves completed levels.

## Food

- Each side starts with 100 food.
- A farm provides 10 / 15 / 20 food every 5 seconds. It does not produce people; arriving peasants remain peasants.
- Every living warrior in a garrison, marching, or waiting consumes 1 food every 30 seconds. Peasants consume none.
- Food shortages stop production and training of new warriors. Existing units survive; peasants and farms continue production.

## Movement and combat

- Melee fighters march in orderly rows of four, or two on bridges. They follow the road through turns and during combat.
- Peasants march behind melee fighters. Archers pass through rear rows but stay one row behind the front swordsmen; without swordsmen, they move independently.
- Large groups leave gradually through the front door. Units waiting to leave remain in the garrison and cannot be sent twice.
- Opposing front rows fight as four simultaneous pairs, including at corners, or two pairs on bridges. Following rows fill empty positions.
- Melee contact is about 0.85 studs. Swings occur every second, casualties after 0.25 seconds. Each sword pair loses one fighter on each side per swing.
- Archers fire every 2 seconds, at 22-stud range, for 25 damage. Health: peasants 30, archers 45, fast fighters 60, defenders 100. Defender shields reduce arrow damage by 35%.
- Archers stop at firing range, do not retreat, and die to the first melee sword strike. Arrows already in flight are considered when selecting targets.
- Melee garrisons stay inside buildings; defenders and attackers exchange casualties at the entrance. Archers are visible behind buildings or on tower roofs and protected until capture.
- After the other defenders die, an ordinary building is captured and its remaining protected archers die. Towers must be destroyed first.
- Towers have 100 durability; sword hits deal 5 and arrows 2. Ruins do not produce warriors until rebuilt.

## Controls and interface

- PC: left-click selects; right-clicking a target sends troops. Shift + left-click and box selection select multiple owned buildings.
- Camera: WASD, wheel zoom, and middle-button dragging. Esc clears selection and then opens the menu.
- Phone: tap selects; **Order →**, then tapping a target sends troops. Drag pans and pinch zooms. Holding selects without issuing an order.
- A compact panel shows garrison composition, capacity, waiting units, and upgrade cost. Send amounts are controlled by percentages.
- A large bottom-center slider on PC; a compact slider in the building panel on phones.
- Three-line menu at the top left. Food, peasants, time, and bridge status at the bottom left; **i** quickly collapses phone information. The total army counter was removed.
- Main menu, mode/map/difficulty selection, settings, profile, separate set inventory, shop, cases, and leaderboards. Menu dimming covers the whole screen.
- Settings for volume, camera motion, zoom, grid, and population labels.
- Calm medieval instrumental music, `Medieval_Ambient_Lute`, is embedded as a Roblox Sound and loops automatically.
- Friendly markings are always blue, enemies red, and neutrals gray, regardless of map side. Cosmetic sets retain side markings, outlines, and flags.

## Level, rank, coins, and leaderboards

- XP and rank are independent. Starting level 1, rank 0, coins 0.
- PvP: a win grants 100 XP and a completed loss 40 XP. Leaving records a loss and grants no XP.
- Easy / medium / hard AI wins grant 20 / 35 / 50 XP. AI does not affect rank or PvP wins.
- Every 200 XP grants a new level and 100 coins.
- First 10 ranked matches: win +100, loss −25. Afterward, win +25; third consecutive win +35, fourth +45, fifth and later +50. A loss is −25 and resets the streak. Rank cannot fall below zero.
- Top-100 rank and PvP-win leaderboards, plus the player's own position even outside the top 100.
- Profiles show XP, level, coins, rank, placement progress, streaks, and PvP/AI results.
- Atomic profile changes preserve existing maps and settings. Duplicate match results, receipts, and chest openings do not grant rewards twice. Pending rewards recover on login.

## Online

- Level-bracket lobbies: 1–9, 10–24, 25–49, 50+. Casual PvP matches players in the same bracket.
- Global ranked matchmaking across lobbies selects the closest rank: difference up to 100, up to 200 after 30 seconds, and up to 300 after 60 seconds.
- Matched pairs transfer to a separate two-player reserved server; AI matches use one-player servers. Return leads to the appropriate level lobby.
- One place serves as both lobby and match. Search cancellation, reservation-failure recovery, waiting for both participants, and ending when the opponent leaves are implemented.
- MemoryStore, reserved servers, and TeleportAsync are implemented. Studio replaces transfers with local matches using test players. Real online operation requires post-publication validation.

## Game language

- All authored game text is English, titled Frontier Kingdoms. Every page, dynamic message, error, editor/tutorial text, map, and set is translated. Root ScreenGuis have AutoLocalize=false.
- English Roblox descriptions: `design/ROBLOX_LISTING_EN.md`; language validation: `design/QA_ENGLISH_RU.md`.

## Sets, inventory, and cases 0.13

- 25 complete sets: Standard Army, Veterans, Royal Guard, Dark Knights, Forest Wardens, Order of the Sun, Moon Watch, Frost Guard, Ashen Legion, Oak Guard, Storm Knights, Iron Bastion, Order of the Rose, Sapphire Crown, Amber Guard, Raven Cloaks, Lion Guard, Griffin Wardens, Dragon Order, Rune Keepers, Star Keepers, White Banners, Coastal Guard, Steppe Riders, and Silver Stag.
- New helmet, shield, weapon, cloak, and ornament shapes. These are cosmetics without combat advantages. Steppe Riders is a set name; separate cavalry is not implemented.
- Base army models, all 21 building models, environment assets, and the chest were updated. Additions include masonry, roof tiles, timber beams, arched entrances, shutters, lanterns, and yard props.
- One set styles the army, bases, and owned roads: colors, crests, roof ornaments, and paving. Roads change appearance when ownership changes; contested sections remain standard. Bridge width and routes are unchanged.
- Inventory contains only owned sets, rarity filters, and equipment controls. Shop is a separate 24-offer storefront with prices, coin/Robux/unowned filters, mythical sets, and purchases. Owned shop items lead to inventory. Both pages have army, building, and road 3D previews. The whole set is equipped for the next match.
- A 300-coin case awards a set with fixed rarity probabilities of 60% / 30% / 9% / 1%. All 24 rewards and exact probabilities are shown before purchase; mythical probability does not rise as other sets are collected. Duplicates refund 100 / 150 / 200 / 250 coins. Owning everything disables purchases.
- The base set is free; 21 sets cost 400 / 800 / 1,200 coins by rarity. Storm Knights / Dragon Order / Star Keepers are prepared at 199 / 399 / 699 Robux and have 0.5% / 0.3% / 0.2% case probabilities. Game Pass IDs are not connected yet; real sales are inactive.
- The server blocks random purchases for accounts restricted by Roblox PolicyService and until permission is obtained.
- Catalog: 803 source models, 1,961 MeshParts with team variants, and 587,404 nondegenerate source triangles. The prepared local file contains 828 Luau sources; after installation, the active folder uses 25 sources and ready templates, while old Geometry remains in backup. Unneeded previews are released.
- Three Blender 5.2 scene sources and visual gallery: `assets/blender/v012/gallery.html`.

## Remaining publication work

- There is no published release yet. DataStores, transfers, global leaderboards, and matchmaking require live validation on real servers.
- 500 / 1,500 / 3,500 coin packs are prepared as Developer Products, but their IDs are 0, so Robux sales are disabled. The game owner's products and IDs are required.
- In version 0.14, the game clones ordinary uploaded MeshParts and retains joint animation. Geometry is not created during Play. glTF/bin/GLB and a Studio installer are prepared; the installer validates import and backs up before replacing files. Actual import and rendering have not yet been tested.
- Physical phone testing remains. Additional screen resolutions are not being cycled through at the user's request.
- The original chat history is not embedded in the Roblox file. This report, agreed rules, and `NEXT_SESSION_RU.md` support continuation on another PC.
