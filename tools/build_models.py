"""Author the approved mildly stylized meshes in Blender; export FBX and geometry."""
import bpy
import json
import math
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets' / 'blender'
OUT.mkdir(parents=True, exist_ok=True)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)

PALETTE = {
    'stone': (0.58, 0.56, 0.49, 1), 'lightstone': (0.76, 0.72, 0.61, 1),
    'darkstone': (0.32, 0.33, 0.31, 1), 'wood': (0.32, 0.17, 0.08, 1),
    'lightwood': (0.56, 0.34, 0.16, 1), 'roof': (0.42, 0.16, 0.11, 1),
    'rooflight': (0.57, 0.25, 0.17, 1), 'skin': (0.77, 0.55, 0.36, 1),
    'metal': (0.46, 0.52, 0.56, 1), 'dark': (0.07, 0.08, 0.09, 1),
    'linen': (0.69, 0.64, 0.47, 1), 'green': (0.27, 0.41, 0.22, 1),
    'gold': (0.73, 0.55, 0.22, 1), 'uniform': (1, 1, 1, 1),
}
MATERIALS = {}
for name, color in PALETTE.items():
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = color
    MATERIALS[name] = mat

ASSETS = []
current = []

def finish_object(obj, name, material, bevel=0):
    obj.name = name
    obj.data.materials.append(MATERIALS[material])
    if bevel:
        mod = obj.modifiers.new('Soft edges', 'BEVEL')
        mod.width = bevel
        mod.segments = 1
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.modifier_apply(modifier=mod.name)
    current.append(obj)
    return obj

def box(name, pos, size, material='stone', bevel=0.025):
    bpy.ops.mesh.primitive_cube_add(size=1, location=pos)
    obj = bpy.context.object
    obj.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish_object(obj, name, material, bevel)

def cylinder(name, pos, radius, depth, material='wood', vertices=12):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=pos)
    return finish_object(bpy.context.object, name, material)

def sphere(name, pos, radius, material='skin', scale=(1,1,1)):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=6, radius=radius, location=pos)
    obj=bpy.context.object
    obj.scale=scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish_object(obj, name, material)

def beam(name, start, end, thickness, material='wood'):
    direction=Vector(end)-Vector(start)
    obj=box(name,(Vector(start)+Vector(end))/2,(thickness,thickness,direction.length),material,0.01)
    obj.rotation_euler=direction.to_track_quat('Z','Y').to_euler()
    return obj

def gable(name, x, y, z, width, depth, height, material='roof'):
    verts=[(-width/2,-depth/2,0),(width/2,-depth/2,0),(-width/2,depth/2,0),(width/2,depth/2,0),(0,-depth/2,height),(0,depth/2,height)]
    faces=[(0,1,4),(2,5,3),(0,4,5,2),(1,3,5,4),(0,2,3,1)]
    mesh=bpy.data.meshes.new(name)
    mesh.from_pydata(verts,[],faces)
    obj=bpy.data.objects.new(name,mesh)
    bpy.context.collection.objects.link(obj)
    obj.location=(x,y,z)
    finish_object(obj,name,material)

def house(x,y,width,depth,height):
    box('Plaster house',(x,y,height/2),(width,depth,height),'lightstone',.08)
    box('Foundation',(x,y,.22),(width+.3,depth+.3,.45),'darkstone',.04)
    gable('Tiled roof',x,y,height,width+.65,depth+.65,height*.48)
    box('Door',(x,y-depth/2-.04,1),(width*.22,.12,2),'wood')
    for wx in [-.31,.31]:
        box('Window',(x+wx*width,y-depth/2-.08,height*.66),(width*.16,.1,height*.22),'dark',.02)
        box('Window ledge',(x+wx*width,y-depth/2-.18,height*.52),(width*.2,.27,.12),'lightwood')
    box('Chimney',(x+width*.27,y+.4,height+1.5),(.9,.9,2),'stone',.04)
    beam('Roof ridge',(x,y-depth/2-.4,height+height*.48),(x,y+depth/2+.4,height+height*.48),.16,'lightwood')

def wall_ring(radius,height,material='stone'):
    for side in [-1,1]:
        box('Outer wall',(side*radius,0,height/2),(1,radius*2+1,height),material,.04)
        box('Rear wall',(0,side*radius,height/2),(radius*2+1,1,height),material,.04)
    for t in range(-int(radius),int(radius)+1,2):
        for side in [-1,1]:
            box('Wall crenellation',(side*radius,t,height+.28),(1.1,.85,.6),material,.015)
            box('Wall crenellation',(t,side*radius,height+.28),(.85,1.1,.6),material,.015)

