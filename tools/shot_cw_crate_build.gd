extends SceneTree
## Every Clockwork building from its placed ghost to finished, the way a Winder's crate lands and unfolds into it
## (docs/shots/cw_crate_build/):
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1600x900 --fixed-fps 30 --script res://tools/shot_cw_crate_build.gd -- <outdir>
## Writes <outdir>/<kind>_<nn>_<moment>.png (the screen around the building, zoomed).
var main: Node
var g
var out := ""
var t := 0.0
var started := false

## [seconds after the crate landed, name]; then the half built, the finished and the damaged building.
const MOMENTS := [[0.05, "crate"], [0.6, "lid"], [1.2, "unfold"], [1.9, "plates"], [2.5, "frame"], [3.4, "scaffold"],
	[7.0, "rising"]]


func _initialize() -> void:
	out = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(delta: float) -> bool:
	t += delta
	if t > 0.2 and main.game == null:
		main.start({"map": "greenhold", "seed": 5, "slots": [
			{"who": "you", "faction": "clockwork", "colour": 0, "side": 0},
			{"who": "easy", "faction": "crown", "colour": 1, "side": 1}]})
		return false
	if main.game == null:
		return false
	g = main.game
	if g.hud:
		g.hud.countdown = 0.0
		g.hud.visible = false
	paused = false
	if not started and t > 1.0:
		started = true
		for ai in g.ais:
			ai.process_mode = Node.PROCESS_MODE_DISABLED
		_run()
	return false


func _open_area(w: int, h: int, avoid: Array) -> Vector2i:
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
			for s in avoid:
				if p.distance_to(s) < 420.0:
					ok = false
			if ok:
				return Vector2i(x, y)
	return Vector2i(-1, -1)


func shot(name: String) -> void:
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])


func _run() -> void:
	g.reveal = true
	g.camera.zoom = Vector2(2.0, 2.0)
	var avoid: Array = []
	for b in g.buildings:
		avoid.append(b.center())
	for k: String in Defs.build_list("clockwork"):
		var cell := _open_area(8, 8, avoid)
		var b: Building = g._add_building(k, 0, cell + Vector2i(2, 2), false, true)
		avoid.append(b.center())
		b.crate = "carried"           # (on its way: the ghost stays)
		g.camera.position = b.center() + Vector2(0, -30)
		await create_timer(1.0).timeout
		shot("%s_00_ghost" % k)
		g.try_start_site(b, null)
		b.land_crate()
		var t0 := 0.0
		var n := 1
		for m in MOMENTS:
			await create_timer(float(m[0]) - t0).timeout
			t0 = float(m[0])
			shot("%s_%02d_%s" % [k, n, m[1]])
			n += 1
		b.progress = 0.6
		await create_timer(0.3).timeout
		shot("%s_%02d_built60" % [k, n])
		b.progress = 0.995
		await create_timer(1.5).timeout
		shot("%s_%02d_finished" % [k, n + 1])
		b.hp = b.max_hp * 0.3
		await create_timer(0.3).timeout
		shot("%s_%02d_damaged" % [k, n + 2])
	quit()
