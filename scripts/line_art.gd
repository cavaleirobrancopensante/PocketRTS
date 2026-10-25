class_name LineArt
extends RefCounted
## Sprite loader for the Line (docs/clockwork_line_art_spec.md): every piece is drawn from a PNG under
## assets/ when it exists and from code when it does not, so art dropped into assets/ shows up without
## code changes. Textures are cached by path (a missing file is remembered as missing).

const SIDES := ["n", "e", "s", "w"]
static var _cache := {}
static var disabled := false     # screenshots of the code-drawn fallback (tools/shot_line.gd code)


## The file stem for a 4-bit side mask (N 1, E 2, S 4, W 8): "ns", "nesw", "none"...
static func mask_name(mask: int) -> String:
	if mask == 0:
		return "none"
	var s := ""
	for i in 4:
		if mask & (1 << i):
			s += SIDES[i]
	return s


## The picture at res://assets/<rel> or null (cached).
static func tex(rel: String) -> Texture2D:
	if disabled:
		return null
	if _cache.has(rel):
		return _cache[rel]
	var path := "res://assets/" + rel
	var t: Texture2D = null
	if ResourceLoader.exists(path):
		t = load(path) as Texture2D
	_cache[rel] = t
	return t


## The Line tile for a side mask (pipe with the rail on its top, docs/clockwork_line_art_spec.md): 32x32,
## assets/world/line/tile_<sides>.png written by tools/import_line_art.py. A lone stub (mask 0) has no tile.
static func pipe(mask: int) -> Texture2D:
	return null if mask == 0 else tex("world/line/tile_%s.png" % mask_name(mask))


## Damage pictures for straight pieces: kind "damaged" / "destroyed", axis "ew" / "ns".
static func damage(axis: String, kind: String) -> Texture2D:
	return tex("world/line/dmg_%s_%s.png" % [axis, kind])


## Steam puff frame 1..4.
static func steam(i: int) -> Texture2D:
	return tex("world/line/steam_%d.png" % (clampi(i, 1, 4)))


## Does a real picture exist for Building `kind` (assets/buildings/<kind>_built.png)?
static func has_building(kind: String) -> bool:
	return tex("buildings/%s_built.png" % kind) != null


## Forget what was looked up (tests that drop files in).
static func reset() -> void:
	_cache.clear()
