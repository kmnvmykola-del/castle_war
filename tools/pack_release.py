"""Pack current game sources for the guarded Studio source-only release update."""
from pathlib import Path
import xml.etree.ElementTree as ET
from pack_static_mesh_setup import item

ROOT=Path(__file__).resolve().parents[1]

def main():
    xml=ET.Element('roblox',{'version':'4'})
    model=item(xml,'Model','KingdomsReleaseSetup')
    item(model,'ModuleScript','Installer',(ROOT/'tools/install_release.luau').read_text(encoding='utf8'))
    runtime=item(model,'Folder','Runtime')
    paths=sorted((ROOT/'src').glob('*.luau'))
    for path in paths:
        kind='Script' if path.name.endswith('.server.luau') else 'LocalScript' if path.name.endswith('.client.luau') else 'ModuleScript'
        name=path.name.removesuffix('.luau').removesuffix('.server').removesuffix('.client')
        item(runtime,kind,name,path.read_text(encoding='utf8'),kind!='ModuleScript')
    out=ROOT/'assets/roblox_meshes/KingdomsReleaseSetup.rbxmx'
    ET.ElementTree(xml).write(out,encoding='utf8',xml_declaration=True)
    print(f'{out}: {len(paths)} sources, {out.stat().st_size} bytes')

if __name__=='__main__':main()
