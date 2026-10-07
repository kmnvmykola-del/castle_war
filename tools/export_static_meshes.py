"""Export the authored game catalogue as ordinary, coloured glTF MeshParts.

No Roblox login, uploads, Blender execution, or desktop input is needed. The
existing Blender exports remain the source of truth, including gameplay LODs.
"""
from pathlib import Path
import hashlib
import json
import math
import re
import struct

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / 'assets/roblox_meshes'
KINDS = ('Peasant', 'Defender', 'Archer', 'Runner')


def catalogue():
    assets = []
    for category in ('base', 'collection', 'decor'):
        assets.extend(json.loads((ROOT / f'assets/blender/v012/{category}/geometry.json').read_text()))
    assert len(assets) == len({a['name'] for a in assets})
    premium = ROOT / 'assets/blender/v016/premium/geometry.json'
    if premium.exists():
        merged = {a['name']: a for a in assets}
        for asset in json.loads(premium.read_text()):
            merged[asset['name']] = asset
        assets = list(merged.values())
    return sorted(assets, key=lambda a: a['name'])


def team_colours():
    source = (ROOT / 'src/Config.luau').read_text(encoding='utf8')
    values = re.search(r'Config.Colors=\{([^\n]+)', source).group(1)
    colours = re.findall(r'Color3.fromRGB\((\d+),(\d+),(\d+)\)', values)
    return dict(zip(('Blue', 'Red', 'Neutral'), (tuple(map(int, c)) for c in colours[:3])))


def cloth_colours(asset, styles):
    if asset['tint'] or not any(f'{kind}_' in asset['name'] for kind in KINDS):
        return []
    prefix = asset['name'].split('_')[0]
    if prefix in styles:
        c = styles[prefix]['Cloth'].lstrip('#')
        return [tuple(int(c[i:i+2], 16)/255 for i in (0, 2, 4))]
    return [(0.23, 0.38, 0.43), (0.27, 0.41, 0.22), (0.69, 0.64, 0.47)]


def is_cloth(colour, targets):
    return any(all(abs(a-b) < .0003 for a, b in zip(colour, target)) for target in targets)


def metadata(asset, styles):
    low = [min(v[i] for v in asset['vertices']) for i in range(3)]
    high = [max(v[i] for v in asset['vertices']) for i in range(3)]
    targets = cloth_colours(asset, styles)
    team = any(is_cloth(t['c'], targets) for t in asset['triangles'])
    neutral = team and asset['name'].split('_')[0] not in styles
    return dict(Minimum=low, Maximum=high, Joint=asset['joint'], Tint=asset['tint'], Team=team, Neutral=neutral)


def lua(value):
    if isinstance(value, bool):
        return str(value).lower()
    if isinstance(value, dict):
        return '{' + ','.join('['+json.dumps(k)+']='+lua(v) for k, v in value.items()) + '}'
    if isinstance(value, (tuple, list)):
        return '{' + ','.join(map(lua, value)) + '}'
    return json.dumps(value, ensure_ascii=True, separators=(',', ':'))


