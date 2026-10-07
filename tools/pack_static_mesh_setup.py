"""Create a reviewable Studio installation model containing the current code.

The game never runs this setup model. Its Script/LocalScript payloads are
disabled until the user explicitly invokes the guarded Studio installer.
"""
from pathlib import Path
import xml.etree.ElementTree as ET
from xml.sax.saxutils import escape

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / 'assets/roblox_meshes/KingdomsMeshSetup.rbxmx'


def item(parent, kind, name, source=None, disabled=False):
    node = ET.SubElement(parent, 'Item', {'class': kind, 'referent': 'RBX'+name})
    props = ET.SubElement(node, 'Properties')
    ET.SubElement(props, 'string', {'name': 'Name'}).text = name
    if source is not None:
        ET.SubElement(props, 'ProtectedString', {'name': 'Source'}).text = source
    if disabled:
        ET.SubElement(props, 'bool', {'name': 'Disabled'}).text = 'true'
    return node


def main():
    xml = ET.Element('roblox', {'version': '4'})
    model = item(xml, 'Model', 'KingdomsMeshSetup')
    item(model, 'ModuleScript', 'Installer', (ROOT / 'tools/install_static_meshes.luau').read_text(encoding='utf8'))
    runtime = item(model, 'Folder', 'Runtime')
    paths = sorted((ROOT / 'src').glob('*.luau'))
    for path in paths:
        kind = 'Script' if path.name.endswith('.server.luau') else 'LocalScript' if path.name.endswith('.client.luau') else 'ModuleScript'
        name = path.name.removesuffix('.luau').removesuffix('.server').removesuffix('.client')
        item(runtime, kind, name, path.read_text(encoding='utf8'), kind != 'ModuleScript')
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    ET.ElementTree(xml).write(OUTPUT, encoding='utf-8', xml_declaration=True)
    parsed = ET.parse(OUTPUT)
    scripts = parsed.findall('.//Item[@class="Script"]') + parsed.findall('.//Item[@class="LocalScript"]')
    assert len(scripts) == 2
    assert all(s.find('./Properties/bool[@name="Disabled"]').text == 'true' for s in scripts)
    print(f'Studio setup: {len(paths)} game sources, {OUTPUT.stat().st_size} bytes; executable payloads disabled.')


if __name__ == '__main__':
    main()