def tower(x,y,width,height,roof=False):
    box('Tower',(x,y,height/2),(width,width,height),'stone',.08)
    box('Tower cornice',(x,y,height-.35),(width+.45,width+.45,.7),'lightstone',.03)
    box('Arrow slit',(x,y-width/2-.05,height*.66),(.32,.14,1.1),'dark',.01)
    if roof:
        bpy.ops.mesh.primitive_cone_add(vertices=4,radius1=width*.9,radius2=0,depth=width*1.1,location=(x,y,height+width*.55),rotation=(0,0,math.pi/4))
        finish_object(bpy.context.object,'Tower roof','roof')
    else:
        for a,b in [(-1,-1),(-1,1),(1,-1),(1,1)]:
            box('Tower merlon',(x+a*width*.37,y+b*width*.37,height+.4),(width*.26,width*.26,.8),'lightstone',.03)

def asset(name, objects, category, joint=None, tint=False):
    bpy.ops.object.select_all(action='DESELECT')
    for obj in objects: obj.select_set(True)
    bpy.context.view_layer.objects.active=objects[0]
    bpy.ops.object.join()
    obj=bpy.context.object
    obj.name=name
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    center=Vector((0,0,0)) if category=='building' else Vector(joint or (0,0,0))
    # Export vertices in Roblox's Y-up coordinate system; preserve a shared model origin.
    points=[]
    for v in obj.data.vertices:
        p=obj.matrix_world@v.co-center
        points.append([round(p.x,5),round(p.z,5),round(-p.y,5)])
    obj.data.calc_loop_triangles()
    triangles=[]
    for tri in obj.data.loop_triangles:
        col=obj.data.materials[tri.material_index].diffuse_color
        triangles.append({'v':list(tri.vertices),'c':[round(c,4) for c in col[:3]]})
    ASSETS.append({'name':name,'category':category,'joint':[center.x,center.z,-center.y], 'tint':tint,'vertices':points,'triangles':triangles})
    # Keep each model at the origin in its individual FBX, then arrange the .blend catalogue.
    bpy.ops.export_scene.fbx(filepath=str(OUT/(name+'.fbx')),use_selection=True,object_types={'MESH'},apply_unit_scale=True,axis_forward='-Z',axis_up='Y',mesh_smooth_type='FACE',add_leaf_bones=False)
    return obj

