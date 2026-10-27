extends SceneTree
## Screenshots of FIRE AT A SPOT (BOMBARD) and of area shots tearing up bodies:
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --script res://tools/shot_attack_ground.gd -- <outdir>
## Writes card.png (a Cannon's command card with ATTACK GROUND, was BOMBARD, and its tooltip), mode.png (Ctrl+A: picking the spot),
## bodies_before.png, shelling.png (a Mortar's shell on its way to the spot), bodies_torn.png (the moment it lands) and
## bodies_after.png.
var main
var out := "/tmp/shots_ground"


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if not a.is_empty():
		out = a[0]
	Settings.load_all()
	Settings.device = "pc"
	Settings.apply()
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred()


func _shot(name: String) -> void:
	await process_frame
	await process_frame
	root.get_viewport().get_texture().get_image().save_png(out.path_join(name))
	print("wrote ", out.path_join(name))


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	await process_frame
	main.start({"map": "hollowfen", "seed": 4242, "slots": [
		{"who": "you", "faction": "crown", "colour": 0, "side": 0, "strategy": "balanced"},
		{"who": "easy", "faction": "brood", "colour": 1, "side": 1, "strategy": "balanced"}]})
	await process_frame
	await process_frame
	var g: Game = main.game
	g.hud.countdown = 0.0
	paused = false
	for ai in g.ais:
		ai.process_mode = Node.PROCESS_MODE_DISABLED
	g.explored.fill(1)
	var c := Vector2i(g.W / 2, g.H / 2)
	var spot: Vector2 = g.cell_center(g.nearest_free(c, 10))
	# the bodies: Raptors and Musketeers in a heap at the spot, two more a little off it
	var heap := [["raptor", 1, Vector2(-14, -6)], ["raptor", 1, Vector2(12, 4)], ["raptor", 1, Vector2(-2, 14)],
		["musketeer", 0, Vector2(18, -14)], ["musketeer", 0, Vector2(-20, 12)], ["raptor", 1, Vector2(110, -10)], ["musketeer", 0, Vector2(-120, 20)]]
	for h in heap:
		var u: Unit = g._add_unit(h[0], h[1], spot + h[2])
		await process_frame
		u.take_damage(99999.0, null)
	# a Mortar and a Cannon of ours below it, and a few Musketeers to see the spot
	var mortar: Unit = g._add_unit("mortar", 0, spot + Vector2(-40, 250))
	var gun: Unit = g._add_unit("cannon", 0, spot + Vector2(60, 270))
	for i in 3:
		g._add_unit("musketeer", 0, spot + Vector2(-90 + i * 26, 190))
	g.camera.position = spot + Vector2(0, 120)
	g.camera.zoom = Vector2(1.35, 1.35)
	await create_timer(2.6).timeout
	await _shot("bodies_before.png")
	# the card: a Cannon selected, the BOMBARD button's tooltip open
	g.set_selection([gun])
	await create_timer(0.3).timeout
	g.hud._refresh_card()
	for bt in g.hud._card_buttons:
		if String(bt["item"][1]) == "ATTACK GROUND":
			g.hud._tip = g.hud._card_tip(bt["item"])
			g.hud._tip_at = (bt["rect"] as Rect2).get_center() + Vector2(-260, -150)
			g.hud._tip_ms = Time.get_ticks_msec() + 100000
	await create_timer(0.2).timeout
	await _shot("card.png")
	g.hud._tip = {}
	# Ctrl+A: picking the spot (the prompt; the Mortar's rings)
	g.set_selection([mortar, gun])
	root.get_viewport().warp_mouse(g.get_viewport().get_canvas_transform() * spot)     # (the mouse on the spot: the guns aim at it)
	var ev := InputEventKey.new()
	ev.keycode = KEY_A
	ev.ctrl_pressed = true
	ev.pressed = true
	g.controls._key(ev)
	await create_timer(0.3).timeout
	await _shot("mode.png")
	g.controls.cancel_mode()
	# the Mortar shells the heap
	g.set_selection([mortar])
	g.bombard_order([mortar], spot)
	var flying = null
	var t0 := Time.get_ticks_msec()
	while flying == null and Time.get_ticks_msec() - t0 < 15000:
		await process_frame
		for n in g.get_children():
			if n is Projectile:
				flying = n
	if flying:
		while is_instance_valid(flying) and (flying as Projectile).t < (flying as Projectile).duration * 0.55:
			await process_frame
		await _shot("shelling.png")
		while is_instance_valid(flying):
			await process_frame
		await create_timer(0.12).timeout
		await _shot("bodies_torn.png")
	mortar.cmd_stop()
	await create_timer(2.0).timeout
	await _shot("bodies_after.png")
	print("bodies blasted: ", g.bodies_blasted)
	quit()
