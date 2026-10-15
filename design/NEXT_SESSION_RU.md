# Frontier Kingdoms — Release 0.16 status, October 6, 2026

## Game and files

PlaceId `81963222072062`, UniverseId `10769541065`. Owner: kolian / Robloxian547270901, UserId `1148782214`.

Version 0.16 was published to the existing game from Studio on 2026-10-06 at 16:13:37 UTC. Creator Hub retains Public access and Strategy without a subgenre; Roblox restricts the audience to users aged 16+ and trusted friends. Mesh / Image APIs is unnecessary and disabled. Do not require documents for this implementation. Game: https://www.roblox.com/games/81963222072062/Frontier-Kingdoms .

Canonical files `inex.rbxl`, `FrontierKingdoms-installed.rbxl`, and `build/release/FrontierKingdoms-launch.rbxl`: 3,216,913 bytes, SHA-256 `2aa3bc738fa324ebfb97afabe5931bf3ea7b59d49e6397e72110f3892510055e`. Downloaded from Studio through Download a Copy and validated with `tools/verify_installed_place.py`: 26 active Sources exactly match src, 1,969 MeshParts have real IDs, 978 archived Sources remain, archived executable scripts are disabled, and Geometry is absent from the active root. Old v12 is retained in `build/release/inex-before-launch.rbxl`.

## Latest changes

- All building levels and ruins face their doors toward the camera (`Config.BuildingYaw=math.pi`). Door offsets and Z reflection during pivot/bounds import were fixed. Verified in real Play by sending 36 fighters from the castle and capturing a village.
- Premium Storm / Dragon / Oracle were completely rebuilt in Blender: new armor silhouettes, helmets, cloaks, weapons, shields, roads, and gates. These are cosmetic changes; combat statistics remain unchanged. Blue/red team elements are separated from colored metal/gems.
- Storm: silver lightning armor, winged helmet, golden channels, and raised road slabs.
- Dragon: overlapping green scales, horned helmet, cloak wings, and road fangs/claws.
- Oracle: split purple robe, star halo, celestial road medallions, and star portal.
- Active is explicitly enabled on shop/inventory/profile/editor ScrollingFrames. Real phone emulator: scrolling moved Shop.CanvasPosition from 0 to 328; purchase buttons and coin packs are visible. No physical phone was tested.
- Inventory shows only owned sets; shop contains offers and purchases. English UI, client-local music/FX, independent volume, tutorials, and retained mechanics behave as before.

## Models and rebuilding

`assets/blender/v016/premium/premium_v016.blend`, with geometry.json, FBX, and PNG alongside. Blender 4.5.0: `build/blender-runtime/blender-4.5.0-windows-x64/blender.exe`. Authored export: 90 models, 54,576 triangles. Full catalog: 806 models / 1,969 MeshParts, CatalogSignature `bd3872582d1ecc17ef2dc3f9462869bd729e5dc61cacb224b93bb909b98925a9`.

`tools/build_premium_v016.py` → export_premium_v016.py → export_static_meshes.py → pack_premium_v016.py / pack_static_mesh_setup.py. Small Storm/Dragon/Oracle glTFs are already imported and uploaded to Roblox. Do NOT repeat imports or installers. Packages were rebuilt after the last UI change. `tools/stage_visual_sources.py` prepares a six-module update with backup; it has already been applied.

Premium installation archive in ServerStorage: `KingdomsBeforePremium16_06382e81-f724-49b2-ae14-b14263e9196b`, containing previous roots, imports, installer, and disabled native QA. KingdomsBeforeFacingFix folders retain previous Sources. No temporary active QA scripts remain.

Use `tools/sync_place.py` for source synchronization: it updates active roots while preserving archives, MeshIds, and properties. Do not overwrite the new inex.rbxl with an old Studio copy.

## Monetization

Sales, images, and prices are created and enabled:

| Product | Roblox ID | Price |
| --- | --- | --- |
| Storm | GamePass 2006883740 | 199 Robux |
| Dragon | GamePass 2005989756 | 399 Robux |
| Oracle | GamePass 2005239786 | 699 Robux |
| 500 coins | Product 3716851182 | 49 Robux |
| 1,500 coins | Product 3716851330 | 129 Robux |
| 3,500 coins | Product 3716851499 | 249 Robux |

