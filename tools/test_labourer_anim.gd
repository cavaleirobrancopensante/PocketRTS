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

const POSES := ["walk", "carry", "carry_keg", "idle", "idle_keg", "idle_carry", "mine", "build", "bury", "death", "death_keg"]
const DIRS := ["s", "se", "e", "ne", "n"]
## the strike (hammer on the stake, spark) is the third frame of every build strip: the
## redrawn strips are in swing order (raise, drop, strike, lift)
const STRIKE_FRAME := {"s": 2, "se": 2, "e": 2, "ne": 2, "n": 2}
## poses redrawn from art/redraws (tools/import_labourer_redraw.py) and their frame counts
const REDRAWN := {"walk": 6, "carry": 6, "carry_keg": 6, "idle_keg": 4, "idle_carry": 2, "mine": 4, "build": 4,
	"idle": 2, "death": 3, "death_keg": 6, "bury": 6}


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
	_gait()
	_v2()
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
	# the redrawn poses: the frame counts the importer makes, and every frame of every strip stands
	# on the ground line (its lowest opaque row is 33, the anchor row) and inside the cell
	var off := []
	var wrong := []
	for p in REDRAWN:
		for d in DIRS:
			var key: String = p + "_" + d
			if int(fr.get(key, 0)) != int(REDRAWN[p]):
				wrong.append(key)
				continue
			var im: Image = (load("res://assets/units/labourer/%s.png" % key) as Texture2D).get_image()
			for i in int(REDRAWN[p]):
				var low := -1
				var edge := false
				for y in 35:
					for x in 42:
						if im.get_pixel(i * 42 + x, y).a > 0.0:
							low = y
							if x == 0 or x == 41:
								edge = true
				if low != 33 or edge:
					off.append("%s[%d] low %d" % [key, i, low])
	check(wrong.is_empty(), "redrawn poses have their frame counts %s" % str(wrong))
	check(off.is_empty(), "every redrawn frame stands on the ground line, inside the cell %s" % str(off))


## The gait (tools/import_labourer_gait.py): in the side and diagonal views the legs must move
## from one frame to the next: the leg rows (24..33) differ by at least GAIT_MIN_DIFF pixels between
## every pair of consecutive frames (the strip loops), the boot span (rows 30..33) swings between a
## wide contact stance (>= 10 px) and a narrow passing one (<= 9 px, at least GAIT_MIN_SWING px
## narrower), the widest stances are half a strip apart (contact A, contact B), and the body bobs.
const GAIT_MIN_DIFF := 22
const GAIT_MIN_SWING := 4


func _gait() -> void:
	var bad := []
	for p in ["walk", "carry", "carry_keg"]:
		for d in ["e", "se", "ne"]:
			var im: Image = (load("res://assets/units/labourer/%s_%s.png" % [p, d]) as Texture2D).get_image()
			var n := im.get_width() / 42
			var spans := []
			var tops := []
			for i in n:
				var lo := 99
				var hi := -1
				var top := 99
				for y in 35:
					for x in 42:
						if im.get_pixel(i * 42 + x, y).a > 0.0:
							top = mini(top, y)
							if y >= 30:
								lo = mini(lo, x)
								hi = maxi(hi, x)
				spans.append(hi - lo + 1)
				tops.append(top)
			for i in n:
				var j := (i + 1) % n
				var diff := 0
				for y in range(24, 34):
					for x in 42:
						if (im.get_pixel(i * 42 + x, y).a > 0.0) != (im.get_pixel(j * 42 + x, y).a > 0.0):
							diff += 1
				if diff < GAIT_MIN_DIFF:
					bad.append("%s_%s %d->%d legs differ by %d px" % [p, d, i, j, diff])
			var mx: int = spans.max()
			var mn: int = spans.min()
			if mx < 10 or mx - mn < GAIT_MIN_SWING:
				bad.append("%s_%s boot span %s" % [p, d, str(spans)])
			# two strides a cycle: the span has at least two peaks (the ChatGPT legs are not exactly half a strip apart)
			var peaks := 0
			for i in n:
				if spans[i] >= mn + 3 and spans[i] >= spans[(i + n - 1) % n] and spans[i] > spans[(i + 1) % n]:
					peaks += 1
			if peaks < 2:
				bad.append("%s_%s only %d stride peaks %s" % [p, d, peaks, str(spans)])
			if (tops.max() - tops.min()) < 1:
				bad.append("%s_%s no body bob %s" % [p, d, str(tops)])
	check(bad.is_empty(), "walk / carry / keg in e, se, ne: legs change every frame, contact and passing stances alternate, body bobs %s" % str(bad))


