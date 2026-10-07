"""Verify a native Studio save, including real mesh IDs and preserved backups."""
import argparse
import hashlib
import json
import re
from pathlib import Path
from save_place import Binary, string, u32
from sync_place import ROOT, active_refs, active_roots, files_for_place, sources, synchronize, serialize


def string_properties(model, wanted):
    values={}
    for tag,data in model.chunks:
        if tag!=b'PROP':continue
        name,pos=string(data,4)
        if name not in wanted:continue
        assert data[pos]==1, ('Unsupported property type',name,data[pos])
        pos+=1
        for ref in model.classes[u32(data)]['ids']:
            value,pos=string(data,pos)
            values[ref]=value.decode('utf8')
    return values


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('place',type=Path)
    args=parser.parse_args()
    raw=args.place.read_bytes();model=Binary(raw)
    roots=active_roots(model);active=active_refs(model)
    embedded=sources(model);files=files_for_place(model)
    assert len(files)==len(embedded) and len(files)>=25
    for path in files:
        name=path.name.removesuffix('.luau').removesuffix('.server').removesuffix('.client')
        assert embedded[name]==path.read_text(encoding='utf8'), ('Source mismatch',name)
    templates=[ref for ref,name in model.names.items() if name=='MeshTemplates'and model.parents[ref]==roots[0]]
    assert len(templates)==1
    mesh_refs={ref for ref,parent in model.parents.items() if parent==templates[0]}
    mesh_classes={ref for group in model.classes.values() if group['name']==b'MeshPart'for ref in group['ids']}
    assert mesh_refs<=mesh_classes
    expected={mesh['name']for mesh in json.loads((ROOT/'assets/roblox_meshes/KingdomsMeshCatalogue.gltf').read_text())['meshes']}
    manifest=json.loads((ROOT/'assets/roblox_meshes/manifest.json').read_text())
    assert {model.names[ref]for ref in mesh_refs}==expected and len(mesh_refs)==len(expected)==manifest['meshParts']
    ids=string_properties(model,{b'MeshId'})
    for ref in mesh_refs:
        match=re.search(r'rbxassetid://(\d+)|[?&]id=(\d+)',ids[ref])
        assert match and int(next(value for value in match.groups()if value))>0, ('Unuploaded mesh',model.names[ref])
    assert not any(model.names[ref]=='Geometry'and model.parents[ref]==roots[0]for ref in active)
    all_sources=string_properties(model,{b'Source'})
    archives={ref:value for ref,value in all_sources.items()if ref not in active}
    assert archives, 'Expected retained backups'
    for tag,data in model.chunks:
        if tag!=b'PROP':continue
        name,pos=string(data,4)
        if name!=b'Disabled':continue
        assert data[pos]==2
        for ref,value in zip(model.classes[u32(data)]['ids'],data[pos+1:]):
            if ref in archives:assert value==1, ('Archived executable enabled',ref)
    header,chunks,names,added,preserved=synchronize(model,files)
    assert not added, 'Synchronization must not restore obsolete Geometry modules'
    synced=Binary(serialize(header,chunks))
    assert synced.names==model.names and synced.parents==model.parents
    assert sources(synced)==embedded
    after=string_properties(synced,{b'Source'})
    assert all(after[ref]==value for ref,value in archives.items())
    before_props=[(tag,data)for tag,data in model.chunks if tag==b'PROP'and string(data,4)[0]!=b'Source']
    after_props=[(tag,data)for tag,data in synced.chunks if tag==b'PROP'and string(data,4)[0]!=b'Source']
    assert before_props==after_props, 'Synchronization changed non-script properties'
    report={'place':str(args.place.resolve()),'bytes':len(raw),'sha256':hashlib.sha256(raw).hexdigest(),
            'activeSourcesMatch':len(embedded),'uploadedMeshParts':len(mesh_refs),'archivedSourcesPreserved':len(archives),
            'archivedExecutablesDisabled':True,'obsoleteGeometryAbsentFromActiveRoot':True,
            'syncPreservesAllMeshPropertiesAndParents':True}
    (ROOT/'build/installed-place-qa-report.json').write_text(json.dumps(report,indent=2),encoding='utf8')
    print(json.dumps(report))


if __name__=='__main__':main()
