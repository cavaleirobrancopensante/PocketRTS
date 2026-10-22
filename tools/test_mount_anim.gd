extends SceneTree
## The riders' mounting animation (tools/import_mount.py strips, scripts/unit.gd "mount"):
##   godot --headless --fixed-fps 30 --script res://tools/test_mount_anim.gd
##   (screenshots: xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 1280x720
##    --fixed-fps 30 --script res://tools/test_mount_anim.gd -- --shots DIR)
## Checks, for every man on foot -> mounted kind: the mount_s / mount_se / mount_e / mount_n
## strips and their horse coat masks exist; while he gets on, he shows the mounted kind's
## strip played forwards (side on, mirrored when he comes from the right; from the front or
## behind when the horse faces S or N, never mirrored; NE / NW side on), in the horse's coat,
## the horse beside him hidden; he ends in the saddle where the horse stood; getting off plays
## it backwards and leaves the horse where the strip drew it. Prints PASS / FAIL and "ALL PASS" (exit 1 on a
## failure).
var main: Node
var t := 0.0
var g
var started := false
var fails := 0
var origin := Vector2i(-1, -1)
var shots := ""

# man on foot, armoured, mounted kind, its sprite set, a coat to try
const PAIRS := [
	["labourer", false, "messenger", "messenger", "white"],
	["musketeer", false, "dragoon", "dragoon", "bay"],
	["musketeer", true, "dragoon", "dragoon_armoured", "white"],
	["dismounted", false, "cuirassier", "horseman", "bay"],
	["dismounted", true, "cuirassier", "cuirassier", "spotted"],
	["missionary", false, "mounted_missionary", "missionary_mounted", "grey"],
]


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.has("--shots"):
		shots = a[a.find("--shots") + 1]
		DirAccess.make_dir_recursive_absolute(shots)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(_delta: float) -> bool:
	t += _delta
	if t > 0.2 and main.game == null:
		main.start({"map": "hollowfen", "seed": 4242, "slots": [
			{"who": "you", "faction": "crown", "colour": 0, "side": 0},
			{"who": "easy", "faction": "brood", "colour": 1, "side": 1}]})
		return false
	if main.game == null:
		return false
	g = main.game
	if g.hud:
		g.hud.countdown = 0.0
	paused = false
	if not started and t > 1.0:
		started = true
		for ai in g.ais:
			ai.process_mode = Node.PROCESS_MODE_DISABLED
		_run()
	return false


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func wait(sec: float) -> void:
	var end: float = g.clock + sec
	while g.clock < end:
		await physics_frame


func wait_for(cond: Callable, sec: float) -> bool:
	var end: float = g.clock + sec
	while g.clock < end:
		if cond.call():
			return true
		await physics_frame
	return cond.call()


func at(dx: float, dy: float) -> Vector2:
	return Vector2(origin) * Defs.TILE + Vector2(dx, dy)


func _open_area(w: int, h: int) -> Vector2i:
	var starts: Array = []
	for b in g.buildings:
		starts.append(b.center())
	for y in range(4, g.H - h - 4):
		for x in range(4, g.W - w - 4):
			var ok := true
			var h0: int = g.height[g.idx(Vector2i(x, y))]
			for yy in h:
				for xx in w:
					var c := Vector2i(x + xx, y + yy)
					if g.solid[g.idx(c)] != 0 or g.ramp[g.idx(c)] != 0 or g.height[g.idx(c)] != h0:
						ok = false
						break
				if not ok:
					break
			if not ok:
				continue
			var p: Vector2 = g.cell_center(Vector2i(x + w / 2, y + h / 2))
			for s in starts:
				if p.distance_to(s) < 700.0:
					ok = false
			if ok:
				return Vector2i(x, y)
	return Vector2i(-1, -1)


func shot(name: String) -> void:
	if shots == "":
		return
	await process_frame
	await process_frame
	root.get_viewport().get_texture().get_image().save_png(shots.path_join(name + ".png"))


