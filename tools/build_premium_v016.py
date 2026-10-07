"""Author three premium silhouettes and paths in Blender, retaining RTS pivots."""
from pathlib import Path
import ast
import json
import math
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
code = (ROOT/'tools/build_art_v012.py').read_text(encoding='utf8')
exec(compile(code[:code.index('\nall_objects=[]')], 'art_library', 'exec'))
node = next(n for n in ast.parse(code).body if isinstance(n, ast.FunctionDef) and n.name == 'unit')
exec(compile(ast.Module(body=[node], type_ignores=[]), 'unit_library', 'exec'))
OUT = ROOT/'assets/blender/v016/premium'
OUT.mkdir(parents=True, exist_ok=True)
ASSETS = []
library_asset = asset
styles = {s['Id']:s for s in json.loads((ROOT/'assets/blender/v012/styles.json').read_text())}

def color(hex_value):
    return tuple(int(hex_value[i:i+2],16)/255 for i in (1,3,5))+(1,)

for key, value in {'gem':'#84E4F1','secondary':'#28394E','ink':'#172130','violet':'#8860CA'}.items():
    m=bpy.data.materials.new(key);m.diffuse_color=color(value);MATERIALS[key]=m

def cone(name, pos, radius, height, material='trim', vertices=6, rotation=(0,0,0)):
    bpy.ops.mesh.primitive_cone_add(vertices=vertices, radius1=radius, radius2=.008,
                                  depth=height, location=pos, rotation=rotation)
    return finish_object(bpy.context.object,name,material)

def blade_shape(name, points, material='trim', depth=.055):
    vertices=[(x,y+offset,z) for offset in (-depth/2,depth/2) for x,y,z in points]
    n=len(points); faces=[tuple(range(n-1,-1,-1)),tuple(range(n,2*n))]
    faces.extend((i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n))
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(vertices,[],faces)
    obj=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(obj)
    return finish_object(obj,name,material)

def bolt(x,y,z,scale,material='gem'):
    pts=[(.12,.48),(-.22,.06),(-.02,.06),(-.15,-.43),(.27,.14),(.045,.14)]
    return blade_shape('Forged lightning',[(x+a*scale,y,z+b*scale)for a,b in pts],material)

def star(x,y,z,radius,material='trim'):
    pts=[]
    for i in range(10):
        a=math.pi/2+i*math.pi/5;r=radius if i%2==0 else radius*.40
        pts.append((x+math.cos(a)*r,y,z+math.sin(a)*r))
    return blade_shape('Five point star',pts,material,.045)

def dragon_wing(x,y,z,side,scale=1,material='secondary'):
    pts=[(0,0),(.16,.50),(.50,.69),(.74,.42),(.58,.10),(.40,.27),(.24,.09)]
    blade_shape('Dragon wing',[(x+side*a*scale,y,z+b*scale)for a,b in pts],material,.055)
    for a,b in [(0,0),(.50,.69),(.74,.42)]:
        beam('Wing bone',(x,y-.032,z),(x+side*a*scale,y-.032,z+b*scale),.028,'trim')

def scales(x,y,z,rows=3,width=.55):
    for row in range(rows):
        for col in range(3):
            cx=x+(col-1)*width/3;cz=z-row*.115
            blade_shape('Overlapping dragon scale',[(cx-.09,y-row*.006,cz+.055),
                (cx+.09,y-row*.006,cz+.055),(cx+.08,y-row*.006,cz-.025),
                (cx,y-.015-row*.006,cz-.08),(cx-.08,y-row*.006,cz-.025)],'armor',.025)

def discard_words(words):
    global current
    keep=[]
    for obj in current:
        if any(word in obj.name for word in words):bpy.data.objects.remove(obj,do_unlink=True)
        else:keep.append(obj)
    current=keep

