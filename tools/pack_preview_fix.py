import xml.etree.ElementTree as ET
from export_static_meshes import ROOT, OUTPUT
from pack_static_mesh_setup import item

xml=ET.Element('roblox',{'version':'4'})
setup=item(xml,'Model','KingdomsPreviewSetup')
item(setup,'ModuleScript','PreviewInstaller',(ROOT/'tools/install_preview_fix.luau').read_text(encoding='utf8'))
runtime=item(setup,'Folder','Runtime')
item(runtime,'ModuleScript','CollectionUI',(ROOT/'src/CollectionUI.luau').read_text(encoding='utf8'))
ET.ElementTree(xml).write(OUTPUT/'KingdomsPreviewSetup.rbxmx',encoding='utf-8',xml_declaration=True)
print('Preview fix packaged; no executable scripts.')
