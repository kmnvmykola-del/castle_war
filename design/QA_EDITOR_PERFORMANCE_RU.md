# Editor latency fixes — October 5, 2026

Root cause was confirmed in code and reproduced: `MapEditor.Refresh` called full `Client.rebuild` even for tool/team/first-road-point selection. `Scene.Build` deleted the previous scene before building the next, after which `Art.Prune` freed its EditableMesh. Recreating models then iterated vertices/faces and called asynchronous AssetService APIs again. Reloading the test map recreated six geometry types.

Fixes:

- Editor geometry versions change only for map edits; tool/team/first-point selection and clearing selection update only UI and highlights.
- `Scene.SyncEditor` preserves grid, environment, unchanged buildings, and roads. New models are prepared before replaced objects are removed.
- Full scene changes retain live old clones until the new scene is ready, reusing shared geometry cache. Loading failures retain the old scene and clean up partial new objects.
- Validated map graphs are reused for road creation, moves, imports, and river changes. Refresh requests run sequentially if loading a new model type yields.
- Unused models are still released; the cache does not retain the entire skin catalog. Bridges and gates belong to the roads folder and are removed with it.

Validation: 826 sources compile and 54 CLI scenarios pass, including eight editor/cache/loading-error/gate checks. Reloading the test map creates zero new EditableMeshes after the fix. Placement, movement, roads, Undo, and deletion preserve unchanged buildings and grid objects. English auditing confirms all embedded sources match `src`, no Russian game strings remain, and all 803 geometry modules are preserved.

CLI uses Roblox substitutes and triangular models to count allocations. Results confirm eliminated repeated work, not FPS or actual-device latency. Checks: `tools/qa_editor_performance.luau`; original failing result: `build/editor-performance-before.txt`.

The main `inex.rbxl` is updated. Pre-fix backup: `build/inex-before-editor-fix.rbxl`. No publication occurred. Close the old Studio tab and reopen the file from disk.
