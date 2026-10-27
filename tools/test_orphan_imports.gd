extends SceneTree
## Every .import file under res://assets has its source file. An orphan .import (its picture deleted, e.g. a veterancy
## trim mask that tools/import_vet_trim.py no longer writes) makes ResourceLoader.exists() say yes, so the game loads
## it and Godot prints "Failed loading resource" errors in the match (seen in the 0.14.53 QA soak: the dismounted
## Cuirassier's walk_e trim mask).
##   godot --headless --script res://tools/test_orphan_imports.gd
var orphans: Array = []


func _walk(dir: String) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	d.list_dir_begin()
	var f := d.get_next()
	while f != "":
		if d.current_is_dir():
			if not f.begins_with("."):
				_walk(dir + "/" + f)
		elif f.ends_with(".import"):
			var src := dir + "/" + f.trim_suffix(".import")
			if not FileAccess.file_exists(src):
				orphans.append(src)
		f = d.get_next()


func _initialize() -> void:
	_walk("res://assets")
	for o in orphans:
		print("ORPHAN .import (no source file): ", o)
	# and the veterancy mask lookup for the strip that had one: no mask, no error
	var tex: Texture2D = load("res://assets/units/dismounted_armoured/walk_e.png")
	var m = VetLook.mask_for(tex, 1) if tex else null
	print("CHECK dismounted_armoured walk_e trim mask: %s" % ("none (fine)" if m == null else "found"))
	print("PASS" if orphans.is_empty() else "FAIL: %d orphan .import file(s)" % orphans.size())
	quit(0 if orphans.is_empty() else 1)
