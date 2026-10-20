extends SceneTree
## Scripted check of the new units: Missionary bandaging, Skywing flying, Tesla Cart.
var main
var out := "/tmp/claude-0/-home-claude/3bf5c283-94b1-59fe-b83b-7f9d81ecfc35/scratchpad/v7"
func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred()
func shot(n: String) -> void:
	await create_timer(0.05).timeout
	root.get_viewport().get_texture().get_image().save_png(out + "/" + n + ".png")
func _run() -> void:
	await process_frame
	main.start(1, true, ["crown", "clockwork"])
	var g = main.game
	for a in g.ais: a.queue_free()
	g.ais.clear()
	var base := Vector2(1300, 900)
	# a wounded musketeer and a missionary
	var m = g._add_unit("musketeer", 0, base)
	m.hp = 20
	var mi = g._add_unit("missionary", 0, base + Vector2(-60, 10))
	# skywings vs a pikeman (can't hit) and a musketeer (can)
	var sw = g._add_unit("skywing", 1, base + Vector2(200, -60))
	var pk = g._add_unit("pikeman", 0, base + Vector2(240, 0))
	# tesla cart near enemies
	var tc = g._add_unit("tesla_cart", 1, base + Vector2(120, 140))
	var foe = g._add_unit("pikeman", 0, base + Vector2(250, 160))
	g.camera.position = base + Vector2(100, 60)
	g.camera.zoom = Vector2(2.2, 2.2)
	var log := []
	for f in 40:
		await create_timer(0.2).timeout
		log.append("t%.1f mi:%s/%s pat_hidden=%s hp=%d cross=%.1f | sky:%s target=%s pk_target=%s | tesla:%s foe_hp=%d" % [f * 0.2, mi.order, mi.work, m.off_field, m.hp, m.cross_t, sw.order, sw.target.kind if sw.target else "-", pk.target.kind if pk.target else "-", tc.tesla_mode, foe.hp])
		if f in [3, 12, 25, 34]:
			await shot("units%02d" % f)
	for l in log:
		print(l)
	quit()
