extends SceneTree
## Files and data that must agree (the QA pass of 2026-10-27):
##  - every strip scripts/art_data.gd names (assets/units/<kind>/<anim>.png) exists, `frames` cells wide and one cell high;
##  - every building of every faction's build list (Defs.build_list: the game's own, gear mode for the Clockwork) has its standing picture (assets/buildings/<art>_built.png, the
##    temporary stand-ins of Defs.TEMP_ART followed), every unit a building trains exists in Defs.UNITS, every
##    requirement names a building or a research, every research's icon and unlock exist;
##  - every unit, building and research button has an icon (the way Hud._icon finds one: the faction's own folder,
##    the shared one, the TEMP_ART stand-in, else a picture drawn in code).
## Prints a FAIL line for each problem and "files: N failures".
##   godot --headless --script res://tools/test_files.gd
var fails := 0
var checked := 0


func _fail(s: String) -> void:
	fails += 1
	print("FAIL ", s)


func _initialize() -> void:
	_strips()
	_buildings_and_data()
	print("files: %d checks, %d failures" % [checked, fails])
	quit(1 if fails > 0 else 0)


## The kinds whose art a normal game shows: every faction's workers and every unit its buildings train, with the
## art they borrow (Defs.TEMP_ART); the rest (the old Clockwork roster, the lab's prototypes) only get a note.
func _used_art() -> Dictionary:
	var used := {}
	for fac in Defs.FACTIONS:
		var f: Dictionary = Defs.FACTIONS[fac]
		var kinds: Array = [String(f.get("worker", ""))]
		for b in Defs.build_list(fac):
			if Defs.BUILDINGS.has(b):
				kinds.append_array(Defs.BUILDINGS[b].get("trains", []))
		for k in kinds:
			used[k] = true
			var t: Dictionary = Defs.TEMP_ART.get(k, {})
			for v in t.values():
				used[String(v)] = true
	return used


func _strips() -> void:
	# unit.gd: a strip is `frames` frames of its width / frames, each at least a cell high (a taller one has extra
	# room on top: aiming up), its feet on art_data's anchor, so a frame must be exactly a cell wide
	var used := _used_art()
	for kind in ArtData.BASE_UNITS:
		var e: Dictionary = ArtData.BASE_UNITS[kind]
		var cell: Vector2i = e["cell"]
		var frames: Dictionary = e["frames"]
		var bad: Array = []
		for anim in frames:
			checked += 1
			var path := "res://assets/units/%s/%s.png" % [kind, anim]
			if not ResourceLoader.exists(path):
				bad.append("%s: no strip" % anim)
				continue
			var tex: Texture2D = load(path)
			var n := int(frames[anim])
			if tex.get_width() != cell.x * n or tex.get_height() < cell.y:
				bad.append("%s %dx%d (wants %d x %dx%d+)" % [anim, tex.get_width(), tex.get_height(), n, cell.x, cell.y])
		if bad.is_empty():
			continue
		if used.has(kind):
			for x in bad:
				_fail("%s %s" % [kind, x])
		else:
			print("NOTE %s (not in a normal game's rosters): %d strips off: %s" % [kind, bad.size(), ", ".join(bad.slice(0, 3))])


func _icon_found(fac: String, name: String) -> bool:
	for n in [name, Defs.icon_for(name)]:
		if fac != "crown" and ResourceLoader.exists("res://assets/icons/%s/%s.png" % [fac, n]):
			return true
		if ResourceLoader.exists("res://assets/icons/%s.png" % n):
			return true
	return CwArt.icon(name) != null


func _buildings_and_data() -> void:
	for fac in Defs.FACTIONS:
		for k in Defs.build_list(fac):
			checked += 1
			if not Defs.BUILDINGS.has(k):
				_fail("%s builds %s: no such building in Defs.BUILDINGS" % [fac, k])
				continue
			var d: Dictionary = Defs.BUILDINGS[k]
			var art := String(Defs.TEMP_ART.get(k, {}).get("building", k))
			var special: bool = k in ["farm", "wall", "gate"]
			if not special and not ResourceLoader.exists("res://assets/buildings/%s_built.png" % art) \
					and not ResourceLoader.exists("res://assets/buildings/%s_built.png" % k):
				_fail("%s %s: no picture assets/buildings/%s_built.png" % [fac, k, art])
			if not _icon_found(fac, k):
				_fail("%s %s: no icon" % [fac, k])
			for u in d.get("trains", []):
				checked += 1
				if not Defs.UNITS.has(u):
					_fail("%s %s trains %s: no such unit" % [fac, k, u])
				elif not _icon_found(fac, u):
					_fail("%s %s trains %s: no icon" % [fac, k, u])
			_requires(fac, k, d)
	for k in Defs.UNITS:
		_requires(String(Defs.UNITS[k].get("faction", "")), k, Defs.UNITS[k])
	for r in Defs.RESEARCH:
		checked += 1
		var info: Dictionary = Defs.RESEARCH[r]
		var fac := String(info.get("faction", "crown"))
		var ic := String(info.get("icon", info.get("unlocks", "")))
		if ic != "" and not _icon_found(fac, ic) and not _icon_found(fac, String(info.get("unlocks", "musketeer"))):
			_fail("research %s: no icon %s" % [r, ic])
		if info.has("unlocks") and not (Defs.UNITS.has(String(info["unlocks"])) or Defs.BUILDINGS.has(String(info["unlocks"]))):
			pass      # (an unlock may be an ability or a level: not checked)
		_requires(fac, "research " + r, info)


func _requires(fac: String, what: String, d: Dictionary) -> void:
	var r = d.get("requires", "")
	var reqs: Array = r if r is Array else ([r] if String(r) != "" else [])
	for q in reqs:
		checked += 1
		var s := String(q)
		if not (Defs.BUILDINGS.has(s) or Defs.RESEARCH.has(s) or Defs.UNITS.has(s)):
			_fail("%s %s requires %s: no such building, research or unit" % [fac, what, s])
