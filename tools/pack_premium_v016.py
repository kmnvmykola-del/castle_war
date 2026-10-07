"""Pack the new catalogue, current sources and reversible premium installer."""
from pathlib import Path
import json
import xml.etree.ElementTree as ET
from export_static_meshes import lua
from pack_static_mesh_setup import item
ROOT=Path(__file__).resolve().parents[1]
data=json.loads((ROOT/'assets/roblox_meshes/premium-manifest.json').read_text())
xml=ET.Element('roblox',{'version':'4'});model=item(xml,'Model','KingdomsPremiumSetup')
item(model,'ModuleScript','Installer',(ROOT/'tools/install_premium_v016.luau').read_text(encoding='utf8'))
item(model,'ModuleScript','Manifest','return '+lua(dict(BaseSignature=data['baseSignature'],ChangedModels=data['changedModels'],MeshCount=data['totalMeshParts'])))
runtime=item(model,'Folder','Runtime')
for path in sorted((ROOT/'src').glob('*.luau')):
    kind='Script'if path.name.endswith('.server.luau')else'LocalScript'if path.name.endswith('.client.luau')else'ModuleScript'
    name=path.name.removesuffix('.luau').removesuffix('.server').removesuffix('.client')
    item(runtime,kind,name,path.read_text(encoding='utf8'),kind!='ModuleScript')
out=ROOT/'assets/roblox_meshes/KingdomsPremiumSetup.rbxmx'
ET.ElementTree(xml).write(out,encoding='utf8',xml_declaration=True)
print('PREMIUM_SETUP',out.stat().st_size,'bytes')