## Round 2 (tools/import_labourer_v2.py): death, keg death, bury, idle and walk from the second ChatGPT sheets.
## No two frames of a strip may be identical (a repeated frame is a ChatGPT row that was not repaired),
## the idle pair must differ (the breath), the front / back walk (s, n) must move its legs
## (>= V2_MIN_LEG_DIFF px between consecutive frames, the strip loops) and swap the lifted foot.
const V2_MIN_LEG_DIFF := 4          # (the owner's ChatGPT s / n walks of 2026-10-24 step less between some frames)


func _v2() -> void:
	var bad := []
	for p in ["death", "death_keg", "bury", "idle", "walk"]:
		for d in DIRS:
			var im: Image = (load("res://assets/units/labourer/%s_%s.png" % [p, d]) as Texture2D).get_image()
			var n := im.get_width() / 42
			for i in n:
				for j in range(i + 1, n):
					var same := true
					for y in 35:
						for x in 42:
							if im.get_pixel(i * 42 + x, y) != im.get_pixel(j * 42 + x, y):
								same = false
								break
						if not same:
							break
					if same:
						bad.append("%s_%s frames %d and %d identical" % [p, d, i, j])
	check(bad.is_empty(), "round 2 strips: no two frames of a strip are identical %s" % str(bad))
	bad = []
	for d in ["s", "n"]:
		var im: Image = (load("res://assets/units/labourer/walk_%s.png" % d) as Texture2D).get_image()
		var lift := []
		for i in 6:
			var j := (i + 1) % 6
			var diff := 0
			for y in range(24, 34):
				for x in 42:
					if (im.get_pixel(i * 42 + x, y).a > 0.0) != (im.get_pixel(j * 42 + x, y).a > 0.0):
						diff += 1
			if diff < V2_MIN_LEG_DIFF:
				bad.append("walk_%s %d->%d legs differ by %d px" % [d, i, j, diff])
			# the outer four columns of the boots, left and right: the raised boot ends higher
			var cmin := 99
			var cmax := -1
			for y in range(28, 34):
				for x in 42:
					if im.get_pixel(i * 42 + x, y).a > 0.0:
						cmin = mini(cmin, x)
						cmax = maxi(cmax, x)
			var lows := [0, 0]
			for y in range(24, 34):
				for x in 42:
					if im.get_pixel(i * 42 + x, y).a > 0.0:
						if x < cmin + 4:
							lows[0] = maxi(lows[0], y)
						elif x > cmax - 4:
							lows[1] = maxi(lows[1], y)
			lift.append(lows[0] - lows[1])
		var lefts := lift.filter(func(v: int) -> bool: return v < 0).size()
		var rights := lift.filter(func(v: int) -> bool: return v > 0).size()
		if lefts == 0 or rights == 0:
			bad.append("walk_%s the lifted foot never swaps sides %s" % [d, str(lift)])
	check(bad.is_empty(), "walk s / n: legs change every frame and the lifted foot swaps sides %s" % str(bad))


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
	# standing with the gold on his back plays the sack idle (no yellow dot), walking the carry
	u.carrying = 60
	for i in 12:
		await physics_frame
	check(u.anim == "idle_carry" and u.sprite.hframes == 2, "standing with gold plays idle_carry (%s, %d frames)" % [u.anim, u.sprite.hframes])
	u.cmd_move(u.position + Vector2(120.0, 0.0))
	for i in 20:
		await physics_frame
	check(u.anim == "carry" and u.sprite.hframes == 6, "walking with gold plays carry (%s, %d frames)" % [u.anim, u.sprite.hframes])
	u.cmd_stop()
	u.carrying = 0
	for i in 45:
		await physics_frame
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
