extends SceneTree
## Screenshots of the Clockwork gear field: the Clocktower with its turning ring, a linked Cog Press, an unlinked building,
## the placement ghost (links / no link / clash) and the command card with the GEAR SWAP button.
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --script res://tools/shot_gear.gd -- <outdir>
## Writes <outdir>/gear_tower_a.png, gear_tower_b.png (half a second apart), gear_press.png, gear_unlinked.png, gear_ghost_ok.png,
## gear_ghost_far.png, gear_ghost_clash.png, gear_card.png, gear_swap.png, gear_base.png
const U := preload("res://tools/gear_test_util.gd")
var main: Node
var g
var out := ""
var t := 0.0
var started := false


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	out = a[0]
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(delta: float) -> bool:
	t += delta
	if t > 0.2 and main.game == null:
		main.start({"map": "ashford_crossing", "seed": 4242, "slots": [
			{"who": "you", "faction": "clockwork", "colour": 0, "side": 0},
			{"who": "easy", "faction": "crown", "colour": 1, "side": 1}]})
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
		for ai in g.ais:
			ai.process_mode = Node.PROCESS_MODE_DISABLED
		_run()
	return false


func _snap(name: String, wait := 0.5) -> void:
	await create_timer(wait).timeout
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])


func _run() -> void:
	g.reveal = true
	g.players[0]["gold"] = 5000
	var tower: Building = U.hall(g, 0)
	var press: Building = null
	for b in g.buildings:
		if b.team == 0 and b.kind == Defs.GEAR_PRESS:
			press = b
	# a small base: an Assembly Works and a Boiler meshing with the Clocktower's ring, a big-gear press
	var asm := U.put(g, 0, "assembly_works", tower.cell)
	var boiler := U.put(g, 0, "boiler", tower.cell)
	var spring := U.put(g, 0, "spring_tower", tower.cell)
	var press2 := U.put(g, 0, Defs.GEAR_PRESS, tower.cell, true)
	var lone: Building = U.put_far(g, 0, "capacitor_works", 14)
	g.camera.zoom = Vector2(1.5, 1.5)
	g.camera.position = tower.center() + Vector2(10, 20)
	await _snap("gear_tower_a", 0.8)
	await _snap("gear_tower_b", 0.5)
	g.camera.zoom = Vector2(2.2, 2.2)
	if press:
		g.camera.position = press.center()
	await _snap("gear_press")
	if lone:
		g.camera.position = lone.center()
		await _snap("gear_unlinked")
	# the ghost: a spot that links, one that does not, one that clashes
	g.camera.zoom = Vector2(1.5, 1.5)
	g.camera.position = tower.center() + Vector2(0, 20)
	g.controls.mode = "place"
	g.controls.place_kind = "engine_hall"
	var ok_c := U.linked_spot(g, 0, "engine_hall", tower.cell)
	if ok_c.x >= 0:
		g.controls.ghost_cell = ok_c
		await _snap("gear_ghost_ok")
	g.controls.ghost_cell = tower.cell + Vector2i(30, 12)
	await _snap("gear_ghost_far")
	g.controls.ghost_cell = tower.cell + Vector2i(-1, 5)
	await _snap("gear_ghost_clash")
	g.controls.mode = ""
	# the command card of the big-gear press, and a swap under way
	g.camera.zoom = Vector2(1.5, 1.5)
	if press2:
		g.camera.position = press2.center()
		g.set_selection([press2])
		await _snap("gear_card")
		g.swap_gear(press2)
		await _snap("gear_swap", 1.5)
	g.set_selection([])
	g.camera.zoom = Vector2(0.9, 0.9)
	g.camera.position = tower.center() + Vector2(20, 40)
	await _snap("gear_base", 4.0)
	quit(0)
