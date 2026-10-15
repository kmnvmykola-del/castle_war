# Frontier Kingdoms audio — October 6, 2026

Two original compositions and eight effects were created through procedural synthesis in `tools/compose_audio.py`. Recordings use no third-party samples or existing melodies. WAV files are in `assets/audio/original`, with listening copies in `audio-site/dist/audio`. Format: stereo PCM, 32 kHz, 16 bit.

| Connection key | File | Purpose |
| --- | --- | --- |
| Menu | menu.wav | Frontier Dawn: menu, editor, preparation |
| Battle | battle.wav | March of the Banners: combat |
| Click | click.wav | Interface buttons |
| Select | select.wav | Building or troop selection |
| Order | order.wav | Sending troops |
| Place | place.wav | Map changes |
| Error | error.wav | Invalid action |
| Chest | chest.wav | Case result |
| Victory | victory.wav | Victory |
| Defeat | defeat.wav | Defeat |

All original `Id` fields in `src/AudioCatalog.luau` currently equal **0**. The game selects temporary Roblox assets; originals are available only as WAV files and on the website. Creator Hub login is needed to upload WAV files to the game owner's account and obtain IDs, because a local file is not a Roblox audio asset. Grant the game access to every uploaded recording. Roblox instructions: [Audio assets](https://create.roblox.com/docs/audio/assets).

Temporary sources:

- Menu: [Medieval Market d OL — APM Music](https://create.roblox.com/store/asset/1847223666/Medieval-Market-d-OL), ID `1847223666`.
- Combat: [Flame a — APM Music](https://create.roblox.com/store/asset/9045862008/Flame-a), ID `9045862008`.
- Interface: [UI Click 1 — 0FFZ3TI](https://create.roblox.com/store/asset/113397864512278/UI-Click-1), ID `113397864512278`. Different actions temporarily vary one recording's speed and volume.
- Additional earlier fallback track: `Medieval_Ambient_Lute`, ID `93176902923482`, by DistrokidOfficial. Availability in the published game has not been separately confirmed.

## Current published-game launch blocker

Real Studio showed `EditableMesh is not accessible. Go to Security Tab...`. The Security access toggle was unavailable; the UI showed `You must be 13+ ID verified to access this API`. This prevented models from loading and kept Play unavailable. It is separate from audio setup. The user later reported account verification was complete, but API access had not been confirmed afterward. Reopen Studio, check Mesh / Image APIs, and test launch. Account verification is performed by the owner. This records the observed state of this particular account.

## Connecting uploaded originals

1. Upload all ten WAV files to Creator Hub as the game owner, wait for assets to become ready, and grant the game usage rights. Copy the numeric Asset ID for each recording.
2. Run `tools/connect_audio.py` with ten explicit IDs. The command below illustrates the format; replace `123` with real IDs. Add `--dry-run` first to validate without writing.

```powershell
python tools/connect_audio.py --dry-run `
  --id Menu=123 --id Battle=123 --id Click=123 --id Select=123 `
  --id Order=123 --id Place=123 --id Error=123 --id Chest=123 `
  --id Victory=123 --id Defeat=123
```

3. Remove `--dry-run` and repeat. The script updates only IDs in `src/AudioCatalog.luau`, `assets/audio/original/manifest.json`, and `audio-site/dist/manifest.json` if present. It does not upload files, publish the game or website, or check Roblox permissions over the network.
4. Run `python tools/sync_place.py`, then `python tools/check_english.py` and `python tools/run_local_qa.py`. Close the old Studio tab and open updated `inex.rbxl`; confirm the correct cloud place is open, then publish the update through Studio.
5. Test menu/combat music and effects in Roblox; separately confirm this game has audio access. Use two players to verify client-local sound. Replacing IDs in a file without synchronization and publication does not update the published version.

Do not run `tools/compose_audio.py` after connecting IDs without preserving those values: the generator rewrites the manifest with `robloxAssetId=0`.
