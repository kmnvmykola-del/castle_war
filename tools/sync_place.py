"""Synchronize src into an existing Studio place, preserving its services.

Unlike the legacy two-stage exporter, this reads the saved place itself. Existing
instance references, metadata, sound and all non-script properties are retained.
Binary format: https://github.com/rojo-rbx/rbx-dom/blob/master/docs/binary.md
"""
from pathlib import Path
import ctypes
import ctypes.util
import json
import shutil
import struct
import time
import uuid

from save_place import Binary, U32, u32, string, pack_string, encode_refs

ROOT = Path(__file__).resolve().parents[1]


def rows(data, count, width):
    assert len(data) == count * width
    return [bytes(data[j * count + i] for j in range(width)) for i in range(count)]


def interleave(values):
    return bytes(value[j] for j in range(len(values[0])) for value in values)


def active_roots(model):
    def child(parent, name):
        refs = [ref for ref, value in model.names.items() if value == name and model.parents.get(ref) == parent]
        assert len(refs) == 1, ('Expected one game instance', name, refs)
        return refs[0]
    replicated = child(-1, 'ReplicatedStorage')
    scripts = child(-1, 'ServerScriptService')
    starter = child(child(-1, 'StarterPlayer'), 'StarterPlayerScripts')
    return (child(replicated, 'Kingdoms'), child(scripts, 'KingdomsServer'), child(starter, 'KingdomsClient'))


def active_refs(model):
    roots = set(active_roots(model))
    refs = set()
    for ref in model.parents:
        ancestor = ref
        while ancestor != -1:
            if ancestor in roots:
                refs.add(ref)
                break
            ancestor = model.parents[ancestor]
    return refs


def files_for_place(model):
    root = active_roots(model)[0]
    installed = any(name == 'MeshTemplates' and model.parents[ref] == root for ref, name in model.names.items())
    return sorted((ROOT / 'src').glob('*.luau') if installed else (ROOT / 'src').rglob('*.luau'))


def sources(model):
    result = {}
    active = active_refs(model)
    for tag, data in model.chunks:
        if tag != b'PROP':
            continue
        prop, pos = string(data, 4)
        if prop != b'Source':
            continue
        assert data[pos] == 1
        pos += 1
        for ref in model.classes[u32(data)]['ids']:
            value, pos = string(data, pos)
            if ref not in active:
                continue
            name = model.names[ref]
            assert name not in result, ('Duplicate source name', name)
            result[name] = value.decode('utf8').replace('\r\n', '\n')
        assert pos == len(data)
    return result


def extend_property(prop, kind, data, count, additions):
    if kind == 1:
        old, pos = [], 0
        for _ in range(count):
            value, pos = string(data, pos)
            old.append(value)
        assert pos == len(data)
        extra = [('{'+str(uuid.uuid4())+'}').encode() if prop == b'ScriptGuid' else b'' for _ in additions]
        return b''.join(pack_string(v) for v in old + extra)
    if kind == 2:
        assert len(data) == count
        return data + bytes(len(additions))
    widths = {0x1b: 8, 0x1c: 4, 0x1f: 16, 0x21: 8}
    if kind not in widths:
        raise ValueError(('Unsupported new ModuleScript property', prop, kind))
    width = widths[kind]
    old = rows(data, count, width)
    if prop == b'UniqueId':
        stamp = int(time.time()) - 1609459200
        extra = [struct.pack('<IIq', ref, stamp, uuid.uuid4().int & ((1 << 63)-1)) for ref in additions]
    elif kind in (0x1b, 0x1c):
        extra = [old[0]] * len(additions)
    else:
        extra = [bytes(width)] * len(additions)
    return interleave(old + extra)


