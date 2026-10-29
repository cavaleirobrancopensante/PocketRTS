extends SceneTree
## Every Brood unit has its voice files and its death sound, and each file is in the gain table.
## godot --headless --fixed-fps 30 --script res://tools/test_brood_voices.gd
const NEED := {
	"grub": ["select", "move"], "spitter": ["select", "move", "attack"], "brute": ["select", "move", "attack"],
	"mist_toad": ["select", "move"], "raptor": ["select", "move", "attack"], "skywing": ["select", "move", "attack"]}
const DEATH := ["grub", "spitter", "mist_toad", "skywing", "brute", "raptor"]

func _init() -> void:
	var fails := 0
	for u in NEED:
		for what in NEED[u]:
			for i in range(1, 4 if what != "attack" else 3):
				var p := "res://assets/voice/%s/%s_%d.wav" % [u, what, i]
				if not ResourceLoader.exists(p):
					print("FAIL missing ", p); fails += 1
				elif not SoundMix.GAIN.has(p):
					print("FAIL no gain entry ", p); fails += 1
	for u in DEATH:
		var p := "res://assets/audio/combat/%s_death_1.wav" % u
		if not ResourceLoader.exists(p):
			print("FAIL missing ", p); fails += 1
		elif not SoundMix.GAIN.has(p):
			print("FAIL no gain entry ", p); fails += 1
	# every Brood unit def that can be selected has a voice list (the Brood's own creatures since 0.15, the Mother, the
	# rooters, the Sires, the Challengers, eggs and piles, have none yet: docs/brood_new.md)
	for k in Defs.UNITS:
		var bd: Dictionary = Defs.UNITS[k]
		if String(bd.get("faction", "")) == "brood" and not NEED.has(k) and not bd.get("new_brood", false) and not bd.get("mature", false):
			print("FAIL Brood unit without voice check: ", k); fails += 1
	# every gain-table path for the Brood voices exists
	for p in SoundMix.GAIN:
		if (p.contains("/voice/grub/") or p.contains("/voice/brute/") or p.contains("/voice/spitter/")) and not ResourceLoader.exists(p):
			print("FAIL gain entry without file ", p); fails += 1
	print("PASS" if fails == 0 else "FAIL %d" % fails)
	print("DONE")
	quit(1 if fails else 0)
