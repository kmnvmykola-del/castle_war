# Frontier Kingdoms — Prototype 0.3

Date: October 4, 2026. Main game file: `inex.rbxl`. The working title is retained from the previous prototype.

This document supersedes version 0.2 where the user requested changes. The previous concept is retained in `CONCEPT_V02_ARCHIVE.md`. Agree on new mechanics and value changes first.

## World and objective

A Roblox RTS in a medieval world with moderately stylized 3D graphics. Models are created in Blender and transferred to Roblox. The setting allows some magic; spells have not been added yet.

Players capture villages, send population to military buildings, upgrade structures, and fight for roads. The bot uses the same economy without free reinforcements. Victory occurs when the opponent has no buildings or living people left, including peasants.

## Map and future editor

The first map is Two Crossings. Each side has a castle, owned farm, four neutral villages, barracks, archery range, and camp. Two neutral towers guard the crossings. Total: 20 buildings, 2 road junctions, and 36 road segments.

Bridges are gated for 60 seconds while sides develop their banks and capture 3–4 villages. Crossings then open. Bridges cannot be destroyed.

The map uses a 32-stud grid. Every building, including a castle, occupies one cell. Buildings and road junctions have cell coordinates and unique names. A road links two existing names. Visible roads, troop routes, and bridge positions use the same endpoints, with approaches reaching the crossings.

Validation checks field bounds, no two objects in one cell, and valid road endpoints. The shortest available route between buildings is chosen automatically. Only this foundation is prepared; the custom-map editor is the next separate agreed stage.

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

Upgrade costs come from the local garrison: peasants first, then fast fighters, defenders, and archers. Production pauses during upgrades. Capture cancels unfinished upgrades but retains completed levels. Overflow stays beside the building and can be sent onward.

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

Groups march along roads in four columns. Rear rows wait for front rows. Defenders and fast fighters use close-range swords; fast fighters retain their higher movement speed.

When sword groups collide, each side loses one fighter every 2 seconds. The front row visibly swings; casualties occur afterward. This pace gives archers time to participate.

Each archer fires every 2 seconds; a hit kills one enemy. Field archer range is 22 studs. Archers follow roads until within range, stop, and shoot. They never retreat. Arrows fly to targets; multiple arrows are not wasted on enemies already assigned a lethal hit.

Peasants retain their weak melee attack from the previous prototype. Their main role is population for production and upgrades.

Towers have separate durability of 100. Sword hits deal 5 and arrows 2; upgraded tower defenses reduce incoming damage. Intact structures protect the garrison with walls. Archers fire from the tower without entering the road.

| Tower | I | II | III |
| --- | --- | --- | --- |
| Archer range | 26 | 32 | 38 studs |
| Archer firing interval | 2 s | 1.8 s | 1.6 s |
| Structure defense | 0% | 10% | 20% |

Destroy the tower first. At zero durability, it becomes ruins and its garrison is destroyed. An approaching group then occupies it: ownership changes and durability returns to 100. The old separate building volley is replaced by fire from archers inside.

## Menus and controls

The start menu has Play vs AI and disabled Find Opponent · COMING SOON. AI offers easy, medium, and hard difficulties, and selection starts a match. Hard AI attacks/intercepts supply more actively. Online matchmaking is not implemented yet.

Building selection opens a small panel: name/population, a 0–100% send slider, and upgrade cost. Default is 50%. There are no separate composition, route, reserve, or supply controls. Send the chosen percentage of each available type.

PC:

- Click an owned building to select a source; click a target to send a group.
- Shift + click or holding selects another source. Clicking the selected building again clears selection.
- WASD pans, the wheel zooms, and the middle mouse button drags the map.
- Esc clears selection. Right-clicking a target also sends troops from the selected source.

Phone:

- Tap a building to select a source; tap a target to send people.
- Holding selects another source.
- One-finger dragging pans; pinching zooms.
- The slider and upgrade button have enlarged touch areas. Moving a finger across the map does not issue accidental orders.

## Validation

Roblox Studio checks cover routes and map-schema errors; instant training and trained-unit type preservation; training suspension during starvation; food consumption; farm levels; upgrade prices; mutual sword casualties; archer firing interval and no retreat; tower destruction/capture; protected garrison fire; AI development; and victory rules. An additional battle tests 50 archers against 100 defenders.

Desktop menus and actions are tested through the real Studio Play UI. Phone layout and basic touch actions are tested in the phone emulator. Physical-phone and published-game validation remain pending.
