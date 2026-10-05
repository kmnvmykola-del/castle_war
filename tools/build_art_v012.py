"""Blender-authored replacement catalogue, preserving RTS origins and animation pivots."""
from pathlib import Path
import ast
import json
import math
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
source = (ROOT / 'tools/build_models.py').read_text(encoding='utf8')
exec(compile(source[:source.index('all_objects=[]')], 'base_mesh_primitives', 'exec'))
OUT = ROOT / 'assets/blender/v012/base'
OUT.mkdir(parents=True, exist_ok=True)
ASSETS = []
MATERIALS['roof'].diffuse_color = (.48, .20, .13, 1)
MATERIALS['rooflight'].diffuse_color = (.64, .31, .19, 1)
for name, color in {
    'roofdark': (.29,.11,.08,1), 'plaster': (.87,.80,.62,1),
    'ivory': (.94,.89,.73,1), 'cloth': (.23,.38,.43,1),
    'armor': (.47,.55,.59,1), 'trim': (.78,.57,.23,1),
    'hair': (.24,.12,.065,1), 'soil': (.20,.145,.075,1),
    'leaf': (.28,.47,.23,1), 'flower': (.77,.35,.28,1),
    'white': (.97,.95,.86,1), 'iris': (.14,.23,.25,1),
}.items():
    m = bpy.data.materials.new(name);m.diffuse_color=color;MATERIALS[name]=m

def torus(name,pos,radius,thickness,material='metal',rotation=(0,0,0)):
    bpy.ops.mesh.primitive_torus_add(major_segments=12,minor_segments=4,location=pos,major_radius=radius,minor_radius=thickness,rotation=rotation)
    return finish_object(bpy.context.object,name,material)

def tapered(name,pos,bottom,top,height,material='cloth'):
    x,y,z=pos
    verts=[]
    for width,depth,dz in [(bottom[0],bottom[1],-height/2),(top[0],top[1],height/2)]:
        verts.extend([(x+sx*width/2,y+sy*depth/2,z+dz)for sx,sy in [(-1,-1),(1,-1),(1,1),(-1,1)]])
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)])
    obj=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(obj)
    return finish_object(obj,name,material,.025)

def roof(x,y,z,width,depth,height,material='roof'):
    gable('Roof body',x,y,z,width,depth,height,material)
    half=width/2
    angle=math.atan2(height,half)
    slope=math.hypot(half,height)
    rows=max(3,round(width*.55));cols=max(3,round(depth*.7))
    for side in [-1,1]:
        for row in range(rows):
            t=(row+.5)/rows
            for col in range(cols):
                tile=box('Individual roof tile',(x+side*half*t,y-depth/2+(col+.5)*depth/cols,z+height*(1-t)+.035),(slope/rows+.08,depth/cols-.035,.10),'rooflight'if(row+col)%4==0 else material,0)
                tile.rotation_euler.y=side*angle
    beam('Rounded ridge',(x,y-depth/2-.07,z+height+.13),(x,y+depth/2+.07,z+height+.13),.25,'roofdark')
    for side in [-1,1]:beam('Eave beam',(x+side*half,y-depth/2,z),(x+side*half,y+depth/2,z),.21,'wood')

def arch(x,y,z,width,height,material='lightstone'):
    radius=width/2
    for side in [-1,1]:box('Arch pillar',(x+side*(radius+.16),y,z+height/2),(.32,.30,height),material,.03)
    for i in range(9):
        angle=(i+.5)*math.pi/9
        stone=box('Arch voussoir',(x+math.cos(angle)*(radius+.15),y,z+height+math.sin(angle)*(radius+.15)),(.36,.32,.40),material,.015)
        stone.rotation_euler.y=math.pi/2-angle
    box('Arch keystone',(x,y-.04,z+height+radius+.19),(.39,.40,.48),'ivory',.03)

def lantern(x,y,z):
    beam('Lantern bracket',(x,y+.3,z+.3),(x,y,z+.3),.09,'darkstone')
    box('Warm lantern',(x,y,z),(.23,.23,.34),'gold',.02)
    for height in [z-.21,z+.21]:box('Lantern cap',(x,y,height),(.32,.32,.09),'darkstone',.02)

def barrel(x,y,z=.55,scale=1):
    cylinder('Barrel staves',(x,y,z*scale),.42*scale,1.1*scale,'wood',12)
    for h in [.14,.87]:torus('Barrel hoop',(x,y,h*scale),.43*scale,.035*scale,'metal')
    cylinder('Barrel lid',(x,y,1.11*scale),.41*scale,.06*scale,'lightwood',12)

