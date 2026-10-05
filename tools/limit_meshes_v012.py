"""Keep each authored mesh below Roblox MeshPart's 20,000 triangle limit."""
from pathlib import Path
import json,bpy
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/blender/v012/base'
bpy.ops.wm.open_mainfile(filepath=str(OUT/'kingdoms_v012.blend'))
assets=json.loads((OUT/'geometry.json').read_text(encoding='utf8'))
changes=[]
for a in assets:
    if len(a['triangles'])<=19000 and a['name']!='Castle_Upgrade3':continue
    obj=bpy.data.objects[a['name']]
    bpy.context.view_layer.objects.active=obj
    bpy.ops.object.select_all(action='DESELECT');obj.select_set(True)
    if len(a['triangles'])>19000:
        mod=obj.modifiers.new('Roblox mesh budget','DECIMATE');mod.ratio=18000/len(a['triangles']);mod.use_collapse_triangulate=True
        bpy.ops.object.modifier_apply(modifier=mod.name)
    obj.data.calc_loop_triangles()
    assert len(obj.data.loop_triangles)<=19000
    # Catalogue placement is separate from mesh coordinates. Their object origins
    # were retained while arranging the Blender scene.
    column=['Village','Castle','Barracks','Archery','Camp','Tower','Farm'].index(obj.name.split('_')[0])
    row=0 if obj.name.endswith('_Base')else 36 if obj.name.endswith('_Upgrade2')else 72
    origin=obj.location-Vector((column*27,row,0))
    points=[v.co+origin for v in obj.data.vertices]
    a['vertices']=[[round(v.x,5),round(v.z,5),round(-v.y,5)]for v in points]
    a['triangles']=[{'v':list(t.vertices),'c':[round(c,4)for c in obj.data.materials[t.material_index].diffuse_color[:3]]}for t in obj.data.loop_triangles]
    location=obj.location.copy();obj.location=origin
    bpy.ops.export_scene.fbx(filepath=str(OUT/(obj.name+'.fbx')),use_selection=True,object_types={'MESH'},apply_unit_scale=True,axis_forward='-Z',axis_up='Y',mesh_smooth_type='FACE',add_leaf_bones=False)
    obj.location=location
    changes.append({'name':a['name'],'triangles':len(a['triangles'])})
(OUT/'geometry.json').write_text(json.dumps(assets,separators=(',',':')),encoding='utf8')
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'kingdoms_v012.blend'))
print(json.dumps(changes))
