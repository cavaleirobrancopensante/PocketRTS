extends SceneTree
## REPLAYS: the players' names stored in English in a replay show in the language in use (0.14.54).
##   godot --headless --script res://tools/test_replay_names_local.gd
var fails := 0


func check(ok: bool, what: String) -> void:
	print(("ok    " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	var was := Loc.lang
	Loc.set_lang("es")
	var a := ReplaysMenu._local_name("P1 Crown (you)")
	check(a == "P1 Corona (tú)", "es you: %s" % a)
	var b := ReplaysMenu._local_name("P2 Brood (easy AI)")
	check(b == "P2 Nidada (IA fácil)", "es easy AI: %s" % b)
	Loc.set_lang("pt")
	var c := ReplaysMenu._local_name("P3 Clockwork (hard AI)")
	check(c == "P3 Mecanismo (IA difícil)", "pt hard AI: %s" % c)
	Loc.set_lang("en")
	var d := ReplaysMenu._local_name("P1 Crown (you)")
	check(d == "P1 Crown (you)", "en unchanged: %s" % d)
	var e := ReplaysMenu._local_name("P2 Brood (easy AI)")
	check(e == "P2 Brood (easy AI)", "en AI unchanged: %s" % e)
	Loc.set_lang(was)
	print("FAILS: %d" % fails)
	quit(1 if fails > 0 else 0)
