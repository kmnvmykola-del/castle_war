"""Validate the staged Blender collection before importing it into the game."""
from pathlib import Path
import json
import hashlib
import math

root=Path(__file__).resolve().parents[1]
base=json.loads((root/'assets/blender/v012/base/geometry.json').read_text(encoding='utf8'))
collection=json.loads((root/'assets/blender/v012/collection/geometry.json').read_text(encoding='utf8'))
styles=json.loads((root/'assets/blender/v012/styles.json').read_text(encoding='utf8'))
decor=json.loads((root/'assets/blender/v012/decor/geometry.json').read_text(encoding='utf8'))
assert len(styles)==24 and len({s['Id']for s in styles})==24
assert len(base)==56 and len(collection)==24*28
assert len(decor)==75
assets={a['name']:a for a in base+collection+decor}
assert len(assets)==len(base)+len(collection)+len(decor)
for a in assets.values():
    assert a['vertices'] and a['triangles']
    assert len(a['triangles'])<=19000,('MeshPart triangle limit',a['name'])
    assert all(len(v)==3 and all(math.isfinite(x)for x in v)for v in a['vertices'])
    assert all(len(f['v'])==3 and min(f['v'])>=0 and max(f['v'])<len(a['vertices']) and len(set(f['v']))==3 for f in a['triangles'])
    assert all(len(f['c'])==3 and all(0<=c<=1 for c in f['c'])for f in a['triangles'])
    assert len(a['joint'])==3
    assert all(math.isfinite(x)for x in a['joint'])

signatures={}
for style in styles:
    body=[]
    for kind in ['Defender','Archer','Runner','Peasant']:
        for limb in ['Torso','Head','LeftArm','RightArm','LeftLeg','RightLeg','Insignia']:
            a=assets[style['Id']+'_'+kind+'_'+limb]
            original=assets[kind+'_'+limb]
            assert a['joint']==original['joint'],a['name']
            assert a['tint']==(limb=='Insignia'),a['name']
            body.append({'vertices':a['vertices'],'faces':[f['v']for f in a['triangles']]})
    signatures[style['Id']]=hashlib.sha256(json.dumps(body,separators=(',',':')).encode()).hexdigest()
assert len(set(signatures.values()))==24,'Two sets differ only in color'
for kind in ['Village','Castle','Barracks','Archery','Camp','Tower','Farm']:
    for suffix in ['Base','Upgrade2','Upgrade3']:
        a=assets[kind+'_'+suffix]
        assert max(abs(v[0])for v in a['vertices'])<13.5,a['name']
        assert max(abs(v[2])for v in a['vertices'])<13.5,a['name']

report={'status':'Artwork validated for v0.12','setsIncludingDefault':25,'newCollectionMeshes':len(collection),'baseMeshes':len(base),'decorMeshes':len(decor),'totalMeshes':len(assets),'triangles':sum(len(a['triangles'])for a in assets.values()),'distinctGeometries':len(set(signatures.values())),'pivotsMatch':True,'teamInsigniaOnlyTinted':True}
(root/'build/art-v012-report.json').write_text(json.dumps(report,indent=2),encoding='utf8')
print(json.dumps(report))
