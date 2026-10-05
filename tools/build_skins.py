"""Author three approved army sets in Blender, retaining base animation pivots."""
from pathlib import Path
import ast
import bpy
import json
from mathutils import Vector

ROOT=Path(__file__).resolve().parents[1]
base=(ROOT/'tools/build_models.py').read_text(encoding='utf8')
# Reuse mesh primitives/exporter, without rebuilding existing buildings.
exec(compile(base[:base.index('all_objects=[]')],str(ROOT/'tools/build_models.py'),'exec'))
OUT=ROOT/'assets/blender/skins';OUT.mkdir(parents=True,exist_ok=True)
ASSETS=[]
styles={'Veteran':{'cloth':(.26,.31,.23,1),'armor':(.42,.44,.43,1),'trim':(.45,.28,.14,1)},'Royal':{'cloth':(.82,.79,.66,1),'armor':(.77,.79,.8,1),'trim':(.83,.63,.22,1)},'Dark':{'cloth':(.18,.17,.2,1),'armor':(.2,.23,.29,1),'trim':(.55,.57,.61,1)}}
original_asset=asset
active_skin=''
def skin_asset(name,objects,category,joint=None,tint=False):
    return original_asset(active_skin+'_'+name,objects,category,joint,False)
asset=skin_asset
unit_source=base[base.index('def unit(kind):'):base.index('for kind in [\'Peasant\',\'Defender\',\'Archer\',\'Runner\']: all_objects.extend(unit(kind))')]
unit_source=unit_source.replace("'uniform'","'cloth'").replace("'metal'","'armor'").replace("'gold'","'trim'")
unit_source=unit_source.replace("    objs.append(asset(kind+'_Torso'", """    box('Decorative collar',(0,-.03,1.46),(.5,.4,.09),'trim',.02)
    for sign in [-1,1]:
        box('Shoulder plate',(sign*.36,0,1.4),(.19,.39,.12),'armor',.025)
    if active_skin=='Royal':
        box('Cape',(0,.24,1.05),(.62,.09,.72),'cloth',.03)
        box('Royal clasp',(0,-.26,1.39),(.12,.05,.12),'trim',.02)
    elif active_skin=='Dark':
        for sign in [-1,1]:
            plate=box('Angular armor',(sign*.2,-.23,1.2),(.25,.06,.43),'armor',.008)
            plate.rotation_euler.y=sign*.12
    else:
        beam('Leather harness',(-.25,-.24,.87),(.25,-.24,1.4),.07,'trim')
    objs.append(asset(kind+'_Torso'""")
unit_source=unit_source.replace("    objs.append(asset(kind+'_Head'", """    if active_skin=='Royal':
        cylinder('Headband',(0,0,1.99),.3,.065,'trim',12)
        if kind=='Defender':
            box('Helmet crest',(0,.07,2.16),(.09,.3,.24),'trim',.015)
    elif active_skin=='Dark' and kind=='Defender':
        box('Angular visor',(0,-.28,1.87),(.51,.06,.13),'armor',.005)
        beam('Helmet ridge',(0,-.17,2.04),(0,.18,2.04),.08,'trim')
    else:
        box('Cap badge',(.15,-.25,1.96),(.09,.04,.1),'trim',.01)
    objs.append(asset(kind+'_Head'""")
unit_source=unit_source.replace("        objs.append(asset(kind+'_'+side+'Arm'", """        if kind=='Defender' and side=='Left':
            beam('Shield emblem',(sign*.5-.2,-.46,.82),(sign*.5+.2,-.46,1.2),.07,'trim')
            if active_skin=='Royal':
                beam('Shield cross',(sign*.5+.2,-.46,.82),(sign*.5-.2,-.46,1.2),.07,'trim')
        if active_skin=='Dark':
            box('Gauntlet',(sign*.44,-.045,1.01),(.23,.28,.17),'armor',.01)
        objs.append(asset(kind+'_'+side+'Arm'""")
exec(compile(unit_source,'approved_skin_units','exec'))
objects=[]
for row,(skin,palette) in enumerate(styles.items()):
    active_skin=skin
    for name,color in palette.items():
        mat=MATERIALS.get(name)or bpy.data.materials.new(name);mat.diffuse_color=color;MATERIALS[name]=mat
    # Objects keep their own material copies, so later styles cannot recolor them.
    for col,kind in enumerate(['Defender','Archer','Runner','Peasant']):
        limbs=unit(kind)
        for obj in limbs:
            for slot in obj.material_slots:slot.material=slot.material.copy()
        current=[]
        box('Side insignia',(-.19,-.3,1.2),(.12,.04,.3),'uniform',.01)
        badge=original_asset(skin+'_'+kind+'_Insignia',current.copy(),'unit',(0,0,1.12),True)
        for obj in limbs+[badge]:obj.location+=Vector((col*3.6,row*4.2,0));objects.append(obj)
(OUT/'geometry.json').write_text(json.dumps(ASSETS,separators=(',',':')),encoding='utf8')
scene=bpy.context.scene
bpy.ops.object.camera_add(location=(5,-10,9))
cam=bpy.context.object;cam.rotation_euler=(Vector((5,4,1))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=18;scene.camera=cam
scene.render.engine='BLENDER_WORKBENCH';scene.display.shading.light='STUDIO';scene.display.shading.color_type='MATERIAL';scene.display.shading.show_cavity=True
scene.world.color=(.25,.28,.3);scene.render.resolution_x=1500;scene.render.resolution_y=1150;scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG';scene.render.filepath=str(OUT/'skins.png')
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'army_skins.blend'));bpy.ops.render.render(write_still=True)
print('ARMY_SKINS',len(ASSETS),'TRIANGLES',sum(len(a['triangles'])for a in ASSETS))
