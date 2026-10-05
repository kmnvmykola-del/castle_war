"""Losslessly compress every script for a single Studio deployment."""
from pathlib import Path
import json,base64,ctypes,ctypes.util
root=Path(__file__).resolve().parents[1]
files=sorted((root/'src').rglob('*.luau'))
payload=json.dumps({str(p.relative_to(root/'src')).replace('\\','/'):p.read_text(encoding='utf8')for p in files},separators=(',',':')).encode()
dll=ctypes.CDLL(ctypes.util.find_library('zstd'))
dll.ZSTD_compressBound.argtypes=[ctypes.c_size_t];dll.ZSTD_compressBound.restype=ctypes.c_size_t
dll.ZSTD_compress.argtypes=[ctypes.c_void_p,ctypes.c_size_t,ctypes.c_void_p,ctypes.c_size_t,ctypes.c_int];dll.ZSTD_compress.restype=ctypes.c_size_t
out=ctypes.create_string_buffer(dll.ZSTD_compressBound(len(payload)))
size=dll.ZSTD_compress(out,len(out),payload,len(payload),5)
b64=base64.b64encode(out.raw[:size]).decode()
(root/'build/all-sources.b64').write_text(b64)
print(json.dumps({'scripts':len(files),'rawBytes':len(payload),'base64Length':len(b64)}))
