"""Merge Studio-serialized gameplay roots into the existing binary place.

The original service data is preserved verbatim. Binary layout references:
https://github.com/rojo-rbx/rbx-dom/blob/master/docs/binary.md
"""
from pathlib import Path
import base64
import ctypes
import ctypes.util
import json
import struct

ROOT = Path(__file__).resolve().parents[1]
U32 = struct.Struct('<I')

def u32(data, pos=0):
    return U32.unpack_from(data, pos)[0]

def string(data, pos):
    size = u32(data, pos)
    return data[pos + 4:pos + 4 + size], pos + 4 + size

def lz4(data, expected):
    out = bytearray()
    pos = 0
    while pos < len(data):
        token = data[pos]; pos += 1
        literal = token >> 4
        if literal == 15:
            while True:
                n = data[pos]; pos += 1; literal += n
                if n != 255: break
        out.extend(data[pos:pos + literal]); pos += literal
        if pos == len(data): break
        offset = struct.unpack_from('<H', data, pos)[0]; pos += 2
        assert 0 < offset <= len(out)
        length = (token & 15) + 4
        if token & 15 == 15:
            while True:
                n = data[pos]; pos += 1; length += n
                if n != 255: break
        for _ in range(length): out.append(out[-offset])
    assert len(out) == expected
    return bytes(out)

def decompress(data, expected):
    if data[:4] != b'\x28\xb5\x2f\xfd': return lz4(data, expected)
    library = ctypes.util.find_library('zstd')
    assert library, 'zstd runtime was not found'
    dll = ctypes.CDLL(library)
    dll.ZSTD_decompress.argtypes = [ctypes.c_void_p, ctypes.c_size_t, ctypes.c_void_p, ctypes.c_size_t]
    dll.ZSTD_decompress.restype = ctypes.c_size_t
    output = ctypes.create_string_buffer(expected)
    source = ctypes.create_string_buffer(data)
    size = dll.ZSTD_decompress(output, expected, source, len(data))
    assert size == expected, ('zstd decode failed', size, expected)
    return output.raw

def decode_array(data, n):
    assert len(data) == 4 * n
    return [int.from_bytes(bytes(data[j * n + i] for j in range(4)), 'big') for i in range(n)]

def encode_array(values):
    rows = [v.to_bytes(4, 'big') for v in values]
    return bytes(row[j] for j in range(4) for row in rows)

def refs(data, n):
    out, last = [], 0
    for v in decode_array(data, n):
        last += (v >> 1) ^ -(v & 1)
        out.append(last)
    return out

def encode_refs(values):
    result, last = [], 0
    for v in values:
        delta = v - last; last = v
        result.append((delta << 1) ^ (delta >> 31))
    return encode_array(result)

def pack_string(value):
    return U32.pack(len(value)) + value

class Binary:
    def __init__(self, raw):
        assert raw[:16] == b'<roblox!\x89\xff\r\n\x1a\n\x00\x00'
        self.header = raw[:32]
        self.chunks = []
        self.classes, self.names, self.parents = {}, {}, {}
        pos = 32
        while pos < len(raw):
            tag, compressed, size, reserved = struct.unpack_from('<4sIII', raw, pos)
            assert reserved == 0
            pos += 16
            data = raw[pos:pos + (compressed or size)]
            pos += compressed or size
            if compressed: data = decompress(data, size)
            assert len(data) == size
            self.chunks.append((tag, data))
            if tag == b'INST':
                class_id = u32(data)
                name, p = string(data, 4)
                service = data[p]; n = u32(data, p + 1)
                ids = refs(data[p + 5:p + 5 + 4 * n], n)
                assert class_id not in self.classes
                self.classes[class_id] = dict(name=name, ids=ids, count=n, service=service, start=p+5)
            elif tag == b'PROP':
                class_id = u32(data)
                name, p = string(data, 4)
                if name == b'Name':
                    assert data[p] == 1
                    p += 1
                    for ref in self.classes[class_id]['ids']:
                        value, p = string(data, p)
                        self.names[ref] = value.decode('utf8')
            elif tag == b'PRNT':
                assert data[0] == 0
                n = u32(data, 1)
                children = refs(data[5:5+4*n], n)
                parents = refs(data[5+4*n:], n)
                self.parent_order = list(zip(children, parents))
                self.parents = dict(self.parent_order)
            elif tag == b'END\0':
                assert data == b'</roblox>'
                assert pos == len(raw)
        assert len(self.classes) == u32(self.header, 16)
        all_refs = [ref for c in self.classes.values() for ref in c['ids']]
        assert len(all_refs) == len(set(all_refs)) == u32(self.header, 20)
        assert set(self.parents) == set(all_refs)
        assert all(p == -1 or p in self.parents for p in self.parents.values())

    def shared_strings(self):
        data = next((d for t,d in self.chunks if t == b'SSTR'), b'\0'*8)
        assert u32(data) == 0
        return u32(data, 4), data[8:]

    def service_ref(self, name):
        classes = [c for c in self.classes.values() if c['name'] == name.encode()]
        assert len(classes) == 1 and classes[0]['count'] == 1
        return classes[0]['ids'][0]

