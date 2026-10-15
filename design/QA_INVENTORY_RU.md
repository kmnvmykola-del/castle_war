# Inventory and sets 0.13 — validation results

Date: October 5, 2026. The user approved both mythical acquisition methods, 300-coin cases, 199/399/699 Robux prices, and a combined mythical probability of 1%.

## Implemented

- Separate Inventory/Shop. Inventory has owned sets and equipment only; shop has 24 offers, prices/purchases, coin/Robux/unowned filters, and a mythical section. Owned offers lead to inventory. Set selections are independent between pages.
- Army, building, and road previews. Each owned set styles four unit types, all building types/levels, crests, roofs, and owned roads.
- 21 coin purchases; mythical Storm/Dragon/Oracle are prepared as three separate Game Pass purchases and case rewards with 0.5%/0.3%/0.2% probabilities.
- Fixed rarity probabilities 60%/30%/9%/1%; all 24 outcomes are disclosed before purchase with numeric probability and exact fraction.
- Duplicate refunds of 100/150/200/250 coins. Request/save retries do not double charges or refunds. Old chest records migrate without another charge.
- Server-side random-purchase restriction through PolicyService, pass verification through UserOwnsGamePassAsync, and ownership restoration on login/profile refresh.
- `inex.rbxl` was updated directly from sources; all 826 Sources match disk, including 803 geometry modules. Existing references, services, music, and properties were retained. Previous-file backup: `build/inex-before-inventory.rbxl`.

## Passed

`tools/run_local_qa.py` uses the official Luau CLI and Roblox test substitutes:

- Compilation of all 826 sources.
- 17 previous XP/rank/coin/leaderboard/queue/result/receipt scenarios.
- 13 new economy scenarios: every purchase, exhaustive enumeration of 84,000 probability tickets, boundaries, fixed odds, refunds, request/UpdateAsync retries, old data, insufficient coins, stale odds, save failures, full collection, pass ownership, and PolicyService.
- 13 scenarios using real MetaUI/CollectionUI builders with mock GUI objects: inventory/shop separation, unowned inventory rejection, currency/rarity filters, 75 asset-checked previews, grants/equipment, independent page selection, purchasing/owned-offer navigation, prices/restrictions, cases/duplicates, preview release, and errors.
- 3 English UI scenarios covering real UI.Build, editor/tutorial and all headings, dynamic profiles/rewards/cases, and automatic-localization blocking. The whole game is English; details: `design/QA_ENGLISH_RU.md`.
- `tools/validate_art_v012.py`: 25 sets, 803 models, 598,272 triangles, valid bounds, colors, indices, and animation pivots.
- Saved-binary validation: the full catalog is embedded, Sources match disk, and original parents are preserved.

Local reports: `build/inventory-qa-report.json`, `build/inventory-save-report.json`.

## Live validation still required

The main menu was observed in real Studio Play after English translation. Full visual validation of other pages did not finish; details: `design/QA_ENGLISH_RU.md`. CLI GUI checks model objects/states rather than render screens; EditableMesh creation is mocked. Previous 0.12 reports concern an earlier version and do not confirm 0.13 rendering.

The game is unpublished; GamePassIds for the three sets and coin-pack ProductIds equal 0. No actual Robux was charged. Sales require creating three passes after publication, setting separate IDs in `src/SkinStyles.luau`'s `premium` table, setting Roblox prices, and running `tools/sync_place.py`. Clients retrieve regional prices from Roblox. Real DataStores, teleports, PolicyService responses, and purchases require published validation.

Documentation: [passes](https://create.roblox.com/docs/production/monetization/passes), [regional pricing](https://create.roblox.com/docs/production/monetization/regional-pricing), [random purchases](https://create.roblox.com/docs/production/monetization/paid-random-items).
