"""24 redesigned army sets plus the default set, authored and rendered in Blender."""
from pathlib import Path
import ast
import math
import json
import bpy
from mathutils import Vector

ROOT=Path(__file__).resolve().parents[1]
base=(ROOT/'tools/build_art_v012.py').read_text(encoding='utf8')
exec(compile(base[:base.index('\nall_objects=[]')],'v012_art_library','exec'))
node=next(n for n in ast.parse(base).body if isinstance(n,ast.FunctionDef)and n.name=='unit')
exec(compile(ast.Module(body=[node],type_ignores=[]),'v012_unit_builder','exec'))
OUT=ROOT/'assets/blender/v012/collection';OUT.mkdir(parents=True,exist_ok=True)
styles=json.loads((ROOT/'assets/blender/v012/styles.json').read_text(encoding='utf8'))
ASSETS=[];all_objects=[];active=None
library_asset=asset

def rgb(value):return tuple(int(value[i:i+2],16)/255 for i in [1,3,5])+(1,)
def arc_emblem(x,y,z,radius,material='trim',start=0,end=math.tau):
    for i in range(12):
        a=start+(end-start)*i/12;b=start+(end-start)*(i+1)/12
        beam('Emblem curve',(x+math.cos(a)*radius,y,z+math.sin(a)*radius),(x+math.cos(b)*radius,y,z+math.sin(b)*radius),.027,material)

def symbol(motif,x,y,z,scale=.25):
    if motif in ['sun','amber','lion','rose']:
        sphere('Raised emblem boss',(x,y,z),scale*.35,'trim',(1,.18,1))
        count=8 if motif=='sun'else 5 if motif=='rose'else 6
        for i in range(count):
            a=i*math.tau/count
            if motif=='rose':sphere('Rose petal',(x+math.cos(a)*scale*.46,y,z+math.sin(a)*scale*.46),scale*.31,'trim',(1,.2,1))
            else:beam('Sun ray',(x+math.cos(a)*scale*.52,y,z+math.sin(a)*scale*.52),(x+math.cos(a)*scale,y,z+math.sin(a)*scale),.027,'trim')
    elif motif=='moon':
        arc_emblem(x,y,z,scale,'trim',.55,math.tau-.55)
        sphere('Moon star',(x+scale*.33,y,z+scale*.25),scale*.13,'ivory',(1,.2,1))
    elif motif in ['gem','ice','star']:
        count=4 if motif=='gem'else 6
        for i in range(count):
            a=i*math.tau/count
            beam('Crystal ray',(x,y,z),(x+math.cos(a)*scale,y,z+math.sin(a)*scale),.035,'trim')
        sphere('Gem heart',(x,y-.025,z),scale*.2,'ivory',(1,.28,1))
    elif motif in ['leaf','antler','stag']:
        beam('Branch',(x,y,z-scale*.65),(x,y,z+scale),.032,'trim')
        for side in [-1,1]:
            for i in range(2):
                point=(x+side*scale*(.62-.12*i),y,z+scale*(.1+.45*i))
                beam('Branch tine',(x,y,z+scale*(i*.3-.1)),point,.026,'trim')
                if motif=='leaf':sphere('Emblem leaf',point,scale*.23,'trim',(1,.22,.45))
    elif motif=='bolt':
        pts=[(x+scale*.3,y,z+scale),(x-scale*.3,y,z),(x+scale*.3,y,z),(x-scale*.3,y,z-scale)]
        for a,b in zip(pts,pts[1:]):beam('Bolt',a,b,.035,'trim')
    elif motif in ['wings','feathers','raven']:
        for side in [-1,1]:
            for i in range(3):beam('Wing feather',(x,y,z-scale*.3+i*scale*.24),(x+side*scale*(1-.20*i),y,z+scale*(.6-.12*i)),.03,'trim')
    elif motif=='anchor':
        beam('Anchor stem',(x,y,z-scale),(x,y,z+scale*.7),.03,'trim')
        arc_emblem(x,y,z-scale*.25,scale*.72,'trim',math.pi,math.tau)
        arc_emblem(x,y,z+scale*.72,scale*.2)
    elif motif in ['scales','runes']:
        for i in range(3):
            h=z+(i-1)*scale*.58
            for side in [-1,1]:beam('Chevron',(x+side*scale*.65,y,h+scale*.27),(x,y,h-scale*.20),.03,'trim')
    elif motif=='crown':
        beam('Crown base',(x-scale,y,z-scale*.3),(x+scale,y,z-scale*.3),.036,'trim')
        for side in [-1,0,1]:beam('Crown prong',(x+side*scale*.7,y,z-scale*.3),(x+side*scale*.85,y,z+scale*(.75 if side==0 else.4)),.035,'trim')
    else:
        beam('Heraldic bar',(x-scale*.75,y,z),(x+scale*.75,y,z),.04,'trim')
        beam('Heraldic vertical',(x,y,z-scale),(x,y,z+scale),.04,'trim')

