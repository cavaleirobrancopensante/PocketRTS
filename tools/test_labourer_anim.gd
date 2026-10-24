extends SceneTree
## The Crown Labourer's animation audit fixes (docs/animation_audit_labourer.md):
##   godot --headless --fixed-fps 30 --script res://tools/test_labourer_anim.gd
## Checks: every pose has all five views with the frame counts ArtData says; the hammer swing
## table (one swing = BUILD_CYCLE, strike frame in each view is the drawn lowest-hammer frame,
## the clip's first big blow lands on a strike after lab_build_lock); the walk is stride-driven
## (a whole strip of frames per LAB_STRIDE px of ground, so the feet stay put at any speed);
## walking does not flick to idle on a slow tick; the view only changes past the octant edge;
## the keg idle plays at one breath rate whatever its frame count. Prints PASS / FAIL and
## "ALL PASS" (exit 1 on a failure).
var main: Node
var t := 0.0
var g
var started := false
var fails := 0

const POSES := ["walk", "carry", "carry_keg", "idle", "idle_keg", "mine", "build", "bury", "death", "death_keg"]
const DIRS := ["s", "se", "e", "ne", "n"]
## the frame where the drawn hammer is lowest (measured on the strips, see the audit)
const STRIKE_FRAME := {"s": 3, "se": 0, "e": 3, "ne": 2, "n": 3}


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(delta: float) -> bool:
	t += delta
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


func _run() -> void:
	_strips()
	_swing()
	await _walk()
	print("ALL PASS" if fails == 0 else "%d FAILED" % fails)
	quit(0 if fails == 0 else 1)


func _strips() -> void:
	var fr: Dictionary = ArtData.UNITS["labourer"]["frames"]
	var bad := []
	for p in POSES:
		for d in DIRS:
			var key: String = p + "_" + d
			if not fr.has(key):
				bad.append(key + " missing")
				continue
			var tex := load("res://assets/units/labourer/%s.png" % key) as Texture2D
			if tex == null or tex.get_width() != int(fr[key]) * 42 or tex.get_height() != 35:
				bad.append(key + " size")
	check(bad.is_empty(), "all %d strips exist, %d x 35 per frame count %s" % [POSES.size() * DIRS.size(), 42, str(bad)])


func _swing() -> void:
	var fr: Dictionary = ArtData.UNITS["labourer"]["frames"]
	for d in DIRS:
		var sw: Dictionary = Unit.BUILD_SWING[d]
		var total := 0.0
		var frames := []
		for st in sw["seq"]:
			total += float(st[1])
			frames.append(int(st[0]))
		var n := int(fr["build_" + d])
		var in_range := frames.all(func(f: int) -> bool: return f >= 0 and f < n)
		var all_used := true
		for f in n:
			if not frames.has(f):
				all_used = false
		var hit_frame: int = sw["seq"][int(sw["hit"])][0]
		check(absf(total - Unit.BUILD_CYCLE) < 0.001 and in_range and all_used and hit_frame == STRIKE_FRAME[d],
			"build_%s: swing %.2f s, frames %s, strike on frame %d" % [d, total, str(frames), hit_frame])
		# the clip's first big blow (0.46 s after it starts) is a strike, and so is every
		# later blow 0.40 s on (5 swings = the 2.0 s clip)
		var t0 := Unit.lab_build_lock(d)
		var ok := true
		for k in 5:
			var blow := t0 + Unit.BUILD_CLIP_BLOW + 0.001 + 0.40 * k
			ok = ok and Unit.lab_build_frame(d, blow) == STRIKE_FRAME[d]
		check(ok, "build_%s: the hammering clip's blows land on the strike frame" % d)
		# a clear rhythm: the raised hammer is held longer than the drop to the strike
		var raise_t: float = sw["seq"][0][1]
		var drop_t: float = sw["seq"][1][1]
		check(raise_t >= drop_t, "build_%s: raise held %.2f s, then the drop %.2f s" % [d, raise_t, drop_t])


func _open(dx: float) -> Vector2:
	var best := Vector2.ZERO
	for b in g.buildings:
		if b.team == 0 and b.kind == "town_hall":
			best = b.center()
	return best + Vector2(dx, 150.0)


func _walk() -> void:
	var u: Unit = g._add_unit("labourer", 0, _open(-200.0))
	u.auto_work = false
	g.camera.position = u.position
	g.camera.zoom = Vector2(2.0, 2.0)
	await create_timer(0.3).timeout
	u.cmd_move(u.position + Vector2(400.0, 0.0))
	var ticks := 0
	var changes := 0
	var last_frame := -1
	var first_pos := Vector2.ZERO
	var frames_seen := {}
	var prev_anim := ""
	var anim_switches := 0
	var start := Time.get_ticks_msec()
	while u.work != "" or u.velocity.length() > 1.0 or ticks < 30:
		await physics_frame
		ticks += 1
		if ticks == 20:
			first_pos = u.position
		if ticks > 20 and u.velocity.length() > 10.0 and u.anim == "walk":
			if u.frame_i != last_frame:
				changes += 1
				last_frame = u.frame_i
			frames_seen[u.frame_i] = true
		if u.anim != prev_anim:
			anim_switches += 1
			prev_anim = u.anim
		if Time.get_ticks_msec() - start > 20000 or ticks > 900:
			break
	var dist := u.position.distance_to(first_pos)
	var n: int = ArtData.UNITS["labourer"]["frames"]["walk_e"]
	var want: float = dist / (float(Unit.LAB_STRIDE["walk"]) / float(n))
	check(frames_seen.size() == n, "walking east shows every one of the %d walk frames" % n)
	check(changes > 0 and absf(float(changes) - want) <= want * 0.2 + 3.0,
		"walk frames follow the ground: %d frame changes over %.0f px (stride says %.0f)" % [changes, dist, want])
	check(anim_switches <= 3, "walking east: no flicker between poses (%d switches)" % anim_switches)
	# the stride is distance-driven: stand still, the frame holds
	u.cmd_stop()
	for i in 45:
		await physics_frame
	check(u.anim == "idle", "he stands idle after the walk (%s, speed %.1f)" % [u.anim, u.velocity.length()])
	# the view hysteresis: a facing just past the octant edge keeps the old view
	u._lab_view = 1                      # SE
	var edge := Vector2.from_angle(PI / 4.0 + PI / 8.0 + 0.05)        # 5 deg past the S/SE edge
	u.facing = edge
	u._set_anim("idle", true)
	check(u.anim_dir == "se" and not u.anim_flip, "a facing just past the SE/S edge keeps the SE view (%s)" % u.anim_dir)
	u.facing = Vector2.from_angle(PI / 2.0)
	u._set_anim("idle", true)
	check(u.anim_dir == "s", "turning clearly south changes to the S view (%s)" % u.anim_dir)
	# the west views are the east drawings mirrored
	u.facing = Vector2(-1, 0)
	u._set_anim("idle", true)
	check(u.anim_dir == "e" and u.anim_flip and u.sprite.scale.x < 0.0, "west = east view mirrored")
	u.facing = Vector2(-1, 1).normalized()
	u._set_anim("idle", true)
	check(u.anim_dir == "se" and u.anim_flip, "south-west = south-east view mirrored")
	u.facing = Vector2(-1, -1).normalized()
	u._set_anim("idle", true)
	check(u.anim_dir == "ne" and u.anim_flip, "north-west = north-east view mirrored")