The server verifies pass ownership; ProcessReceipt atomically saves coin grants and rejects duplicate receipts. UI requests actual Roblox prices. Robux purchases are intentionally disabled in Studio. Owners naturally own their passes; validation neither granted free sets to others nor spent Robux. Real charges and receipt restoration on a published server remain untested.

300-coin cases: Common/Rare/Epic/Mythic 60/30/9/1%. Storm/Dragon/Oracle 0.5/0.3/0.2%; all 24 outcomes are shown. PolicyService blocks random purchases on restriction or response failure. Do not change agreed values without the user.

## Audio and website

All 10 original recordings are uploaded to Roblox and confirmed IsLoaded on both real clients: Menu 119718967994975, Battle 124112194729458, Click 120162779880223, Select 124159972087187, Order 123835389545068, Place 112056872756115, Error 82716831723745, Chest 123191148517154, Victory 83900946007025, Defeat 115137529677758. Client PlayLocalSound and Music/FX groups isolate other players' clicks.

Published gallery: https://frontier-kingdoms-sound-library.kmnv-mykola.chatgpt.site . Site access currently allows the owner, not all visitors. Sources: `audio-site`, commit `6cf6464ec2180008b542d11d011a11393a7f89db`, deployment `appgdep_6ac51279cce481919d5e352f1247b0e4`. Do not republish without changes.

## Presentation and videos

English title and description are saved in Creator Hub. The icon and 3 previous covers remain. New gameplay/editor PNGs in `assets/promo` were captured from v0.16. The Roblox trailer uploaded successfully: Creator Hub showed "Video under review", with 2 of 3 uploads remaining. Do not resubmit. A new gameplay PNG was submitted to the Thumbnails uploader, but Save Changes has NOT been clicked. Editor PNG has not been submitted. The user stopped control with physical Esc; perform no further UI actions in that turn. Continue only with new authorization. Previous covers were not deleted.

Videos using real v0.16 footage and original music are ready:
- `build/release/Frontier-Kingdoms-Shorts.mp4`: 29 seconds, 1080x1920, 30 FPS. Illustrative key art appears at the beginning and end.
- `build/release/Frontier-Kingdoms-Roblox-Trailer.mp4`: 30 seconds, 1920x1080, real gameplay footage.
- `build/release/PROMO_POST_EN.txt`: social caption and link.

Both MP4s were fully decoded by FFmpeg without errors. TikTok/YouTube uploads have not happened because the user has not selected a channel. Do not choose another/random account or start paid advertising.

## Validation and explicit limits

90 CLI scenarios PASS; 832 embedded sources compile. Full geometry validation PASS. `build/inventory-qa-report.json`, `build/installed-place-qa-report.json`, `build/release/native-release-qa.json`, `build/release/native-premium-qa.json`.

Two real clients: friendly Blue63, enemies Red63, Scene errors 0; all 10 audio assets loaded, and different volumes stayed local. This tested previous code 0.15; version 0.16 network logic was unchanged. New native 0.16 validation covered 24 fighters across three skins and both teams; 142 unique premium assets loaded without errors, and all model orientations/parts were checked. Play covered three previews, roads/gates, combat with door exits and capture. Editor PlaceVillage/Undo had no noticeable pause; mobile Shop scrolling works.

Do not claim validation of real payment, published DataStore on rejoining, global matchmaking/cross-server transfers, or a physical phone. The public page opened and showed Mild / Ages16+, Strategy, and Play. Clicking Play in IAB showed "Roblox is now loading", but Roblox Player launch was not confirmed; no live public client was tested. User Esc stopped further validation. Public page screenshot: `build/release/public-game-page.png`. Earlier simulation results were deliberately distinguished from real Studio.

## Preferences and tools

The user explicitly authorized the current Studio work and game publication. Prefer files/APIs where possible to avoid interfering with the PC; PC control is currently authorized. After Esc, stop control until new authorization. Discuss new mechanics/prices first. Use Blender for models. Do not test every resolution. **Do not delegate to subagents without a request.**

Python: `C:/Users/Kolia/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe`, run with `-B -Xutf8`. Windows UI: computer-use skill and @oai/sky only. Creator Hub: IAB browser, owner account authorized; do not enter passwords/documents. The user requested no root GitHub/PR/commit operations. The website uses a separate authorized Sites workflow.