def planter(x,y):
    tapered('Flower planter',(x,y,.40),(.55,.55),(.80,.80),.80,'roof')
    for ox,oy in [(-.18,0),(.18,.15),(0,-.18)]:
        sphere('Leaves',(x+ox,y+oy,.85),.24,'leaf',(1,1,.6))
        sphere('Flowers',(x+ox,y+oy,1.00),.12,'flower',(1,1,.65))

def house(x,y,width,depth,height):
    box('Warm plaster walls',(x,y,height/2),(width,depth,height),'plaster',.08)
    box('Cut stone footing',(x,y,.27),(width+.28,depth+.28,.54),'darkstone',.035)
    roof(x,y,height,width+.68,depth+.66,height*.46)
    front=y-depth/2-.065
    for sx in [-1,1]:
        box('Timber corner',(x+sx*(width/2-.12),front,height/2),(.22,.22,height),'wood',.02)
        box('Side timber',(x+sx*(width/2+.025),y,height*.54),(.16,depth,.20),'wood',.02)
        for sy in [-1,1]:beam('Side diagonal',(x+sx*(width/2+.04),y+sy*depth*.42,.55),(x+sx*(width/2+.04),y,height*.7),.15,'lightwood')
    for h in [.52,height*.73]:box('Facade timber',(x,front,h),(width,.2,.18),'wood',.02)
    door_width=width*.22;door_height=min(2.1,height*.6)
    box('Inset entry',(x,front-.02,door_height/2), (door_width,.10,door_height),'dark',.02)
    for i in range(5):box('Door plank',(x-door_width/2+(i+.5)*door_width/5,front-.09,door_height/2),(door_width/5-.025,.06,door_height),'wood',.008)
    for h in [door_height*.23,door_height*.76]:box('Door hinge bar',(x,front-.15,h),(door_width*.83,.07,.09),'darkstone',.008)
    torus('Door handle',(x+door_width*.27,front-.19,door_height*.48),.07,.019,'trim',(math.pi/2,0,0))
    arch(x,front-.11,0,door_width,door_height*.68)
    box('Doorstep',(x,front-.37,.12),(door_width+.70,.80,.24),'lightstone',.03)
    for sx in [-1,1]:
        wx=x+sx*width*.31;w=width*.15;h=height*.24;wz=height*.53
        box('Window recess',(wx,front-.015,wz),(w,.08,h),'dark',.02)
        for ox in [-1,1]:box('Window jamb',(wx+ox*(w/2+.07),front-.12,wz),(.12,.16,h+.23),'lightwood',.015)
        box('Window sill',(wx,front-.18,wz-h/2-.1),(w+.4,.34,.14),'lightstone',.015)
        box('Window mullion',(wx,front-.10,wz),(.06,.10,h),'wood',.005)
        for side in [-1,1]:
            shutter=box('Shutter',(wx+side*(w/2+.21),front-.19,wz),(.28,.10,h),'green',.01)
            shutter.rotation_euler.z=side*.12
    box('Stone chimney',(x+width*.28,y+depth*.14,height+1.18),(.75,.85,2.36),'stone',.04)
    box('Chimney cap',(x+width*.28,y+depth*.14,height+2.38),(.95,1.05,.22),'lightstone',.02)
    planter(x+width/2-.65,front-.60)
    lantern(x-door_width*.8,front-.23,door_height+.38)

simple_gable=gable
def gable(name,x,y,z,width,depth,height,material='roof'):
    if name in ['Keep roof','Shed roof']:
        roof(x,y,z,width,depth,height,material)
    else:
        simple_gable(name,x,y,z,width,depth,height,material)

def tower(x,y,width,height,roofed=False):
    box('Squared stone tower',(x,y,height/2),(width,width,height),'stone',.07)
    for h in [.36,height*.36,height*.73,height-.3]:box('Masonry courses',(x,y,h),(width+.11,width+.11,.12),'lightstone',.015)
    for sx in [-1,1]:
        for sy in [-1,1]:
            for i in range(max(2,int(height/1.3))):box('Corner ashlar',(x+sx*(width/2-.13),y+sy*(width/2-.13),.8+i*1.23),(.34,.34,.46),'lightstone',.02)
    for sx in [-1,1]:
        box('Arrow slit',(x+sx*width*.23,y-width/2-.05,height*.63),(.15,.06,.8),'dark',.005)
        box('Slit lintel',(x+sx*width*.23,y-width/2-.10,height*.63+.47),(.36,.18,.13),'lightstone',.015)
    box('Tower cornice',(x,y,height-.15),(width+.44,width+.44,.40),'lightstone',.03)
    if roofed:
        bpy.ops.mesh.primitive_cone_add(vertices=8,radius1=width*.76,radius2=.1,depth=width*1.1,location=(x,y,height+width*.55))
        finish_object(bpy.context.object,'Faceted tower roof','roof')
        for i in range(8):
            a=2*math.pi*i/8
            beam('Roof rib',(x+math.cos(a)*width*.76,y+math.sin(a)*width*.76,height),(x,y,height+width*1.1),.09,'roofdark')
        sphere('Roof finial',(x,y,height+width*1.1+.14),.17,'trim')
    else:
        for sx,sy in [(-1,-1),(-1,1),(1,-1),(1,1)]:box('Battlement',(x+sx*width*.36,y+sy*width*.36,height+.42),(width*.27,width*.27,.85),'lightstone',.035)

