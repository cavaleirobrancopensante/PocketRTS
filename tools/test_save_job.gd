extends SceneTree
## The autosave written in steps (SaveGame.begin / SaveJob.step, a hundred units a frame) gives the same text as the
## save written at once (SaveGame.save):
##   godot --headless --script res://tools/test_save_job.gd
## A Brood match with 350 more Raptors and a Crown match: both texts compared. Prints "save job: PASS" or FAIL.

var main: Node
var t := 0.0
var step := 0
var fails := 0


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(delta: float) -> bool:
	t += delta
	if step == 0 and t > 0.2:
		step = 1
		main.start({"map": "dune_sea", "seed": 4242, "slots": [
			{"who": "you", "faction": "brood", "colour": 0, "side": 0},
			{"who": "easy", "faction": "crown", "colour": 1, "side": 1}]})
		return false
	if step == 1 and t > 1.5 and main.game:
		step = 2
		var g: Game = main.game
		var hall: Building = g.halls_of(0, false)[0]
		for i in 350:
			g._add_unit("raptor", 0, hall.center() + Vector2(120 + (i % 20) * 16, -150 + (i / 20) * 16))
	if step >= 2 and step < 40:
		step += 1                # (a second of play: the units move about)
		return false
	if step == 40:
		_check(main.game)
		print("save job: %s" % ("PASS" if fails == 0 else "FAIL (%d)" % fails))
		quit(1 if fails > 0 else 0)
		return true
	return false


func _check(g: Game) -> void:
	# (the player's own autosave is put back afterwards)
	var keep := FileAccess.get_file_as_string(SaveGame.PATH) if FileAccess.file_exists(SaveGame.PATH) else ""
	_compare(g)
	if keep != "":
		SaveGame.write(keep)
	else:
		DirAccess.remove_absolute(SaveGame.PATH)


func _compare(g: Game) -> void:
	var cfg := {"map": "dune_sea"}
	var d := SaveGame.capture(g, cfg)
	var whole := JSON.stringify(d)
	var job: SaveGame.SaveJob = SaveGame.begin(g, cfg)
	var n := 0
	while not job.step():
		n += 1
	var f := FileAccess.open(SaveGame.PATH, FileAccess.READ)
	var stepped := f.get_as_text() if f else ""
	# (the save's time of day is in both: the same second unless the clock ticked over between them)
	var a := whole.substr(whole.find("\"saved_at\""), 40)
	var b := stepped.substr(stepped.find("\"saved_at\""), 40)
	stepped = stepped.replace(b, a)
	print("save job: %d units, %d steps, %d characters" % [(d["units"] as Array).size(), n + 1, whole.length()])
	if stepped != whole:
		fails += 1
		var i := 0
		while i < mini(whole.length(), stepped.length()) and whole[i] == stepped[i]:
			i += 1
		print("FAIL: the texts differ at %d: ...%s... vs ...%s..." % [i, whole.substr(maxi(0, i - 40), 80), stepped.substr(maxi(0, i - 40), 80)])
	if JSON.parse_string(stepped) == null:
		fails += 1
		print("FAIL: the stepped save isn't JSON")


