extends SceneTree
## Pictures of the STATS ROW on the unit card (scripts/ui/unit_stats.gd, docs/unit_stats.md; docs/shots/unit_stats/):
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1600x900 --fixed-fps 30 --script res://tools/shot_unit_stats.gd -- <outdir> pc
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 915x412 --fixed-fps 30 --script res://tools/shot_unit_stats.gd -- <outdir> mobile
## pc: <kind>.png for a Musketeer, a Cuirassier, a Raptor, a Brute, a Clock Soldier, a Pendulum, an uprooted and a rooted
## Tyrannosaur, the Brood Mother; tooltip_*.png with a chip's tooltip open; group.png a mixed group
## mobile: phone_<kind>.png, phone_tooltip.png (the phone at 915 x 412, held sideways)
var main: Node
var g
var out := ""
var dev := "pc"
var t := 0.0
var started := false


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	out = a[0]
	dev = a[1] if a.size() > 1 else "pc"
	DirAccess.make_dir_recursive_absolute(out)
	Settings.load_all()
	Settings.device = dev
	Settings.tooltips = true
	Settings.ui_size = int(a[2]) if a.size() > 2 else 0      # (0: the device's own interface size; a phone's is x1.5)
	Settings.apply()
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(delta: float) -> bool:
	t += delta
	if t > 0.2 and main.game == null:
		main.start({"map": "greenhold", "seed": 3, "slots": [
			{"who": "you", "faction": Defs.BROOD_NEW, "colour": 0, "side": 0},
			{"who": "easy", "faction": "crown", "colour": 1, "side": 1}]})
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


func _snap(name: String, wait := 0.5) -> void:
	await create_timer(wait).timeout
	var pre := "phone_" if dev != "pc" else ""
	root.get_viewport().get_texture().get_image().save_png("%s/%s%s.png" % [out, pre, name])


func show(u: Unit, name: String) -> void:
	g.set_selection([u])
	g.camera.position = u.position + Vector2(0, 40)
	g.camera.zoom = Vector2(1.4, 1.4)
	await _snap(name)


## The tooltip of the chip with this icon (or the specials' with "specials"), opened as a tap / hover would.
func tip(icon: String, name: String) -> void:
	await create_timer(0.2).timeout
	for sr in g.hud._stat_rects:
		var c: Dictionary = sr[1]
		if c.get("icon", "") == icon or (icon == "specials" and c.has("specials")):
			g.hud._tip = UnitStats.tip(c)
			g.hud._tip_at = (sr[0] as Rect2).get_center()
			g.hud._tip_ms = Time.get_ticks_msec() + 100000
			g.hud._hover_id = "stat"
			break
	await _snap(name, 0.3)
	g.hud._tip = {}


func _run() -> void:
	await create_timer(0.5).timeout
	var home: Vector2 = g.units[0].position
	var at := home + Vector2(320, 120)
	var mk := func(k: String, team: int) -> Unit:
		var u: Unit = g._add_unit(k, team, at)
		return u
	var m: Unit = mk.call("musketeer", 0)
	m.kills = 12
	m.lock = "flintlock"
	await show(m, "musketeer")
	await tip("ranged", "tooltip_attack")
	await tip("attack_speed", "tooltip_reload")
	await tip("specials", "tooltip_specials")
	g.consume_unit(m)
	var c: Unit = mk.call("cuirassier", 0)
	c.put_on_armour()
	await show(c, "cuirassier")
	g.consume_unit(c)
	for k in ["raptor", "brute", "clock_soldier", "pendulum"]:
		var u: Unit = mk.call(k, 0)
		await show(u, k)
		if k == "pendulum":
			await tip("vs_armoured", "tooltip_bonus")
		g.consume_unit(u)
	var ty: Unit = mk.call("tyrannosaur", 0)
	ty.tesla_mode = "packed"
	await show(ty, "tyrannosaur_uprooted")
	ty.tesla_mode = "deployed"
	await show(ty, "tyrannosaur_rooted")
	await tip("no_attack", "tooltip_rooted")
	g.consume_unit(ty)
	var q: Unit = null
	for u in g.units:
		if u.kind == BroodNew.QUEEN and u.team == 0:
			q = u
	if q:
		await show(q, "brood_mother")
	# a mixed group: the first one's stats
	var grp: Array = []
	for i in 6:
		grp.append(mk.call("raptor" if i < 4 else "brute", 0))
	g.set_selection(grp)
	g.camera.position = at
	await _snap("group")
	quit()