def building(kind):
    global current
    current=[]
    if kind=='Village':
        house(0,0,7,6,4)
        for x,y in [(-4,-4),(-4,4),(4,4)]: cylinder('Fence post',(x,y,.7),.16,1.4,'lightwood',8)
        beam('Fence',(-4,4,.9),(4,4,.9),.2,'lightwood')
        cylinder('Barrel',(4,-2,.6),.46,1.2,'wood',10)
    elif kind=='Castle':
        box('Keep',(0,0,4.3),(12,10,8.6),'stone',.08)
        gable('Keep roof',0,0,8.6,13,11,4)
        for x in [-6,6]:
            for y in [-5,5]: tower(x,y,3.5,11.5,True)
        box('Entrance',(0,-5.13,2),(2.6,.2,4),'wood',.03)
        for x in [-3.7,3.7]: box('Keep window',(x,-5.13,5.8),(1,.18,1.9),'dark')
        box('Stone steps',(0,-6.3,.25),(4,2,.5),'lightstone',.025)
    elif kind=='Barracks':
        house(0,0,9,7,4.3)
        for x in [-4,4]:
            box('Training post',(x,-5,1.4),(.3,.3,2.8),'wood')
            box('Practice shield',(x,-5.18,1.9),(1.1,.2,1.3),'metal',.06)
            beam('Training sword',(x-.65,-5.35,1.2),(x+.65,-5.35,2.5),.13,'metal')
    elif kind=='Archery':
        house(-1,1,6,6,3.7)
        for x in [-2.8,0,2.8]:
            cylinder('Target',(x,-4.2,1.6),.85,.22,'linen',16).rotation_euler=(math.pi/2,0,0)
            cylinder('Target center',(x,-4.35,1.6),.33,.1,'roof',12).rotation_euler=(math.pi/2,0,0)
            beam('Target leg',(x,-4.1,.1),(x,-4.1,1.8),.18,'wood')
        for x in [-3,3]: beam('Archery awning post',(x,3,0),(x,3,4),.2,'lightwood')
    elif kind=='Camp':
        gable('Large canvas tent',0,1,.2,7,6,4,'green')
        box('Tent entrance',(0,-2.06,1.2),(1.5,.08,2.4),'dark')
        for x in [-4,4]:
            cylinder('Camp post',(x,-3,1.5),.14,3,'lightwood',8)
            beam('Camp rope',(x,-3,2.8),(x*.7,1,4),.06,'wood')
        box('Supply chest',(3,-3,.5),(1.4,1,1),'wood',.07)
    elif kind=='Tower':
        tower(0,0,4.8,9.8,False)
        box('Tower door',(0,-2.5,1.2),(1.3,.16,2.4),'wood')
        box('Base',(0,0,.25),(6,6,.5),'darkstone',.04)
        for x in [-1.6,1.6]: beam('Arrow rack',(x,-2.2,8.5),(x,-3,9),.15,'lightwood')
    elif kind=='Farm':
        house(-2,2,5,4,3)
        box('Field soil',(2,-2,.13),(6,6,.25),'wood',0)
        for x in [0,1,2,3,4]:
            for y in [-4,-3,-2,-1,0]:
                cylinder('Wheat stem',(x,y,.65),.045,1,'gold',5)
                sphere('Grain',(x,y,1.12),.13,'linen',(.6,.6,1.5))
        cylinder('Food barrel',(-4,-2,.6),.5,1.2,'wood',10)
    objs=[asset(kind+'_Base',current.copy(),'building')]
    current=[]
    # Each tier is a complete replacement mesh, including its taller main building.
    core=objs[0].copy();core.data=objs[0].data.copy();bpy.context.collection.objects.link(core)
    core.scale.z=1.12;current.append(core)
    if kind=='Village':
        for x in [-5,5]:
            for y in [-4.5,4.5]: cylinder('Improved fence',(x,y,1),.18,2,'wood',8)
        for y in [-4.5,4.5]: beam('Improved railing',(-5,y,1.3),(5,y,1.3),.22,'lightwood')
        box('Store shed',(5,1,1.4),(2.3,3,2.8),'lightwood')
        gable('Shed roof',5,1,2.8,2.8,3.5,1.2)
    elif kind=='Castle': wall_ring(9,3.5)
    elif kind=='Farm':
        house(4,3,3,3,2.5)
        for x in [-5,5]: beam('Farm fence',(x,-5,.9),(x,5,.9),.18,'lightwood')
    elif kind=='Tower':
        box('Reinforced base',(0,0,1),(7,7,2),'lightstone',.08)
        for x in [-2.7,2.7]: box('Buttress',(x,0,3),(.7,5.7,5.5),'darkstone',.05)
    else:
        for x in [-5.6,5.6]:
            for y in [-4.5,4.5]: cylinder('Palisade post',(x,y,1.2),.22,2.4,'wood',8)
        beam('Reinforced palisade',(-5.6,4.5,1.4),(5.6,4.5,1.4),.33,'lightwood')
        box('Tool chest',(4.3,2,.6),(1.8,1.4,1.2),'wood',.05)
    if kind in ['Barracks','Archery','Camp']:
        house(-5,2,3.3,3,3.1)
    if kind=='Castle':
        box('Gate arch',(0,-9,3.5),(5.5,1.2,1),'lightstone',.06)
        for x in [-2.6,2.6]:box('Gate pillar',(x,-9,1.8),(1,1.2,3.6),'lightstone',.04)
    objs.append(asset(kind+'_Upgrade2',current.copy(),'building'))
    current=[]
    core=objs[1].copy();core.data=objs[1].data.copy();bpy.context.collection.objects.link(core)
    core.scale.z=1.1;current.append(core)
    if kind=='Village':
        house(-5,2,3.4,3,2.5)
        tower(5,3,1.8,4.6,True)
    elif kind=='Castle':
        for x in [-9,9]:
            for y in [-9,9]: tower(x,y,2.6,6.2,True)
    elif kind=='Tower':
        for x,y in [(-3,0),(3,0),(0,3)]: tower(x,y,1.3,7.4,False)
        box('Top reinforcement',(0,0,7.2),(5.5,5.5,.5),'lightstone')
    elif kind=='Farm':
        cylinder('Grain silo',(-4,4,2.2),1,4.4,'lightwood',12)
        bpy.ops.mesh.primitive_cone_add(vertices=12,radius1=1.3,radius2=.1,depth=1,location=(-4,4,4.9))
        finish_object(bpy.context.object,'Silo roof','roof')
        box('Grain sacks',(3,-5,.6),(3,1.2,1.2),'linen',.16)
    else:
        tower(5.4,3.5,1.8,5.8,True)
        box('Rear stone wall',(0,5,1.1),(11.5,.6,2.2),'stone',.025)
        house(0,5.3,5,2.5,3.6)
    objs.append(asset(kind+'_Upgrade3',current.copy(),'building'))
    return objs