class Export:
    def __init__(self):
        self.binary = bytearray()
        self.gltf = dict(asset={'version': '2.0', 'generator': 'Frontier Kingdoms static mesh exporter'},
                         scene=0, scenes=[{'nodes': [0]}], nodes=[{'name': 'KingdomsMeshCatalogue', 'children': []}],
                         meshes=[], accessors=[], bufferViews=[], buffers=[],
                         materials=[{'name': 'Authored vertex colours', 'doubleSided': False,
                                     'pbrMetallicRoughness': {'baseColorFactor': [1, 1, 1, 1], 'metallicFactor': 0, 'roughnessFactor': .85}}])

    def accessor(self, blob, count, component, kind, *, target=34962, bounds=None, normalized=False):
        while len(self.binary) % 4:
            self.binary.append(0)
        view = len(self.gltf['bufferViews'])
        self.gltf['bufferViews'].append(dict(buffer=0, byteOffset=len(self.binary), byteLength=len(blob), target=target))
        self.binary.extend(blob)
        access = dict(bufferView=view, componentType=component, count=count, type=kind)
        if normalized:
            access['normalized'] = True
        if bounds:
            access.update(min=bounds[0], max=bounds[1])
        self.gltf['accessors'].append(access)
        return len(self.gltf['accessors']) - 1

    def add(self, asset, info, styles, teams):
        center = [(a+b)/2 for a, b in zip(info['Minimum'], info['Maximum'])]
        positions, normals, colours, indices, lookup = [], [], [], [], {}
        skipped = 0
        for triangle in asset['triangles']:
            a, b, c = (asset['vertices'][i] for i in triangle['v'])
            ab, ac = ([b[i]-a[i] for i in range(3)], [c[i]-a[i] for i in range(3)])
            normal = (ab[1]*ac[2]-ab[2]*ac[1], ab[2]*ac[0]-ab[0]*ac[2], ab[0]*ac[1]-ab[1]*ac[0])
            length = math.sqrt(sum(n*n for n in normal))
            if length < 1e-10:
                skipped += 1
                continue
            normal = tuple(round(n/length, 6) for n in normal)
            colour = tuple(triangle['c'])
            for vertex in triangle['v']:
                key = (vertex, normal, colour)
                if key not in lookup:
                    lookup[key] = len(positions)
                    positions.append(tuple(p-center[i] for i, p in enumerate(asset['vertices'][vertex])))
                    normals.append(normal)
                    colours.append(colour)
                indices.append(lookup[key])
        assert positions and indices, asset['name']
        assert len(indices)//3 <= 20000, asset['name']
        packed = lambda vs: struct.pack('<'+'f'*(len(vs)*3), *(n for v in vs for n in v))
        bounds = ([min(v[i] for v in positions) for i in range(3)], [max(v[i] for v in positions) for i in range(3)])
        position = self.accessor(packed(positions), len(positions), 5126, 'VEC3', bounds=bounds)
        normal = self.accessor(packed(normals), len(normals), 5126, 'VEC3')
        short = len(positions) <= 65535
        index = self.accessor(struct.pack('<'+('H' if short else 'I')*len(indices), *indices), len(indices), 5123 if short else 5125, 'SCALAR', target=34963)
        targets = cloth_colours(asset, styles)
        variants = [(asset['name'], None)]
        if info['Team']:
            variants += [(asset['name']+'__'+name, teams[name]) for name in ('Blue', 'Red')]
        if info['Neutral']:
            variants.append((asset['name']+'__Neutral', teams['Neutral']))
        for name, team in variants:
            rgba = bytearray()
            for colour in colours:
                value = team if team and is_cloth(colour, targets) else tuple(round(max(0, min(1, v))*255) for v in colour)
                rgba.extend((*value, 255))
            color = self.accessor(rgba, len(colours), 5121, 'VEC4', normalized=True)
            mesh = len(self.gltf['meshes'])
            self.gltf['meshes'].append({'name': name, 'primitives': [{'attributes': {'POSITION': position, 'NORMAL': normal, 'COLOR_0': color}, 'indices': index, 'material': 0}]})
            self.gltf['nodes'][0]['children'].append(len(self.gltf['nodes']))
            self.gltf['nodes'].append({'name': name, 'mesh': mesh})
        return {'name': asset['name'], 'variants': len(variants), 'vertices': len(positions), 'triangles': len(indices)//3, 'degenerateRemoved': skipped}

    def save(self, path):
        self.gltf['buffers'] = [{'byteLength': len(self.binary)}]
        # Studio explicitly documents .gltf support. Keep the binary beside it
        # so the user can select this file without relying on a GLB extension.
        bin_path = path.with_suffix('.bin')
        bin_path.write_bytes(self.binary)
        external = dict(self.gltf, buffers=[{'byteLength': len(self.binary), 'uri': bin_path.name}])
        path.with_suffix('.gltf').write_text(json.dumps(external, separators=(',', ':')), encoding='utf8')
        document = json.dumps(self.gltf, separators=(',', ':')).encode()
        document += b' '*(-len(document) % 4)
        binary = bytes(self.binary) + b'\0'*(-len(self.binary) % 4)
        raw = struct.pack('<III', 0x46546C67, 2, 12+8+len(document)+8+len(binary))
        raw += struct.pack('<II', len(document), 0x4E4F534A) + document
        raw += struct.pack('<II', len(binary), 0x004E4942) + binary
        path.write_bytes(raw)
        return len(raw)


def main():
    assets = catalogue()
    styles = {v['Id']: v for v in json.loads((ROOT / 'assets/blender/v012/styles.json').read_text())}
    teams = team_colours()
    models = {a['name']: metadata(a, styles) for a in assets}
    signature = hashlib.sha256(json.dumps({'assets': assets, 'teams': teams}, sort_keys=True, separators=(',', ':')).encode()).hexdigest()
    manifest = dict(Version=2 if (ROOT/'assets/blender/v016/premium/geometry.json').exists() else 1, Signature=signature, Models=models)
    source = '-- Generated by tools/export_static_meshes.py; ordinary imported MeshParts.\nreturn '+lua(manifest)+'\n'
    assert len(source.encode()) < 180000, 'Split the metadata module before exceeding Roblox Source limits'
    (ROOT / 'src/MeshCatalog.luau').write_text(source, encoding='utf8')
    OUTPUT.mkdir(parents=True, exist_ok=True)
    export = Export()
    records = [export.add(a, models[a['name']], styles, teams) for a in assets]
    glb = OUTPUT / 'KingdomsMeshCatalogue.glb'
    size = export.save(glb)
    assert size < 100*1024*1024, 'Studio import exceeds the documented file limit'
    report = {'version': 1, 'signature': signature, 'file': glb.name, 'bytes': size,
              'sha256': hashlib.sha256(glb.read_bytes()).hexdigest(), 'models': len(models),
              'studioFile': glb.with_suffix('.gltf').name,
              'gltfSha256': hashlib.sha256(glb.with_suffix('.gltf').read_bytes()).hexdigest(),
              'binSha256': hashlib.sha256(glb.with_suffix('.bin').read_bytes()).hexdigest(),
              'meshParts': len(export.gltf['meshes']), 'teamColours': teams,
              'triangleCount': sum(r['triangles']*r['variants'] for r in records),
              'records': records}
    (OUTPUT / 'manifest.json').write_text(json.dumps(report, indent=2), encoding='utf8')
    print(json.dumps({k: v for k, v in report.items() if k != 'records'}))


if __name__ == '__main__':
    main()