func _run() -> void:
	origin = _open_area(20, 14)
	if origin.x < 0:
		print("FAIL: no open ground for the test")
		quit(1)
		return
	g.reveal = true
	if g.hud:
		g.hud.visible = shots == ""
	# the strips and their coat masks
	for p in PAIRS:
		var art: String = p[3]
		var fr: Dictionary = ArtData.UNITS[art]["frames"]
		for dr in ["s", "se", "e", "n"]:
			var ok: bool = fr.has("mount_" + dr) and int(fr["mount_" + dr]) >= 6 \
				and ResourceLoader.exists("res://assets/units/%s/mount_%s.png" % [art, dr]) \
				and ResourceLoader.exists("res://assets/units/horse_masks/%s/mount_%s.png" % [art, dr])
			check(ok, "%s: mount_%s strip (%d frames) and its coat mask" % [art, dr, int(fr.get("mount_" + dr, 0))])
	# the facing snap: the nearest drawn way (NE / NW side on)
	for p in PAIRS:
		var art: String = p[3]
		var want := {Vector2(0, 1): "s", Vector2(0.3, 1): "s", Vector2(1, 1): "se", Vector2(-1, 1): "se",
			Vector2(1, 0): "e", Vector2(-1, -0.2): "e", Vector2(1, -1): "e", Vector2(-1, -1): "e",
			Vector2(0, -1): "n", Vector2(-0.3, -1): "n"}
		var bad := []
		for f in want:
			var mf := Unit.mount_face(art, f)
			var flip_ok: bool = Unit.mount_dir(mf) in ["s", "n"] or (mf.x < 0.0) == (f.x < 0.0)
			if Unit.mount_dir(mf) != want[f] or not flip_ok:
				bad.append("%s -> %s" % [str(f), str(mf)])
		check(bad.is_empty(), "%s: facing snaps to the nearest drawn way %s" % [art, str(bad)])
	var i := 0
	for p in PAIRS:
		for dr in ["e", "se", "s", "n"]:
			for side in [1.0, -1.0]:
				await _mount(p, side, dr, i)
				i += 1
		# a horse facing NE: side on
		await _mount(p, 1.0, "ne", i)
		i += 1
	await _quick_dragoon()
	print("ALL PASS" if fails == 0 else "%d FAILED" % fails)
	quit(0 if fails == 0 else 1)


## One man gets on a horse and off again: side 1 he comes from the left (the horse faces
## `dr`: E, SE, S, N, or NE: shown side on), -1 from the right (W / SW: the strip mirrored;
## S and N: not mirrored, he goes round to the horse's side).
func _mount(p: Array, side: float, dr: String, i: int) -> void:
	var foot: String = p[0]
	var art: String = p[3]
	var coat: String = p[4]
	var hp := at(320, 220)
	var m: Unit = g._add_unit(foot, 0, hp - Vector2(34.0 * side, 0))
	m.auto_work = false
	if p[1]:
		m.put_on_armour()
	var h: Unit = g._add_unit("horse", 0, hp)
	h.coat = coat
	h.facing = {"e": Vector2(side, 0), "se": Vector2(side, 1.0).normalized(), "s": Vector2(0, 1),
		"n": Vector2(0, -1), "ne": Vector2(side, -1.0).normalized()}[dr]
	HorseCoat.apply(h)
	h.graze_at = hp
	g.camera.position = hp + Vector2(0, -24)
	g.camera.zoom = Vector2(2.6, 2.6)
	var front := dr == "s" or dr == "n"
	var flip := side < 0.0 and not front
	var tag := "%s %s%s" % [art, dr.to_upper(), "" if side > 0 else (" from the right" if front else " mirrored")]
	m.cmd_mount(h)
	await wait_for(func() -> bool: return m.work == "mounting", 5.0)
	await wait(0.15)
	var want_dir := "e" if dr == "ne" else dr
	check(m.anim == "mount" and m._anim_art == art and m.anim_dir == want_dir and m.anim_flip == flip,
		"%s: getting on shows the %s strip (%s %s %s flip %s)" % [tag, art, m.anim, m._anim_art, m.anim_dir, m.anim_flip])
	check(m.sprite.texture.resource_path.ends_with("%s/mount_%s.png" % [art, want_dir]), "  the strip's texture (%s)" % m.sprite.texture.resource_path)
	var mat := m.sprite.material as ShaderMaterial
	var want_coat := HorseCoat.COATS.find(coat) if coat != HorseCoat.NATIVE.get(p[2], "") else -1
	check(int(mat.get_shader_parameter("coat")) == want_coat and mat.get_shader_parameter("horse_mask") != null,
		"  the horse in the strip wears its coat (%s)" % coat)
	check(h.modulate.a < 0.01, "  the horse itself is hidden (the strip draws it)")
	check(m.sprite.position.distance_to(h.position - m.position) < 0.5, "  the strip is drawn where the horse stands")
	var frames: Array = []
	var n: int = m.sprite.hframes
	var shot_at := [0.3, 0.55, 0.8]
	while m.work == "mounting":
		if frames.is_empty() or frames[-1] != m.sprite.frame:
			frames.append(m.sprite.frame)
		var prog := 1.0 - m.work_t / m._mount_len
		if not shot_at.is_empty() and prog >= shot_at[0]:
			shot_at.pop_front()
			await shot("%02d_%s_%s_on_%d" % [i, art, dr, 3 - shot_at.size()])
		await physics_frame
	var rising := true
	for k in range(1, frames.size()):
		rising = rising and frames[k] >= frames[k - 1]
	check(rising and frames[0] <= 1 and frames[-1] >= n - 1 and frames.size() >= n - 1, "  played forwards over the mount time (%s of %d)" % [str(frames), n])
	await wait_for(func() -> bool: return m.kind == p[2], 3.0)
	await wait(0.1)
	check(m.kind == p[2] and m.position.distance_to(hp) < 1.0 and m.anim != "mount" and m.sprite.position == Vector2.ZERO,
		"  in the saddle where the horse stood (%.1f px), standing" % m.position.distance_to(hp))
	# and off again (backwards)
	var at0 := m.position
	m.cmd_dismount()
	await wait(0.1)
	check(m.anim == "mount" and m._anim_art == art and m.anim_dir == want_dir and m.anim_flip == flip, "  getting off shows the strip (%s %s flip %s)" % [m.anim, m.anim_dir, m.anim_flip])
	frames = []
	var shot_off := true
	while m.work == "dismounting":
		if frames.is_empty() or frames[-1] != m.sprite.frame:
			frames.append(m.sprite.frame)
		if shot_off and 1.0 - m.work_t / m._mount_len >= 0.5:
			shot_off = false
			await shot("%02d_%s_%s_off_1" % [i, art, dr])
		await physics_frame
	var falling := true
	for k in range(1, frames.size()):
		falling = falling and frames[k] <= frames[k - 1]
	check(falling and frames[0] >= n - 2 and frames[-1] <= 1, "  played backwards (%s)" % str(frames))
	await wait_for(func() -> bool: return m.kind == foot, 3.0)
	var st: Unit = m.steed
	check(st != null and is_instance_valid(st) and st.position.distance_to(at0) < 4.0 and st.coat == coat,
		"  his horse stands where the strip drew it (%.1f px), its coat" % (st.position.distance_to(at0) if st else -1.0))
	var man: Vector2 = Unit.mount_man(art, want_dir)
	check(m.position.distance_to(at0 + Vector2(man.x * (-1.0 if flip else 1.0), man.y)) < 3.0, "  he stands where the strip had him (%s)" % str(m.position - at0))
	check(st != null and is_instance_valid(st) and Unit.mount_dir(st.facing) == want_dir and (st.facing.x < -0.3) == flip,
		"  the horse faces the strip's way (%s)" % (str(st.facing) if st else "-"))
	await wait(0.2)
	await shot("%02d_%s_%s_off_done" % [i, art, dr])
	g.consume_unit(m)
	if st and is_instance_valid(st):
		g.consume_unit(st)
	await physics_frame