def synchronize(model, files):
    module_id = next(i for i, c in model.classes.items() if c['name'] == b'ModuleScript')
    module = model.classes[module_id]
    active = active_refs(model)
    existing = {name: ref for ref, name in model.names.items() if ref in active}
    expected = {p.name.removesuffix('.luau').removesuffix('.server').removesuffix('.client'): p for p in files}
    assert len(expected) == len(files)
    assert set(sources(model)) <= set(expected), 'Place contains scripts outside src; review them first'
    added_names = sorted(set(expected) - set(existing))
    next_ref = max(model.parents) + 1
    added = {name: next_ref + i for i, name in enumerate(added_names)}
    all_refs = module['ids'] + list(added.values())
    names = {**model.names, **{ref: name for name, ref in added.items()}}
    chunks, preserved = [], []
    for tag, original in model.chunks:
        data = original
        if tag == b'INST' and u32(data) == module_id:
            data = U32.pack(module_id) + pack_string(b'ModuleScript') + b'\0' + U32.pack(len(all_refs)) + encode_refs(all_refs)
        elif tag == b'PROP':
            cid = u32(data)
            prop, pos = string(data, 4)
            kind = data[pos]
            prefix, payload = data[:pos+1], data[pos+1:]
            refs = all_refs if cid == module_id else model.classes[cid]['ids']
            if prop == b'Source' or cid == module_id and prop == b'Name':
                assert kind == 1
                old_values, offset = {}, 0
                for ref in model.classes[cid]['ids']:
                    old_values[ref], offset = string(payload, offset)
                values = []
                for ref in refs:
                    if prop == b'Name':
                        values.append(names[ref].encode())
                    elif ref in active or ref in added.values():
                        values.append(expected[names[ref]].read_text(encoding='utf8').encode())
                    else:
                        values.append(old_values[ref])
                data = prefix + b''.join(pack_string(v) for v in values)
            elif cid == module_id and added:
                data = prefix + extend_property(prop, kind, payload, module['count'], list(added.values()))
        if tag in (b'PRNT', b'END\0'):
            continue
        chunks.append((tag, data))
        if data == original:
            preserved.append((tag, data))
    pairs = model.parent_order + [(ref, existing['Geometry'] if expected[name].parent.name == 'Geometry' else existing['Kingdoms']) for name, ref in added.items()]
    parents, children = dict(pairs), {}
    for child, parent in pairs:
        children.setdefault(parent, []).append(child)
    ordered = []

    def walk(ref):
        for child in children.get(ref, []):
            walk(child)
        ordered.append((ref, parents[ref]))

    for ref in children[-1]:
        walk(ref)
    assert len(ordered) == len(pairs)
    chunks.append((b'PRNT', b'\0' + U32.pack(len(pairs)) + encode_refs([c for c, p in ordered]) + encode_refs([p for c, p in ordered])))
    chunks.append((b'END\0', b'</roblox>'))
    header = model.header[:20] + U32.pack(len(pairs)) + model.header[24:]
    return header, chunks, names, added, preserved


def serialize(header, chunks):
    library = ctypes.util.find_library('zstd')
    assert library, 'zstd runtime was not found'
    dll = ctypes.CDLL(library)
    dll.ZSTD_compressBound.argtypes = [ctypes.c_size_t]
    dll.ZSTD_compressBound.restype = ctypes.c_size_t
    dll.ZSTD_compress.argtypes = [ctypes.c_void_p, ctypes.c_size_t, ctypes.c_void_p, ctypes.c_size_t, ctypes.c_int]
    dll.ZSTD_compress.restype = ctypes.c_size_t
    result = [header]
    for tag, data in chunks:
        output = ctypes.create_string_buffer(dll.ZSTD_compressBound(len(data)))
        size = dll.ZSTD_compress(output, len(output), data, len(data), 9)
        assert size <= len(output), 'Zstd compression failed'
        compressed = output.raw[:size]
        use = tag != b'END\0' and len(compressed) < len(data)
        result.append(struct.pack('<4sIII', tag, len(compressed) if use else 0, len(data), 0))
        result.append(compressed if use else data)
    return b''.join(result)


def main():
    output = ROOT / 'inex.rbxl'
    build = ROOT / 'build'
    build.mkdir(exist_ok=True)
    before = Binary(output.read_bytes())
    files = files_for_place(before)
    header, chunks, names, added, preserved = synchronize(before, files)
    raw = serialize(header, chunks)
    after = Binary(raw)
    assert after.names == names
    for ref, parent in before.parents.items():
        assert after.parents[ref] == parent, ('Parent changed', ref)
    assert all(item in after.chunks for item in preserved)
    actual = sources(after)
    assert len(actual) == len(files)
    for path in files:
        name = path.name.removesuffix('.luau').removesuffix('.server').removesuffix('.client')
        assert actual[name] == path.read_text(encoding='utf8'), ('Source mismatch', name)
    backup = build / 'inex-before-inventory.rbxl'
    if not backup.exists():
        shutil.copy2(output, backup)
    staged = build / 'inventory-staged.rbxl'
    staged.write_bytes(raw)
    Binary(staged.read_bytes())
    staged.replace(output)
    report = {'sources': len(actual), 'geometry': sum(path.parent.name == 'Geometry' for path in files), 'addedModules': len(added), 'instances': len(after.parents), 'bytes': len(raw), 'preservedChunks': len(preserved), 'backup': str(backup), 'allSourcesMatch': True, 'originalParentsPreserved': True}
    (build / 'inventory-save-report.json').write_text(json.dumps(report, indent=2), encoding='utf8')
    print(json.dumps(report))


if __name__ == '__main__':
    main()
