"""Connect uploaded original Roblox audio IDs; never upload or publish anything."""
import argparse
import json
from pathlib import Path
import re


KEYS = ('Menu', 'Battle', 'Click', 'Select', 'Order', 'Place', 'Error', 'Chest', 'Victory', 'Defeat')
ROOT = Path(__file__).resolve().parents[1]


def parse_ids(values):
    result = {}
    for value in values:
        key, separator, raw_id = value.partition('=')
        if not separator or key not in KEYS:
            raise ValueError('Use --id KEY=NUMBER; valid keys: ' + ', '.join(KEYS))
        if key in result:
            raise ValueError('Duplicate audio key: ' + key)
        if not re.fullmatch(r'[0-9]+', raw_id) or int(raw_id) <= 0:
            raise ValueError(key + ' requires a positive integer Roblox asset ID.')
        result[key] = int(raw_id)
    missing = [key for key in KEYS if key not in result]
    if missing:
        raise ValueError('Missing audio IDs: ' + ', '.join(missing))
    return {key: result[key] for key in KEYS}


def plan_updates(root, ids):
    catalog_path = root / 'src/AudioCatalog.luau'
    with catalog_path.open(encoding='utf8', newline='') as source:
        catalog = source.read()
    for key, asset_id in ids.items():
        pattern = re.compile(r'(?m)^(\s*' + re.escape(key) + r'\s*=\s*\{\s*Id\s*=\s*)[0-9]+(?=\s*,)')
        catalog, count = pattern.subn(lambda match: match[1] + str(asset_id), catalog)
        if count != 1:
            raise ValueError('Expected one AudioCatalog entry for ' + key + '; found ' + str(count))
    plans = [(catalog_path, catalog)]
    manifests = [root / 'assets/audio/original/manifest.json']
    site_manifest = root / 'audio-site/dist/manifest.json'
    if site_manifest.is_file():
        manifests.append(site_manifest)
    for path in manifests:
        manifest = json.loads(path.read_text(encoding='utf8'))
        tracks = manifest.get('tracks')
        if not isinstance(tracks, list):
            raise ValueError(str(path) + ': tracks must be a list.')
        counts = dict.fromkeys(KEYS, 0)
        for track in tracks:
            if not isinstance(track, dict):
                raise ValueError(str(path) + ': invalid track entry.')
            key = track.get('key')
            if key in ids:
                counts[key] += 1
                track['robloxAssetId'] = ids[key]
        if any(count != 1 for count in counts.values()):
            raise ValueError(str(path) + ': each of the ten audio keys must appear exactly once.')
        plans.append((path, json.dumps(manifest, indent=2) + '\n'))
    return plans


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--id', action='append', required=True, metavar='KEY=NUMBER',
                        help='Repeat for all ten keys: ' + ', '.join(KEYS))
    parser.add_argument('--dry-run', action='store_true', help='Validate and report proposed changes without writing.')
    parser.add_argument('--root', type=Path, default=ROOT, help='Project directory; defaults to the project containing this script.')
    args = parser.parse_args()
    try:
        ids = parse_ids(args.id)
        plans = plan_updates(args.root.resolve(), ids)
        if not args.dry_run:
            for path, content in plans:
                with path.open('w', encoding='utf8', newline='') as destination:
                    destination.write(content)
    except (ValueError, OSError) as error:
        parser.error(str(error))
    print(json.dumps({'dryRun': args.dry_run, 'ids': ids, 'files': [str(path) for path, _ in plans],
                      'uploaded': False, 'published': False}, indent=2))


if __name__ == '__main__':
    main()
