import json
import base64,ctypes,ctypes.util
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
out=ROOT/'src'/'Geometry'
out.mkdir(parents=True,exist_ok=True)
modern=[ROOT/'assets/blender/v012'/name/'geometry.json'for name in ['base','collection','decor']]
inputs=modern if all(p.exists()for p in modern)else [ROOT/'assets/blender/geometry.json',ROOT/'assets/blender/skins/geometry.json']
assets=[]
def compact(data):
    payload=json.dumps(data,separators=(',',':')).encode()
    dll=ctypes.CDLL(ctypes.util.find_library('zstd'))
    dll.ZSTD_compressBound.argtypes=[ctypes.c_size_t];dll.ZSTD_compressBound.restype=ctypes.c_size_t
    dll.ZSTD_compress.argtypes=[ctypes.c_void_p,ctypes.c_size_t,ctypes.c_void_p,ctypes.c_size_t,ctypes.c_int];dll.ZSTD_compress.restype=ctypes.c_size_t
    out=ctypes.create_string_buffer(dll.ZSTD_compressBound(len(payload)))
    size=dll.ZSTD_compress(out,len(out),payload,len(payload),15)
    blob=base64.b64encode(out.raw[:size]).decode()
    return 'local e=game:GetService("EncodingService")\nreturn game:GetService("HttpService"):JSONDecode(buffer.tostring(e:DecompressBuffer(e:Base64Decode(buffer.fromstring("'+blob+'")),Enum.CompressionAlgorithm.Zstd)))\n'
for path in inputs:
    if path.exists():assets.extend(json.loads(path.read_text()))
for a in assets:
    palette=[]
    faces=[]
    for f in a['triangles']:
        if f['c'] not in palette: palette.append(f['c'])
        faces.append(f['v']+[palette.index(f['c'])+1])
    def array(values):
        return '{'+','.join(array(v) if isinstance(v,list) else str(v).lower() for v in values)+'}'
    source='return {Name="'+a['name']+'",Tint='+str(a['tint']).lower()+',Joint='+array(a['joint'])+',Vertices='+array(a['vertices'])+',Palette='+array(palette)+',Faces='+array(faces)+'}\n'
    if len(source)>180000:source=compact(dict(Name=a['name'],Tint=a['tint'],Joint=a['joint'],Vertices=a['vertices'],Palette=palette,Faces=faces))
    (out/(a['name']+'.luau')).write_text(source,encoding='utf-8')
print('Geometry modules:',len(list(out.glob('*.luau'))))
