"""Package only neutral meshes and two updated modules for an existing install."""
import json
import xml.etree.ElementTree as ET
from export_static_meshes import ROOT, OUTPUT
from pack_static_mesh_setup import item
from retry_mesh_import import subset


def main():
    full = json.loads((OUTPUT/'KingdomsMeshCatalogue.gltf').read_text())
    names = [mesh['name'] for mesh in full['meshes'] if mesh['name'].endswith('__Neutral')]
    document, data = subset(full, (OUTPUT/'KingdomsMeshCatalogue.bin').read_bytes(), names)
    path = OUTPUT/'KingdomsMeshNeutral.gltf'
    document['buffers'] = [{'byteLength':len(data),'uri':path.with_suffix('.bin').name}]
    path.with_suffix('.bin').write_bytes(data)
    path.write_text(json.dumps(document,separators=(',',':')),encoding='utf8')
    xml = ET.Element('roblox', {'version':'4'})
    setup = item(xml,'Model','KingdomsNeutralSetup')
    item(setup,'ModuleScript','NeutralInstaller',(ROOT/'tools/install_neutral_meshes.luau').read_text(encoding='utf8'))
    runtime = item(setup,'Folder','Runtime')
    for name in ('Art','MeshCatalog'):
        item(runtime,'ModuleScript',name,(ROOT/f'src/{name}.luau').read_text(encoding='utf8'))
    ET.ElementTree(xml).write(OUTPUT/'KingdomsNeutralSetup.rbxmx',encoding='utf-8',xml_declaration=True)
    print(json.dumps({'neutralMeshes':len(names),'binaryBytes':len(data),'accessorBytesPreserved':True}))


if __name__=='__main__':main()