def premium_asset(name,objects,category,joint=None,tint=False):
    global current
    kind=name.split('_')[0]
    torso=name.endswith('_Torso');head=name.endswith('_Head')
    arm=name.endswith('Arm');leg=name.endswith('Leg')
    sx=-1 if 'Left' in name else 1
    if torso:
        discard_words(['Tunic','tunic','apron','Armor','armor','breastplate','Shoulder','shoulder','Collar','strap','scale'])
        if active=='Oracle':
            tapered('Layered celestial robe',(0,0,1.12),(.81,.47),(.61,.39),.76,'secondary')
            for side in (-1,1):
                obj=tapered('Split embroidered mantle',(side*.25,-.235,1.14),(.22,.06),(.17,.06),.62,'violet')
                obj.rotation_euler.y=side*.09
                beam('Gold robe piping',(side*.34,-.272,.79),(side*.22,-.272,1.46),.025,'trim')
                star(side*.28,-.305,1.25,.065)
            torus('Ceremonial collar',(0,0,1.45),.28,.05,'trim')
            star(0,-.29,1.32,.13,'gem')
            tapered('Long star cape',(0,.28,1.12),(.77,.08),(.49,.08),.75,'violet')
            star(0,.335,1.19,.15)
        else:
            tapered('Armoured surcoat',(0,0,1.14),(.70,.41),(.64,.39),.67,'cloth')
            tapered('Forged cuirass',(0,-.22,1.24),(.49,.09),(.62,.11),.45,'armor')
            for side in (-1,1):
                tapered('Flared articulated tasset',(side*.22,-.17,.9),(.24,.10),(.19,.08),.30,'secondary')
                plate=box('Layered shoulder guard',(side*.36,0,1.45),(.31,.40,.14),'armor',.035)
                plate.rotation_euler.y=side*.18
                box('Shoulder gilding',(side*.36,-.20,1.47),(.26,.045,.07),'trim',.008)
            if active=='Storm':
                bolt(0,-.295,1.25,.48)
                for side in (-1,1):bolt(side*.35,-.23,1.47,.17)
                tapered('Storm officer cape',(0,.26,1.17),(.73,.08),(.44,.08),.66,'secondary')
                for side in (-1,1):beam('Silver cape edging',(side*.22,.315,1.49),(side*.35,.315,.87),.025,'armor')
            else:
                scales(0,-.285,1.40,3)
                for side in (-1,1):
                    cone('Pauldron horn',(side*.39,.06,1.61),.072,.27,'trim',6,(0,side*.40,0))
                    dragon_wing(0,.31,.96,side,.64)
                sphere('Emerald chest jewel',(0,-.34,1.43),.062,'gem',(1,.55,1))
        box('Prominent team sash',(-.18,-.34,1.09),(.13,.045,.32),'cloth',.006)
    if head:
        discard_words(['helmet','Helmet','cowl','Hood','cap','Cap','band','brow','Cheek','central rib'])
        if active=='Storm':
            sphere('Silver thunder helm',(0,.02,1.97),.315,'armor',(1,.96,.55))
            box('Dark open visor',(0,-.27,1.85),(.39,.035,.075),'ink',.006)
            for side in (-1,1):
                box('Angled cheek armour',(side*.265,-.09,1.77),(.09,.25,.25),'armor',.018)
                blade_shape('Winged helm fin',[(side*.20,.045,2.04),(side*.49,.045,2.24),
                    (side*.37,.045,1.97),(side*.24,.045,1.99)],'armor')
            bolt(0,-.285,2.02,.23,'trim')
        elif active=='Dragon':
            sphere('Dragon crown',(0,.03,1.98),.31,'secondary',(1,.95,.55))
            for side in (-1,1):
                cone('Swept dragon horn',(side*.245,.07,2.14),.08,.38,'trim',6,(0,side*.5,0))
                box('Scalloped cheek armour',(side*.26,-.065,1.80),(.10,.24,.24),'armor',.02)
            for i in range(3):cone('Dragon ridge',(0,-.08+i*.12,2.12),.07,.16,'armor',6)
            sphere('Crown emerald',(0,-.29,2.02),.065,'gem',(1,.45,1))
        else:
            sphere('Celestial hood',(0,.10,1.89),.32,'violet',(1,.80,.80))
            for side in (-1,1):box('Hood border',(side*.25,.04,1.78),(.06,.24,.30),'trim',.018)
            torus('Raised orbital halo',(0,.05,2.27),.32,.024,'trim',(math.pi/2,0,0))
            star(0,-.02,2.57,.10,'gem')
            for side in (-1,1):star(side*.27,-.015,2.27,.045)
    if arm:
        if active=='Oracle':
            tapered('Bell sleeve',(sx*.435,0,1.24),(.30,.33),(.23,.28),.37,'violet')
            box('Gilded cuff',(sx*.435,-.02,1.03),(.31,.34,.09),'trim',.017)
            if kind=='Peasant'and sx==1:
                beam('Astral staff',(.51,-.15,.40),(.51,-.15,1.96),.055,'trim')
                torus('Staff orbit',(.51,-.15,2.10),.14,.024,'trim',(math.pi/2,0,0))
                star(.51,-.18,2.10,.095,'gem')
        else:
            box('Articulated vambrace',(sx*.435,-.01,1.08),(.24,.29,.30),'armor',.025)
            for h in (1.00,1.16):box('Gauntlet rim',(sx*.435,-.025,h),(.26,.31,.04),'trim',.008)
        if kind=='Defender'and sx==-1:
            discard_words(['Shield cross','Shield stripe'])
            if active=='Storm':bolt(-.52,-.49,1.10,.62)
            elif active=='Dragon':
                scales(-.52,-.49,1.36,4,.55)
                for side in (-1,1):cone('Shield talon',(-.52+side*.27,-.44,1.51),.055,.20,'trim',6)
                sphere('Shield emerald',(-.52,-.54,1.22),.075,'gem',(1,.45,1))
            else:
                torus('Celestial shield orbit',(-.52,-.49,1.11),.25,.025,'trim',(math.pi/2,0,0))
                star(-.52,-.53,1.11,.20,'gem')
        if kind in ('Defender','Runner')and sx==1:
            discard_words(['Sword blade','Sword fuller'])
            if active=='Dragon':
                blade_shape('Dragon fang sword',[(.37,-.11,1.10),(.56,-.11,1.16),(.57,-.11,1.80),
                    (.44,-.11,2.05),(.36,-.11,1.70)],'armor')
            elif active=='Oracle':
                tapered('Crystal sword',(.435,-.11,1.53),(.15,.045),(.015,.045),.95,'gem')
                star(.435,-.16,1.10,.12)
            else:
                tapered('Thunder longsword',(.435,-.11,1.50),(.15,.05),(.015,.05),.89,'armor')
                bolt(.435,-.145,1.49,.30,'gem')
        if kind=='Archer'and sx==-1:
            for height in (.62,1.59):
                if active=='Dragon':cone('Dragon bow tip',(-.53,-.19,height),.055,.18,'trim',6)
                elif active=='Oracle':star(-.53,-.21,height,.085)
                else:bolt(-.53,-.21,height,.19)
    if leg:
        if active=='Oracle':
            box('Embroidered boot',(sx*.18,-.045,.21),(.30,.38,.25),'secondary',.03)
            beam('Boot constellation',(sx*.18,-.25,.15),(sx*.18,-.25,.35),.023,'trim')
        else:
            tapered('Forged greave',(sx*.18,-.11,.48),(.20,.11),(.24,.11),.30,'armor')
            box('Angular sabaton',(sx*.18,-.09,.18),(.29,.42,.16),'armor',.025)
            if active=='Dragon':scales(sx*.18,-.19,.60,2,.22)
            else:bolt(sx*.18,-.20,.48,.24,'trim')
    result=library_asset(active+'_'+name,current.copy(),category,joint,tint)
    for slot in result.material_slots:slot.material=slot.material.copy()
    return result

