# Frontier Kingdoms — Prototype 0.9

Date: October 5, 2026. Main game file: `inex.rbxl`. The working title is retained from the previous prototype.

This document supersedes version 0.8 archer movement and garrison-defense rules. The previous concept is retained in `CONCEPT_V08_ARCHIVE.md`. The user requested archers slightly behind swordsmen, melee defenders remaining inside, and only protected archers visible. Agreed details: buildings exchange casualties in both directions; archers remain protected until capture and die on capture; towers must be destroyed first. Four-wide roads, four combat pairs, two bridge pairs, population, health, damage, and attack rates are retained. Agree on other new mechanics and value changes first.

## World and objective

A Roblox RTS in a medieval world with moderately stylized 3D graphics. Models are created in Blender and transferred to Roblox. The setting allows some magic; spells have not been added yet.

Players capture villages, send population to military buildings, upgrade structures, and fight for roads. The bot uses the same economy without free reinforcements. Victory occurs when the opponent has no buildings or living people left, including peasants.

## Map and editor

The first map is Two Crossings. Each side has a castle, owned farm, four neutral villages, barracks, archery range, and camp. Two neutral towers stand near the crossings. Total: 20 buildings, 2 road junctions, and 36 links between objects. These generate 190 physical road-network segments.

Bridges are gated for the first 60 seconds: each side develops its own bank and can capture 3–4 villages. Crossings then open. Bridges cannot be destroyed. Troops cross two abreast; formations narrow before bridges and widen after the last row passes.

Additional base maps: riverless Land Frontiers and River Passage with one crossing. They have the same 20 buildings and starting garrisons. Against AI, select a specific, random base, or saved map; against a player, always use a random base map.

The editor toggles river presence. Without a river, central cells allow buildings, junctions, and roads. Enabling a river with occupied central cells is rejected with a hint, without deleting objects. Field type is preserved in map code and undo history.

The map uses a 32-stud grid. Every building, including a castle, occupies one cell. Buildings and road junctions have cell coordinates and unique names. A road links two existing names. Visible roads, troop routes, and bridge positions use the same endpoints, with approaches reaching the crossings.

Roads follow free cells and route around building-cell edges. Building entrances are separate terminal branches; passing groups avoid intermediate buildings without entering garrisons or training. Approaches and bridges share one network. Models stand on cell platforms.

Traversal is allowed only between explicitly connected objects. Visual intersections do not connect roads or shorten routes. Named junctions connect required objects at forks. Disconnected crossings are marked with wooden overpasses. Full road rings are no longer drawn automatically around buildings; only required approaches appear. Instructions show on first editor opening; **?** reopens them.

The in-game editor places buildings and road junctions on cells, connects point pairs, moves/deletes objects, undoes changes, and exports/imports map codes. Incomplete maps can be edited freely. Play/save validation covers bounds, occupied cells, road endpoints, one castle per side, and connectivity of all buildings. Custom maps can be played against AI. Unpublished Studio saves maps only for the current session; map codes transfer manually between runs. DataStore is prepared for the published game and still requires validation there.

## Starting forces

| Building | Starting population |
| --- | --- |
| Each side's castle | 50 defenders and 20 peasants |
| Neutral village | 8 peasants |
| Neutral barracks | 12 defenders |
| Neutral archery range | 12 archers |
| Neutral camp | 12 fast fighters |
| Neutral tower | 15 archers |
| Owned farm near each castle | 0 people |

Neutral buildings produce no reinforcements until captured.

## Population and upgrades

Villages produce only peasants. Barracks and castles produce defenders; archery ranges and towers produce archers; camps produce fast fighters. Military buildings produce slowly; villages are the main source of reinforcements.

Intermediate neutral/enemy buildings cannot be crossed until capture. Routing searches for an alternative; if none exists, reject with an explanation. The final target may be hostile; junctions need no capture. Players, AI, and route highlights use the same rule.

