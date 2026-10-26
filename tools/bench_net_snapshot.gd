extends SceneTree
## What an online snapshot costs the host, part by part: two Hard computers play to `secs` game seconds, then
## NetSnapshot.build is timed (and its parts: the unit rows, the building rows, the Line, the packing) over `n` runs.
##   godot --headless --fixed-fps 30 --script res://tools/bench_net_snapshot.gd -- secs:420 n:50 map:hollowfen
var main: Node
var t := 0.0
var g: Game
var map := "hollowfen"
var secs := 420.0
var n := 50


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("map:"):
			map = a.substr(4)
		elif a.begins_with("secs:"):
			secs = float(a.substr(5))
		elif a.begins_with("n:"):
			n = int(a.substr(2))


func _process(delta: float) -> bool:
	t += delta
	if t > 0.2 and main.game == null:
		main.start({"map": map, "seed": 4242, "slots": [
			{"who": "hard", "faction": "crown", "colour": 0, "side": 0, "strategy": "balanced"},
			{"who": "hard", "faction": "brood", "colour": 1, "side": 1, "strategy": "balanced"}]})
		return false
	if main.game == null:
		return false
	g = main.game
	paused = false
	if g.clock >= secs or g.over:
		_bench()
		quit(0)
	return false


func _ms(t0: int) -> float:
	return (Time.get_ticks_usec() - t0) / 1000.0


func _bench() -> void:
	var s := NetSession.new()
	s.game = g
	var parts := {"build": 0.0, "pack": 0.0, "unit rows": 0.0, "building rows": 0.0, "line": 0.0, "players": 0.0}
	var bytes := 0
	var worst := 0.0
	for i in n:
		s.snap_n += 1
		var t0 := Time.get_ticks_usec()
		var m := NetSnapshot.build(s)
		var b := _ms(t0)
		parts["build"] += b
		worst = maxf(worst, b)
		t0 = Time.get_ticks_usec()
		var pk := NetCodec.pack(m)
		parts["pack"] += _ms(t0)
		bytes += pk.size()
		# the parts on their own
		t0 = Time.get_ticks_usec()
		for u in g.units:
			if is_instance_valid(u) and not u.dead:
				for p in NetSnapshot.UNIT_PROPS:
					NetSnapshot.q(u.get(p))
		parts["unit rows"] += _ms(t0)
		t0 = Time.get_ticks_usec()
		for bd in g.buildings:
			if is_instance_valid(bd):
				for p in NetSnapshot.BLD_PROPS:
					NetSnapshot.q(bd.get(p))
		parts["building rows"] += _ms(t0)
		t0 = Time.get_ticks_usec()
		g.line_net.fingerprint()
		parts["line"] += _ms(t0)
		t0 = Time.get_ticks_usec()
		for tm in g.n_players():
			g.players[tm].duplicate(true)
		parts["players"] += _ms(t0)
	# the packing on its own: var_to_bytes, then each compression
	var m2 := NetSnapshot.build(s)
	var t1 := Time.get_ticks_usec()
	var raw := PackedByteArray()
	for i in 20:
		raw = var_to_bytes(m2)
	print("BENCH var_to_bytes %.2f ms, %d bytes raw" % [_ms(t1) / 20.0, raw.size()])
	for mode in [["deflate", FileAccess.COMPRESSION_DEFLATE], ["zstd", FileAccess.COMPRESSION_ZSTD], ["fastlz", FileAccess.COMPRESSION_FASTLZ], ["gzip", FileAccess.COMPRESSION_GZIP]]:
		t1 = Time.get_ticks_usec()
		var z := PackedByteArray()
		for i in 20:
			z = raw.compress(mode[1])
		var c_ms := _ms(t1) / 20.0
		t1 = Time.get_ticks_usec()
		for i in 20:
			z.decompress(raw.size(), mode[1])
		print("BENCH %-8s compress %.2f ms, decompress %.2f ms, %d bytes" % [mode[0], c_ms, _ms(t1) / 20.0, z.size()])
	print("BENCH at %.0f s: %d units, %d buildings" % [g.clock, g.units.size(), g.buildings.size()])
	for k in parts:
		print("BENCH %-14s %.2f ms avg" % [k, parts[k] / n])
	print("BENCH build worst %.2f ms, packed %.0f bytes avg" % [worst, float(bytes) / n])