def merge(original, runtime):
    original_classes = {c['name'] for c in original.classes.values()}
    assert not original_classes.intersection(c['name'] for c in runtime.classes.values()), 'Class collision requires explicit merge'
    class_offset = max(original.classes) + 1
    ref_offset = max(original.parents) + 1
    ss_count, ss_data = original.shared_strings()
    new_ss_count, new_ss_data = runtime.shared_strings()
    chunks = [(t,d) for t,d in original.chunks if t == b'META']
    if ss_count + new_ss_count:
        chunks.append((b'SSTR', struct.pack('<II',0,ss_count+new_ss_count) + ss_data + new_ss_data))
    chunks.extend((t,d) for t,d in original.chunks if t == b'INST')
    for tag, data in runtime.chunks:
        if tag != b'INST': continue
        c = runtime.classes[u32(data)]
        start, n = c['start'], c['count']
        new = U32.pack(u32(data) + class_offset) + data[4:start]
        new += encode_refs([r + ref_offset for r in c['ids']])
        new += data[start + 4 * n:]
        chunks.append((tag, new))
    chunks.extend((t,d) for t,d in original.chunks if t == b'PROP')
    for tag,data in runtime.chunks:
        if tag != b'PROP': continue
        c = runtime.classes[u32(data)]
        prop, pos = string(data, 4)
        kind = data[pos]; pos += 1
        value = data[pos:]
        if kind == 0x13:
            value = encode_refs([r + ref_offset if r != -1 else -1 for r in refs(value,c['count'])])
        elif kind == 0x1c:
            value = encode_array([i + ss_count for i in decode_array(value,c['count'])])
        elif kind == 0x22:
            # Source strings are type 1. Reject object content needing extra remaps.
            assert all(v in (0,1) for v in decode_array(value[:4*c['count']],c['count']))
        chunks.append((tag,U32.pack(u32(data)+class_offset)+data[4:pos]+value))
    destinations = {
        'Kingdoms': original.service_ref('ReplicatedStorage'),
        'KingdomsServer': original.service_ref('ServerScriptService'),
        'KingdomsClient': original.service_ref('StarterPlayerScripts'),
    }
    new_pairs = []
    for child, parent in runtime.parent_order:
        dest = destinations[runtime.names[child]] if parent == -1 else parent + ref_offset
        new_pairs.append((child+ref_offset,dest))
    pairs = original.parent_order + new_pairs
    # Preserve Studio's descendant-before-parent ordering, including service roots.
    parent_map = dict(pairs)
    children = {}
    for child,parent in pairs: children.setdefault(parent,[]).append(child)
    ordered = []
    def walk(ref):
        for child in children.get(ref,[]): walk(child)
        ordered.append((ref,parent_map[ref]))
    for ref in children[-1]: walk(ref)
    assert len(ordered) == len(pairs)
    chunks.append((b'PRNT',b'\0'+U32.pack(len(ordered))+encode_refs([c for c,p in ordered])+encode_refs([p for c,p in ordered])))
    chunks.append((b'END\0',b'</roblox>'))
    header = original.header[:16] + struct.pack('<II',len(original.classes)+len(runtime.classes),len(pairs)) + original.header[24:]
    raw = header + b''.join(struct.pack('<4sIII',tag,0,len(data),0)+data for tag,data in chunks)
    result = Binary(raw)
    for ref,name in original.names.items(): assert result.names[ref] == name
    for ref,parent in original.parents.items(): assert result.parents[ref] == parent
    for ref,parent in new_pairs: assert result.parents[ref] == parent
    return raw, result

def main():
    import sys
    if '--runtime-bin' in sys.argv:
        model=(ROOT/'build/runtime.bin').read_bytes()
    else:
        parts = sorted((ROOT/'build').glob('runtime-part-*.b64'), key=lambda p: int(p.stem.rsplit('-',1)[1]))
        assert parts, 'Export the Studio runtime roots first'
        encoded = ''.join(p.read_text().strip() for p in parts)
        assert '(truncated)' not in encoded
        model = base64.b64decode(encoded,validate=True)
        (ROOT/'build/runtime.bin').write_bytes(model)
    original = Binary((ROOT/'build/original-place.bin').read_bytes())
    runtime = Binary(model)
    raw, result = merge(original,runtime)
    sources = {}
    for tag,data in result.chunks:
        if tag != b'PROP': continue
        prop,pos = string(data,4)
        if prop != b'Source': continue
        assert data[pos] == 1
        pos += 1
        for ref in result.classes[u32(data)]['ids']:
            source,pos = string(data,pos)
            sources[result.names[ref]] = source.decode('utf8')
    for path in (ROOT/'src').rglob('*.luau'):
        name = path.name.removesuffix('.luau').removesuffix('.server').removesuffix('.client')
        assert sources[name].replace('\r\n','\n') == path.read_text(encoding='utf8'), ('Source mismatch',name)
    assert len(sources) == len(list((ROOT/'src').rglob('*.luau')))
    output = ROOT/'inex.rbxl'
    temporary = ROOT/'build/place-staged.bin'
    temporary.write_bytes(raw)
    Binary(temporary.read_bytes())
    output.write_bytes(raw)
    report = dict(bytes=len(raw),original_instances=len(original.parents),added_instances=len(runtime.parents),scripts=len(sources),roots=['Kingdoms','KingdomsServer','KingdomsClient'],validation='All references, service parents, and source contents match; Windows line endings normalized')
    (ROOT/'build/save-report.json').write_text(json.dumps(report,indent=2),encoding='utf8')
    print(json.dumps(report))

if __name__ == '__main__': main()
