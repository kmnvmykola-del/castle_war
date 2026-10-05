"""Export lighter game meshes while retaining the detailed Blender/FBX originals."""
from pathlib import Path
import json,bpy
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'assets/blender/v012/base'
bpy.ops.wm.open_mainfile(filepath=str(OUT/'kingdoms_v012.blend'))
assets=json.loads((OUT/'geometry.json').read_text(encoding='utf8'))
high=OUT/'geometry.highdetail.json'
if not high.exists():high.write_text(json.dumps(assets,separators=(',',':')),encoding='utf8')
changes=[]
for a in assets:
    if a['name']not in ['Castle_Upgrade2','Castle_Upgrade3']:continue
    original=bpy.data.objects[a['name']]
    obj=original.copy();obj.data=original.data.copy();bpy.context.collection.objects.link(obj)
    obj.data.calc_loop_triangles();count=len(obj.data.loop_triangles)
    bpy.ops.object.select_all(action='DESELECT');obj.select_set(True);bpy.context.view_layer.objects.active=obj
    modifier=obj.modifiers.new('Game LOD','DECIMATE');modifier.ratio=8000/count;modifier.use_collapse_triangulate=True
    bpy.ops.object.modifier_apply(modifier=modifier.name);obj.data.calc_loop_triangles()
    assert len(obj.data.loop_triangles)<=8000
    row=36 if a['name'].endswith('_Upgrade2')else 72
    origin=original.location-Vector((27,row,0))
    points=[v.co+origin for v in obj.data.vertices]
    a['vertices']=[[round(v.x,5),round(v.z,5),round(-v.y,5)]for v in points]
    a['triangles']=[{'v':list(t.vertices),'c':[round(c,4)for c in obj.data.materials[t.material_index].diffuse_color[:3]]}for t in obj.data.loop_triangles]
    obj.location=origin
    bpy.ops.export_scene.fbx(filepath=str(OUT/(a['name']+'_GameLOD.fbx')),use_selection=True,object_types={'MESH'},apply_unit_scale=True,axis_forward='-Z',axis_up='Y',mesh_smooth_type='FACE',add_leaf_bones=False)
    changes.append({'name':a['name'],'gameTriangles':len(a['triangles']),'originalTriangles':count})
    bpy.data.objects.remove(obj,do_unlink=True)
(OUT/'geometry.json').write_text(json.dumps(assets,separators=(',',':')),encoding='utf8')
print(json.dumps(changes))