all_objects=[]
for kind in ['Village','Castle','Barracks','Archery','Camp','Tower','Farm']:
    all_objects.extend(building(kind))

def unit(kind):
    global current
    objs=[]
    # Independent mesh limbs preserve animation pivots on import.
    current=[]
    box('Tunic',(0,0,1.12),(.64,.35,.72),'uniform',.07)
    box('Belt',(0,-.01,.85),(.68,.38,.1),'wood',.015)
    if kind=='Defender':
        box('Breastplate',(0,-.19,1.14),(.51,.09,.58),'metal',.045)
    if kind=='Runner':
        box('Leather armor',(0,-.185,1.16),(.53,.07,.53),'lightwood',.035)
    objs.append(asset(kind+'_Torso',current.copy(),'unit',(0,0,1.12),True))
    current=[]
    sphere('Head',(0,0,1.73),.285,'skin',(1,.92,1.07))
    for x in [-.095,.095]: sphere('Eye',(x,-.252,1.78),.027,'dark')
    box('Nose',(0,-.28,1.69),(.075,.1,.07),'skin',.012)
    if kind=='Defender':
        sphere('Helmet',(0,.018,1.88),.3,'metal',(1,.94,.65))
        box('Helmet rim',(0,-.015,1.81),(.62,.5,.075),'metal',.025)
    elif kind in ['Archer','Runner']:
        sphere('Hood',(0,.06,1.81),.3,'green',(1,.85,1.04))
        sphere('Face',(0,-.17,1.72),.22,'skin',(1,.55,1.03))
        for x in [-.082,.082]: sphere('Eye',(x,-.284,1.77),.024,'dark')
    else:
        cylinder('Simple cap',(0,0,1.96),.3,.12,'linen',12)
    objs.append(asset(kind+'_Head',current.copy(),'unit',(0,0,1.56)))
    for side, sign in [('Left',-1),('Right',1)]:
        current=[]
        box('Sleeve',(sign*.44,0,1.19),(.25,.29,.38),'uniform',.035)
        box('Forearm',(sign*.44,-.01,.92),(.22,.25,.24),'skin',.035)
        if side=='Left' and kind=='Defender':
            box('Shield',(sign*.5,-.3,1.01),(.66,.12,.88),'lightwood',.08)
            box('Shield rim',(sign*.5,-.38,1.01),(.72,.05,.94),'metal',.06)
            box('Shield face',(sign*.5,-.42,1.01),(.55,.04,.74),'uniform',.03)
        if side=='Right' and kind in ['Defender','Runner']:
            beam('Sword',(sign*.44,-.03,.91),(sign*.44,-.13,1.72),.1,'metal')
            box('Crossguard',(sign*.44,-.07,1),(.34,.12,.075),'gold',.015)
        if side=='Left' and kind=='Archer':
            for i in range(6):
                a=-math.pi*.45+i*math.pi*.9/6
                b=-math.pi*.45+(i+1)*math.pi*.9/6
                beam('Bow',(-.53,-.26+math.cos(a)*.19,1.03+math.sin(a)*.63),(-.53,-.26+math.cos(b)*.19,1.03+math.sin(b)*.63),.07,'wood')
            beam('Bowstring',(-.53,-.23,.43),(-.53,-.23,1.64),.018,'linen')
        objs.append(asset(kind+'_'+side+'Arm',current.copy(),'unit',(sign*.44,0,1.39)))
    for side,sign in [('Left',-1),('Right',1)]:
        current=[]
        box('Trouser leg',(sign*.18,0,.52),(.26,.29,.6),'linen',.025)
        box('Boot',(sign*.18,-.045,.17),(.29,.39,.28),'wood',.035)
        objs.append(asset(kind+'_'+side+'Leg',current.copy(),'unit',(sign*.18,0,.82)))
    return objs

for kind in ['Peasant','Defender','Archer','Runner']: all_objects.extend(unit(kind))

# Environment models belong to the same authored Blender catalogue.
current=[]
cylinder('Trunk',(0,0,1.5),.35,3,'wood',10)
for z,r in [(3,2.1),(4.2,1.65),(5.3,1.05)]:
    bpy.ops.mesh.primitive_cone_add(vertices=10,radius1=r,radius2=.15,depth=2.6,location=(0,0,z))
    finish_object(bpy.context.object,'Tree canopy','green')
