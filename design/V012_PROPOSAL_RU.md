# Approved and implemented update 0.12 rules

The user requested 25 attractive skins, updates to old army/building models, chests, and owned-road styling. After the user said "continue", the proposal below was accepted. This describes the implemented version, not a proposal awaiting approval.

- 25 complete sets total, including free Standard and the three previous sets. Each styles armies, bases, and owned roads without combat advantages.
- The three previous sets sell directly for 400 / 800 / 1,200 coins. The 21 new sets come from chests.
- A chest costs 300 coins and awards one random paid set not yet owned. Every remaining set has equal probability 1/N. Rewards and numeric probabilities are visible before purchase. No duplicates; purchasing closes when the collection is complete.
- Road styling appears only on owned-base connections without enemy/neutral intermediate controlled bases. Junctions inherit style only under unified ownership; contested shared segments remain standard. Capture/loss updates appearance while preserving the route graph.
- Armies vary helmet, shield, cloak, and weapon shapes, not just colors. Friendly/enemy markings remain.
- Previous models were updated in Blender, including all 21 building variants. Crests, roof ornaments, and paving were added. Detailed castle originals remain in Blender/FBX; reduced 8,000-triangle variants were exported for game levels II/III.
- Geometry loads on demand. Old previews are released on page changes and match start. Network snapshots apply sequentially while new models load.

Because coins are planned for Robux purchase, the server respects `PolicyService.ArePaidRandomItemsRestricted` under [Roblox Paid random items](https://create.roblox.com/docs/production/monetization/paid-random-items). Random purchases remain unavailable before permission or upon restriction. Real Robux sales are not connected: ProductIds remain 0.

Main file: `inex.rbxl`. Full list: `ALL_FEATURES_RU.md`; validation: `QA_V012_RU.md`; handoff: `NEXT_SESSION_RU.md`. Preupdate copy: `build/pre-v012.bin`; version 0.11 rules: `CONCEPT_V011_ARCHIVE.md`.
