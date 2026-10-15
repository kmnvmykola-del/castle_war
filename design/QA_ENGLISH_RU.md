# English version — validation results

Date: October 5, 2026. The user requested translating the ENTIRE game into English and preparing a Roblox description.

## Completed

- Translated 404 unique fragments across 17 game modules: menus/settings, combat/results, profile/leaderboards, Inventory/Shop/Chests, editor/tutorial/import, map names, all 25 sets, troop/building types, server/persistence/matchmaking/connection/purchase messages, and model-loading errors.
- Menu title: Frontier Kingdoms. Mythical sets: Storm Knights, Dragon Order, Star Keepers.
- AutoLocalize=false on KingdomsUI and KingdomsOverlay preserves the English game interface under automatic Roblox translation.
- Player-entered map names and player names remain user data. System menus, purchase dialogs, and game pages belong to Roblox and are not translated by game code.
- English descriptions for the game, three passes, and coin packs are prepared in `design/ROBLOX_LISTING_EN.md`. Nothing was published to Roblox.
- `inex.rbxl` was rebuilt from sources. Pretranslation backup: `build/inex-before-english.rbxl`.

## Validated

- All 826 sources compile using the official Luau CLI.
- All 46 scenarios passed: 17 progression/online, 13 economy, 13 inventory/shop separation, and 3 English UI checks.
- `tools/check_english.py`: zero Cyrillic fragments in source files or embedded Sources; zero Cyrillic static Text/PlaceholderText/ToolTip/Name values; all 826 Sources match their source files.
- Reports: `build/english-audit-report.json`, `build/inventory-qa-report.json`, `build/inventory-save-report.json`.

## Validation limits

CLI builds real UI.Build/MetaUI/CollectionUI on mock Roblox objects and simulates mesh loading. It validates content/behavior, not live rendering quality.

Live Studio Play showed the updated main menu: Frontier Kingdoms, Play, Map Editor, Profile, Inventory, Shop, Leaderboards, Settings, and English control hints; the standard player list showed Level/Wins/Rank. Full visual validation of other pages did not finish because the tool refused input after detecting manual user input. Overall studioRenderVerified remains false; observing the main menu does not validate all pages or meshes.

Robux sales require a published version and real GamePassIds/ProductIds; these currently equal 0. The agent did not publish this version. Real purchases, DataStores, and cross-server transfers were not tested in this session. No physical phone was tested.

Roblox documentation: [AutoLocalize](https://create.roblox.com/docs/reference/engine/classes/GuiBase2d), [source language](https://create.roblox.com/docs/production/localization).

