extends SceneTree
## Localisation checks:
##   godot --headless --script res://tools/test_i18n.gd
## 1. every key in the Portuguese table is in the Spanish one and the other way round;
## 2. the placeholders (%s %d %f) of each translation match the English key;
## 3. every name / description / tip in Defs, every help paragraph and every map description
##    has a translation in both languages;
## 4. switching the language changes the text (Loc.t and a Label) and back to English restores it.
## Prints PASS or FAIL lines; exit code 1 on a failure.
const KEYS := ["name", "about", "label", "tip", "desc", "title", "tag"]
var fails := 0
var missing := 0
var re := RegEx.new()


func _initialize() -> void:
	re.compile("%[-+0#]*\\d*(?:\\.\\d+)?[sdfxXc]|%%")
	var pt: Dictionary = LangPt.T
	var es: Dictionary = LangEs.T
	for k in pt:
		if not es.has(k):
			_fail("key only in pt: " + String(k).left(60))
	for k in es:
		if not pt.has(k):
			_fail("key only in es: " + String(k).left(60))
	for code in ["pt", "es"]:
		var d: Dictionary = pt if code == "pt" else es
		for k in d:
			if _phs(String(k)) != _phs(String(d[k])):
				_fail("%s placeholders differ: %s" % [code, String(k).left(60)])
			if String(d[k]).strip_edges() == "":
				_fail("%s empty translation: %s" % [code, String(k).left(60)])
	print("tables: %d pt, %d es entries" % [pt.size(), es.size()])

	# coverage of the data tables and the help pages
	var texts: Array = []
	_walk(Defs.UNITS, texts)
	_walk(Defs.BUILDINGS, texts)
	_walk(Defs.RESEARCH, texts)
	_walk(Defs.FACTIONS, texts)
	_walk(Defs.HALL_LEVELS, texts)
	_walk(Defs.ARMOURED, texts)
	for k in Defs.TIPS:
		texts.append(Defs.TIPS[k])
	for k in MapData.NAMED:    # map names stay English (proper names)
		var md: Dictionary = MapData.NAMED[k]
		if md.has("about"):
			texts.append(md["about"])
	var help: Dictionary = (load("res://scripts/main.gd") as GDScript).get_script_constant_map()["HELP"]
	for sec in help:
		for p in String(help[sec]).split("\n\n"):
			texts.append(p)
	for s in AI.STRATEGIES:
		texts.append(AI.STRATEGIES[s]["name"])
	for code in ["pt", "es"]:
		Loc.set_lang(code)
		var n := 0
		for s in texts:
			var str := String(s)
			if str.strip_edges() == "" or str.length() < 2:
				continue
			if Loc.t(str) == str and not _same_ok(str):
				n += 1
				if n <= 40:
					print("  untranslated (%s): %s" % [code, str.left(70).replace("\n", "\\n")])
		print("%s: %d of %d data texts untranslated" % [code, n, texts.size()])
		if n > 0:
			_fail("%s has untranslated data texts" % code)

	# patch notes: every version has a translated item for every English item, in both languages
	for n in PatchNotes.NOTES:
		for code in ["pt", "es"]:
			var tr: Dictionary = PatchPt.N if code == "pt" else PatchEs.N
			if not tr.has(n["v"]) or tr[n["v"]].size() != n["items"].size() or tr[n["v"]].has(""):
				_fail("patch notes %s not fully translated to %s" % [n["v"], code])
	Loc.set_lang("pt")
	var shown: Array = PatchNotes.items(PatchNotes.NOTES[0])
	if shown == PatchNotes.NOTES[0]["items"]:
		_fail("PatchNotes.items did not translate")
	Loc.set_lang("en")
	# voices: each translated line folder has the same file names as the English one where it speaks
	for code in ["pt", "es"]:
		for unit in ["labourer", "musketeer", "cannon", "cuirassier", "missionary", "winder", "gearknight", "bolt", "steam_walker", "tesla_cart"]:
			if DirAccess.get_files_at("res://assets/voice_%s/%s" % [code, unit]).is_empty():
				_fail("no %s voice files for %s" % [code, unit])
	# switching changes text, including a Label through the TranslationServer
	var lab := Label.new()
	lab.text = "SETTINGS"
	root.add_child(lab)
	Loc.set_lang("en")
	var en: String = Loc.t("SETTINGS")
	Loc.set_lang("pt")
	var p: String = Loc.t("SETTINGS")
	Loc.set_lang("es")
	var e: String = Loc.t("SETTINGS")
	if en == p or en == e or p == e:
		_fail("SETTINGS does not change with the language: %s / %s / %s" % [en, p, e])
	Loc.set_lang("pt")
	if lab.tr("SETTINGS") != p:
		_fail("Label translation (pt) differs from Loc.t")
	Loc.set_lang("en")
	if Loc.t("SETTINGS") != "SETTINGS":
		_fail("English not restored")
	# a pattern with a nested translated piece
	Loc.set_lang("pt")
	var m := Loc.t("Not enough gold.")
	if m == "Not enough gold.":
		print("  note: 'Not enough gold.' has no pattern translation")
	Loc.set_lang("en")
	print("FAIL (%d)" % fails if fails > 0 else "PASS")
	quit(1 if fails > 0 else 0)


func _phs(s: String) -> Array:
	var out: Array = []
	for m in re.search_all(s):
		out.append(m.get_string())
	out.sort()
	return out


func _same_ok(s: String) -> bool:
	# names that are the same in all three languages (no letters to translate)
	return not s.to_lower().contains("a") and not s.to_lower().contains("e") and not s.to_lower().contains("o")


func _walk(v: Variant, out: Array) -> void:
	if v is Dictionary:
		for k in v:
			if v[k] is String and String(k) in KEYS:
				out.append(v[k])
			elif v[k] is Dictionary or v[k] is Array:
				_walk(v[k], out)
	elif v is Array:
		for x in v:
			_walk(x, out)


func _fail(msg: String) -> void:
	fails += 1
	print("FAIL: " + msg)
