"""Render each authored set alone for a readable visual review gallery."""
from pathlib import Path
import bpy
import json
from mathutils import Vector

root=Path(__file__).resolve().parents[1]
folder=root/'assets/blender/v012/collection'
styles=json.loads((root/'assets/blender/v012/styles.json').read_text(encoding='utf8'))
bpy.ops.wm.open_mainfile(filepath=str(folder/'collection_v012.blend'))
scene=bpy.context.scene;cam=scene.camera
cam.data.ortho_scale=6.1;scene.render.resolution_x=1400;scene.render.resolution_y=700;scene.render.resolution_percentage=100
for index,style in enumerate(styles):
    for obj in scene.objects:
        if obj.type=='MESH':obj.hide_render=not obj.name.startswith(style['Id']+'_')
    cx=(index%5)*7.4+2.1;cy=(index//5)*6.1
    cam.location=(cx,cy-9,3.1);cam.rotation_euler=(Vector((cx,cy,1.16))-cam.location).to_track_quat('-Z','Y').to_euler()
    scene.render.filepath=str(folder/(style['Id']+'.png'));bpy.ops.render.render(write_still=True)
    print('PREVIEW',style['Id'],flush=True)
cards=['<article><img src="base/units.png" alt="Standard Army"><h2>Standard Army</h2></article>']
cards.extend('<article><img src="collection/'+s['Id']+'.png" alt="'+s['Name']+'"><h2>'+s['Name']+'</h2></article>'for s in styles)
html='''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Frontier Kingdoms · Collection</title><style>body{margin:0;padding:36px;background:#121d24;color:#efead8;font:16px system-ui}h1{font-size:30px;margin-bottom:8px}p{color:#b5c0c5}main{display:grid;grid-template-columns:repeat(auto-fit,minmax(300px,1fr));gap:20px;margin-top:28px}article{background:#263640;border:1px solid #536271;border-radius:12px;overflow:hidden}img{display:block;width:100%}h2{font-size:17px;margin:16px}section{margin-top:40px}section img{max-width:1100px;border-radius:12px}</style><h1>Collection of 25 sets</h1><p>Models created in Blender. 25 army, base, and road sets. Cases cost 300 coins, without duplicates.</p><main>'''+''.join(cards)+'''</main><section><h1>Updated buildings</h1><img src="base/buildings.png" alt="Three building levels"></section></html>'''
(root/'assets/blender/v012/gallery.html').write_text(html,encoding='utf8')
print('GALLERY_READY',len(cards),flush=True)
