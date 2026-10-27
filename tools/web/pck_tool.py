#!/usr/bin/env python3
"""Reads and rewrites Godot 4 .pck files (pack format 2 to 4) for the web build (docs/web_load.md).

  pck_tool.py list FILE [N]            sizes by kind and by source folder, and the N biggest files
  pck_tool.py assets IN OUT            keep only the art/sound entries (assets/..., .godot/imported/...)
                                       and write them in a fixed order, so the same art always gives
                                       a byte-identical pack (and the same hash, and a browser cache hit)

The "Web assets" export also carries project.binary (it holds the version number, so it changes with
every release), the script class list and the UID cache; those belong to the code pack, and the art
pack must not replace them when scripts/web_boot.gd mounts it.
"""
import collections
import hashlib
import os
import re
import struct
import sys

MAGIC = b'GDPC'
REL_FILEBASE = 2


def read(path):
    d = open(path, 'rb').read()
    if d[:4] != MAGIC:
        raise SystemExit('%s: not a Godot pack' % path)
    fmt, ma, mi, pa, flags = struct.unpack_from('<5I', d, 4)
    if fmt < 2 or fmt > 4:
        raise SystemExit('%s: pack format %d not handled' % (path, fmt))
    if flags & 1:
        raise SystemExit('%s: encrypted directory not handled' % path)
    o = 24
    base = struct.unpack_from('<Q', d, o)[0]
    o += 8
    if fmt >= 3:
        diro = struct.unpack_from('<Q', d, o)[0]
        o = diro
    else:
        o += 16 * 4
    n = struct.unpack_from('<I', d, o)[0]
    o += 4
    files = []
    for _ in range(n):
        ln = struct.unpack_from('<I', d, o)[0]
        o += 4
        name = d[o:o + ln].rstrip(b'\0').decode()
        o += ln
        off, size = struct.unpack_from('<QQ', d, o)
        o += 16
        md5 = d[o:o + 16]
        o += 16
        fl = struct.unpack_from('<I', d, o)[0]
        o += 4
        start = (base + off) if flags & REL_FILEBASE else off
        files.append({'path': name, 'data': d[start:start + size], 'md5': md5, 'flags': fl})
    return {'fmt': fmt, 'version': (ma, mi, pa), 'flags': flags, 'files': files}


def write(path, pack):
    """Header, the files one after another (32-byte aligned, in path order), then the directory."""
    fmt = pack['fmt']
    ma, mi, pa = pack['version']
    files = sorted(pack['files'], key=lambda f: f['path'])
    header_size = 4 + 4 * 5 + 8 + (8 if fmt >= 3 else 0) + 16 * 4
    blob = bytearray()
    offsets = []
    for f in files:
        while len(blob) % 32:
            blob.append(0)
        offsets.append(len(blob))
        blob += f['data']
    while len(blob) % 32:
        blob.append(0)
    directory = bytearray(struct.pack('<I', len(files)))
    for f, off in zip(files, offsets):
        name = f['path'].encode()
        name += b'\0' * (4 - len(name) % 4 if len(name) % 4 else 0)
        directory += struct.pack('<I', len(name)) + name
        directory += struct.pack('<QQ', off, len(f['data'])) + f['md5'] + struct.pack('<I', f['flags'])
    base = header_size
    dir_off = base + len(blob)
    head = MAGIC + struct.pack('<5I', fmt, ma, mi, pa, REL_FILEBASE) + struct.pack('<Q', base)
    if fmt >= 3:
        head += struct.pack('<Q', dir_off)
    head += b'\0' * (16 * 4)
    assert len(head) == header_size
    with open(path, 'wb') as out:
        out.write(head)
        out.write(blob)
        out.write(directory)


def is_asset(p):
    p = p[6:] if p.startswith('res://') else p
    return p.startswith('assets/') or p.startswith('.godot/imported/')


def cmd_assets(src, dst):
    pack = read(src)
    dropped = [f['path'] for f in pack['files'] if not is_asset(f['path'])]
    pack['files'] = [f for f in pack['files'] if is_asset(f['path'])]
    write(dst, pack)
    check = read(dst)
    assert [f['path'] for f in check['files']] == sorted(f['path'] for f in pack['files'])
    for f in check['files']:
        if hashlib.md5(f['data']).digest() != f['md5'] and f['md5'] != b'\0' * 16:
            raise SystemExit('md5 mismatch after rewrite: ' + f['path'])
    print('%s: %d files kept, left out %s' % (dst, len(pack['files']), ', '.join(dropped) or 'nothing'))


def source_of(p, project='.'):
    m = re.match(r'(?:res://)?\.godot/imported/(.+?)-[0-9a-f]{32}\.\w+$', p)
    return m.group(1) if m else p.replace('res://', '')


def cmd_list(src, top=20):
    pack = read(src)
    # the .import files name the source of each imported file
    dest = {}
    for f in pack['files']:
        if f['path'].endswith('.import'):
            t = f['data'].decode('utf-8', 'replace')
            for m in re.findall(r'"res://(\.godot/imported/[^"]+)"', t):
                dest[m] = f['path'].replace('res://', '')[:-7]
    kinds = collections.Counter()
    dirs = collections.Counter()
    for f in pack['files']:
        p = f['path'].replace('res://', '')
        src_path = dest.get(p, p)
        kinds[os.path.splitext(p)[1] or p] += len(f['data'])
        dirs['/'.join(src_path.split('/')[:2])] += len(f['data'])
    total = sum(len(f['data']) for f in pack['files'])
    print('%s: %d files, %.2f MB' % (src, len(pack['files']), total / 1e6))
    print('by kind:')
    for k, s in kinds.most_common(12):
        print('  %8.2f MB  %s' % (s / 1e6, k))
    print('by folder:')
    for k, s in dirs.most_common(25):
        print('  %8.2f MB  %s' % (s / 1e6, k))
    print('biggest:')
    for f in sorted(pack['files'], key=lambda f: -len(f['data']))[:top]:
        p = f['path'].replace('res://', '')
        print('  %8.2f MB  %s' % (len(f['data']) / 1e6, dest.get(p, p)))


if __name__ == '__main__':
    if len(sys.argv) >= 3 and sys.argv[1] == 'list':
        cmd_list(sys.argv[2], int(sys.argv[3]) if len(sys.argv) > 3 else 20)
    elif len(sys.argv) == 4 and sys.argv[1] == 'assets':
        cmd_assets(sys.argv[2], sys.argv[3])
    else:
        print(__doc__)
        sys.exit(1)
