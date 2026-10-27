class_name ReplayFile
extends RefCounted
## A replay on disk (docs/replays.md): the match's pictures, not its commands.
## user://replays/replay_<date>.hfr, written as the match goes so a crash keeps all but the last few seconds:
##   "HFR1", then records: [u8 type][u32 size][f32 t0][f32 t1][size bytes]
##   T_HEAD    var_to_bytes: the setup (map, seed, slots, the game version, who recorded, the snapshot field lists)
##   T_CHUNK   one keyframe and the deltas after it (t0..t1 = their match times): u32 raw size + zstd of the frames,
##             each frame [u32 size][var_to_bytes(the snapshot)] (NetSnapshot.build, every side's units)
##   T_EVENTS  var_to_bytes: [[time, "chat", team, text], [time, "end", winner, note]...] since the last record
##   T_FOOT    var_to_bytes: how it ended (winner, length, note); missing if the game closed before the end
## Next to it, replay_<date>.json: what the REPLAYS list shows (players, map, result, length, kept), so the list
## never opens the big files.

const DIR := "user://replays"
const MAGIC := "HFR1"
const FORMAT := 1
const T_HEAD := 1
const T_CHUNK := 2
const T_EVENTS := 3
const T_FOOT := 4
const KEEP_DEFAULT := 30
const REC_HEAD := 13          # bytes before a record's payload


static func ensure_dir() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)


## A new file name: replay_2026-10-27_14-05-33.hfr (another one that second gets _2).
static func new_path(tag := "") -> String:
	ensure_dir()
	var stamp := Time.get_datetime_string_from_system(false, true).replace(":", "-").replace(" ", "_")
	var base := "%s/replay_%s%s" % [DIR, stamp, tag]
	var p := base + ".hfr"
	var k := 2
	while FileAccess.file_exists(p):
		p = "%s_%d.hfr" % [base, k]
		k += 1
	return p


static func meta_path(path: String) -> String:
	return path.get_basename() + ".json"


# ------------------------------------------------------------------ writing

static func _record(type: int, t0: float, t1: float, payload: PackedByteArray) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(REC_HEAD)
	out.encode_u8(0, type)
	out.encode_u32(1, payload.size())
	out.encode_float(5, t0)
	out.encode_float(9, t1)
	out.append_array(payload)
	return out


## Start a file with its header. False if it can't be written.
static func begin(path: String, header: Dictionary) -> bool:
	ensure_dir()
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_buffer(MAGIC.to_ascii_buffer())
	f.store_buffer(_record(T_HEAD, 0.0, 0.0, var_to_bytes(header)))
	f.close()
	return true


## Add a record at the end (the file is opened and closed each time: what is written stays, whatever happens next).
static func append(path: String, type: int, t0: float, t1: float, payload: PackedByteArray) -> bool:
	var f := FileAccess.open(path, FileAccess.READ_WRITE)
	if f == null:
		return false
	f.seek_end()
	f.store_buffer(_record(type, t0, t1, payload))
	f.close()
	return true


## The frames of a chunk (each var_to_bytes of a snapshot), packed: u32 raw size + zstd.
static func pack_frames(frames: Array) -> PackedByteArray:
	var raw := PackedByteArray()
	for fb in frames:
		var b: PackedByteArray = fb
		var n := raw.size()
		raw.resize(n + 4)
		raw.encode_u32(n, b.size())
		raw.append_array(b)
	var out := PackedByteArray()
	out.resize(4)
	out.encode_u32(0, raw.size())
	out.append_array(raw.compress(FileAccess.COMPRESSION_ZSTD))
	return out


## The way back: the frames' bytes (each one a var_to_bytes), oldest first; [] if damaged.
static func unpack_frames(payload: PackedByteArray) -> Array:
	if payload.size() < 5:
		return []
	var n := payload.decode_u32(0)
	if n > 256 * 1024 * 1024:
		return []
	var raw := payload.slice(4).decompress(n, FileAccess.COMPRESSION_ZSTD)
	var out: Array = []
	var i := 0
	while i + 4 <= raw.size():
		var sz := raw.decode_u32(i)
		if i + 4 + sz > raw.size():
			break
		out.append(raw.slice(i + 4, i + 4 + sz))
		i += 4 + sz
	return out


# ------------------------------------------------------------------ reading

## Everything in a replay's bytes: {"ok", "header", "chunks": [{t0, t1, data}], "events", "footer", "truncated"}.
## A record cut short (the game closed while writing it) ends the reading: what came before still plays.
static func parse(bytes: PackedByteArray) -> Dictionary:
	var out := {"ok": false, "header": {}, "chunks": [], "events": [], "footer": {}, "truncated": false}
	if bytes.size() < 4 or bytes.slice(0, 4).get_string_from_ascii() != MAGIC:
		return out
	var i := 4
	while i < bytes.size():
		if i + REC_HEAD > bytes.size():
			out["truncated"] = true
			break
		var type := bytes.decode_u8(i)
		var sz := bytes.decode_u32(i + 1)
		var t0 := bytes.decode_float(i + 5)
		var t1 := bytes.decode_float(i + 9)
		if i + REC_HEAD + sz > bytes.size():
			out["truncated"] = true
			break
		var body := bytes.slice(i + REC_HEAD, i + REC_HEAD + sz)
		i += REC_HEAD + sz
		match type:
			T_HEAD:
				var h = bytes_to_var(body)
				if h is Dictionary:
					out["header"] = h
			T_CHUNK:
				(out["chunks"] as Array).append({"t0": t0, "t1": t1, "data": body})
			T_EVENTS:
				var ev = bytes_to_var(body)
				if ev is Array:
					(out["events"] as Array).append_array(ev)
			T_FOOT:
				var ft = bytes_to_var(body)
				if ft is Dictionary:
					out["footer"] = ft
	out["ok"] = not (out["header"] as Dictionary).is_empty() and not (out["chunks"] as Array).is_empty()
	return out


