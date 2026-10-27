class_name NetCodec
extends RefCounted
## Packing of online messages, and of the arguments of a command (entities travel as ids).
## A message is a Dictionary; on the wire it is `var_to_bytes` (never objects), compressed when big:
## byte 0 = 0 plain / 2 zstd (1 deflate, no longer sent) (then 4 bytes: the size when plain), then the bytes.
## (zstd: a 3.5 KB snapshot of a 100-entity game packs in 0.1 ms, deflate took 3.5 ms, for the same size:
## tools/bench_net_snapshot.gd.)

const DEFLATE_FROM := 160


static func pack(msg: Dictionary) -> PackedByteArray:
	var raw := var_to_bytes(msg)
	var out := PackedByteArray()
	if raw.size() < DEFLATE_FROM:
		out.append(0)
		out.append_array(raw)
		return out
	var z := raw.compress(FileAccess.COMPRESSION_ZSTD)
	out.append(2)
	out.resize(5)
	out.encode_u32(1, raw.size())
	out.append_array(z)
	return out


## The message in the bytes, or {} if they are not one.
static func unpack(bytes: PackedByteArray) -> Dictionary:
	if bytes.size() < 2:
		return {}
	var raw: PackedByteArray
	if bytes[0] == 0:
		raw = bytes.slice(1)
	elif (bytes[0] == 1 or bytes[0] == 2) and bytes.size() > 5:
		var n := bytes.decode_u32(1)
		if n > 32 * 1024 * 1024:
			return {}
		raw = bytes.slice(5).decompress(n, FileAccess.COMPRESSION_ZSTD if bytes[0] == 2 else FileAccess.COMPRESSION_DEFLATE)
	else:
		return {}
	if raw.is_empty():
		return {}
	var v = bytes_to_var(raw)
	return v if v is Dictionary else {}


## An argument of a command, as plain data. Entities become {"e": net_id}; a Callable (or any
## other object) can't travel: `ok` is cleared and the command is dropped.
static func enc(v, ok: Array):
	if v is Entity:
		if v.net_id == 0:
			ok[0] = false
		return {"e": v.net_id}
	if v is Array:
		var out: Array = []
		for x in v:
			out.append(enc(x, ok))
		return out
	if v is Dictionary:
		var od := {}
		for k in v:
			od[k] = enc(v[k], ok)
		return od
	if v is Object or v is Callable or v is Signal:
		ok[0] = false
		return null
	return v


## The way back: ids become the entities `ents` (id -> Entity) holds (a missing one becomes null).
static func dec(v, ents: Dictionary):
	if v is Dictionary:
		if v.size() == 1 and v.has("e") and typeof(v["e"]) == TYPE_INT:
			var e = ents.get(int(v["e"]))
			return e if is_instance_valid(e) else null
		var od := {}
		for k in v:
			od[k] = dec(v[k], ents)
		return od
	if v is Array:
		var out: Array = []
		for x in v:
			out.append(dec(x, ents))
		return out
	return v
