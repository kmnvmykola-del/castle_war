"""Read the actual GLB and compare every face against the Blender exports."""
import hashlib
import json
from pathlib import Path
import re
import struct
import xml.etree.ElementTree as ET
import numpy as np

from export_static_meshes import ROOT, OUTPUT, catalogue, cloth_colours, is_cloth, metadata, team_colours


def main():
    raw = (OUTPUT / 'KingdomsMeshCatalogue.glb').read_bytes()
    magic, version, length = struct.unpack_from('<III', raw)
    assert magic == 0x46546C67 and version == 2 and length == len(raw)
    size, tag = struct.unpack_from('<II', raw, 12)
    assert tag == 0x4E4F534A
    gltf = json.loads(raw[20:20+size])
    offset = 20+size
    binary_size, tag = struct.unpack_from('<II', raw, offset)
    assert tag == 0x004E4942 and offset+8+binary_size == len(raw)
    binary = memoryview(raw)[offset+8:]
    external = json.loads((OUTPUT/'KingdomsMeshCatalogue.gltf').read_text())
    imported_binary = (OUTPUT/'KingdomsMeshCatalogue.bin').read_bytes()
    assert external['buffers'] == [{'byteLength': len(imported_binary), 'uri': 'KingdomsMeshCatalogue.bin'}]
    external['buffers'] = [{'byteLength': len(imported_binary)}]
    assert external == gltf, 'Studio glTF differs from the validated GLB'
    assert imported_binary == binary[:len(imported_binary)], 'Studio binary geometry differs from GLB'
    def array(index):
        access = gltf['accessors'][index];view = gltf['bufferViews'][access['bufferView']]
        columns = {'SCALAR': 1, 'VEC3': 3, 'VEC4': 4}[access['type']]
        dtype = {5121: 'u1', 5123: '<u2', 5125: '<u4', 5126: '<f4'}[access['componentType']]
        a = np.frombuffer(binary, dtype=dtype, count=access['count']*columns, offset=view.get('byteOffset', 0))
        assert a.nbytes == view['byteLength']
        return a.reshape(-1, columns)
    meshes = {m['name']: m for m in gltf['meshes']}
    assert len(meshes) == len(gltf['meshes'])
    assert {n['name'] for n in gltf['nodes'][1:]} == set(meshes)
    styles = {v['Id']: v for v in json.loads((ROOT / 'assets/blender/v012/styles.json').read_text())}
    teams = team_colours();expected_names=set();faces=0;variants=0
    for asset in catalogue():
        info = metadata(asset, styles)
        low, high = np.array(info['Minimum']), np.array(info['Maximum'])
        center = (low+high)/2
        vertices = np.array(asset['vertices'])
        triangles = np.array([t['v'] for t in asset['triangles']])
        colours = np.array([t['c'] for t in asset['triangles']])
        originals = vertices[triangles]
        normal = np.cross(originals[:,1]-originals[:,0], originals[:,2]-originals[:,0])
        lengths = np.linalg.norm(normal, axis=1)
        valid = lengths >= 1e-10
        originals, colours, normal = originals[valid], colours[valid], normal[valid]/lengths[valid,None]
        base = meshes[asset['name']]['primitives'][0]
        indices = array(base['indices']).reshape(-1)
        attributes=base['attributes'];position=array(attributes['POSITION']);normals=array(attributes['NORMAL'])
        assert len(indices) == len(originals)*3 and len(originals) <= 20000 and len(position)<=60000, asset['name']
        assert np.isfinite(position).all() and np.isfinite(normals).all()
        assert indices.max()<len(position)
        assert np.allclose(position[indices].reshape(-1,3,3)+center, originals, rtol=0, atol=1e-4), asset['name']+' positions'
        assert np.allclose(normals[indices].reshape(-1,3,3), normal[:,None,:], atol=2e-6), asset['name']+' normals/winding'
        targets=cloth_colours(asset, styles)
        cloth=np.array([is_cloth(c,targets) for c in colours])
        expected=np.rint(np.clip(colours,0,1)*255).astype('u1')
        names=[(asset['name'],None)]
        if info['Team']:names += [(asset['name']+'__'+key,teams[key]) for key in ('Blue','Red')]
        if info['Neutral']:names.append((asset['name']+'__Neutral',teams['Neutral']))
        for name,team in names:
            expected_names.add(name);variants+=1
            primitive=meshes[name]['primitives'][0]
            assert primitive['indices']==base['indices']
            assert primitive['attributes']['POSITION']==attributes['POSITION'] and primitive['attributes']['NORMAL']==attributes['NORMAL']
            color_id=primitive['attributes']['COLOR_0']
            assert gltf['accessors'][color_id]['normalized'] is True
            actual=array(color_id)[indices].reshape(-1,3,4)
            wanted=expected.copy()
            if team:wanted[cloth]=team
            assert (actual[:,:,:3]==wanted[:,None,:]).all() and (actual[:,:,3]==255).all(), name+' palette'
            if team:assert (wanted[~cloth]==expected[~cloth]).all(), name+' armour/skin changed'
        faces += len(originals)
    assert set(meshes)==expected_names
    manifest=json.loads((OUTPUT/'manifest.json').read_text())
    assert manifest['sha256']==hashlib.sha256(raw).hexdigest()
    assert manifest['gltfSha256']==hashlib.sha256((OUTPUT/'KingdomsMeshCatalogue.gltf').read_bytes()).hexdigest()
    assert manifest['binSha256']==hashlib.sha256(imported_binary).hexdigest()
    runtime={p.name.removesuffix('.luau').removesuffix('.server').removesuffix('.client'):p.read_text(encoding='utf8') for p in (ROOT/'src').glob('*.luau')}
    for name,source in runtime.items():
        assert not re.search(r':CreateEditable(?:Mesh|Image)|:CreateMeshPartAsync|:AddTriangle|:AddVertex',source), name+' dynamic mesh call'
    setup=ET.parse(OUTPUT/'KingdomsMeshSetup.rbxmx')
    payload={}
    for item in setup.findall('.//Item'):
        props=item.find('Properties')
        text=props.find('ProtectedString[@name="Source"]')
        if text is None:continue
        name=props.find('string[@name="Name"]').text
        if name=='Installer':continue
        assert name not in payload
        payload[name]=text.text
        if item.attrib['class']in ('Script','LocalScript'):assert props.find('bool[@name="Disabled"]').text=='true'
    assert payload==runtime, 'Setup payload differs from current game sources'
    report={'models':len(catalogue()),'meshParts':variants,'originalFacesCompared':faces,
            'allVertexPositionsAndNormalsMatch':True,'allTeamColoursMatch':True,
            'nonClothColoursPreservedAt8BitPrecision':True,'runtimeGeometryGenerationCalls':0,
            'setupSourcesMatch':True,'studioGltfMatchesValidatedGlb':True,'realRobloxImportVerified':False}
    (ROOT/'build/static-mesh-qa-report.json').write_text(json.dumps(report,indent=2))
    print(json.dumps(report))


if __name__=='__main__':main()