Peasants automatically become warriors when they reach the **final** owned military building. There is no training queue. During food shortages, they wait as peasants until food becomes available. Passing intermediate buildings does not change type. Trained defenders, archers, and fast fighters never retrain. Peasants arriving at villages or farms remain peasants.

| Property | I | II | III |
| --- | --- | --- | --- |
| Cost to reach this level | Starting level | 50 people | Another 100 people |
| Upgrade time | — | 6 s | 10 s |
| Village: 1 new peasant | Every 5 s | Every 3 s | Every 2 s |
| Military building: 1 new warrior | Every 20 s | Every 15 s | Every 12 s |
| Ordinary building capacity | 80 | 160 | 260 |
| Castle capacity | 120 | 240 | 400 |
| Tower capacity | 60 | 140 | 220 |
| Ordinary damage reduction while defending a building | 0% | 10% | 20% |

Upgrade costs come from the local garrison: peasants first, then fast fighters, defenders, and archers. Production pauses during upgrades. Capture cancels unfinished upgrades while preserving completed levels. Capacity is strict at the user's choice: production stops at the limit and reinforcements wait outside. Waiting units enter and disappear from the map as places open. Peasants train only after entering the final military building. Warriors outside continue consuming food and can be sent onward. The panel shows garrison and waiting counts separately.

## Food and farms

Each side begins with 100 food and one owned farm behind its castle.

| Farm level | Food every 5 seconds |
| --- | --- |
| I | 10 |
| II | 15 |
| III | 20 |

Farms produce only food, not people. Arriving peasants remain peasants and can pay for farm upgrades at the ordinary 50/100 cost.

Every living warrior consumes 1 food every 30 seconds in garrisons and while marching. Peasants consume none. Shortages stop creation and training of new warriors; existing units survive, and peasant/food production continues. Food never drops below zero.

## Combat and towers

Defenders and fast fighters follow roads in orderly four-wide formations. Peasants form behind all melee fighters even when the last soldier row is incomplete; only archers move freely through formations. Column spacing is 1.15 studs and row spacing 1.4 studs. The slowest formation member sets overall speed. Turns rotate rows together; different columns do not block each other. Formations narrow to two columns before bridges and widen after the final row passes. Groups containing only fast fighters retain 12 studs/s speed.

When two sword groups collide, all four front-row pairs fight simultaneously, or two on bridges. Each pair loses one fighter per side per swing. In incomplete front rows, available pairs fight. Melee fighters approach near-contact range: 0.85 studs with a small tolerance. The front row visibly swings every 1 second; casualties occur 0.25 seconds afterward. Rear rows follow the actual front row and fill vacant positions.

Columns are retained during combat. Groups follow their original road and its turns instead of straightening across the map along one axis. At corners, opposing front rows align so outer fighters also participate. The nearest two rear rows smoothly connect that front to the remaining formation on the road; distant rows retain routing and 1.4-stud path spacing. The next four move into casualties' positions at normal speed. Groups approach building entrances or tower siege range; survivors continue after combat. A lone field archer remains reachable even by a wide formation.

Large groups leave building doors gradually and assemble on the road. Waiting units stay inside the garrison, occupy capacity, and consume food; they cannot be sent twice. Protected archers given an order also disappear into the building and emerge from its front door.

When defending, swordsmen, fast fighters, and peasants stay in the hidden garrison. When enemies reach the entrance, melee fighters exchange casualties with the garrison: up to four pairs per swing, retaining the previous interval and delay. Peasants retain their weak attack. Ordinary-building archers are visible behind the model and tower archers on the roof; they cannot be attacked directly until the building falls. Once other defenders die, an approaching group captures an ordinary building and its remaining protected archers die. Field archers can hit hidden ordinary-building defenders. Towers must first be destroyed under existing durability rules; their melee garrisons also exchange contact casualties with attackers. Ruins produce no warriors until rebuilt.

