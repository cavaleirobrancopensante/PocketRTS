extends SceneTree
## Close-up frames of the Escapement's working loop in the CLOCKWORK LAB (it meshes with the Mainspring there, so it
## works from the start): the anchor rocks, the wheel ticks (tools/press_anim/escapement_work.py).
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --script res://tools/shot_escapement.gd -- <outdir> [frames] [zoom]
## Writes <outdir>/esc_00.png ... (frames, default 24, one game frame of the loop apart: Defs.GEAR "escapement_dt").
var main: Node
var g
var out := ""
var frames := 24
var zoom := 3.0
var t := 0.0
var started := false


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	out = a[0]
	if a.size() > 1:
		frames = int(a[1])
	if a.size() > 2:
		zoom = float(a[2])
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(delta: float) -> bool:
	t += delta
	if t > 0.2 and main.game == null:
		main.start_lab()
		return false
	if main.game == null:
		return false
	g = main.game
	if g.hud:
		g.hud.countdown = 0.0
	paused = false
	if not started and t > 1.0:
		started = true
		_run()
	return false


func _run() -> void:
	var esc: Building = null
	for b in g.buildings:
		if b.team == g.human and b.kind == Defs.CW_TECH:
			esc = b
	if esc == null:
		print("NO ESCAPEMENT")
		quit(1)
		return
	g.reveal = true
	for c in root.find_children("*", "CanvasLayer", true, false):
		c.visible = false
	g.camera.position = esc.center() + Vector2(0, -20)
	g.camera.zoom = Vector2(zoom, zoom)
	await create_timer(1.5).timeout
	print("escapement working: %s, texture %s" % [str(esc.drill_anim), esc.sprite.texture.resource_path if esc.sprite.texture else "-"])
	var dt := float(Defs.GEAR["escapement_dt"])
	for i in frames:
		# (snap each frame of the loop once: wait for the game clock to reach it)
		var want := int(g.clock / dt) + 1
		while int(g.clock / dt) < want:
			await process_frame
		await process_frame
		root.get_viewport().get_texture().get_image().save_png("%s/esc_%02d.png" % [out, i])
	quit(0)