old_asset=asset
def asset(name,objects,category,joint=None,tint=False):
    # Structures gain class-specific foreground props and masonry, without moving entry points.
    if name.endswith('_Base') and category=='building':
        kind=name.split('_')[0]
        if kind=='Castle':
            arch(0,-5.32,0,2.7,2.8)
            for sx in [-1,1]:lantern(sx*2.05,-5.6,3.4)
            for h in [1.1,4.5,7.9]:box('Keep stone band',(0,0,h),(12.15,10.15,.18),'lightstone',.02)
            for sx in [-1,1]:
                for h in [1.5,3,4.5,6,7.5]:box('Keep corner blocks',(sx*5.9,-5.12,h),(.46,.25,.58),'lightstone',.02)
        elif kind=='Village':
            barrel(-4,-2);box('Courtyard bench',(-4,2,.80),(2.2,.60,.18),'lightwood',.02)
            for bx in [-4.7,-3.3]:box('Bench foot',(bx,2,.4),(.18,.46,.8),'wood',.02)
        elif kind=='Barracks':
            barrel(4.6,2);box('Weapons crate',(-4.5,2,.45),(1.3,1,.9),'wood',.03)
            for ox in [-.25,0,.25]:beam('Stored spear',(-4.5+ox,2,.6),(-4.5+ox,2.12,3),.075,'metal')
        elif kind=='Archery':
            barrel(3.4,2);box('Arrow supply',(-3.8,-1,.45),(1.0,.7,.9),'wood',.02)
        elif kind=='Camp':
            for i in range(4):barrel(3.1+i%2*.9,1.1+i//2*.9,scale=.7)
            beam('Tent ridge',(0,-2,4.3),(0,4,4.3),.15,'trim')
        elif kind=='Tower':
            arch(0,-2.65,0,1.3,1.4);lantern(1.1,-2.75,2.4)
            box('Stone stair',(0,-3.20,.18),(2.0,1.1,.36),'lightstone',.025)
        elif kind=='Farm':
            barrel(-4.8,1,scale=.8)
            for oy in [-4.5,0.5]:beam('Field curb',(-.4,oy,.25),(4.5,oy,.25),.20,'lightwood')
        objects=current.copy()
    return old_asset(name,objects,category,joint,tint)

all_objects=[]
for kind in ['Village','Castle','Barracks','Archery','Camp','Tower','Farm']:all_objects.extend(building(kind))

def unit(kind):
    global current
    objs=[];current=[]
    tapered('Tailored tunic',(0,0,1.13),(.61,.37),(.65,.40),.64,'cloth')
    box('Tunic hem',(0,0,.84),(.66,.4,.12),'cloth',.035)
    box('Leather belt',(0,-.018,.91),(.64,.41,.09),'wood',.015)
    box('Belt buckle',(0,-.235,.91),(.12,.05,.10),'trim',.012)
    for sx in [-1,1]:box('Collar',(sx*.14,-.2,1.45),(.18,.07,.08),'ivory',.012)
    if kind=='Defender':
        tapered('Forged breastplate',(0,-.17,1.18),(.49,.11),(.57,.13),.45,'armor')
        for sx in [-1,1]:sphere('Shoulder plate',(sx*.32,0,1.40),.17,'armor',(1,.95,.55))
    elif kind=='Runner':
        beam('Diagonal leather strap',(-.23,-.23,.97),(.24,-.23,1.44),.09,'lightwood')
        for sx in [-1,1]:box('Leather scale',(sx*.16,-.215,1.19),(.22,.08,.30),'wood',.018)
    elif kind=='Archer':
        beam('Quiver strap',(-.23,-.23,1.44),(.22,-.23,.99),.055,'lightwood')
        cylinder('Back quiver',(.17,.27,1.16),.13,.55,'wood',10)
        for i in range(3):
            beam('Quivered arrow',(.10+i*.06,.29,1.32),(.10+i*.06,.29,1.68),.025,'lightwood')
            box('Arrow feather',(.10+i*.06,.29,1.65),(.045,.08,.12),'ivory',.005)
    else:
        box('Linen apron',(0,-.23,1.11),(.4,.045,.47),'ivory',.015)
        box('Work satchel',(.26,.05,.93),(.19,.32,.27),'lightwood',.025)
    objs.append(asset(kind+'_Torso',current.copy(),'unit',(0,0,1.12)))
    current=[]
    sphere('Friendly face',(0,-.015,1.73),.30,'skin',(1,.91,1.04))
    for sx in [-1,1]:
        sphere('Ear',(sx*.285,-.02,1.73),.07,'skin',(.7,.6,1))
        sphere('Eye white',(sx*.10,-.274,1.78),.036,'white',(1,.38,1.12))
        sphere('Eye pupil',(sx*.10,-.29,1.78),.021,'iris',(1,.4,1.1))
        beam('Eyebrow',(sx*.10-.045,-.273,1.85),(sx*.10+.045,-.273,1.855),.017,'hair')
    sphere('Nose',(0,-.288,1.70),.05,'skin',(.75,1,.72))
    beam('Smile',(-.045,-.273,1.615),(.045,-.273,1.615),.012,'hair')
    if kind=='Defender':
        sphere('Raised helmet',(0,.025,1.92),.314,'armor',(1,.94,.60))
        torus('Helmet brow',(0,.015,1.85),.303,.030,'trim')
        beam('Helmet central rib',(0,-.23,2.04),(0,.23,2.04),.055,'metal')
        for sx in [-1,1]:box('Cheek guard',(sx*.27,-.01,1.77),(.08,.22,.22),'armor',.025)
    elif kind in ['Archer','Runner']:
        sphere('Leather cowl',(0,.09,1.86),.315,'green',(1,.87,.80))
        box('Hood opening trim',(0,-.055,1.93),(.43,.11,.05),'lightwood',.014)
        for sx in [-1,1]:box('Hood side',(sx*.25,.015,1.75),(.11,.25,.31),'green',.03)
    else:
        sphere('Hair',(0,.07,1.94),.294,'hair',(1,.86,.45))
        cylinder('Folded cap',(0,.02,2.015),.285,.12,'linen',12)
        torus('Cap band',(0,.02,1.97),.278,.033,'cloth')
    objs.append(asset(kind+'_Head',current.copy(),'unit',(0,0,1.56)))
    for side,sx in [('Left',-1),('Right',1)]:
        current=[]
        box('Rounded sleeve',(sx*.435,0,1.25),(.26,.30,.32),'cloth',.055)
        box('Forearm',(sx*.435,-.012,1.005),(.20,.24,.22),'skin',.04)
        box('Cuff',(sx*.435,-.005,1.13),(.225,.26,.07),'lightwood',.015)
        sphere('Hand',(sx*.435,-.025,.87),.125,'skin',(.83,.97,.85))
        if kind in ['Defender','Runner']:box('Bracer',(sx*.435,.015,1.01),(.225,.27,.17),'armor'if kind=='Defender'else'wood',.025)
        if kind=='Defender'and side=='Left':
            tapered('Kite shield',(sx*.52,-.35,1.05),(.20,.13),(.73,.13),.84,'metal')
            tapered('Shield inset',(sx*.52,-.426,1.07),(.15,.035),(.59,.035),.70,'cloth')
            box('Shield cross',(sx*.52,-.46,1.11),(.36,.045,.065),'trim',.01)
            box('Shield stripe',(sx*.52,-.46,1.09),(.06,.045,.49),'trim',.01)
            for ox in [-.25,.25]:sphere('Shield rivet',(sx*.52+ox,-.45,1.38),.035,'trim')
        if kind in ['Defender','Runner']and side=='Right':
            beam('Leather sword grip',(sx*.435,-.035,.85),(sx*.435,-.08,1.04),.09,'wood')
            tapered('Sword blade',(sx*.435,-.11,1.47),(.125,.04),(.02,.04),.83,'metal')
            box('Sword fuller',(sx*.435,-.135,1.45),(.025,.01,.59),'armor',.002)
            box('Sword guard',(sx*.435,-.07,1.08),(.31,.09,.07),'trim',.015)
            sphere('Sword pommel',(sx*.435,-.035,.81),.065,'trim')
        if kind=='Archer'and side=='Left':
            for i in range(8):
                a=-1.43+i*2.86/8;b=-1.43+(i+1)*2.86/8
                beam('Carved recurve bow',(-.53,-.23+math.cos(a)*.23,1.09+math.sin(a)*.65),(-.53,-.23+math.cos(b)*.23,1.09+math.sin(b)*.65),.06,'wood')
            beam('Bow string',(-.53,-.197,.45),(-.53,-.197,1.73),.013,'linen')
            box('Bow grip',(-.53,-.005,1.09),(.09,.095,.16),'lightwood',.01)
        objs.append(asset(kind+'_'+side+'Arm',current.copy(),'unit',(sx*.44,0,1.39)))
    for side,sx in [('Left',-1),('Right',1)]:
        current=[]
        tapered('Linen trousers',(sx*.18,0,.55),(.22,.26),(.27,.30),.55,'linen')
        box('Knee patch',(sx*.18,-.144,.53),(.17,.04,.12),'lightwood',.015)
        box('Sturdy boot',(sx*.18,-.055,.18),(.29,.38,.29),'wood',.045)
        box('Boot cuff',(sx*.18,0,.33),(.30,.32,.10),'lightwood',.02)
        box('Boot sole',(sx*.18,-.055,.055),(.30,.40,.075),'darkstone',.018)
        objs.append(asset(kind+'_'+side+'Leg',current.copy(),'unit',(sx*.18,0,.82)))
    current=[]
    box('Team tabard',(-.19,-.258,1.20),(.11,.025,.28),'uniform',.006)
    objs.append(asset(kind+'_Insignia',current.copy(),'unit',(0,0,1.12),True))
    return objs

for kind in ['Peasant','Defender','Archer','Runner']:all_objects.extend(unit(kind))
# Copy the authored environment section, retaining its established names and bounds.
environment=source[source.index('# Environment models belong'):source.index("(OUT/'geometry.json')")]
exec(compile(environment,'base_environment','exec'))

current=[]
box('Chest carved body',(0,0,.56),(1.80,1.10,1.10),'wood',.075)
for x in [-.65,.65]:
    box('Chest brass band',(x,0,.59),(.16,1.16,1.19),'trim',.025)
    for y in [-.58,.58]:
        for z in [.15,.98]:sphere('Chest rivet',(x,y,z),.055,'trim')
box('Chest lid',(0,0,1.16),(1.92,1.17,.26),'lightwood',.10)
box('Chest clasp',(0,-.62,.89),(.29,.10,.36),'trim',.025)
torus('Chest keyhole',(0,-.68,.90),.047,.018,'dark',(math.pi/2,0,0))
all_objects.append(asset('CollectionChest',current.copy(),'building'))

(OUT/'geometry.json').write_text(json.dumps(ASSETS,separators=(',',':')),encoding='utf8')
for obj in all_objects:
    prefix=obj.name.split('_')[0]
    if prefix in ['Village','Castle','Barracks','Archery','Camp','Tower','Farm']:
        obj.location.x+=['Village','Castle','Barracks','Archery','Camp','Tower','Farm'].index(prefix)*27
        obj.location.y+=0 if obj.name.endswith('_Base') else 36 if obj.name.endswith('_Upgrade2') else 72
    elif prefix in ['Peasant','Defender','Archer','Runner']:
        obj.location.x+=['Peasant','Defender','Archer','Runner'].index(prefix)*4;obj.location.y+=104
    else:obj.hide_render=True
scene=bpy.context.scene
scene.render.engine='BLENDER_WORKBENCH';scene.display.shading.light='STUDIO';scene.display.shading.color_type='MATERIAL'
scene.display.shading.show_cavity=True;scene.display.shading.show_shadows=True;scene.display.shading.background_type='WORLD'
scene.world.color=(.16,.19,.21)
bpy.ops.object.camera_add(location=(125,-100,160));cam=bpy.context.object
cam.rotation_euler=(Vector((78,42,3))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=202;scene.camera=cam
scene.render.resolution_x=1800;scene.render.resolution_y=1250;scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG';scene.render.filepath=str(OUT/'buildings.png')
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'kingdoms_v012.blend'));bpy.ops.render.render(write_still=True)
for obj in all_objects:obj.hide_render=obj.name.split('_')[0]not in ['Peasant','Defender','Archer','Runner']
cam.location=(7,93,5);cam.rotation_euler=(Vector((6,104,1))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=15
scene.render.resolution_x=1600;scene.render.resolution_y=800;scene.render.filepath=str(OUT/'units.png');bpy.ops.render.render(write_still=True)
print('V012_BASE_ASSETS',len(ASSETS),'TRIANGLES',sum(len(a['triangles'])for a in ASSETS))
