# Version 0.10 validation — October 5, 2026

Main `inex.rbxl` saved: 1,475,971 bytes. All 66 embedded sources match `src`; service references/parents were checked. Previous game: `build/pre-v010.bin`; rules: `design/CONCEPT_V09_ARCHIVE.md`.

## Changes

Visible roads and routes share one physical network. Segments split at intersections and overlapping-section endpoints; intersections and T-junctions connect automatically. Junctions no longer force other roads around their cells. Disconnected-crossing wooden markers were removed, and editor instructions updated.

Intermediate-base capture gates remain at the user's confirmation. Enemy controlled approaches are closed; available outside detours are searched automatically. Ordinary shared streets past neutral buildings remain accessible. Repeated routing respects ownership: capture opens a path, loss closes it. Closed bridges and crossing-direction preferences remain effective.

## Validation

`tools/qa_v010.luau`: **8 of 8**, no failures.

- Barracks and archery range share the visible street formed by castle roads. Scenario route length decreased from 208 to 112 studs without visiting the castle entrance. Peasants train only at the final archery range.
- Four independent directions form a traversable intersection; T-junctions and overlapping sections connect without duplicate segments.
- Separate roads remain separate. Map validation/editor import accept maps connected only through visible intersections.
- Neutral/enemy intermediate bases block approaches; final targets remain attackable. Repeated routes are correct after capture/loss.
- An outside shared street stays accessible beside a neutral castle.
- All three base maps were checked across 380 directed building-to-building routes: each path segment exists in the visible network. Bridge closure and north/south crossing preferences were checked.

Previous `qa_gameplay`, `qa_v06`, `qa_v07`, `qa_v08`, all 12 `qa_v09` checks, and all 6 `qa_full` checks passed, including nine three-minute AI matches on every base map/difficulty. Retained behavior includes four/two-wide formations, four simultaneous corner combat pairs, archer movement, hidden building defense, strict capacity, and door exits.

In real Studio Play on one ordinary PC screen, a castle/barracks/archery-range scene was created. Left-click selected barracks; right-clicking the range sent half its garrison: 8 defenders and 2 peasants. Highlight and troops followed the shared street without entering the castle. All 10 arrived; two peasants became archers while defenders retained type. The scene had 23 road segments and no old disconnected-crossing markers.

Results: `build/qa-v010-report.json`. Changes affect `MapNetwork`, `Scene`, and `UI`; values, combat rules, and other game modules are unchanged. Stopping Play removed temporary scenarios; the export attribute was cleared and Studio left in Edit. Additional resolutions/devices were not tested at the user's request.
