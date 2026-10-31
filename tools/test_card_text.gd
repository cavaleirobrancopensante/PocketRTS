extends SceneTree
## THE CARD TEXT (the owner, 2026-10-31; Defs.SHORT, Hud._portrait_tip):
##   godot --headless --script res://tools/test_card_text.gd
## 1. every unit and building that can be in a match (each faction's build list, what they train, the Brood's
##    creatures, the mounted and matured forms, the armoured soldiers) has a short card line, at most Defs.SHORT_MAX
##    characters in English, Portuguese and Spanish (every line translated);
## 2. no short line and no "about" text of those kinds speaks of retired things: mines, Boilers, Ore Crushers,
##    batteries, essence, the Spore Mother, the Bloater, swamp pits, the gear swap;
## 3. Defs.short_of falls back to the first sentence of "about" for a kind with no line, and about_of gives an
##    armoured soldier his own text.
## Prints PASS or FAIL lines; exit code 1 on a failure.
var fails := 0
const EXTRA := ["messenger", "mounted_missionary", "ticking_owl", "tyrant_challenger", "venom_challenger", "storm_challenger"]
const RETIRED := ["\\bmines?\\b", "gold mine", "\\bboilers?\\b", "ore crusher", "\\bbatter(y|ies)\\b", "\\bessence\\b",
	"spore mother", "\\bbloater", "swamp pit", "swap\\w*( (its|the|to the|a))? ?(big |small )?gear", "gear swap"]


func _initialize() -> void:
	var live := {}
	for f in ["crown", "clockwork"]:
		var q: Array = Defs.build_list(f).duplicate()
		q.append(Defs.FACTIONS[f]["worker"])
		while not q.is_empty():
			var k: String = q.pop_back()
			if live.has(k):
				continue
			live[k] = true
			if Defs.BUILDINGS.has(k):
				for t in Defs.BUILDINGS[k].get("trains", []):
					q.append(t)
	for k in BroodNew.hatch_list() + BroodNew.KINDS + EXTRA:
		live[k] = true
	var lines: Array = []        # [kind, text]
	for k in live:
		if not (Defs.UNITS.has(k) or Defs.BUILDINGS.has(k)):
			_fail("%s: not a unit or building" % k)
			continue
		if not Defs.SHORT.has(k):
			_fail("%s: no short card line in Defs.SHORT" % k)
			continue
		lines.append([k, String(Defs.SHORT[k])])
		if Defs.ARMOURED.has(k):
			if not Defs.SHORT_ARMOURED.has(k):
				_fail("%s: no armoured card line in Defs.SHORT_ARMOURED" % k)
			else:
				lines.append([k + " (armoured)", String(Defs.SHORT_ARMOURED[k])])
	var pt: Dictionary = LangPt.T
	var es: Dictionary = LangEs.T
	var longest := 0
	for l in lines:
		var en: String = l[1]
		for pair in [["en", en], ["pt", String(pt.get(en, ""))], ["es", String(es.get(en, ""))]]:
			var txt: String = pair[1]
			if txt == "":
				_fail("%s: no %s translation of its card line" % [l[0], pair[0]])
				continue
			longest = maxi(longest, txt.length())
			if txt.length() > Defs.SHORT_MAX:
				_fail("%s: %s card line is %d characters (max %d): %s" % [l[0], pair[0], txt.length(), Defs.SHORT_MAX, txt])
			if "\n" in txt:
				_fail("%s: %s card line has a line break" % [l[0], pair[0]])
	print("%d card lines, the longest %d characters (max %d)" % [lines.size(), longest, Defs.SHORT_MAX])
	# retired words, in the short lines and the full texts of every live kind
	var res: Array = []
	for w in RETIRED:
		var re := RegEx.new()
		re.compile("(?i)" + w)
		res.append(re)
	var texts: Array = lines.duplicate()
	for k in live:
		texts.append([k + " about", Defs.about_of(k)])
		if Defs.ARMOURED.has(k):
			texts.append([k + " armoured about", Defs.about_of(k, true)])
	for t in texts:
		for i in res.size():
			var m: RegExMatch = (res[i] as RegEx).search(String(t[1]))
			if m:
				_fail("%s mentions a retired thing (\"%s\"): %s" % [t[0], m.get_string(), String(t[1]).left(90)])
	# the fallbacks
	if Defs.short_of("labourer") != Defs.SHORT["labourer"]:
		_fail("short_of(labourer) is not its line")
	if Defs.short_of("musketeer", true) != Defs.SHORT_ARMOURED["musketeer"]:
		_fail("short_of(musketeer, armoured) is not the Guardsman's line")
	var odd := ""
	for k in Defs.UNITS:
		if not Defs.SHORT.has(k) and String(Defs.UNITS[k].get("about", "")).find(". ") > 0:
			odd = k
			break
	if odd != "":
		var fb := Defs.short_of(odd)
		if fb == "" or not fb.ends_with(".") or fb.length() >= String(Defs.UNITS[odd]["about"]).length():
			_fail("short_of(%s) does not fall back to the first sentence: %s" % [odd, fb])
	if Defs.about_of("musketeer", true) != String(Defs.ARMOURED["musketeer"]["about"]):
		_fail("about_of(musketeer, armoured) is not the Guardsman's text")
	if fails == 0:
		print("PASS test_card_text: %d kinds" % live.size())
	quit(1 if fails > 0 else 0)


func _fail(msg: String) -> void:
	fails += 1
	print("FAIL " + msg)
