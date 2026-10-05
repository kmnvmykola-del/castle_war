"""Update the previously Studio-serialized roots from source without network access.

Preserves folders, entry scripts, Sound properties and references. ModuleScript
properties are rebuilt from the complete source catalogue. save_place validates
every source and merges the roots with the untouched original Studio services.
"""
from pathlib import Path
import struct
from save_place import Binary,U32,u32,string,pack_string,encode_refs

ROOT=Path(__file__).resolve().parents[1]
model=Binary((ROOT/'build/runtime.bin').read_bytes())
files={p.name.removesuffix('.luau').removesuffix('.client').removesuffix('.server'):p for p in (ROOT/'src').rglob('*.luau')}
assert len(files)==len(list((ROOT/'src').rglob('*.luau')))
module_id=next(i for i,c in model.classes.items()if c['name']==b'ModuleScript')
modules=model.classes[module_id]
old_by_name={name:ref for ref,name in model.names.items()}
new_names=sorted(set(files)-set(old_by_name))
next_ref=max(model.parents)+1
new_refs={name:next_ref+i for i,name in enumerate(new_names)}
all_refs=modules['ids']+list(new_refs.values())
names={**model.names,**{ref:name for name,ref in new_refs.items()}}
chunks=[]
for tag,data in model.chunks:
    if tag==b'INST'and u32(data)==module_id:
        data=U32.pack(module_id)+pack_string(b'ModuleScript')+b'\0'+U32.pack(len(all_refs))+encode_refs(all_refs)
    elif tag==b'PROP':
        cid=u32(data);prop,pos=string(data,4)
        if cid==module_id: continue
        if prop==b'Source':
            data=U32.pack(cid)+pack_string(prop)+b'\1'+b''.join(pack_string(files[names[r]].read_text(encoding='utf8').encode())for r in model.classes[cid]['ids'])
    elif tag in (b'PRNT',b'END\0'): continue
    chunks.append((tag,data))
for prop in ('Name','Source'):
    values=[names[r]if prop=='Name'else files[names[r]].read_text(encoding='utf8')for r in all_refs]
    chunks.append((b'PROP',U32.pack(module_id)+pack_string(prop.encode())+b'\1'+b''.join(pack_string(v.encode())for v in values)))
pairs=model.parent_order+[(ref,old_by_name['Geometry']if files[name].parent.name=='Geometry'else old_by_name['Kingdoms'])for name,ref in new_refs.items()]
parents=dict(pairs);children={}
for child,parent in pairs: children.setdefault(parent,[]).append(child)
ordered=[]
def walk(ref):
    for child in children.get(ref,[]):walk(child)
    ordered.append((ref,parents[ref]))
for ref in children[-1]:walk(ref)
chunks.append((b'PRNT',b'\0'+U32.pack(len(pairs))+encode_refs([c for c,p in ordered])+encode_refs([p for c,p in ordered])))
chunks.append((b'END\0',b'</roblox>'))
header=model.header[:20]+U32.pack(len(pairs))+model.header[24:]
raw=header+b''.join(struct.pack('<4sIII',tag,0,len(data),0)+data for tag,data in chunks)
result=Binary(raw)
assert set(names.values())==set(result.names.values())
(ROOT/'build/runtime.bin').write_bytes(raw)
print({'modules':len(all_refs),'newModules':len(new_names),'preservedSound':any(c['name']==b'Sound'for c in result.classes.values()),'bytes':len(raw)})
