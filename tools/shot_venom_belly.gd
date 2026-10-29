extends SceneTree
## Pictures for docs/venom_belly.md (docs/shots/venom_belly/): the venom line's belly and flank stripe in game, in two
## team colours, beside a Raptor (the rest of the Brood: crests in the team colour) for comparison.
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1600x900 --fixed-fps 30 --script res://tools/shot_venom_belly.gd -- <outdir> [c0:<n> c1:<n> name:<prefix>]
## Two allied Brood sides (Defs.PALETTE colours c0 and c1, default Red and Blue), a row each: Raptor, Spitter, Venom
## Challenger, Venom Sire, then a veteran Spitter (25 kills) and an elite one (50).
## <prefix>.png             all of them, facing south-east
## <prefix>_<dir>.png       closer, facing se, e, w, s, n
var main: Node
var g
var out := ""
var t := 0.0
var started := false
var c0 := 1
var c1 := 0
var prefix := "venom"
const ROW := ["raptor", "spitter", "venom_challenger", "dilophosaurus", "spitter", "spitter"]
const KILLS := [0, 0, 0, 0, 25, 50]
const FACES := {"se": Vector2(0.7071, 0.7071), "e": Vector2(1, 0), "w": Vector2(-1, 0), "s": Vector2(0, 1), "n": Vector2(0, -1)}


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out = args[0]
	for a in args:
		if a.begins_with("c0:"):
			c0 = int(a.substr(3))
		elif a.begins_with("c1:"):
			c1 = int(a.substr(3))
		elif a.begins_with("name:"):
			prefix = a.substr(5)
	DirAccess.make_dir_recursive_absolute(out)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(delta: float) -> bool:
	t += delta
	if t > 0.2 and main.game == null:
		# (allied: the two rows stand side by side without a fight)
		var third := 2
		while [c0, c1].has(third):
			third += 1
		main.start({"map": "hollowfen", "seed": 7, "slots": [
			{"who": "you", "faction": "brood", "colour": c0, "side": 0},
			{"who": "easy", "faction": "brood", "colour": c1, "side": 0},
			{"who": "easy", "faction": "crown", "colour": third, "side": 1}]})
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


## The clear ground nearest the map's middle where 24 x 10 tiles are walkable on one level.
func _origin() -> Vector2i:
	var mid := Vector2i(Game.W / 2, Game.H / 2)
	var best := Vector2i(-1, -1)
	var bd := INF
	for y in range(1, Game.H - 11):
		for x in range(1, Game.W - 25):
			var c := Vector2i(x, y)
			var dd := Vector2(c - mid).length()
			if dd >= bd:
				continue
			var ok := true
			for yy in 10:
				for xx in 24:
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
	for team in 2:
		for i in ROW.size():
			var p := Vector2((o.x + 2.0 + i * 3.3) * Defs.TILE, (o.y + 3.0 + team * 4.4) * Defs.TILE)
			var u: Unit = g._add_unit(ROW[i], team, p)
			u.facing = FACES["se"]
			if KILLS[i] > 0:
				u.kills = KILLS[i]
				VetLook.apply(u)
			u.cmd_hold()
			made.append(u)
	await create_timer(1.5).timeout
	for u in made:
		print("%s team %d venom_swap %s mask %s" % [u.kind, u.team, VetLook.venom(u),
			(u.sprite.material as ShaderMaterial).get_shader_parameter("venom_mask") != null])
	if g.hud:
		g.hud.visible = false
	g.camera.position = Vector2((o.x + 10.25) * Defs.TILE, (o.y + 4.3) * Defs.TILE)
	g.camera.zoom = Vector2(1.6, 1.6)
	await _snap(prefix, 0.5)
	g.camera.position = Vector2((o.x + 10.25) * Defs.TILE, (o.y + 4.3) * Defs.TILE)
	g.camera.zoom = Vector2(2.2, 2.2)
	for d in FACES:
		for u in made:
			u.facing = FACES[d]
		await _snap(prefix + "_" + d, 0.6)
	quit()