def ornament(name,kind):
    motif=active['Motif'];knight=kind=='Defender'
    if name.endswith('_Torso'):
        if motif in ['crown','moon','feathers','raven','star','cross','stag']:
            tapered('Layered cape',(0,.28,1.15),(.57,.08),(.48,.07),.65,'cloth')
            for side in [-1,1]:box('Cape clasp',(side*.22,-.245,1.40),(.08,.045,.08),'trim',.012)
        elif motif in ['rivets','scales','bolt','lion','gem','ice']:
            for side in [-1,1]:
                plate=tapered('Overlapping armor',(side*.19,-.265,1.20),(.22,.06),(.29,.06),.32,'armor');plate.rotation_euler.y=side*.12
                box('Raised shoulder ridge',(side*.34,0,1.46),(.23,.34,.09),'trim',.012)
        elif motif in ['leaf','antler','anchor','scarf','harness','amber']:
            beam('Broad harness',(-.26,-.265,.95),(.25,-.265,1.41),.065,'trim')
            for side in [-1,1]:box('Supply pouch',(side*.27,-.05,.91),(.16,.32,.23),'wood',.025)
        symbol(motif,.03,-.288,1.27,.115)
    elif name.endswith('_Head'):
        if motif=='crown':
            torus('Royal coronet',(0,0,2.04),.29,.024,'trim')
            if knight:
                for i in range(5):
                    a=i*math.tau/5;beam('Crown point',(math.cos(a)*.27,math.sin(a)*.27,2.04),(math.cos(a)*.27,math.sin(a)*.27,2.17),.044,'trim')
        elif motif in ['antler','stag']and knight:
            for side in [-1,1]:
                beam('Antler branch',(side*.18,.03,2.02),(side*.28,.04,2.30),.045,'trim')
                beam('Antler tine',(side*.23,.04,2.19),(side*.37,.04,2.25),.03,'trim')
        elif motif in ['raven','feathers','wings']and knight:
            for side in [-1,1]:
                for i in range(3):beam('Helmet wing',(side*.22,.08,2.00),(side*(.34+i*.07),.14,2.12+(2-i)*.07),.045,'armor')
        elif motif in ['flame','lion','sun']and knight:
            for i in range(5):sphere('Horsehair crest',(0,-.15+i*.08,2.095),.095,'cloth',(.60,1,1.5))
        elif motif in ['ice','gem','bolt']and knight:
            for side in [-1,1]:
                crest=box('Faceted helmet ridge',(side*.16,0,2.07),(.065,.22,.18),'trim',.008);crest.rotation_euler.y=side*.30
        elif motif=='scarf':
            for h in [1.98,2.045]:torus('Wrapped head cloth',(0,.01,h),.286,.048,'ivory')
            box('Scarf tail',(.24,.18,1.8),(.14,.09,.53),'cloth',.025)
        elif motif in ['cross','rivets','scales']and knight:
            box('Visor brow',(0,-.26,1.89),(.52,.07,.065),'trim',.009)
            for side in [-1,1]:box('Wide cheek plate',(side*.27,-.08,1.76),(.08,.25,.28),'armor',.016)
        else:
            sphere('Cap brooch',(.19,-.23,1.96),.048,'trim',(1,.4,1))
        if motif in ['moon','star','runes','leaf']:
            torus('Decorated headband',(0,.015,1.96),.286,.025,'trim')
    elif name.endswith('_LeftArm')and knight:
        symbol(motif,-.52,-.481,1.08,.235)
        if motif in ['ice','gem','bolt','rivets']:
            for side in [-1,1]:box('Shield edge brace',(-.52+side*.29,-.48,1.20),(.05,.035,.30),'trim',.012)
    elif name.endswith('_RightArm')and kind in ['Defender','Runner']:
        if motif in ['ice','gem','moon','runes','star']:box('Sword inlay',(.435,-.146,1.42),(.035,.018,.42),'trim',.004)
    elif name.endswith('Leg')and motif in ['rivets','crown','lion','scales','gem','cross']:
        sx=-1 if 'Left' in name else 1
        box('Engraved greave',(sx*.18,-.17,.48),(.185,.07,.24),'armor',.025)

def collection_asset(name,objects,category,joint=None,tint=False):
    kind=name.split('_')[0]
    ornament(name,kind)
    result=library_asset(active['Id']+'_'+name,current.copy(),category,joint,tint)
    for slot in result.material_slots:slot.material=slot.material.copy()
    return result

asset=collection_asset
for index,active in enumerate(styles):
    for role,value in [('cloth',active['Cloth']),('armor',active['Armor']),('metal',active['Armor']),('trim',active['Trim']),('green',active['Cloth']),('linen',active['Cloth'])]:MATERIALS[role].diffuse_color=rgb(value)
    for col,kind in enumerate(['Defender','Archer','Runner','Peasant']):
        for obj in unit(kind):obj.location+=Vector(((index%5)*7.4+col*1.4,(index//5)*6.1,0));all_objects.append(obj)

(OUT/'geometry.json').write_text(json.dumps(ASSETS,separators=(',',':')),encoding='utf8')
scene=bpy.context.scene;scene.render.engine='BLENDER_WORKBENCH';scene.display.shading.light='STUDIO';scene.display.shading.color_type='MATERIAL'
scene.display.shading.show_cavity=True;scene.display.shading.show_shadows=True;scene.display.shading.background_type='WORLD';scene.world.color=(.17,.20,.23)
bpy.ops.object.camera_add(location=(19,-33,48));cam=bpy.context.object
cam.rotation_euler=(Vector((17,13,0))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=40;scene.camera=cam
scene.render.resolution_x=2400;scene.render.resolution_y=2000;scene.render.resolution_percentage=100;scene.render.image_settings.file_format='PNG'
scene.render.filepath=str(OUT/'collection.png');bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'collection_v012.blend'));bpy.ops.render.render(write_still=True)
cam.data.ortho_scale=6.5;scene.render.resolution_x=1400;scene.render.resolution_y=650
for index in [0,1,2,3,6,9,13,16,23]:
    cx=(index%5)*7.4+2.1;cy=(index//5)*6.1
    cam.location=(cx,cy-9,3.1);cam.rotation_euler=(Vector((cx,cy,1.16))-cam.location).to_track_quat('-Z','Y').to_euler()
    scene.render.filepath=str(OUT/(styles[index]['Id']+'.png'));bpy.ops.render.render(write_still=True)
print('V012_COLLECTION_ASSETS',len(ASSETS),'TRIANGLES',sum(len(a['triangles'])for a in ASSETS))
