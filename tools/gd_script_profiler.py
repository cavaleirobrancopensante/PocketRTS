#!/usr/bin/env python3
"""Godot's script profiler without the editor: a tiny stand-in for the editor's debugger.

The game connects to it (--remote-debug), it switches the profiler on when a printed line
contains ON_TEXT and off when one contains OFF_TEXT, and writes every GDScript function's own
time, total time and call count over that stretch to OUT, slowest first.

    python3 tools/gd_script_profiler.py 6007 /tmp/prof.txt "PERF min 10" "PERF min 12" &
    godot --headless --fixed-fps 60 --remote-debug tcp://127.0.0.1:6007 \
        --script res://tools/perf_bench.gd -- sundered_realm crown brood crown clockwork 2v2 minutes:13

Keep the game running a few seconds after OFF_TEXT: the totals come in a little later.
The profiler slows the game down (use it to find where the time goes, and time with plain
runs). Its "self" time includes the engine calls a function makes (draw calls, dictionary
look-ups, text measuring). One or two functions now and then come out with an impossible time
(more than the whole run): ignore those.
"""
import socket, struct, sys, collections


class R:
    def __init__(s, b):
        s.b = b
        s.p = 0

    def u32(s):
        v = struct.unpack_from('<I', s.b, s.p)[0]; s.p += 4; return v

    def i32(s):
        v = struct.unpack_from('<i', s.b, s.p)[0]; s.p += 4; return v

    def i64(s):
        v = struct.unpack_from('<q', s.b, s.p)[0]; s.p += 8; return v

    def f32(s):
        v = struct.unpack_from('<f', s.b, s.p)[0]; s.p += 4; return v

    def f64(s):
        v = struct.unpack_from('<d', s.b, s.p)[0]; s.p += 8; return v

    def raw(s, n):
        v = s.b[s.p:s.p + n]; s.p += n; return v

    def string(s):
        n = s.u32(); v = s.raw(n).decode('utf8', 'replace'); s.p += (4 - n % 4) % 4; return v


def _ctype(r, kind):
    if kind == 1:
        r.u32()
    elif kind in (2, 3):
        r.string()


def dec(r):
    """One Variant in Godot 4's binary encoding (enough of it for the debugger's messages)."""
    h = r.u32(); t = h & 0xFF; wide = (h >> 16) & 1
    fl = r.f64 if wide else r.f32
    if t == 0: return None
    if t == 1: return r.u32() != 0
    if t == 2: return r.i64() if wide else r.i32()
    if t == 3: return fl()
    if t in (4, 21): return r.string()
    if t == 22:
        n = r.u32()
        if n & 0x80000000:
            nn = n & 0x7fffffff; sub = r.u32(); r.u32()
            return '/'.join(r.string() for _ in range(nn + sub))
        return r.string()
    if t == 5: return (fl(), fl())
    if t == 6: return (r.i32(), r.i32())
    if t == 7: return tuple(fl() for _ in range(4))
    if t == 8: return tuple(r.i32() for _ in range(4))
    if t == 9: return tuple(fl() for _ in range(3))
    if t == 10: return tuple(r.i32() for _ in range(3))
    if t in (11, 16): return tuple(fl() for _ in range(6))
    if t in (12, 14, 15): return tuple(fl() for _ in range(4))
    if t == 13: return tuple(r.i32() for _ in range(4))
    if t == 17: return tuple(fl() for _ in range(9))
    if t == 18: return tuple(fl() for _ in range(12))
    if t == 19: return tuple(fl() for _ in range(16))
    if t == 20: return tuple(r.f32() for _ in range(4))
    if t == 23: return r.i64()
    if t == 24:
        if (h >> 16) & 1: return ('obj', r.i64())
        cls = r.string()
        if cls == '': return None
        for _ in range(r.u32()):
            r.string(); dec(r)
        return ('obj', cls)
    if t in (25, 26): return None
    if t == 27:
        _ctype(r, (h >> 16) & 3); _ctype(r, (h >> 18) & 3)
        d = {}
        for _ in range(r.u32() & 0x7fffffff):
            k = dec(r); v = dec(r)
            try: d[k] = v
            except TypeError: d[str(k)] = v
        return d
    if t == 28:
        _ctype(r, (h >> 16) & 3)
        return [dec(r) for _ in range(r.u32() & 0x7fffffff)]
    if t == 29:
        n = r.u32(); v = r.raw(n); r.p += (4 - n % 4) % 4; return v
    if t == 30: n = r.u32(); return list(struct.unpack_from('<%di' % n, r.raw(4 * n)))
    if t == 31: n = r.u32(); return list(struct.unpack_from('<%dq' % n, r.raw(8 * n)))
    if t == 32: n = r.u32(); return list(struct.unpack_from('<%df' % n, r.raw(4 * n)))
    if t == 33: n = r.u32(); return list(struct.unpack_from('<%dd' % n, r.raw(8 * n)))
    if t == 34: n = r.u32(); return [r.string() for _ in range(n)]
    if t in (35, 36, 37, 38):
        n = r.u32(); k = {35: 2, 36: 3, 37: 4, 38: 4}[t]
        return [tuple((r.f64() if (wide and t != 37) else r.f32()) for _ in range(k)) for _ in range(n)]
    raise ValueError('variant type %d' % t)


