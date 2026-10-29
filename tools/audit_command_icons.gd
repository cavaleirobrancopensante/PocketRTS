extends SceneTree
## The command-card icon audit (docs/command_icons_audit.md): plays each faction in turn, selects every unit and building it
## has (and its workers' build pages, the placing and unloading cards), builds the command card the HUD would show and
## prints, for every button, the icon it asks for and where that picture really comes from, the way Hud._icon finds it:
##   assets/icons/<faction>/<name>.png (Brood, Clockwork), else assets/icons/<name>.png, else the TEMP_ART stand-in
##   (Defs.icon_for), else a picture drawn in code (CwArt.icon), else nothing.
##   godot --headless --fixed-fps 30 --script res://tools/audit_command_icons.gd -- <crown|brood|clockwork> [outdir]
## Lines: "ICON <faction> | <where> | <label> | <icon name> | <source>". With an outdir, the code-drawn pictures are saved
## there (code_<name>.png) for the contact sheets.
var main: Node
var t := 0.0
var step := 0
var fac := "crown"
var out_dir := ""
var seen := {}


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		fac = args[0]
	if args.size() > 1:
		out_dir = args[1]
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(delta: float) -> bool:
	t += delta
	if step == 0 and t > 0.2:
		step = 1
		_start(fac)
		return false
	var g: Game = main.game
	if step == 1 and g != null and t > 1.2:
		step = 2
		if g.hud:
			g.hud.countdown = 0.0
		for ai in g.ais:
			ai.process_mode = Node.PROCESS_MODE_DISABLED
		_sweep(g, fac)
	return false


func _start(f: String) -> void:
	var foe := "brood" if f == "crown" else "crown"
	main.start({"map": "hollowfen", "seed": 4242, "slots": [
		{"who": "you", "faction": f, "colour": 0, "side": 0},
		{"who": "easy", "faction": foe, "colour": 1, "side": 1}]})


func _src(f: String, name: String) -> String:
	if f != "crown" and ResourceLoader.exists("res://assets/icons/%s/%s.png" % [f, name]):
		return "icons/%s/%s.png" % [f, name]
	if ResourceLoader.exists("res://assets/icons/%s.png" % name):
		return "icons/%s.png" % name
	var alt := Defs.icon_for(name)
	if alt != name:
		if f != "crown" and ResourceLoader.exists("res://assets/icons/%s/%s.png" % [f, alt]):
			return "temp:icons/%s/%s.png" % [f, alt]
		if ResourceLoader.exists("res://assets/icons/%s.png" % alt):
			return "temp:icons/%s.png" % alt
	var tex := CwArt.icon(name)
	if tex != null:
		if out_dir != "":
			tex.get_image().save_png(out_dir.path_join("code_%s.png" % name))
		return "code:CwArt.icon"
	return "MISSING"


func _card(g: Game, f: String, where: String) -> void:
	g.hud._card_items = []
	var items: Array = g.hud._build_card()
	for it in items:
		var lab := String(it[1]).trim_prefix("> ").trim_prefix("~ ")
		var key := "%s|%s|%s" % [f, lab, String(it[0])]
		var line := "ICON %s | %s | %s | %s | %s" % [f, where, lab, String(it[0]), _src(f, String(it[0]))]
		if not seen.has(key):
			seen[key] = true
			print(line)


func _sweep(g: Game, f: String) -> void:
	g.explored.fill(1)
	g.players[0]["gold"] = 99999
	g.players[0]["res2"] = 99999.0
	g.players[0]["tension"] = 9999.0
	var c := Vector2i(g.W / 2, g.H / 2)
	var at: Vector2 = g.cell_center(g.nearest_free(c, 10))
	# ---- units: each alone, as it comes and in its other states
	var kinds: Array = []
	for k in Defs.UNITS:
		var d: Dictionary = Defs.UNITS[k]
		if String(d.get("faction", "")) != fac or Defs.energy_only(k) or (Defs.CW_KINDS.has(k) and not Defs.cw_roster):
			continue
		kinds.append(k)
	for pass_i in 2:
		if pass_i == 1:
			for rk in Defs.RESEARCH:
				g.players[0]["tech"][rk] = true      # (the refit buttons, armoured trains)
		for k in kinds:
			var u: Unit = g._add_unit(k, 0, at)
			await physics_frame
			g.set_selection([u])
			_card(g, fac, "unit %s" % k)
			# other states: set up, canister, hold fire, landed, braced, a horse led / ridden
			if u.deploys():
				u.tesla_mode = "deployed" if u.tesla_mode == "packed" else "packed"
				_card(g, fac, "unit %s (other mode)" % k)
			if k == "cannon":
				u.mode = "canister"
				_card(g, fac, "unit cannon (canister)")
			if u.has_gun():
				u.hold_fire = not u.hold_fire
				_card(g, fac, "unit %s (hold fire)" % k)
			if k == "skywing":
				u.sky = "ground"
				_card(g, fac, "unit skywing (landed)")
			if u.can_lead():
				var h: Unit = g._add_unit("horse", 0, at + Vector2(20, 0))
				await physics_frame
				u.take_reins(h)
				_card(g, fac, "unit %s (leading a horse)" % k)
				g.consume_unit(h)
			g.consume_unit(u)
			await physics_frame
	# a worker's build pages (every building) and a mixed army + worker selection
	var w: Unit = g._add_unit(String(Defs.FACTIONS[fac]["worker"]), 0, at)
	await physics_frame
	g.set_selection([w])
	for pg in ["build", "advanced"]:
		g.hud.page = pg
		for bp in 3:
			g.hud.build_page = bp
			_card(g, fac, "worker build page %d" % bp)
	g.hud.page = ""
	# ---- buildings: each finished one alone (no research yet: its research buttons), then with everything researched
	for pass_i in 2:
		for rk in Defs.RESEARCH:
			if pass_i == 0:
				g.players[0]["tech"].erase(rk)
			else:
				g.players[0]["tech"][rk] = true
		for k in Defs.build_list(fac):
			var cell := g.nearest_free(c + Vector2i(6, 6), 14)
			var b: Building = g._add_building(k, 0, cell, true)
			await physics_frame
			g.set_selection([b])
			_card(g, fac, "building %s" % k)
			if k == "gate":
				b.locked = true
				_card(g, fac, "building gate (locked)")
			# a train in its queue (CANCEL) and the unfinished site (ABANDON)
			var tr: Array = b.d.get("trains", [])
			if not tr.is_empty():
				g.train(b, String(tr[0]))
				_card(g, fac, "building %s (training)" % k)
			b.take_damage(999999.0, null)
			await physics_frame
		var site: Building = g._add_building(String(Defs.build_list(fac)[1]), 0, g.nearest_free(c + Vector2i(-8, 6), 14), false)
		await physics_frame
		g.set_selection([site])
		_card(g, fac, "building site")
	# placing a building (a gate for the Crown: ROTATE), and a balloon unloading
	g.set_selection([w])
	g.controls.begin_place("gate" if fac == "crown" else String(Defs.build_list(fac)[1]))
	_card(g, fac, "placing a building")
	g.controls.cancel_mode()
	g.controls.mode = "unload"
	_card(g, fac, "a targeted order (unload / cast) waiting")
	g.controls.cancel_mode()
	print("AUDIT DONE %s" % fac)
	quit(0)
