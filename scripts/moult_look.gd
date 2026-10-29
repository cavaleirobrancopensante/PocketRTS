class_name MoultLook
extends RefCounted
## THE MOULT'S PICTURES (the owner, 2026-10-29; docs/brood_anims.md): what a young Brood unit looks like while it MATURES
## (BroodMature: Defs.NB "moult" s, then Unit.morph into its Challenger). Pictures only: nothing here touches the game's
## state (the moult's time is Unit.moult_t; what is left on the ground afterwards keeps its own clock on its node).
## The young unit and the Challenger are the game's own sprites; the SHELL, its cracking and splitting and the empty
## shell are the cocoon sheet's case greyed toward stone (tools/import_brood_moult.py, art keys "moult_<line>"), the SHED
## SKIN (Venom and Tyrant lines) the owner's Gemini drawing, cleaned. One south-east view: the young unit turns to the
## south-east when it starts (BroodMature.start) and the Challenger steps out facing it.
##   0.00-0.12  it HUNCHES: its own first idle frame, squashing a little, greying (the team shader's wash)
##   0.08-0.24  the SHELL closes round it: the closed case swelling up from a little over its size, fading in, the young
##              one fading out inside (a flyer comes down to the ground first)
##   0.24-0.74  the shell BREATHES and swells on (to SHELL_GROW of its own size)
##   0.74-0.88  it CRACKS: the shell's glow, shake and crack frames, shaking
##   0.88-1.00  it SPLITS and the CHALLENGER comes out: the split frames, the Challenger (its own first idle frame) fading
##              in over it, still grey, rising a little (a Storm Challenger rises into the air)
##   after      the Challenger regains its colour (AFTER_COLOUR s); the empty shell and the shed skin stay on the ground
##              behind it, then fade (AFTER_HOLD, AFTER_FADE s)

const LINE := {"spitter": "venom", "venom_challenger": "venom", "raptor": "tyrant", "tyrant_challenger": "tyrant",
	"hatchlings": "storm", "storm_challenger": "storm"}
const SHELL := "MoultShell"
const NEW := "MoultNew"
const LEFT := "MoultLeft"
const SKIN := "MoultSkin"
const GREY := 0.75                # the wash at its greyest
const SHELL_START := 0.62         # the shell's scale when it has closed round the young one (of its imported size)
const SHELL_GROW := 1.0           # ... and when it has swollen (its imported size: about halfway to the Challenger)
const AFTER_COLOUR := 1.2
const AFTER_HOLD := 1.6
const AFTER_FADE := 1.4
const AIR_Y := -20.0              # a flyer's height (Unit._animate)


static func line_of(u: Unit) -> String:
	return String(LINE.get(u.kind, ""))


static func has_art(u: Unit) -> bool:
	var ln := line_of(u)
	return ln != "" and ArtData.UNITS.has("moult_" + ln)


static func _strip(art: String, key: String) -> Array:
	var info: Dictionary = ArtData.UNITS[art]
	var tx := Game.tex("res://assets/units/%s/%s.png" % [art, key])
	var cell: Vector2i = info["cell"]
	var anc: Vector2 = info["anchor"]
	return [tx, int((info["frames"] as Dictionary).get(key, 1)), -anc - Vector2(0, tx.get_height() - cell.y)]


static func _sprite(u: Unit, nm: String, behind := false) -> Sprite2D:
	var s := u.get_node_or_null(nm) as Sprite2D
	if s == null:
		s = Sprite2D.new()
		s.name = nm
		s.centered = false
		u.add_child(s)
		u.move_child(s, u.sprite.get_index() + (0 if behind else 1))
	return s


static func _show(s: Sprite2D, art: String, key: String, f: int) -> void:
	var st := _strip(art, key)
	if s.texture != st[0]:
		s.texture = st[0]
		s.hframes = int(st[1])
		s.offset = st[2]
	s.frame = clampi(f, 0, s.hframes - 1)


static func _wash(m: Material, k: float) -> void:
	var sm := m as ShaderMaterial
	if sm != null:
		sm.set_shader_parameter("wash", Color(0.62, 0.62, 0.58, clampf(k, 0.0, 1.0)))