## A Dragoon's own quick dismount to fire (Defs.HORSES quick) plays it too, him on the side
## of his target.
func _quick_dragoon() -> void:
	var dg: Unit = g._add_unit("dragoon", 0, at(200, 400))
	dg.facing = Vector2.RIGHT
	g.camera.position = dg.position
	dg.cmd_dismount(true)
	await wait(0.1)
	check(dg.anim == "mount" and dg._anim_art == "dragoon" and is_equal_approx(dg._mount_len, float(Defs.HORSES["quick"])), "a Dragoon's quick dismount plays the strip (%.1f s)" % dg._mount_len)
	await wait_for(func() -> bool: return dg.kind == "musketeer", 2.0)
	check(dg.kind == "musketeer" and dg.steed and dg.position.x > dg.steed.position.x, "  he gets off on his target's side of the horse (%s)" % str(dg.position - dg.steed.position))
	# the Armoured Dragoon's strip has him by the horse's rump: the horse turned away
	var ad: Unit = g._add_unit("dragoon", 0, at(200, 400))
	ad.put_on_armour()
	ad.facing = Vector2.RIGHT
	ad.cmd_dismount(true)
	await wait_for(func() -> bool: return ad.kind == "musketeer", 2.0)
	check(ad.kind == "musketeer" and ad.steed and ad.position.x > ad.steed.position.x, "  an Armoured Dragoon too (%s)" % str(ad.position - ad.steed.position))
	g.consume_unit(ad)
	if ad.steed and is_instance_valid(ad.steed):
		g.consume_unit(ad.steed)
	g.consume_unit(dg)
	if dg.steed and is_instance_valid(dg.steed):
		g.consume_unit(dg.steed)
	await physics_frame
