from pathlib import Path
import bpy
from mathutils import Vector

root=Path(__file__).resolve().parents[1];folder=root/'assets/blender/v012/base'
bpy.ops.wm.open_mainfile(filepath=str(folder/'kingdoms_v012.blend'))
scene=bpy.context.scene;cam=scene.camera
scene.render.resolution_x=1200;scene.render.resolution_y=1000;scene.render.resolution_percentage=100
for kind in ['Village','Castle','Barracks','Archery','Camp','Tower','Farm']:
    name=kind+'_Upgrade3';obj=scene.objects[name]
    for other in scene.objects:
        if other.type=='MESH':other.hide_render=other!=obj
    bounds=[obj.matrix_world@Vector(corner)for corner in obj.bound_box]
    low=Vector(tuple(min(v[i]for v in bounds)for i in range(3)))
    high=Vector(tuple(max(v[i]for v in bounds)for i in range(3)))
    center=(low+high)/2;size=max(high-low)
    cam.location=center+Vector((size*.70,-size*1.2,size*.85));cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=size*1.55
    scene.render.filepath=str(folder/(kind.lower()+'.png'));bpy.ops.render.render(write_still=True)
    print('BUILDING_PREVIEW',kind,flush=True)
