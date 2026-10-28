extends "res://tools/shot_aoe_show.gd"
## Pictures of the BLACK POWDER SMOKE (docs/powder_smoke.md): two lines of Musketeers (and a Field Cannon) trading
## fire for 20 s, then the enemy line gone and the haze clearing, with a GIF of it all:
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1600x900 --fixed-fps 30 --script res://tools/shot_powder_smoke.gd -- <outdir> [light|thick]
## (<outdir>/gif/ gets the GIF's frames; tools/powder_smoke_gif.py makes the GIF from them)
## The men do no damage (they fire all the while) and are a little hurt (their health bars show).

var lv := 2


func _initialize() -> void:
	if "light" in OS.get_cmdline_user_args():
		lv = 1
	if "thick" in OS.get_cmdline_user_args():
		lv = PowderSmoke.THICK
	PowderSmoke.force = lv
	super._initialize()


func _process(delta: float) -> bool:
	t += delta
	if t > 0.2 and main.game == null:
		main.start({"map": "hollowfen", "seed": 4242, "slots": [
			{"who": "you", "faction": "crown", "colour": 0, "side": 0},
			{"who": "easy", "faction": "crown", "colour": 1, "side": 1}]})
		return false
	if main.game == null:
		return false
	g = main.game
	if g.hud:
		g.hud.countdown = 0.0
	paused = false
	if not started and t > 1.0:
		started = true
		for ai in g.ais:
			ai.process_mode = Node.PROCESS_MODE_DISABLED
		_run()
	return false


func _shooter(kind: String, team: int, p: Vector2, face: Vector2) -> Unit:
	var u: Unit = g._add_unit(kind, team, p)
	u.max_hp = 99999.0
	u.hp = 99999.0 * randf_range(0.55, 0.9)
	u.auto_work = false
	u.d = u.d.duplicate()
	u.d["damage"] = 0
	u.facing = face
	u.cmd_stop()
	return u


var _gif_i := 0
var _gif_t := 0.0


func _film(secs: float) -> void:
	var e := 0.0
	while e < secs:
		await process_frame
		e += 1.0 / 30.0
		_gif_t += 1.0 / 30.0
		if _gif_t >= 0.5:
			_gif_t = 0.0
			var img: Image = root.get_viewport().get_texture().get_image()
			img = img.get_region(_mid(1200, 680))
			img.resize(720, 408, Image.INTERPOLATE_BILINEAR)
			img.save_png("%s/gif/f%03d.png" % [out, _gif_i])
			_gif_i += 1


func _run() -> void:
	var hall: Building = null
	for b in g.buildings:
		if b.team == g.human and not b.dead and b.kind == "town_hall":
			hall = b
	_ui(false)
	var open := _open_ground(hall)
	for u in g.units.filter(func(u: Unit) -> bool: return not u.dead):
		u.position = hall.center() + Vector2(0, 60)
	var mine: Array = []
	var theirs: Array = []
	for i in 14:
		mine.append(_shooter("musketeer", 0, open + Vector2(-150 + (i % 2) * 14, -200 + i * 30), Vector2.RIGHT))
		theirs.append(_shooter("musketeer", 1, open + Vector2(150 - (i % 2) * 14, -200 + i * 30), Vector2.LEFT))
	var gun := _shooter("cannon", 0, open + Vector2(-230, 10), Vector2.RIGHT)
	g.camera.position = open
	g.camera.zoom = Vector2.ONE
	for f in 30:
		await process_frame
	await _snap("0_before")
	for u in mine + [gun]:
		u.cmd_attack(theirs[mine.find(u) % theirs.size()] if u in mine else theirs[7])
	for u in theirs:
		u.cmd_attack(mine[theirs.find(u)])
	await _film(5.0)
	await _snap("1_fire_5s")
	await _film(5.0)
	await _snap("2_fire_10s")
	await _film(10.0)
	await _snap("3_fire_20s")
	# health bars and selection rings over the haze
	for u in mine:
		u.selected = true
		g.selection.append(u)
	await process_frame
	await process_frame
	await _snap("4_fire_20s_selected")
	_ui(true)
	await process_frame
	await process_frame
	await _snap("5_fire_20s_hud")
	_ui(false)
	g.selection.clear()
	for u in mine:
		u.selected = false
	# the enemy line is gone: the haze clears
	for u in theirs:
		_gone(u)
	for u in mine + [gun]:
		u.cmd_stop()
	await _film(5.0)
	await _snap("6_after_5s")
	await _film(5.0)
	await _snap("7_after_10s")
	await _film(10.0)
	await _snap("8_after_20s")
	print("puffs made %d, alive %d" % [g.powder_smoke.made, g.powder_smoke.alive])
	quit(0)