static func read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false}
	return parse(FileAccess.get_file_as_bytes(path))


## The length of a replay whose game closed before the end (no footer): the last chunk's end time, read from the
## record heads only.
static func scan_length(path: String) -> float:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return 0.0
	var last := 0.0
	f.seek(4)
	while f.get_position() + REC_HEAD <= f.get_length():
		var type := f.get_8()
		var sz := f.get_32()
		var _t0 := f.get_float()
		var t1 := f.get_float()
		if f.get_position() + sz > f.get_length():
			break
		if type == T_CHUNK:
			last = maxf(last, t1)
		f.seek(f.get_position() + sz)
	f.close()
	return last


# ------------------------------------------------------------------ the list

static func write_meta(path: String, meta: Dictionary) -> void:
	var f := FileAccess.open(meta_path(path), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(meta))
		f.close()


static func read_meta(path: String) -> Dictionary:
	var mp := meta_path(path)
	if not FileAccess.file_exists(mp):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(mp))
	return d if d is Dictionary else {}


## Every replay, newest first: its meta with "path" and "size" (bytes). One without a finished meta (the game closed
## during the match) gets its length from the file and the result "unfinished".
static func list() -> Array:
	ensure_dir()
	var out: Array = []
	for fn in DirAccess.get_files_at(DIR):
		if not fn.ends_with(".hfr"):
			continue
		var path := DIR + "/" + fn
		var m := read_meta(path)
		if m.is_empty():
			var r := read(path)
			if not r.get("ok", false):
				continue
			m = meta_from(r["header"], r["footer"], path)
		if not m.has("len") or float(m.get("len", 0.0)) <= 0.0:
			m["len"] = scan_length(path)
			if String(m.get("result", "")) == "":
				m["result"] = "unfinished"
		m["path"] = path
		var f := FileAccess.open(path, FileAccess.READ)
		m["size"] = f.get_length() if f else 0
		out.append(m)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a["path"]) > String(b["path"]))
	return out


## What the list shows, from a header (and a footer, if the match ended). The result is for the player who recorded.
static func meta_from(header: Dictionary, footer: Dictionary, path: String, me_for := -2) -> Dictionary:
	var cfg: Dictionary = header.get("cfg", {})
	var me := int(header.get("me", -1)) if me_for < -1 else me_for
	var players: Array = []
	var slots: Array = cfg.get("slots", [])
	for i in slots.size():
		var sl: Dictionary = slots[i]
		var nm := String((header.get("names", []) as Array)[i]) if i < (header.get("names", []) as Array).size() else "P%d" % (i + 1)
		nm = nm.replace(" (you)", "") + (" (you)" if i == me else "")
		players.append({"name": nm,
			"faction": String(sl.get("faction", "")), "colour": int(sl.get("colour", 0)), "side": int(sl.get("side", i)), "who": String(sl.get("who", ""))})
	var m := {"file": path.get_file(), "date": int(header.get("date", 0)), "map": String(cfg.get("map", "")),
		"map_name": String(header.get("map_name", cfg.get("map", ""))), "players": players, "me": me,
		"version": String(header.get("game_version", "?")), "view_only": bool(header.get("view_only", false)),
		"online": String(header.get("online", "")), "kept": false, "result": "", "len": 0.0}
	if not footer.is_empty():
		m["len"] = float(footer.get("len", 0.0))
		m["result"] = result_for(header, footer, me)
	return m


## "victory", "defeat", "draw", "watched" (no player of yours) or "left" (left before the end).
static func result_for(header: Dictionary, footer: Dictionary, me: int) -> String:
	if bool(footer.get("left", false)):
		return "left"
	var w := int(footer.get("winner", -1))
	var sides: Array = []
	for sl in (header.get("cfg", {}) as Dictionary).get("slots", []):
		sides.append(int(sl.get("side", 0)))
	if me < 0:
		return "watched"
	if w < 0 or w >= sides.size() or me >= sides.size():
		return "draw"
	return "victory" if sides[w] == sides[me] else "defeat"


static func set_kept(path: String, on: bool) -> void:
	var m := read_meta(path)
	if m.is_empty():
		var r := read(path)
		if not r.get("ok", false):
			return
		m = meta_from(r["header"], r["footer"], path)
	m["kept"] = on
	write_meta(path, m)


static func delete(path: String) -> void:
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(meta_path(path))


## Keep the newest `keep` replays that aren't KEPT; older ones go (kept ones never do).
static func prune(keep: int) -> int:
	var gone := 0
	var n := 0
	for m in list():
		if bool(m.get("kept", false)):
			continue
		n += 1
		if n > keep:
			delete(String(m["path"]))
			gone += 1
	return gone


## A replay file brought in from elsewhere (bytes): saved under its own new name, with its list entry. "" if the bytes
## are not a replay, else the new path.
## `me`: the player it is saved for (its result theirs; -2: the one who recorded it). `tag`: the end of the new name.
static func import_bytes(bytes: PackedByteArray, keep_name := "", me := -2, tag := "_imported") -> String:
	var r := parse(bytes)
	if not r.get("ok", false):
		return ""
	var path := new_path(tag) if keep_name == "" else DIR + "/" + keep_name
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return ""
	f.store_buffer(bytes)
	f.close()
	var m := meta_from(r["header"], r["footer"], path, me)
	if m["len"] <= 0.0:
		m["len"] = (r["chunks"] as Array).back()["t1"]
		m["result"] = "unfinished"
	write_meta(path, m)
	return path
