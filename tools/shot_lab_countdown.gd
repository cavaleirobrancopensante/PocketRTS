extends SceneTree
## Screenshot of the CLOCKWORK LAB during the 3-2-1 countdown: the gear rings must already stand drawn (not pop in at GO).
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --script res://tools/shot_lab_countdown.gd -- <out.png>
var main: Node
var out := ""
var t := 0.0
var shot := false


func _initialize() -> void:
	out = OS.get_cmdline_user_args()[0]
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(delta: float) -> bool:
	t += delta
	if t > 0.2 and main.game == null:
		main.start_lab()
		return false
	if main.game == null:
		return false
	var hud = main.game.hud
	if not shot and hud and hud.countdown > 0.0 and hud.countdown < 2.2:
		shot = true
		root.get_viewport().get_texture().get_image().save_png(out)
		print("shot at countdown %.2f" % hud.countdown)
		quit()
	return false