all_objects.append(asset('Tree',current.copy(),'building'))
current=[]
for x,y,z,r in [(0,0,.6,1.2),(.7,.3,.35,.6),(-.7,-.2,.25,.45)]: sphere('Rock',(x,y,z),r,'stone',(1,.82,.64))
all_objects.append(asset('Rock',current.copy(),'building'))
current=[]
box('Ruined tower foundation',(0,0,.22),(6,6,.44),'darkstone',.04)
for x,y,angle in [(-2,-1,.3),(2,1,-.4),(-1,2,.9),(1,-2,-.8)]:
    obj=box('Broken tower wall',(x,y,.7),(2.1,.8,1.3),'stone',.08)
    obj.rotation_euler.z=angle
for x,y,r in [(-2.8,2.3,.6),(2.4,-2.5,.5),(0,1,.7),(1,0,.45)]: sphere('Tower rubble',(x,y,.4),r,'lightstone',(1,.7,.65))
all_objects.append(asset('Tower_Ruins',current.copy(),'building'))
current=[]
for x in range(-16,17): box('Bridge plank',(x,0,.35),(.93,7,.4),'lightwood',.025)
for y in [-3.4,3.4]:
    beam('Bridge railing',(-16,y,1.8),(16,y,1.8),.22,'wood')
    for x in range(-15,16,5): cylinder('Bridge post',(x,y,.95),.16,1.9,'wood',8)
all_objects.append(asset('Bridge',current.copy(),'building'))
current=[]
box('Banner cloth',(.85,0,0),(1.7,.09,1.1),'uniform',.015)
all_objects.append(asset('FlagCloth',current.copy(),'building',tint=True))
current=[]
cylinder('Banner pole',(0,0,1.6),.07,3.2,'wood',8)
all_objects.append(asset('FlagPole',current.copy(),'building'))

(OUT/'geometry.json').write_text(json.dumps(ASSETS,separators=(',',':')),encoding='utf-8')
# Arrange an inspectable model catalogue and render a contact sheet.
for obj in all_objects:
    prefix=obj.name.split('_')[0]
    if prefix in ['Village','Castle','Barracks','Archery','Camp','Tower','Farm']:
        index=['Village','Castle','Barracks','Archery','Camp','Tower','Farm'].index(prefix)
        tier=0 if obj.name.endswith('_Base') else 1 if obj.name.endswith('_Upgrade2') else 2
        obj.location.x += index*27
        obj.location.y += tier*36
    elif prefix in ['Peasant','Defender','Archer','Runner']:
        obj.location.x += ['Peasant','Defender','Archer','Runner'].index(prefix)*4
        obj.location.y += 104
    else:
        obj.location.x+= {'Tree':22,'Rock':29,'Bridge':45,'FlagCloth':38,'FlagPole':38}[prefix]
        obj.location.y+=104 if prefix!='Bridge' else 129
    obj.hide_render = 'Ruins' in obj.name
bpy.ops.object.light_add(type='AREA',location=(90,-40,100))
light=bpy.context.object
light.data.energy=8000
light.data.shape='DISK'
light.data.size=100
bpy.ops.object.camera_add(location=(125,-95,180))
cam=bpy.context.object
target=Vector((80,45,2))
cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler()
cam.data.type='ORTHO'
cam.data.ortho_scale=210
bpy.context.scene.camera=cam
bpy.context.scene.render.engine='BLENDER_WORKBENCH'
bpy.context.scene.display.shading.light='STUDIO'
bpy.context.scene.display.shading.color_type='MATERIAL'
bpy.context.scene.display.shading.show_shadows=True
bpy.context.scene.display.shading.show_cavity=True
bpy.context.scene.display.shading.background_type='WORLD'
bpy.context.scene.render.resolution_x=1800
bpy.context.scene.render.resolution_y=1200
bpy.context.scene.render.resolution_percentage=100
bpy.context.scene.world.color=(.35,.35,.35)
bpy.context.scene.render.image_settings.file_format='PNG'
bpy.context.scene.render.filepath=str(OUT/'catalogue.png')
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'kingdoms_models.blend'))
bpy.ops.render.render(write_still=True)
cam.location=(10,93,7)
cam.rotation_euler=(Vector((6,104,1))-cam.location).to_track_quat('-Z','Y').to_euler()
cam.data.ortho_scale=18
bpy.context.scene.render.filepath=str(OUT/'units.png')
bpy.ops.render.render(write_still=True)
print('KINGDOMS_ASSETS',len(ASSETS),'TRIANGLES',sum(len(x['triangles']) for x in ASSETS))
