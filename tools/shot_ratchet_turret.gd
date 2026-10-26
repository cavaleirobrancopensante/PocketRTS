extends SceneTree
## Screenshots of the RATCHET TURRET (scripts/ratchet_turret.gd) in the CLOCKWORK LAB: the Lab's start (no Charging Pylon,
## no energy pill), the turret firing at a ground enemy and at a flyer (the screw in flight), and the head's 8 facings.
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --script res://tools/shot_ratchet_turret.gd -- <outdir>
## Writes <outdir>/lab_start.png, turret_close.png, fire_ground.png, fire_air.png, hit_air.png, facing_0..7.png (0 = east,
## clockwise) and turret_built/construction/damaged/destroyed.png.
var main: Node
var g
var out := ""
var t := 0.0
var started := false


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
	g = main.game
	if g.hud:
		g.hud.countdown = 0.0
		g.hud.visible = true
	paused = false
	if not started and t > 1.0:
		started = true
		_run()
	return false


func _snap(name: String, wait := 0.5) -> void:
	if wait > 0.0:
		await create_timer(wait).timeout
	await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])


func _find(kind: String) -> Building:
	for b in g.buildings:
		if b.team == g.human and b.kind == kind and not b.dead:
			return b
	return null


## An enemy of `kind` at p that does not die (a target to shoot at).
func _dummy(kind: String, p: Vector2) -> Unit:
	var u: Unit = g._add_unit(kind, 1, p)
	u.max_hp = 99999.0
	u.hp = 99999.0
	u.cmd_hold()
	u.set_physics_process(false)      # (a still target: it neither walks nor fights)
	return u


## Wait for the turret's next screw, then snap while it flies.
func _snap_shot(tur: Building, name: String, after := 0.12) -> void:
	var n: int = tur.turret.shots
	var waited := 0.0
	while tur.turret.shots == n and waited < 6.0:
		await process_frame
		waited += 1.0 / 60.0
	await create_timer(after).timeout
	await _snap(name, 0.0)


func _run() -> void:
	var tur := _find(Defs.CW_TURRET)
	await _snap("lab_start", 2.5)
	if tur == null:
		print("NO TURRET")
		quit(1)
		return
	g.reveal = true
	var ui := root.find_children("*", "CanvasLayer", true, false)
	for c in ui:
		c.visible = false
	g.camera.position = tur.center() + Vector2(40, -10)
	g.camera.zoom = Vector2(2.2, 2.2)
	await _snap("turret_close", 0.6)
	# a ground enemy in range (slow motion: under xvfb a frame takes long, and the screw would be gone)
	Engine.time_scale = 0.12
	var foot := _dummy("labourer", tur.center() + Vector2(150, 50))
	g.camera.position = tur.center() + Vector2(70, 0)
	await _snap_shot(tur, "fire_ground_muzzle", 0.0)
	await _snap_shot(tur, "fire_ground", 0.05)
	await _snap_shot(tur, "fire_ground2", 0.14)
	foot.die()
	# a flyer in range
	var fly := _dummy("balloon", tur.center() + Vector2(-120, -110))
	g.camera.position = tur.center() + Vector2(-50, -50)
	await _snap_shot(tur, "fire_air", 0.07)
	await _snap_shot(tur, "hit_air", 0.3)
	fly.die()
	Engine.time_scale = 1.0
	await create_timer(1.0).timeout
	# the 8 facings (idle: it keeps the one it is given)
	g.camera.position = tur.center() + Vector2(0, -20)
	g.camera.zoom = Vector2(3.0, 3.0)
	for i in 8:
		tur.turret.facing = i
		tur.turret._show()
		await _snap("facing_%d" % i, 0.15)
	# the base's states
	tur.turret.facing = 2
	tur.turret._show()
	await _snap("turret_built", 0.2)
	tur.hp = tur.max_hp * 0.3
	tur._update_sprite()
	await _snap("turret_damaged", 0.2)
	tur.die()
	await _snap("turret_destroyed", 0.4)
	quit(0)
