extends SceneTree
## Prints the English texts kept in data tables (names, descriptions, tips), one per line as
## "<source>\t<text>", for writing translations (tools/i18n_merge.py) and for checking coverage:
##   godot --headless --script res://tools/i18n_dump.gd > texts.tsv
const KEYS := ["name", "about", "label", "tip", "desc", "title", "tag"]


func _initialize() -> void:
	_walk("UNITS", Defs.UNITS)
	_walk("BUILDINGS", Defs.BUILDINGS)
	_walk("RESEARCH", Defs.RESEARCH)
	_walk("FACTIONS", Defs.FACTIONS)
	_walk("HALL_LEVELS", Defs.HALL_LEVELS)
	_walk("ARMOURED", Defs.ARMOURED)
	for k in Defs.TIPS:
		_out("TIPS." + String(k), Defs.TIPS[k])
	for k in UiStyle.FACTION_TAG:
		_out("FACTION_TAG." + String(k), UiStyle.FACTION_TAG[k])
	for k in MapData.NAMED:
		_walk("MAP." + String(k), MapData.NAMED[k])
	for k in AI.STRATEGIES:
		_out("STRATEGY." + String(k), AI.STRATEGIES[k]["name"])
	quit()


func _walk(path: String, v: Variant) -> void:
	if v is Dictionary:
		for k in v:
			if v[k] is String and String(k) in KEYS:
				_out("%s.%s" % [path, k], v[k])
			elif v[k] is Dictionary or v[k] is Array:
				_walk("%s.%s" % [path, k], v[k])
	elif v is Array:
		for i in v.size():
			_walk("%s[%d]" % [path, i], v[i])


func _out(src: String, s: String) -> void:
	if s.strip_edges() != "":
		print("%s\t%s" % [src, s.replace("\n", "\\n")])
