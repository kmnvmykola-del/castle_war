"""Pack selected source files for native Studio deployment."""
from pathlib import Path
import json,base64,ctypes,ctypes.util,sys
root=Path(__file__).resolve().parents[1]
files=[root/'src'/name for name in sys.argv[1:]]
payload=json.dumps({str(p.relative_to(root/'src')).replace('\\','/'):p.read_text(encoding='utf8')for p in files},separators=(',',':')).encode()
dll=ctypes.CDLL(ctypes.util.find_library('zstd'))
dll.ZSTD_compressBound.argtypes=[ctypes.c_size_t];dll.ZSTD_compressBound.restype=ctypes.c_size_t
dll.ZSTD_compress.argtypes=[ctypes.c_void_p,ctypes.c_size_t,ctypes.c_void_p,ctypes.c_size_t,ctypes.c_int];dll.ZSTD_compress.restype=ctypes.c_size_t
out=ctypes.create_string_buffer(dll.ZSTD_compressBound(len(payload)))
size=dll.ZSTD_compress(out,len(out),payload,len(payload),5)
encoded=base64.b64encode(out.raw[:size]).decode()
(root/'build/patch-sources.b64').write_text(encoded)
print(json.dumps({'files':len(files),'base64Length':len(encoded)}))