Each archer fires every 2 seconds for 25 health damage. Health: peasants 30, archers 45, fast fighters 60, defenders 100; defender shields reduce arrow damage by 35%. Healthy units survive the first hit. In-flight damage is considered when selecting targets to avoid wasting arrows on doomed enemies. Field archer range is 22 studs. Archers follow their road until within range, stop, and fire. They do not retreat. Their movement is free through melee formations. A swordsman kills a field archer with the first melee swing. Arrows still deal 2 structural damage to towers.

In mixed groups, archers do not overtake the front melee row and stay one existing row interval, 1.4 studs, behind it. They still pass freely through rear rows. If there are no melee fighters initially, or all die, archers continue independently; an empty formation does not hold them. Corners use path distances without segment-change jumps.

Peasants retain their weak melee attack from the previous prototype. Their main role is population for production and upgrades.

Towers have separate durability of 100. Sword hits deal 5 and arrows 2; upgraded tower defenses reduce incoming damage. Intact structures protect the garrison with walls. Archers fire from the tower without entering the road.

| Tower | I | II | III |
| --- | --- | --- | --- |
| Archer range | 26 | 32 | 38 studs |
| Archer firing interval | 2 s | 1.8 s | 1.6 s |
| Structure defense | 0% | 10% | 20% |

Destroy the tower first. At zero durability, it becomes ruins and its garrison is destroyed. An approaching group then occupies it: ownership changes and durability returns to 100. The old separate building volley is replaced by fire from archers inside.

## Menus and controls

The start menu contains Play, editor, and settings. Play offers Vs AI or With Player. AI provides map selection and three difficulties. Hard AI attacks and intercepts supply more actively. Published public lobbies share MemoryStore matchmaking: pairs transfer to reserved servers with random base maps, while AI gets a separate one-player server. PvP starts after both participants load and has no bot; leaving awards the opponent a win. Return leads to the public lobby. Studio uses local validation because real teleports are unavailable there. Settings and calm medieval music are retained.

All modal backdrops cover the entire screen, including the top region and areas around phone safe insets. Upgrades replace the entire level model; 21 building variants were created in Blender, transferred to Roblox, and aligned to ground level.

Colors are relative to the player: friendly buildings/troops blue, enemies red, neutrals gray. Capture changes platform, outline, flag, and population colors.

The top bar was removed. A three-line button at the top left opens the menu. Resources, peasants, time, and bridge status are at the bottom left without a total army counter. On phones, **i** toggles this information. PC uses an enlarged bottom-center slider; phones retain a compact building panel.

Selecting a building opens a compact panel: name and level, garrison counts by unit type, capacity and outside waiting count, a 0–100% send slider, and upgrade cost. Default is 50%. Phones include an order-mode button. The chosen percentage of each available unit type is sent.

PC:

- Left-click selects a building for inspection and orders; right-clicking a target sends troops.
- Shift + left-click adds/removes an owned building from the group. Box selection selects several owned buildings.
- WASD pans, the wheel zooms, and the middle mouse button drags the map.
- Esc clears selection, then opens the match menu.

Phone:

- Tap selects a building. Tap **Order →**, then a target to send people.
- Holding selects a building without sending troops.
- One-finger dragging pans; pinching zooms.
- The slider and upgrade button have enlarged touch areas. Moving a finger across the map does not issue accidental orders.

## Validation

Roblox Studio checks cover routes and map-schema errors; instant training and trained-unit type preservation; training suspension during starvation; food consumption; farm levels; upgrade prices; mutual sword casualties; archer firing interval and no retreat; tower destruction/capture; protected garrison fire; AI development; and victory rules. An additional battle tests 50 archers against 100 defenders.

Desktop menus and actions are tested through the real Studio Play UI. Phone layout and basic touch actions are tested in the phone emulator. Physical-phone and published-game validation remain pending.
