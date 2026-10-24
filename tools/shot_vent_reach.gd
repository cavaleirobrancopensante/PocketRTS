extends SceneTree
## Screenshot with rings 10 and 20 tiles round the Brood capital: xvfb-run -a godot --rendering-driver opengl3 --resolution 1600x1000 --script res://tools/shot_vent_reach.gd -- /tmp/vent_reach.png
var main


class Rings extends Node2D:
	var c := Vector2.ZERO
	var t := 32.0
	func _draw() -> void:
		for r in [10, 20]:
			draw_arc(c, r * t, 0, TAU, 128, Color(1, 0.95, 0.3) if r == 10 else Color(1, 0.4, 0.2), 4.0)
			draw_string(ThemeDB.fallback_font, c + Vector2(6, -r * t - 8), "%d tiles" % r, HORIZONTAL_ALIGNMENT_LEFT, -1, 36, Color(1, 1, 1))
		for k in range(0, 21, 5):
			draw_line(c + Vector2(k * t, 0), c + Vector2(k * t, 14), Color(1, 1, 1), 3.0)
		draw_line(c, c + Vector2(20 * t, 0), Color(1, 1, 1), 3.0)


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred(OS.get_cmdline_user_args())


func _run(a: Array) -> void:
	await process_frame
	main.start({"map": "highmoor", "seed": 5, "slots": [
		{"who": "human", "faction": "brood", "colour": 0, "side": 0, "strategy": "balanced"},
		{"who": "hard", "faction": "crown", "colour": 1, "side": 1, "strategy": "balanced"}]})
	var g = main.game
	Engine.time_scale = 8.0
	await create_timer(90.0 / 8.0, true, false, true).timeout
	Engine.time_scale = 1.0
	var hall = g.buildings.filter(func(b): return b.team == g.human and b.kind == g.faction_hall(g.human))[0]
	var r := Rings.new()
	r.c = hall.center(); r.t = float(Defs.TILE); r.z_index = 50
	g.add_child(r)
	g.camera.position = hall.center()
	var vs := root.get_viewport().get_visible_rect().size
	var z := minf(vs.x, vs.y) / (44.0 * float(Defs.TILE))
	g.camera.zoom = Vector2(z, z)
	await create_timer(0.8).timeout
	root.get_viewport().get_texture().get_image().save_png(a[0])
	quit()