asset=premium_asset
display=[]
for active in ('Storm','Dragon','Oracle'):
    palette={'Storm':('#BDD4E0','#EBD172','#84E4F1','#253F55','#5D7E9B'),
             'Dragon':('#315346','#DAB568','#81E69C','#172B27','#315F42'),
             'Oracle':('#CDC3DE','#EDD6A0','#ADDDF4','#28223E','#8660BA')}[active]
    for key,value in zip(('armor','trim','gem','secondary','violet'),palette):MATERIALS[key].diffuse_color=color(value)
    for key in ('cloth','green','linen'):MATERIALS[key].diffuse_color=color(styles[active]['Cloth'])
    objects=[]
    for i,kind in enumerate(('Defender','Archer','Runner','Peasant')):
        for obj in unit(kind):obj.location.x+=(i-1.5)*1.55;objects.append(obj)
    current=[]
    if active=='Storm':
        box('Thunderstone road bed',(0,0,.07),(4.6,4.10,.14),'secondary',.018)
        for x in (-1.05,1.05):
            for y in (-1.35,0,1.35):
                box('Silver road slab',(x,y,.16),(1.87,1.19,.18),'armor',.045)
        for side in (-1,1):
            box('Metal road channel',(side*2.16,0,.15),(.19,4.10,.28),'trim',.025)
            for y in (-1.38,0,1.38):box('Lightning channel',(side*2.035,y,.265),(.085,.60,.026),'gem',.005)
        obj=bolt(0,0,0,2,'gem');obj.rotation_euler.x=math.pi/2;obj.location.z=.266
    elif active=='Dragon':
        box('Obsidian causeway',(0,0,.07),(4.60,4.10,.14),'secondary',.02)
        for row in range(4):
            for col in range(3):
                x=(col-1)*1.36;y=(row-1.5)*.95
                pts=[(x-.64,y-.38,.19),(x+.64,y-.38,.19),(x+.61,y+.15,.19),(x,y+.51,.19),(x-.61,y+.15,.19)]
                # A horizontal extruded shield tile, with genuine scalloped gaps.
                verts=[(a,b,c+h)for h in (-.10,.02)for a,b,c in pts]
                mesh=bpy.data.meshes.new('Scale pavement');mesh.from_pydata(verts,[],[(4,3,2,1,0),(5,6,7,8,9)]+[(i,(i+1)%5,(i+1)%5+5,i+5)for i in range(5)])
                ob=bpy.data.objects.new('Scale pavement',mesh);bpy.context.collection.objects.link(ob);finish_object(ob,'Scale pavement','armor'if(row+col)%2 else'secondary')
        for side in (-1,1):
            box('Gilded dragon kerb',(side*2.20,0,.16),(.18,4.1,.30),'trim',.02)
            for y in (-1.5,0,1.5):cone('Road talon',(side*2.20,y,.37),.08,.20,'gem',6)
    else:
        box('Celestial road bed',(0,0,.065),(4.60,4.10,.13),'secondary',.02)
        for x in (-1.12,1.12):
            for y in (-1.30,0,1.30):box('Violet mosaic',(x,y,.14),(2.02,1.16,.14),'violet',.04)
        for side in (-1,1):box('Double gold border',(side*2.18,0,.16),(.13,4.1,.25),'trim',.025)
        torus('Celestial pavement medallion',(0,0,.225),.83,.045,'trim')
        obj=star(0,0,0,.59,'gem');obj.rotation_euler.x=math.pi/2;obj.location.z=.235
        for y in (-1.52,1.52):
            torus('Orbital inlay',(0,y,.225),.27,.025,'trim')
            cylinder('Starlight stone',(0,y,.235),.075,.03,'gem',8)
    road=library_asset(active+'_RoadTile',current.copy(),'building');road.location.y=4;objects.append(road)
    current=[]
    if active=='Storm':
        for side in (-1,1):
            box('Thunder portal pillar',(side*1.08,0,1.15),(.22,.27,2.30),'armor',.03)
            bolt(side*1.08,-.19,1.28,.55)
        beam('Peaked thunder lintel',(-1.12,0,2.28),(0,0,2.62),.19,'trim')
        beam('Peaked thunder lintel',(0,0,2.62),(1.12,0,2.28),.19,'trim')
        bolt(0,-.16,2.63,.70)
    elif active=='Dragon':
        for side in (-1,1):
            box('Dragon gate pillar',(side*1.10,0,1.16),(.28,.33,2.32),'secondary',.035)
            scales(side*1.10,-.20,2.17,4,.24)
            dragon_wing(side*.10,0,2.2,side,1.18)
        box('Dragon gate lintel',(0,0,2.28),(2.43,.30,.20),'trim',.02)
        sphere('Gate emerald',(0,-.22,2.47),.16,'gem',(1,.45,1))
    else:
        for side in (-1,1):
            cylinder('Astral portal column',(side*1.10,0,1.18),.12,2.36,'armor',8)
            for h in (.20,2.18):torus('Column gold ring',(side*1.1,0,h),.13,.025,'trim')
        for i in range(10):
            a=i*math.pi/10;b=(i+1)*math.pi/10
            beam('Stellar arch',(math.cos(a)*1.1,0,2.1+math.sin(a)*.60),
                 (math.cos(b)*1.1,0,2.1+math.sin(b)*.60),.09,'trim')
        star(0,-.06,2.90,.23,'gem')
    gate=library_asset(active+'_Gateway',current.copy(),'building');gate.location.y=7;objects.append(gate)
    for obj in objects:
        for slot in obj.material_slots:slot.material=slot.material.copy()
    display.append((active,objects))

