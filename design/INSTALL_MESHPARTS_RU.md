# Installing ordinary models — October 6, 2026

The transition is complete: all models are uploaded, installed, and published in Frontier Kingdoms, Roblox v12. The main `inex.rbxl` and separate `FrontierKingdoms-installed.rbxl` already contain real MeshIds. No reimport is needed for the current game.

The instructions below cover a new installation. The package contains 803 source models, blue/red variants of all 25 sets, and 23 gray neutral army parts: 1,984 MeshParts in total. Open the installed file to continue development. This implementation does not use Allow Mesh / Image APIs or document verification.

## 1. Open your game

In Studio, open the **existing published Frontier Kingdoms** to update. Stop Play if running. Do not create another game.

The installer updates code itself; do not save an old open Studio file over the updated local `inex.rbxl`.

## 2. Import models

Select **File → Import** and choose:

```text
C:\Users\Kolia\castle_war\assets\roblox_meshes\KingdomsMeshCatalogue.gltf
```

`KingdomsMeshCatalogue.bin` containing geometry is alongside it. Keep both files together. Select only `.gltf` for import.

Import settings:

| Setting | Value |
| --- | --- |
| Creator | Game owner or the group owning the game |
| Name | `KingdomsMeshCatalogue` |
| Upload to Roblox | Enabled |
| Add to Workspace | Enabled |
| Import Only As Model | Enabled |
| Merge Meshes | Disabled |
| Ignore Vertex Colors | Disabled |
| World Up | Top |
| World Forward | Front |
| Scale Unit | Studs |

Click **Import** and wait for upload completion. Catalog models share one location, so temporarily overlap in Workspace. The installer sets game positions and sizes. Do not rename individual MeshParts or import the catalog twice.

glTF, vertex colors, and these settings are described in the [Roblox importer documentation](https://create.roblox.com/docs/studio/importer). `Add to Workspace` when importing into a published game also grants the game access to uploaded models.

## 3. Add the installer

In the current Studio version, select **File → Import Roblox Model**, then:

```text
C:\Users\Kolia\castle_war\assets\roblox_meshes\KingdomsMeshSetup.rbxmx
```

`KingdomsMeshSetup` appears in Workspace. Its game Script/LocalScript instances are disabled; inserting the file does not automatically replace anything. Some Studio versions offer Workspace → Insert From File; the tested version 0.741 uses the File menu.

## 4. Install with one command

Open Studio **Command Bar** and run:

```lua
require(workspace.KingdomsMeshSetup.Installer).Install()
```

The installer validates all names and uploaded MeshIds, prepares new folders, then replaces game scripts. Incomplete imports, duplicate names, or unuploaded models stop installation before replacement. Errors during replacement restore previous game folders.

Successful installation creates `ReplicatedStorage.Kingdoms.MeshTemplates` and prints `Installed 1984 ordinary MeshParts` in Output. Previous game folders and the imported catalog are retained in `ServerStorage.KingdomsBeforeMeshImport_…`. Backup scripts are disabled, with their previous Disabled value stored in `DisabledBeforeMeshImport`. Player data and purchases are unchanged.

## 5. Validate and publish

Press **F5**. Check main-menu loading, match launch, Inventory/Shop models, and map editor. Check troop colors with two players: each sees friendly armies blue and enemies red. UI clicks should be audible only to the clicking client.

After validation, select **Stop → File → Publish to Roblox** for this same game. Then save a local installed copy through **File → Download a Copy** in the current Studio version; it contains real imported MeshParts and MeshIds. Choose a separate name such as `FrontierKingdoms-installed.rbxl` to preserve the prepared file and previous backups.

If a step fails, provide its Output error text. Do not rerun the installer after successful installation: it has already moved into backup.

On October 6, import was completed through Studio control at the user's request. After three parts timed out, Reconfigure → Import in the same session completed uploading. Gray parts were added through a separate small file without reuploading the 1,961 completed models. The match, collection, and editor were checked; the update was published to PlaceId 81963222072062, v12. Saving to Roblox and publishing are separate actions; Output must specifically confirm Published new changes.
