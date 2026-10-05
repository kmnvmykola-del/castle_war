"""Compress local geometry sources for a lossless transfer into Studio."""
import base64
import ctypes
import ctypes.util
import json
from pathlib import Path
root = Path(__file__).resolve().parents[1]
dll = ctypes.CDLL(ctypes.util.find_library('zstd'))
dll.ZSTD_compressBound.argtypes = [ctypes.c_size_t]
dll.ZSTD_compressBound.restype = ctypes.c_size_t
dll.ZSTD_compress.argtypes = [ctypes.c_void_p, ctypes.c_size_t, ctypes.c_void_p, ctypes.c_size_t, ctypes.c_int]
dll.ZSTD_compress.restype = ctypes.c_size_t
payload = json.dumps({p.stem:p.read_text(encoding='utf-8') for p in sorted((root/'src'/'Geometry').glob('*.luau'))},separators=(',',':')).encode()
out = ctypes.create_string_buffer(dll.ZSTD_compressBound(len(payload)))
size = dll.ZSTD_compress(out,len(out),payload,len(payload),5)
encoded = base64.b64encode(out.raw[:size]).decode()
(root/'build'/'geometry-transfer.b64').write_text(encoded)
print(json.dumps({'sources':len(list((root/'src'/'Geometry').glob('*.luau'))),'rawBytes':len(payload),'base64Length':len(encoded)}))