(OUT/'geometry.json').write_text(json.dumps(ASSETS,separators=(',',':')),encoding='utf8')
scene=bpy.context.scene;scene.render.engine='BLENDER_WORKBENCH'
scene.display.shading.light='STUDIO';scene.display.shading.color_type='MATERIAL'
scene.display.shading.show_cavity=True;scene.display.shading.show_shadows=True
scene.display.shading.background_type='WORLD';scene.world.color=(.09,.12,.17)
bpy.ops.object.camera_add(location=(0,-10,3.2));cam=bpy.context.object;cam.data.type='ORTHO';scene.camera=cam
scene.render.image_settings.file_format='PNG';scene.render.resolution_percentage=100
for active,objects in display:
    for obj in bpy.data.objects:
        if obj.type=='MESH':obj.hide_render=obj not in objects
    for label,target,location,scale,resolution in (
        ('army',(0,0,1.25),(1,-10,3.0),7.2,(1500,720)),
        ('road',(0,4,.1),(3,-1,6),6.0,(1000,850)),
        ('gate',(0,7,1.5),(2,-1,4),4.8,(1000,850))):
        for obj in objects:obj.hide_render=(label=='army'and obj.name.endswith(('_RoadTile','_Gateway')))or(label=='road'and not obj.name.endswith('_RoadTile'))or(label=='gate'and not obj.name.endswith('_Gateway'))
        cam.location=location;cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=scale
        scene.render.resolution_x,scene.render.resolution_y=resolution
        scene.render.filepath=str(OUT/f'{active}-{label}.png');bpy.ops.render.render(write_still=True)
    for obj in objects:obj.hide_render=False
for obj in bpy.data.objects:
    if obj.type=='MESH':obj.hide_render=False
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'premium_v016.blend'))
print('PREMIUM_V016',len(ASSETS),'meshes',sum(len(a['triangles'])for a in ASSETS),'triangles')
