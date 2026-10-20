extends SceneTree
## Capture screenshots: godot --script res://tools/shot.gd -- <outdir> <f0> <f1>
var main
var out := ""
func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	out = a[0]
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred(a.slice(1))

func _run(f: Array) -> void:
	await process_frame
	main.start(1, f.size() > 2, f.slice(0, 2))
	var g = main.game
	Engine.time_scale = 8.0
	await create_timer((420.0 if f.size() > 2 else 150.0) / 8.0, true, false, true).timeout
	Engine.time_scale = 1.0
	var hall = g.buildings.filter(func(b): return b.team == maxi(g.human, 0) and b.kind == g.faction_hall(maxi(g.human, 0)))[0]
	g.camera.position = hall.center() + Vector2(120, -40)
	await create_timer(0.5).timeout
	root.get_viewport().get_texture().get_image().save_png(out + "/mines.png")
	g.over = true
	g._sample_stats()
	main._on_end(0)
	await create_timer(1.6).timeout
	root.get_viewport().get_texture().get_image().save_png(out + "/report.png")
	quit()
