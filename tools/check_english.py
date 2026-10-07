"""Audit authored game text in sources and the saved Roblox place."""
from pathlib import Path
import argparse
import json
import re

from save_place import Binary, string, u32
from sync_place import sources, files_for_place

ROOT = Path(__file__).resolve().parents[1]
CYRILLIC = re.compile(r'[\u0400-\u04ff]')
LITERAL = re.compile(r"'(?:\\.|[^'\\])*'|\"(?:\\.|[^\"\\])*\"")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--list', action='store_true', help='List untranslated source literals')
    args = parser.parse_args()
    files = sorted((ROOT / 'src').rglob('*.luau'))
    pending = {}
    for path in files:
        text = path.read_text(encoding='utf8')
        for match in LITERAL.finditer(text):
            value = match.group()[1:-1]
            if CYRILLIC.search(value):
                pending.setdefault(value, []).append(f'{path.name}:{text.count(chr(10), 0, match.start())+1}')
    if args.list:
        for index, (value, locations) in enumerate(pending.items()):
            print(json.dumps({'index': index, 'text': value, 'locations': locations}, ensure_ascii=False))
        print(f'{len(pending)} untranslated literals')
        return
    place = Binary((ROOT / 'inex.rbxl').read_bytes())
    embedded = sources(place)
    mismatch = []
    active_files = files_for_place(place)
    for path in active_files:
        name = path.name.removesuffix('.luau').removesuffix('.server').removesuffix('.client')
        if embedded.get(name) != path.read_text(encoding='utf8'):
            mismatch.append(name)
    properties = []
    source_cyrillic = [name for name, value in embedded.items() if CYRILLIC.search(value)]
    for tag, data in place.chunks:
        if tag != b'PROP':
            continue
        name, pos = string(data, 4)
        if name not in (b'Text', b'PlaceholderText', b'ToolTip', b'Name') or data[pos] != 1:
            continue
        pos += 1
        count = place.classes[u32(data)]['count']
        for _ in range(count):
            value, pos = string(data, pos)
            decoded = value.decode('utf8')
            if CYRILLIC.search(decoded):
                properties.append({'property': name.decode(), 'value': decoded})
    report = {'sources': len(files), 'activePlaceSources': len(active_files), 'untranslatedLiterals': pending,
              'embeddedSourcesWithCyrillic': source_cyrillic, 'sourceMismatches': mismatch,
              'untranslatedPlaceProperties': properties}
    target = ROOT / 'build/english-audit-report.json'
    target.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf8')
    print(json.dumps(report, ensure_ascii=False))
    assert not pending and not source_cyrillic and not mismatch and not properties, 'English text audit failed'


if __name__ == '__main__':
    main()
