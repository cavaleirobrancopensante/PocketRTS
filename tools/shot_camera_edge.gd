extends SceneTree
## The camera past the map edge (Defs.CAMERA_MARGIN_TILES): the view centred on your starting
## hall (add a second argument "far" to push it as far toward the nearest corner as it goes):
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --script res://tools/shot_camera_edge.gd -- out.png
var main: Node
var out := ""
var t := 0.0
var step := 0


func _initialize() -> void:
	out = OS.get_cmdline_user_args()[0]
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(delta: float) -> bool:
	t += delta
	if t > 0.2 and main.game == null:
		main.start({"map": "greenhold", "seed": 5, "slots": [
			{"who": "you", "faction": "crown", "colour": 0, "side": 0},
			{"who": "easy", "faction": "brood", "colour": 1, "side": 1}]})
		return false
	if main.game == null:
		return false
	var g: Game = main.game
	if g.hud:
		g.hud.countdown = 0.0
	paused = false
	if step == 0 and t > 1.5:
		step = 1
		for ai in g.ais:
			ai.process_mode = Node.PROCESS_MODE_DISABLED
		var hall: Building = g.halls_of(g.human)[0]
		var c := hall.center()
		var mid := Vector2(Game.W, Game.H) * Game.T * 0.5
		# the hall's nearest corner: centre the view on the base, then slide toward that corner
		var dir := Vector2(signf(c.x - mid.x), signf(c.y - mid.y))
		g.camera.zoom = Vector2(0.8, 0.8)
		g.camera.position = c if OS.get_cmdline_user_args().size() < 2 else c + dir * 100000.0
		g.controls._clamp_camera()
		print("hall at %s, camera at %s" % [c, g.camera.position])
	elif step == 1 and t > 3.0:
		step = 2
		main.get_viewport().get_texture().get_image().save_png(out)
		print("saved " + out)
		quit(0)
	return false