static func _ease(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


## Every frame of the moult (Unit._animate, after its own animation): the pictures for how far it is.
static func look(u: Unit) -> void:
	var s := u.sprite
	var ln := line_of(u)
	var art := "moult_" + ln
	var p := BroodMature.frac(u)
	var t := u.moult_t
	var air: bool = u.d.get("air", false)
	# its own picture: its first idle frame (it stands still), squashing a little and greying
	s.frame = 0
	var hunch := _ease(p / 0.12)
	var sx := signf(s.scale.x) if s.scale.x != 0.0 else 1.0
	var asc := float(u.d.get("art_scale", 1.0))
	s.scale = Vector2(sx * (1.0 + 0.05 * hunch), 1.0 - 0.12 * hunch) * asc
	_wash(s.material, GREY * hunch)
	var down := _ease(p / 0.1) if air else 1.0          # (a flyer comes down to the ground first)
	if air:
		s.position.y = lerpf(s.position.y, 0.0, down)
	s.self_modulate.a = 1.0 - _ease((p - 0.12) / 0.12)
	# the shell
	var sh := _sprite(u, SHELL)
	var close := _ease((p - 0.08) / 0.16)
	var k := lerpf(SHELL_START * 0.75, SHELL_START, close)
	if p >= 0.24:
		k = lerpf(SHELL_START, SHELL_GROW, _ease((p - 0.24) / 0.5))
	var breathe := 1.0 + (0.025 * sin(t * TAU / 1.5) if p >= 0.2 and p < 0.74 else 0.0)
	sh.scale = Vector2(k / breathe, k * breathe)
	sh.position = Vector2.ZERO
	sh.self_modulate = Color(1, 1, 1, close)
	var nshell := int((ArtData.UNITS[art]["frames"] as Dictionary).get("shell_se", 1))
	if p < 0.74:
		_show(sh, art, "shell_se", 0)
		var glow := 1.0 + 0.12 * maxf(0.0, sin(t * TAU / 1.5)) * float(p >= 0.24)
		sh.self_modulate = Color(glow, glow, glow, close)
	elif p < 0.88:
		var c := (p - 0.74) / 0.14
		_show(sh, art, "shell_se", 1 + clampi(int(c * float(nshell - 1)), 0, nshell - 2))
		sh.position.x = roundf(sin(t * 47.0) * (0.6 + 1.2 * c))       # (it shakes, harder as it cracks)
	else:
		var e := (p - 0.88) / 0.12
		_show(sh, art, "split_se", 0 if e < 0.45 else 1)
	# the Challenger comes out of it
	var m := BroodMature.mature_of(u.kind)
	var nw := u.get_node_or_null(NEW) as Sprite2D
	if p >= 0.9 and m != "" and ArtData.UNITS.has(m):
		if nw == null:
			nw = _sprite(u, NEW)
			var lm := (s.material as ShaderMaterial).duplicate() as ShaderMaterial if s.material is ShaderMaterial else null
			if lm != null:
				lm.set_shader_parameter("vet_style", 0)
				lm.set_shader_parameter("venom_swap", false)
				lm.set_shader_parameter("vet_mask", null)
				lm.set_shader_parameter("venom_mask", null)
				lm.set_shader_parameter("wash", Color(0.62, 0.62, 0.58, GREY))
			nw.material = lm
			u.move_child(nw, sh.get_index() + 1)
		_show(nw, m, "idle_se", 0)
		var o := _ease((p - 0.9) / 0.08)
		var mas := float(Defs.UNITS[m].get("art_scale", 1.0))
		nw.scale = Vector2.ONE * mas * lerpf(0.82, 1.0, o)
		nw.self_modulate = Color(1, 1, 1, o)
		var rise := _ease((p - 0.94) / 0.06)
		nw.position = Vector2(0.0, (AIR_Y * rise) if air else -2.0 * (1.0 - o))
	elif nw != null:
		nw.queue_free()


## Its moult is over (BroodMature.tick, right after Unit.morph): the Challenger takes over; the split shell and the shed
## skin are left on the ground behind it (after()).
static func finish(u: Unit) -> void:
	for nm in [SHELL, NEW]:
		var n := u.get_node_or_null(nm)
		if n != null:
			n.queue_free()
			u.remove_child(n)
	if u.sprite == null or not has_art(u):
		return
	var art := "moult_" + line_of(u)
	var left := _sprite(u, LEFT, true)
	_show(left, art, "open_se", 0)
	left.position = Vector2.ZERO
	if (ArtData.UNITS[art]["frames"] as Dictionary).has("skin_se"):
		var sk := _sprite(u, SKIN, true)
		_show(sk, art, "skin_se", 0)
		sk.position = Vector2(-10.0, -3.0)
	u.set_meta("moult_left", 0.0)
	u.set_meta("moult_pos", u.position)
	_wash(u.sprite.material, GREY)


## Every frame after the moult while something is left (Unit._animate): the colour comes back, the shell and the skin
## stay where the moult was (the Challenger may walk off) and fade. delta: the frame's time.
static func after(u: Unit, delta: float) -> void:
	var el := float(u.get_meta("moult_left", 0.0)) + delta
	u.set_meta("moult_left", el)
	if u.moult_t < 0.0:
		_wash(u.sprite.material, GREY * (1.0 - _ease(el / AFTER_COLOUR)))
	var at: Vector2 = u.get_meta("moult_pos", u.position)
	var a := 1.0 - _ease((el - AFTER_HOLD) / AFTER_FADE)
	for nm in [LEFT, SKIN]:
		var n := u.get_node_or_null(nm) as Sprite2D
		if n != null:
			n.position = (at - u.position) + (Vector2(-10.0, -3.0) if nm == SKIN else Vector2.ZERO)
			n.self_modulate.a = a
			n.visible = not u.dead
	if el >= AFTER_HOLD + AFTER_FADE or u.dead:
		clear(u)


static func clear(u: Unit) -> void:
	for nm in [SHELL, NEW, LEFT, SKIN]:
		var n := u.get_node_or_null(nm)
		if n != null:
			n.queue_free()
			u.remove_child(n)
	if u.has_meta("moult_left"):
		u.remove_meta("moult_left")
		u.remove_meta("moult_pos")
	if u.sprite != null:
		_wash(u.sprite.material, 0.0)


static func busy(u: Unit) -> bool:
	return u.has_meta("moult_left")