def enc(v):
    if v is None: return struct.pack('<I', 0)
    if isinstance(v, bool): return struct.pack('<II', 1, 1 if v else 0)
    if isinstance(v, int): return struct.pack('<Iq', 2 | (1 << 16), v)
    if isinstance(v, float): return struct.pack('<Id', 3 | (1 << 16), v)
    if isinstance(v, str):
        b = v.encode(); return struct.pack('<II', 4, len(b)) + b + b'\0' * ((4 - len(b) % 4) % 4)
    if isinstance(v, list): return struct.pack('<II', 28, len(v)) + b''.join(enc(x) for x in v)
    raise ValueError(v)


def first_string(m):
    # a message is Array[name, thread, data]: its name without decoding the rest
    r = R(m); r.u32(); r.u32()
    h = r.u32()
    return r.string() if h & 0xFF in (4, 21) else ''


def write(out, sig, a):
    # servers:profile_total: 6 numbers, the servers, then 5 numbers per script function
    idx = 7
    for _ in range(a[6]):
        idx += 2 + a[idx + 1]
    rows = []
    n = a[idx]; idx += 1
    for _ in range(n // 5):
        sid, calls, self_t, total_t, _internal = a[idx:idx + 5]; idx += 5
        rows.append((self_t, total_t, calls, sig.get(sid, str(sid))))
    rows.sort(reverse=True)
    with open(out, 'w') as f:
        f.write('  self_ms  total_ms    calls us/call  function\n')
        for st, tt, cc, nm in rows:
            f.write('%9.1f %9.1f %8d %7.2f  %s\n' % (st * 1000, tt * 1000, cc, st * 1e6 / max(cc, 1), nm))


def main():
    port, out, on_text, off_text = int(sys.argv[1]), sys.argv[2], sys.argv[3], sys.argv[4]
    srv = socket.socket(); srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    srv.bind(('127.0.0.1', port)); srv.listen(1)
    c, _ = srv.accept()
    tid = [0]

    def send(cmd, data):
        b = enc([cmd, tid[0], data]); c.sendall(struct.pack('<I', len(b)) + b)

    sig = {}
    names = collections.Counter()
    buf = b''
    state = 0
    while True:
        d = c.recv(1 << 22)
        if not d:
            break
        buf += d
        while len(buf) >= 4:
            n = struct.unpack_from('<I', buf)[0]
            if len(buf) < 4 + n:
                break
            m = buf[4:4 + n]; buf = buf[4 + n:]
            name = first_string(m)
            names[name] += 1
            if name in ('servers:profile_frame', 'performance:profile_frame', 'error'):
                continue
            msg = dec(R(m)); data = msg[2]
            if name == 'output':
                tid[0] = msg[1]           # (commands go to the main thread's queue)
                txt = ' '.join(str(x) for x in data[0]) if data and isinstance(data[0], list) else str(data)
                for line in txt.split('\n'):
                    if 'PERF' in line:
                        print(line[:160], flush=True)
                if state == 0 and on_text in txt:
                    state = 1; send('profiler:servers', [True, [5000, False]]); print('PROFILER ON', flush=True)
                elif state == 1 and off_text in txt:
                    state = 2; send('profiler:servers', [False]); print('PROFILER OFF', flush=True)
            elif name == 'debug_enter':
                print('script error, going on:', data[:3], flush=True); send('continue', [])
            elif name == 'servers:function_signature':
                sig[data[1]] = data[0]
            elif name == 'servers:profile_total':
                write(out, sig, data); print('written', out, flush=True)


if __name__ == '__main__':
    main()
