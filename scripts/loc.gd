class_name Loc
## Localisation. The game's text is written in English in the code; the English string IS the key.
## Loc.t("Some text") gives it in the chosen language (the English text itself when there is no
## translation). Translations live in scripts/lang/lang_<code>.gd (generated from
## tools/i18n/*.txt by tools/i18n_build.py; see docs/localisation.md).
##
## Formatted text works without touching the code that formats it: a key such as
## "Not enough %s." (%s, %d, %f placeholders) is also a PATTERN, so the finished English text
## "Not enough gold." translates to "Ouro insuficiente." / "No hay suficiente oro." (the pieces
## that fill the placeholders are translated too when they have an entry of their own).
##
## Godot's own controls (Label, Button, tooltips) ask the TranslationServer, which asks
## LocTranslation, which asks Loc.t: so every Label / Button text is translated by itself and
## again when the language changes. Text drawn by hand (draw_string) must go through Loc.t.
## Voice lines and music stay English except where assets/voice_<code>/ exists (Sfx).

const LANGS := ["en", "pt", "es"]
const LOCALE := {"en": "en", "pt": "pt_BR", "es": "es_ES"}
## Each language's own name (shown as is; never translated).
const NATIVE := {"en": "English", "pt": "Português", "es": "Español"}

static var lang := "en"
static var _dict := {}
static var _tables := {}
static var _pats := {}        # first letters of the literal start -> [[regex, key, kinds]]
static var _pats_any: Array = []   # patterns that start with a placeholder
static var _cache := {}
static var _trans: LocTranslation = null


## The translation table of one language ({} for English or an unknown code).
static func table(code: String) -> Dictionary:
	if _tables.has(code):
		return _tables[code]
	var d := {}
	match code:
		"pt":
			d = LangPt.T
		"es":
			d = LangEs.T
	_tables[code] = d
	return d


## Switch language: the lookup table, the patterns, and Godot's locale.
static func set_lang(code: String) -> void:
	if not LANGS.has(code):
		code = "en"
	lang = code
	_dict = table(code)
	_cache.clear()
	_build_patterns()
	if _trans == null:
		_trans = LocTranslation.new()
		_trans.locale = "pt_BR"
		TranslationServer.add_translation(_trans)
		var t2 := LocTranslation.new()
		t2.locale = "es_ES"
		TranslationServer.add_translation(t2)
	TranslationServer.set_locale(LOCALE[code])


static func _build_patterns() -> void:
	_pats.clear()
	_pats_any.clear()
	var ph := RegEx.new()
	ph.compile("%[-+0#]*\\d*(?:\\.\\d+)?[sdfxXc]")
	for key: String in _dict:
		if not "%" in key:
			continue
		var ms := ph.search_all(key)
		if ms.is_empty():
			continue
		var rx := "^"
		var kinds: Array = []
		var at := 0
		var first_lit := ""
		for m in ms:
			var lit := key.substr(at, m.get_start() - at).replace("%%", "%")
			if at == 0:
				first_lit = lit
			rx += _esc(lit)
			var c := m.get_string().right(1)
			kinds.append(c)
			rx += "(.*?)" if c == "s" else ("(-?\\d+)" if c in "dxXc" else "(-?\\d+(?:\\.\\d+)?)")
			at = m.get_end()
		rx += _esc(key.substr(at).replace("%%", "%")) + "$"
		var re := RegEx.new()
		re.compile(rx)
		var entry := [re, key, kinds]
		if first_lit.length() >= 4:
			var k := first_lit.substr(0, 4)
			if not _pats.has(k):
				_pats[k] = []
			_pats[k].append(entry)
		else:
			_pats_any.append(entry)


static func _esc(s: String) -> String:
	var out := ""
	for ch in s:
		if ch in "\\.^$*+?()[]{}|":
			out += "\\"
		out += ch
	return out


## English text in, the chosen language out.
static func t(s: String) -> String:
	if _dict.is_empty() or s.length() < 2:
		return s
	var hit: Variant = _dict.get(s)
	if hit != null:
		return hit
	if _cache.has(s):
		return _cache[s]
	var r := _pattern(s)
	if r == s:
		var st := s.strip_edges()
		if st != s and st.length() >= 3:
			var r2 := t(st)
			if r2 != st:
				r = s.substr(0, s.find(st)) + r2 + s.substr(s.find(st) + st.length())
	if _cache.size() > 6000:
		_cache.clear()
	_cache[s] = r
	return r


static var _ph: RegEx = null


static func _pattern(s: String) -> String:
	var cands: Array = []
	if s.length() >= 4 and _pats.has(s.substr(0, 4)):
		cands = _pats[s.substr(0, 4)]
	for group in [cands, _pats_any]:
		for e in group:
			var m: RegExMatch = e[0].search(s)
			if m == null:
				continue
			return _fill(_dict[e[1]], e[2], m)
	# a text made of several pieces (lines, "a · b", "a.  b"): translate each piece by itself
	for sep in ["\n", "  ·  ", " · ", "  ", ": ", " + "]:
		if sep in s:
			var parts := s.split(sep)
			var out: PackedStringArray = []
			var changed := false
			for p in parts:
				var r := t(p)
				if r != p:
					changed = true
				out.append(r)
			if changed:
				return sep.join(out)
	return s


## The translated template with the pieces captured from the English text put in order.
static func _fill(tpl: String, kinds: Array, m: RegExMatch) -> String:
	if _ph == null:
		_ph = RegEx.new()
		_ph.compile("%[-+0#]*\\d*(?:\\.\\d+)?[sdfxXc]")
	var out := ""
	var n := 0
	var at := 0
	for pm in _ph.search_all(tpl):
		out += tpl.substr(at, pm.get_start() - at).replace("%%", "%")
		if n < kinds.size():
			var piece := m.get_string(n + 1)
			out += t(piece) if kinds[n] == "s" else piece
		n += 1
		at = pm.get_end()
	out += tpl.substr(at).replace("%%", "%")
	if tpl.begins_with("%s") and out != "":
		out = out.substr(0, 1).to_upper() + out.substr(1)      # (a name that opens the sentence)
	return out


## Loc.f("%d gold for %s", [n, who]): translate the format first, then fill it in.
static func f(fmt: String, args: Array) -> String:
	return t(fmt) % args


## A long text in paragraphs (split on blank lines), each translated by itself.
static func paras(text: String) -> String:
	if _dict.is_empty():
		return text
	var out: PackedStringArray = []
	for p in text.split("\n\n"):
		out.append(t(p))
	return "\n\n".join(out)


## Every line of a text (split on newlines) translated by itself, for lists of short lines.
static func lines(text: String) -> String:
	if _dict.is_empty():
		return text
	var out: PackedStringArray = []
	for p in text.split("\n"):
		var hit: Variant = _dict.get(p)
		out.append(hit if hit != null else p)
	return "\n".join(out)


static func upper(s: String) -> String:
	return t(s).to_upper()
