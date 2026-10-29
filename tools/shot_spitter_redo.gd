extends SceneTree
## Pictures for docs/spitter_redo.md (docs/shots/spitter_redo/): the new Spitter and Venom Challenger in game, in two
## team colours (two allied Brood sides, a row each), beside a Raptor, the Venom Sire and the Mist Toad (its own colours
## again, details in the team colour).
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1600x900 --fixed-fps 30 --script res://tools/shot_spitter_redo.gd -- <outdir> [c0:<n> c1:<n>]
## lineup.png / lineup_close.png   standing, facing south-east
## walk.png                        everyone walking east (then west, walk_west.png: the mirrored views)
## spit_<kk>.png                   the Spitters and the Challengers spitting at Crown labourers (kk = 00..15, 0.05 s apart)
## death_<k>.png                   the Spitters and the Challengers dying (k = 0..2)
var main: Node
var g
var out := ""
var t := 0.0
var started := false
var c0 := 1
var c1 := 0
const ROW := ["raptor", "spitter", "spitter", "venom_challenger", "dilophosaurus", "mist_toad"]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out = args[0]
	for a in args:
		if a.begins_with("c0:"):
			c0 = int(a.substr(3))
		elif a.begins_with("c1:"):
			c1 = int(a.substr(3))
	DirAccess.make_dir_recursive_absolute(out)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(delta: float) -> bool:
	t += delta
	if t > 0.2 and main.game == null:
		main.start({"map": "hollowfen", "seed": 7, "slots": [
			{"who": "you", "faction": "brood", "colour": c0, "side": 0},
			{"who": "easy", "faction": "brood", "colour": c1, "side": 0},
			{"who": "easy", "faction": "crown", "colour": 2 if not [c0, c1].has(2) else 3, "side": 1}]})
		return false
	if main.game == null:
		return false
	g = main.game
	if g.hud:
		g.hud.countdown = 0.0
	paused = false
	if not started and t > 0.6:
		started = true
		for ai in g.ais:
			ai.process_mode = Node.PROCESS_MODE_DISABLED
		_run()
	return false


func _snap(name: String, wait := 1.0) -> void:
	await create_timer(wait).timeout
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])


## The clear ground nearest the map's middle where 34 x 14 tiles are walkable on one level.
func _origin() -> Vector2i:
	var mid := Vector2i(Game.W / 2, Game.H / 2)
	var best := Vector2i(-1, -1)
	var bd := INF
	for y in range(1, Game.H - 15):
		for x in range(1, Game.W - 35):
			var c := Vector2i(x, y)
			var dd := Vector2(c - mid).length()
			if dd >= bd:
				continue
			var ok := true
			for yy in 14:
				for xx in 34:
					var cc := c + Vector2i(xx, yy)
					if not g._walkable(cc) or not g.is_free(cc) or g.ramp[g.idx(cc)] != 0 or g.height[g.idx(cc)] != g.height[g.idx(c)]:
						ok = false
						break
				if not ok:
					break
			if ok:
				bd = dd
				best = c
	return best


func _run() -> void:
	var o := _origin()
	print("origin ", o)
	var made := []
	var spitters := []
	for team in 2:
		for i in ROW.size():
			var p := Vector2((o.x + 3.0 + i * 5.0) * Defs.TILE, (o.y + 3.0 + team * 4.2) * Defs.TILE)
			var u: Unit = g._add_unit(ROW[i], team, p)
			u.facing = BroodNew.SE
			u.cmd_hold()
			made.append(u)
			if ROW[i] == "spitter" or ROW[i] == "venom_challenger":
				spitters.append(u)
	await create_timer(1.5).timeout
	for u in made:
		print("%s team %d venom_swap %s" % [u.kind, u.team, VetLook.venom(u)])
	g.camera.position = Vector2((o.x + 16.0) * Defs.TILE, (o.y + 6.0) * Defs.TILE)
	g.camera.zoom = Vector2(1.4, 1.4)
	if g.hud:
		g.hud.visible = false
	await _snap("lineup", 0.5)
	g.camera.position = Vector2((o.x + 14.0) * Defs.TILE, (o.y + 5.5) * Defs.TILE)
	g.camera.zoom = Vector2(2.4, 2.4)
	await _snap("lineup_close", 0.5)
	# walking east, then west
	for u in made:
		u.cmd_move(u.position + Vector2(5.0 * Defs.TILE, 0.0))
	await _snap("walk", 0.7)
	await create_timer(2.5).timeout
	for u in made:
		u.cmd_move(u.position - Vector2(5.0 * Defs.TILE, 0.0))
	await _snap("walk_west", 0.7)
	await create_timer(2.5).timeout
	# spitting at Crown labourers a little east of each (they cannot die: the film is of the spit)
	for u in made:
		u.cmd_hold()
	for u in spitters:
		var m: Unit = g._add_unit("labourer", 2, u.position + Vector2(4.0, 1.4) * Defs.TILE)
		m.max_hp = 99999.0
		m.hp = 99999.0
		m.cmd_hold()
		u.cmd_attack(m)
	g.camera.position = Vector2((o.x + 13.0) * Defs.TILE, (o.y + 6.0) * Defs.TILE)
	g.camera.zoom = Vector2(2.0, 2.0)
	for k in 16:
		await _snap("spit_%02d" % k, 0.05)
	await create_timer(0.5).timeout
	for u in spitters:
		u.take_damage(99999.0, null)
	await _snap("death_0", 0.15)
	await _snap("death_1", 0.3)
	await _snap("death_2", 1.0)
	quit()
