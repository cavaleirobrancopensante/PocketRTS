extends SceneTree
## The build-placement grid (BuildGrid): tile classes, one-tile gaps, and a ghost that would
## seal a one-tile corridor is flagged while one on open ground is not.
##   godot --headless --fixed-fps 30 --script res://tools/test_build_grid.gd
var fails := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	print("%s %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		fails += 1


func _run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.start({"map": "highmoor", "seed": 5, "slots": [
		{"who": "human", "faction": "crown", "colour": 0, "side": 0, "strategy": "balanced"},
		{"who": "hard", "faction": "crown", "colour": 1, "side": 1, "strategy": "balanced"}]})
	await process_frame
	await process_frame
	var g: Game = main.game
	# an arena far from anything: open ground 40x40 at (10,10); a wall row with a one-tile door
	var o := Vector2i(10, 10)
	for y in 40:
		for x in 40:
			g.solid[g.idx(o + Vector2i(x, y))] = 0
	for x in 40:
		g.solid[g.idx(o + Vector2i(x, 20))] = 1
		g.solid[g.idx(o + Vector2i(x, 21))] = 1
	g.solid[g.idx(o + Vector2i(20, 20))] = 0
	g.solid[g.idx(o + Vector2i(20, 21))] = 0      # the door: a two-tile-long, one-wide corridor
	g.solid[g.idx(o + Vector2i(5, 5))] = 2
	g.solid[g.idx(o + Vector2i(6, 5))] = 4
	g.solid[g.idx(o + Vector2i(7, 5))] = 5
	_check(BuildGrid.cell_class(g, o + Vector2i(1, 1)) == BuildGrid.FREE, "free tile")
	_check(BuildGrid.cell_class(g, o + Vector2i(0, 20)) == BuildGrid.TERRAIN, "terrain tile")
	_check(BuildGrid.cell_class(g, o + Vector2i(5, 5)) == BuildGrid.BUILDING, "building tile")
	_check(BuildGrid.cell_class(g, o + Vector2i(6, 5)) == BuildGrid.WALL, "wall tile")
	_check(BuildGrid.cell_class(g, o + Vector2i(7, 5)) == BuildGrid.FIELD, "farm field tile")
	_check(BuildGrid.cell_class(g, Vector2i(-3, 4)) == BuildGrid.TERRAIN, "off the map")
	var bg := BuildGrid.new()
	bg.update(g, "cottage", o + Vector2i(30, 8), 0.0, true)
	_check(not bg.sealed, "a cottage on open ground cuts nothing")
	_check(bg.narrowed == 0, "and narrows nothing")
	bg.update(g, "cottage", o + Vector2i(24, 14), 0.0, true)
	var wi := (o.y + 20 - bg.org.y) * bg.win.x + (o.x + 20 - bg.org.x)
	_check(bg.choke[wi] == 1, "the door is a one-tile gap")
	_check(bg.choke[wi - 1] == 0, "the wall beside it is not")
	# a cottage (size 2x2?) planted in the doorway side would close the door
	var size: Vector2i = Defs.BUILDINGS["cottage"]["size"]
	bg.update(g, "cottage", o + Vector2i(20 - (size.x - 1) / 2, 22), 0.0, true)
	_check(bg.sealed, "a cottage on the door's mouth cuts the route (%s)" % size)
	bg.update(g, "cottage", o + Vector2i(30, 23), 0.0, true)
	_check(not bg.sealed, "a cottage beside the door leaves the route")
	bg.update(g, "cottage", o + Vector2i(18, 23), 0.0, true)
	_check(bg.narrowed >= 0, "narrow count works")
	print("ALL PASS" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails > 0 else 0)
