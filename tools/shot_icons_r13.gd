extends SceneTree
## Screenshots of the round 13 icons on real command cards (tools/import_round13.py):
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --script res://tools/shot_icons_r13.gd -- <crown|brood|clockwork> <outdir>
## Writes <faction>_<n>.png: the whole screen with one selection each (the card at the bottom right, the top bar's pills).
var main
var out := "/tmp/shots_icons"
var fac := "clockwork"

const PICKS := {
	"clockwork": [["clock_soldier", "springer", "cuckoo"], ["springer"], ["cuckoo"], ["winder"], ["winder", "build"], ["@cog_press"]],
	"brood": [["skywing"], ["mist_toad"], ["grub"], ["grub", "build"], ["brood_mother"], ["raptor", "spitter"]],
	"crown": [["cannon"], ["balloon"], ["mortar"], ["powder_wagon"], ["labourer", "build"], ["musketeer", "cannon", "mortar", "balloon", "powder_wagon", "horseman"]],
}


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		fac = a[0]
	if a.size() > 1:
		out = a[1]
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
	var foe := "brood" if fac == "crown" else "crown"
	main.start({"map": "hollowfen", "seed": 4242, "slots": [
		{"who": "you", "faction": fac, "colour": 0, "side": 0, "strategy": "balanced"},
		{"who": "easy", "faction": foe, "colour": 1, "side": 1, "strategy": "balanced"}]})
	await process_frame
	await process_frame
	var g: Game = main.game
	g.hud.countdown = 0.0
	paused = false
	for ai in g.ais:
		ai.process_mode = Node.PROCESS_MODE_DISABLED
	g.explored.fill(1)
	g.players[g.human]["gold"] = 2000
	g.players[g.human]["tension"] = 150.0
	var hall: Building = g.buildings.filter(func(b): return b.team == g.human and b.kind == g.faction_hall(g.human))[0]
	var at: Vector2 = hall.center() + Vector2(0, 150)
	g.camera.position = at
	await create_timer(1.0).timeout
	var n := 0
	for pick in PICKS[fac]:
		n += 1
		var sel: Array = []
		var build_page := false
		for k in pick:
			if k == "build":
				build_page = true
				continue
			if String(k).begins_with("@"):
				var kind := String(k).substr(1)
				var bs: Array = g.buildings.filter(func(b): return b.team == g.human and b.kind == kind)
				if bs.is_empty():
					var b: Building = g._add_building(kind, g.human, g.nearest_free(Vector2i(g.W / 2, g.H / 2), 10), true)
					if b:
						bs = [b]
				sel.append_array(bs.slice(0, 1))
				continue
			var u: Unit = g._add_unit(k, g.human, at + Vector2(-200 + 70 * n + randf_range(-20, 20), randf_range(-30, 30)))
			sel.append(u)
		await create_timer(0.4).timeout
		if sel.is_empty():
			continue
		g.set_selection(sel)
		g.hud.page = "build" if build_page else ""
		await create_timer(0.3).timeout
		g.hud._refresh_card()
		await create_timer(0.2).timeout
		await _shot("%s_%d.png" % [fac, n])
		g.set_selection([])
		await create_timer(0.2).timeout
	quit()
