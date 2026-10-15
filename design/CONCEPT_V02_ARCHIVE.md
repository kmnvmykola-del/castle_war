# Frontier Kingdoms — Concept 0.2

Date: October 4, 2026. The working title may be changed.

Status: the user approved concept 0.2 and authorized the first prototype. Agree on new mechanics and rule changes with the user first.

## 1. User requirements already established

- Platform: Roblox.
- Starting point: LandGrabbers and similar games; combine compatible ideas into an independent game.
- World: medieval with a little magic.
- Graphics: full 3D, moderately stylized.
- Workflow: design → approval → game implementation.
- Villages are the main population source. Military structures slowly produce fighters and train arriving peasants.
- Each participant should have time to capture 3–4 villages at the start.
- Upgrading to level two consumes 50 people; level three consumes another 100. Relevant building statistics improve with levels.
- Mixed armies: defenders, archers, and fast fighters; an example desired battle is 50 archers against 100 defenders.
- Create models in Blender and transfer them to Roblox. The existing `inex.rbxl` is the main project file.

The user approved the concrete speeds, statistics, training queue, preparation minute, and initial layout below. Starting garrisons were also approved: each castle has 50 defenders and 20 peasants; neutral villages have 8 peasants; barracks, archery ranges, and camps have 12 fighters of their type; towers have 15 archers. The bot is challenging, actively attacks/intercepts supply, and receives no free resources.

## 2. Games researched and conclusions

Research used official developer and publisher descriptions. This analyzes those materials rather than claiming personal playthroughs. Proposed adaptations and assessments are our design conclusions.

| Game | Confirmed idea | Proposed adaptation |
| --- | --- | --- |
| LandGrabbers | Army-based building capture, sending half a garrison, upgrades, defense towers, stables, arsenals, artifacts | Core: buildings produce troops; attacking weakens the home garrison; specialized structures affect tactics |
| Mushroom Wars 2 | Short RTS battles, heroes with special abilities, campaign, up to four players and 2v2 | Later add commanders, team battles, and a campaign with special objectives |
| Galcon Fusion | Quickly sending large groups between points; solo and team modes | Fast orders and coordinated attacks from several fortresses |
| Auralux: Constellations | Simple RTS foundation, gradual mechanics, fog of war, moving planets, wormholes | Introduce one map feature at a time: crossings, mountain detours, then fog and rare portals |
| Tentacle Wars | Line-based links, continuous energy transfer, link management and disconnection | Automatic reinforcement between owned buildings with a mandatory garrison reserve; cancel a line with one action |

Sources:

1. [Nevosoft: LandGrabbers, press kit](https://iphone.nevosoft.com/games/landgrabbers/presskit).
2. [Mushroom Wars 2: publisher description on Steam](https://store.steampowered.com/app/457730/Mushroom_Wars_2/).
3. [Galcon Fusion: official website](https://www.galcon.com/fusion/).
4. [Auralux: Constellations: publisher description on Steam](https://store.steampowered.com/app/444130/Auralux_Constellations/).
5. [Tentacle Wars: FDG Entertainment description on Google Play](https://play.google.com/store/apps/details?id=com.fdgentertainment.tentaclewars.gp.free&hl=en).

Build our game around compatible mechanics, with original title, models, maps, interface, characters, and music.

## 3. Game idea

Players lead a small kingdom fighting for villages, military structures, and routes between them. Villages supply population; players send peasants to military buildings to become defenders, archers, or fast fighters. Trained troops physically follow roads, collide, and fight. Towers cover approaches; rare commander abilities may follow later.

The central decision is: improve production, retain defenders, or send the army now?

Proposed distinction: route control. Important locations have a short dangerous route and a longer alternative. The selected route is visible before confirming orders. Victory depends on numbers, timing, and army position.

## 4. One match

1. Each participant starts with a castle and identical garrison. Their starting area has four neutral villages and accessible military structures.
2. Central crossings remain closed for 60 seconds. Participants capture 3–4 villages, choose their first military buildings, and arrange supply.
3. Players send population to barracks, archery ranges, or fast-fighter camps and decide whether to spend 50 people on a level-two building.
4. Crossings open, starting the struggle for towers, supply routes, and enemy military structures.
5. Players assemble mixed groups, exploit troop strengths, and decide when to invest 100 people in level three.
6. Players receive match results and rewards for participation and achievements.

Target duration for an ordinary population-and-training match: 10–15 minutes; tutorials are shorter. This guides future testing rather than promising finished balance. Preparation counts toward match duration. Initially propose the preparation minute as the main-map rule; a separate fast mode could omit it.

Proposed first-prototype defeat rule: no remaining buildings or living groups on the map, including peasants. Losing the starting castle alone does not end the match. The last participant with forces on the map wins.

For prolonged matches, later discuss time limits and transparent scoring. Control-point modes will have separate victory rules.

## 5. Controls and camera

Recommendation pending user choice: angled overhead camera with zoom and map panning. The world is fully 3D, and the camera keeps buildings and armies clearly visible.

- Select an owned building → choose a target → send a group.
- Default send amount is 50% of the selected garrison composition. Additional options: 25%, 75%, and 100%.
- Choose the sent composition: all, peasants only, defenders, archers, or fast fighters. Orders show exact counts by type.
- PC supports multiple-building selection; phones select sources sequentially.
- Troop counts and their route are visible before issuing orders.
- Automatic supply: an owned village periodically sends peasants to a selected military building while retaining a specified reserve. Owned military buildings can send trained reinforcements to one another. Ownership changes at either endpoint disable the automatic line.
- Orders can be canceled while selecting. After dispatch, the first version takes troops to their destination; discuss redirection separately.

A directly controlled field character is outside the current recommendation. Choosing a hero or mixed control requires reconsidering camera, combat pace, and interface.

## 6. Army, capture, and progression

### Population and training

Villages produce only peasants. Castles, barracks, archery ranges, camps, and towers slowly recruit their own fighters. A peasant arriving at an owned military building enters its training queue. One peasant becomes one fighter; training does not add another person.

Barracks/castles train defenders, archery ranges/towers train archers, and camps train fast fighters. Trained fighters retain their type when entering other buildings. Reversion and free retraining are not proposed for the first version.

| Parameter | Level 1 | Level 2 | Level 3 |
| --- | --- | --- | --- |
| Cost to reach this level | Starting level | 50 people from the garrison | Another 100 people from the garrison |
| Village production | 1 peasant / 5 s | 1 / 3 s | 1 / 2 s |
| Independent military recruitment | 1 fighter / 20 s | 1 / 15 s | 1 / 12 s |
| Training arriving peasants | 1 fighter / 3 s | 1 / 2 s | 1 / 1.5 s |
| Additional garrison defense inside buildings | 0% | 10% incoming damage reduction | 20% reduction |
| Village / ordinary military building capacity | 80 | 160 | 260 |
| Castle capacity | 120 | 240 | 400 |
| Tower capacity | 60 | 140 | 220 |

Capacity includes trained fighters, peasants, and the training queue combined. Independent recruitment stops when full. Excess arrivals cannot hide inside: they remain a visible friendly group at the entrance, vulnerable to attacks, and can be sent onward. Training peasants already inside does not increase population.

### Upgrade expenditure

Level 2 requires at least 50 people in that building and consumes exactly 50. Level 3 requires at least 100 and consumes another 100. These are separate payments: level 1 to level 3 consumes 150 people total.

Peasants or fighters become a construction team and no longer fight. Peasants are used first by default; exact expenditure composition is visible before confirmation. If peasants are insufficient, the interface clearly shows which fighters will be spent. Separate gold, timber, and stone are unnecessary in the first version.

Upgrades take 6 seconds to level 2 and 10 seconds to level 3. Recruitment/training pause, while the garrison continues defending. Towers retain their old firing statistics until completion. Capture cancels unfinished construction without refunding spent people; the last completed building level remains.

### Troop composition — initial test values

The following statistics are proposals for the future prototype and have not yet been tested in the engine.

| Type | Health | Damage per hit | Attack interval | Speed, studs/s | Range, studs | Role |
| --- | --- | --- | --- | --- | --- | --- |
| Peasant | 30 | 3 | 1.5 s | 8 | 2 | Population, training, construction; weak self-defense |
| Defender | 100 | 12 | 1.2 s | 6 | 2 | Front line and capture; shield reduces arrow damage by 35% |
| Archer | 45 | 10 | 1.5 s | 7 | 22 | Ranged attacks; vulnerable once enemies close in |
| Fast fighter | 60 | 8 | 1 s | 12 | 2 | Flanking, peasant interception, archer attacks |

Defenders are stronger in melee; fast fighters reach archers more effectively; archers are useful behind friendly defenders. Peasants can resist a small group, but military training greatly improves combat usefulness. Account level grants no permanent troop bonuses.

### Combat and capture

The simple "30 minus 20 equals 10" rule is replaced by individual health, speed, and range. Hostile groups fight when they meet on roads. Defenders lead mixed groups; archers stay behind. Attacks are automatic; endless automatic archer retreat is not proposed.

Garrisons meet attackers near their building with its defense bonus, which ends when defenders enter the road. Defender shields and building bonuses apply sequentially rather than adding percentages: at level 3, for example, arrow damage is multiplied by 0.65 × 0.8.

Buildings are captured when the previous garrison is destroyed and at least one living attacker arrives. Queued peasants count as garrison and defend using their weak statistics. If both sides lose every fighter simultaneously, the original owner retains the empty building. The defeated garrison's queue is cleared; victorious warriors retain their types.

50 archers versus 100 defenders is a possible battle composition. On an open road, expect the 100 defenders to have an advantage: they withstand arrows and win after closing in. Friendly tower support, other infantry, and distance alter the outcome. The exact result will be tested in the prototype, not promised beforehand.

Capture changes ownership of an existing structure. Free-form city construction and siege engines are left for future additions.

## 7. Buildings in the full concept

| Structure | Proposed role | Introduction stage |
| --- | --- | --- |
| Castle | Large garrison, slow defender recruitment, peasant training | First prototype |
| Village | Fast peasant production for supply and upgrades | First prototype |
| Barracks | Shielded defenders; slow recruitment and peasant training | First prototype |
| Archery range | Archers; slow recruitment and peasant training | First prototype |
| Camp | Fast fighters; slow recruitment and peasant training | First prototype |
| Watchtower | Shoots passing enemies, slowly recruits archers and trains peasants | First prototype |
| Stable | Later unlocks mounted scouts or knights | Expansion |
| Smithy | Later provides local troop upgrades; needs separate balancing | Expansion |
| Rune sanctuary | Later accelerates commander ability recovery | Alongside commanders |

All first-version combat buildings slowly recruit troops independently. The smithy and sanctuary are excluded for now; agree on their roles and staffing when adding them.

Only watchtowers fire independently; other buildings defend with troops. Towers volley at up to three different nearest enemies while at least one trained fighter remains inside. Garrison size does not multiply the building's own volley arrows.

| Tower statistic | Level 1 | Level 2 | Level 3 |
| --- | --- | --- | --- |
| Damage per volley arrow | 12 | 16 | 20 |
| Range, studs | 26 | 32 | 38 |
| Volley interval | 2 s | 1.8 s | 1.6 s |
| Garrison defense | Base | −10% incoming damage | −20% |

Garrison archers use ordinary attacks; the building volley is separate limited support. Tower arrows respect defender shields. Neighboring tower ranges and time under fire will be tested on the first map.

Initially use garrison capacity and limited upgrade levels to prevent an accumulated advantage deciding matches too early. Do not automatically grant free armies to losing players. Test whether distances and alternate routes allow counterattacks.

## 8. A little magic

In the full concept, choose a commander with one active ability before a match:

- Warlord: briefly accelerates a selected group.
- Engineer: temporarily increases defense of an owned building.
- Mage: briefly slows enemies in a limited area.

All three are expansion proposals. First test population, training, mixed combat, and upgrades in the prototype, then add one speed boost. Abilities have visible cooldowns and cannot destroy an entire army in one click. Spells use short, readable effects.

## 9. Visual style

Fully dimensional fortresses, hills, trees, a river, and small groups with movement animations. Forms are slightly simplified; soldiers have near-normal proportions with somewhat more visible helmets, shields, and banners.

- Recognizable stone and timber, large details, and restrained textures.
- Natural colors: greenery, sandstone, wood, and cool stone.
- Army colors read through flags, shields, roofs, and markers; distinct emblems help identify teams.
- Soft lighting; short hit and magic effects.
- Tree canopies and high walls do not obscure important garrisons from the main camera.
- Upgrades visibly add a turret, wall, roof, or banner.

The map diagram in chat illustrates object placement and tactical roles. It is not an approved final-graphics reference.

## 10. First main map: Two Crossings

This layout replaces the eight-building version 0.1 diagram. Total: 18 structures:

- One castle per side — 2.
- Four neutral villages in each starting area — 8.
- Barracks, archery range, and fast-fighter camp on each side — 6.
- Two neutral watchtowers beside central crossings — 2.

Northern and southern crossings connect the banks, with towers covering approaches. Starting sides have mirrored opportunities. Neutral military structures are captured like villages but have stronger garrisons. Starting troops are designed to establish the economy; exact neutral counts will be chosen during map testing.

Visible gates with a countdown block access to the opponent for 60 seconds. Movement/capture within each starting area are immediately available. Once opened, gates stay open. This gives time to capture 3–4 villages without early enemy attacks; villages are not automatically awarded.

Players choose whether to hold one crossing, expand to the second, or launch opposing attacks. Slow tower recruitment cannot fill a large garrison; supplying towers from villages and military buildings is worthwhile. Fast fighters can intercept peasant groups on roads.

Crossings are road sections, not separately capturable buildings. Passage does not require owning the neighboring tower, but enemies can attack passing groups. Bridges cannot be destroyed on the first map.

Later maps: a mountain pass with a long detour, islands with several bridges, and a winter map. Portals and fog of war are separate expansions after the core routing system.

## 11. Modes and between-match progression

Recommended stages:

1. Tutorial and one-bot battles.
2. 1v1 duels after rules and controls are validated.
3. Two-player co-op against bots and 2v2.
4. A small campaign with new map conditions, then challenges and control points.

Between matches, unlock new maps, alternative commanders, army appearances, flags, and castle ornaments. Competitive unlocks must not grant permanent strength increases based on account level.

If monetization is needed later, propose skins, banners, and victory emotes. Monetization decisions are unnecessary for the current design.

## 12. Decisions before development

- Are training queues acceptable: one peasant → one specific fighter?
- Approve spending 50 people for level 2 and another 100 for level 3, prioritizing peasants.
- Approve initial production/training rates and troop/tower statistics as starting test balance.
- Are 60 seconds of preparation and four available villages per side acceptable?
- Approve mixed battles with range and health; numerical advantage alone does not determine results.
- Camera recommendation remains angled overhead command, zoom, and convenient PC/phone orders.

After this version is approved, start the first prototype without requesting approval for the same scope again: one 18-structure map, one bot, peasants and three combat types, six building types, training, mixed combat, capture, three upgrade levels, and a clear interface. Commanders, cavalry, smithies, and additional modes remain later stages.

## 13. Roblox file and Blender

Develop in the existing `C:/Users/kolia/Desktop/roblox-real-good_project/inex.rbxl`, the main Roblox project file. Design documents and working model sources may occupy separate folders; they are not additional Roblox places.

Create buildings, environment assets, and all four unit types in Blender. Maintain consistent scale, moderately stylized proportions, and readable silhouettes. Buildings need details added at levels 2 and 3. Units need movement, melee or firing, hit, and defeat/disappearance animations.

Export Blender models as FBX or glTF; import into Roblox Studio and check scale, materials, pivots, collisions, and animations. Assemble the scene and connect gameplay in Studio. This workflow is supported by the official [Roblox Blender documentation](https://create.roblox.com/docs/art/blender).

Creating the first prototype is authorized. Agree on new mechanics, additional modes, and approved-rule changes with the user first.

