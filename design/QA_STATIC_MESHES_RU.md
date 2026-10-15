# MeshPart transition validation — October 6, 2026

The transition was installed in real Roblox Studio and published to the existing **Frontier Kingdoms**, version **v12**. PlaceId: `81963222072062`, GameId: `10769541065`. Output at 09:18:38 UTC confirmed `Published new changes in "Frontier Kingdoms" to Roblox`.

## Models and local checks

The working catalog contains **1,984 ordinary MeshParts**: 803 source models, blue/red clothing variants for all 25 sets, and 23 gray parts for the standard neutral army. Art clones templates and retains joints and six-part character animation. Geometry is no longer created during gameplay or editor use.

`validate_static_meshes.py` compared all 587,404 nondegenerate source triangles with Blender JSON: positions, normals, vertex order, indices, and colors. All variants match; recoloring fabric preserves skin, armor, and weapons. 10,868 zero-area faces were removed. The full catalog with variants contains 1,291,748 triangles; this is catalog volume, not a single scene. GLB size is 52,927,828 bytes; glTF/bin match it exactly.

`run_local_qa.py`: **73 scenarios, 0 failures**; all 828 sources compile. Checks covered economy, purchases, separate Inventory/Shop, English UI, editor updates, both team colors for all sets, neutral army, local sound, and full and supplemental installation with rollback on errors. CLI uses mock MeshIds/CFrames; these are absent from the saved game.

## Studio validation

- Initial import was delayed by HTTP timeouts for three MeshParts. Reconfigure → Import in the same session retained successful uploads and finished with a green check mark.
- The first 1,961 MeshParts were installed, with previous game folders backed up in ServerStorage.
- The first match exposed an error: TeamKey supported blue/red colors but rejected gray neutral archers. 23 gray parts and a regression check for all four standard neutral army types were added. Previously uploaded models retained their IDs.
- The English menu loads; Play → Vs AI → Easy starts a match. A 35-fighter group reached and captured the neutral barracks. A repeated match showed no Kingdoms snapshot / Unsupported army team colour warnings.
- Inventory shows only owned sets; Shop shows offers and Coming Soon for unconnected Robux purchases. Dragon Order army, castle, and road previews were checked.
- UIGradient was removed from ViewportFrame because it darkened the rendered models. Models have normal brightness after the fix.
- Editor checks covered selecting a farm, placement, Undo, and placement again. FPS was not measured.

## Saving

`FrontierKingdoms-installed.rbxl` was saved by Studio through Download a Copy; `inex.rbxl` contains the same installed version. Size: 2,848,109 bytes. SHA-256: `d1a964eb22e8dd843257263466bed8c2b4be17d5152935cf43f1769609ce80a2`.

`verify_installed_place.py` read the binary: all 25 active Sources match `src/`, all 1,984 templates have real positive MeshIds, and Geometry is absent from the active folder. 860 archived sources are preserved; archived Script/LocalScript instances are disabled. In-memory synchronization preserves model IDs, all nonscript properties, parents, and archived Sources; obsolete Geometry is not reintroduced. `check_english.py` confirms there are no untranslated literals, Cyrillic text, or active-code mismatches.

Backup folders in ServerStorage:

- `KingdomsBeforeMeshImport_98f2443d-b844-40b1-8f03-93e77634d38a` — previous game roots and initial import.
- `KingdomsBeforeNeutralFix_870ea26e-633e-48e5-beb8-27ad7229206d` — Art/MeshCatalog before gray parts.
- `KingdomsBeforePreviewFix_dec2cb2a-c966-42fc-9a0a-9a0a4efa398f` — CollectionUI before the dimming fix.

Local copies: `build/inex-before-static-meshes.rbxl`, `build/inex-before-native-install.rbxl`. Reports: `build/static-mesh-qa-report.json`, `build/inventory-qa-report.json`, `build/installed-place-qa-report.json`, `build/native-studio-qa-report.json`, and `build/english-audit-report.json`.

## Validation limits

Studio validation covered one client and an AI match. Two real clients, sound isolation across two devices, FPS, published DataStores, and actual Robux transactions were not tested separately. Studio confirmed v12 publication; the external Roblox app was not launched in this session. Original music and Robux products still require their own AssetIds/GamePassIds.
