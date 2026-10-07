"""Export only missing uploaded meshes for a small, repeatable Studio retry.

The mesh payload is copied byte-for-byte from the validated full catalogue.
Pass a JSON array of missing MeshPart names produced by the Studio check.
"""
import argparse
import copy
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FOLDER = ROOT/'assets/roblox_meshes'


def subset(source, binary, names):
    meshes = {mesh['name']: mesh for mesh in source['meshes']}
    assert names and len(names) == len(set(names)), 'Missing names must be unique'
    assert set(names) <= meshes.keys(), 'Unknown model name in retry list'
    out = copy.deepcopy(source)
    out['meshes'], out['nodes'], out['accessors'], out['bufferViews'] = [], [{'name': 'KingdomsMeshCatalogue', 'children': []}], [], []
    out['scenes'] = [{'nodes': [0]}]
    data = bytearray()
    accesses, views = {}, {}

    def accessor(old):
        if old in accesses:
            return accesses[old]
        item = copy.deepcopy(source['accessors'][old])
        view_id = item['bufferView']
        if view_id not in views:
            view = copy.deepcopy(source['bufferViews'][view_id])
            start, size = view.get('byteOffset', 0), view['byteLength']
            payload = binary[start:start+size]
            assert len(payload) == size
            data.extend(b'\0'*(-len(data)%4))
            view['byteOffset'] = len(data)
            data.extend(payload)
            views[view_id] = len(out['bufferViews'])
            out['bufferViews'].append(view)
        item['bufferView'] = views[view_id]
        accesses[old] = len(out['accessors'])
        out['accessors'].append(item)
        return accesses[old]

    for name in sorted(names):
        mesh = copy.deepcopy(meshes[name])
        for primitive in mesh['primitives']:
            primitive['indices'] = accessor(primitive['indices'])
            primitive['attributes'] = {key: accessor(value) for key, value in primitive['attributes'].items()}
        out['nodes'][0]['children'].append(len(out['nodes']))
        out['nodes'].append({'name': name, 'mesh': len(out['meshes'])})
        out['meshes'].append(mesh)
    # Independently verify that every copied accessor retains its bytes and
    # count/format, including colour, normals and vertex/index order.
    for old, new in accesses.items():
        before = source['accessors'][old]; after = out['accessors'][new]
        assert {k:v for k,v in before.items() if k!='bufferView'} == {k:v for k,v in after.items() if k!='bufferView'}
        a = source['bufferViews'][before['bufferView']]; b = out['bufferViews'][after['bufferView']]
        assert binary[a.get('byteOffset',0):a.get('byteOffset',0)+a['byteLength']] == data[b['byteOffset']:b['byteOffset']+b['byteLength']]
    return out, data


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('names', type=Path)
    args = parser.parse_args()
    names = json.loads(args.names.read_text(encoding='utf8'))
    source = json.loads((FOLDER/'KingdomsMeshCatalogue.gltf').read_text())
    binary = (FOLDER/'KingdomsMeshCatalogue.bin').read_bytes()
    document, data = subset(source, binary, names)
    path = FOLDER/'KingdomsMeshRetry.gltf'
    document['buffers'] = [{'byteLength':len(data),'uri':path.with_suffix('.bin').name}]
    path.with_suffix('.bin').write_bytes(data)
    path.write_text(json.dumps(document,separators=(',',':')),encoding='utf8')
    print(json.dumps({'meshes':len(names),'binaryBytes':len(data),'studioFile':str(path),'allAccessorBytesPreserved':True}))


if __name__=='__main__':main()
