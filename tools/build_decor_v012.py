"""Matching architectural heraldry, roof ornaments and road tiles for each collection."""
from pathlib import Path
import bpy
import json
import math

ROOT=Path(__file__).resolve().parents[1]
code=(ROOT/'tools/build_collection_v012.py').read_text(encoding='utf8')
exec(compile(code[:code.index('\nasset=collection_asset')],'collection_art_library','exec'))
OUT=ROOT/'assets/blender/v012/decor';OUT.mkdir(parents=True,exist_ok=True)
ASSETS=[]
default={'Id':'Default','Cloth':'#704E38','Armor':'#ADAB9C','Trim':'#B69159','Motif':'cross'}
for active in [default]+styles:
    for role,value in [('cloth',active['Cloth']),('armor',active['Armor']),('metal',active['Armor']),('trim',active['Trim'])]:MATERIALS[role].diffuse_color=rgb(value)
    current=[]
    tapered('Carved heraldic plaque',(0,0,.75),(.25,.18),(1.35,.18),1.45,'trim')
    tapered('Enamel heraldic field',(0,-.11,.79),(.17,.04),(1.18,.04),1.23,'cloth')
    symbol(active['Motif'],0,-.155,.91,.40)
    for x in [-.47,.47]:sphere('Plaque rivet',(x,-.16,1.26),.045,'trim')
    library_asset(active['Id']+'_Herald',current.copy(),'building')
    current=[]
    box('Ornament pedestal',(0,0,.10),(1.30,.70,.20),'armor',.035)
    motif=active['Motif']
    if motif in ['antler','stag','leaf']:
        for side in [-1,1]:
            beam('Roof antler',(side*.12,0,.17),(side*.48,0,1.35),.11,'trim')
            for i in range(2):beam('Antler tine',(side*(.25+i*.09),0,.59+i*.27),(side*(.62+i*.15),0,.83+i*.25),.075,'trim')
    elif motif in ['raven','feathers','wings']:
        for side in [-1,1]:
            for i in range(4):beam('Architectural wing',(0,0,.25+i*.14),(side*(.90-i*.14),0,.7+i*.20),.11,'trim')
    elif motif in ['ice','gem','star','runes','bolt']:
        for i in [-1,0,1]:
            bpy.ops.mesh.primitive_cone_add(vertices=4,radius1=.18,radius2=.03,depth=.68+(i==0)*.5,location=(i*.34,0,.50+(i==0)*.24))
            finish_object(bpy.context.object,'Architectural crystal','trim')
    else:
        sphere('Gilded roof boss',(0,0,.48),.24,'trim')
        for side in [-1,0,1]:beam('Roof crest',(side*.27,0,.32),(side*.48,0,.93+(side==0)*.28),.12,'trim')
    library_asset(active['Id']+'_RoofCrest',current.copy(),'building')
    current=[]
    for ix in range(3):
        for iy in range(3):
            box('Paving stone',(-1.5+ix*1.5,-1.35+iy*1.35,.085),(1.43,1.28,.15),'armor',.025)
    for side in [-1,1]:
        box('Road border',(side*2.18,0,.11),(.18,4.10,.20),'trim',.025)
        for y in [-1.45,1.45]:box('Heraldic inlay',(side*2.02,y,.173),(.10,.36,.025),'cloth',.004)
    library_asset(active['Id']+'_RoadTile',current.copy(),'building')
(OUT/'geometry.json').write_text(json.dumps(ASSETS,separators=(',',':')),encoding='utf8')
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'kingdom_decor_v012.blend'))
print('V012_DECOR_ASSETS',len(ASSETS),'TRIANGLES',sum(len(a['triangles'])for a in ASSETS))
