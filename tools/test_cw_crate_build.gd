extends SceneTree
## Every Clockwork building goes up out of the Winder's crate (owner, 0.14.82: "a lot of Clockwork buildings... are lacking
## the box building animation during the construction phase"): the crate lands and unfolds (its own strip,
## assets/effects/crate_unfold_<kind>.png, from tools/import_crate.py), then the construction sprite rises from the
## bottom (Building._rise), then the finished building; a damaged one still draws its damaged sprite.
##   godot --headless --script res://tools/test_cw_crate_build.gd
var main: Node
var fails := 0


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _free_cell(g, kind: String, from: Vector2i) -> Vector2i:
	for r in range(8, 40):
		for dx in range(-r, r + 1, 2):
			for c in [from + Vector2i(dx, r), from + Vector2i(dx, -r)]:
				if g.placement_problem(1, kind, c) == "":
					return c
	return Vector2i(-1, -1)


func _run() -> void:
	await process_frame
	main.start({"map": "greenhold", "seed": 5, "slots": [
		{"who": "you", "faction": "crown", "colour": 0, "side": 0},
		{"who": "easy", "faction": "clockwork", "colour": 1, "side": 1}]})
	await process_frame
	var g = main.game
	g.hud.countdown = 0.0
	paused = false
	for ai in g.ais:
		ai.process_mode = Node.PROCESS_MODE_DISABLED
	await physics_frame
	var hall = g.halls_of(1)[0]
	var base: Vector2i = g.cell_of(hall.center())
	var kinds: Array = Defs.build_list("clockwork")
	check(kinds.size() >= 8, "the Clockwork build list: %s" % [kinds])
	for k: String in kinds:
		check(not (ArtData.CRATE.get(k, []) as Array).is_empty()
			and ResourceLoader.exists("res://assets/effects/crate_unfold_%s.png" % k), "%s has its own crate unfold strip" % k)
		var cell := _free_cell(g, k, base)
		if cell.x < 0:
			check(false, "%s: room to place it" % k)
			continue
		# (the computer's site, as the computer's Winder brings it: the same code draws the player's)
		var b: Building = g._add_building(k, 1, cell, false, true)
		b.crate = "carried"
		await physics_frame
		check(not b.seeded and b.sprite.modulate.a < 0.5, "%s: a see-through ghost until the crate lands" % k)
		g.try_start_site(b, null)
		b.land_crate()
		await physics_frame
		await physics_frame
		var u: Sprite2D = b._unfold
		check(u != null and u.texture != null and u.frame == 0 and b.sprite.modulate.a < 0.05,
			"%s: the closed crate on the ground (frame 0), the building not drawn yet" % k)
		var frames := {}
		var t := 0.0
		while b.unfold_t >= 0.0 and t < 10.0:
			if b._unfold:
				frames[b._unfold.frame] = true
			await physics_frame
			t += 1.0 / 60.0
		check(frames.size() >= 5, "%s: the crate unfolds (frames seen %s)" % [k, frames.keys()])
		check(b._unfold == null and not b.built, "%s: the unfold ends while it builds" % k)
		var tex_h := b.sprite.texture.get_height()
		check(b.sprite.texture.resource_path.ends_with("%s_construction.png" % k) and b.sprite.region_enabled
			and b.sprite.region_rect.size.y < tex_h * 0.75, "%s: build-up: only the bottom of the scaffold stands" % k)
		var r0: float = b.sprite.region_rect.size.y
		b.progress = 0.25
		b._update_sprite()
		check(b.sprite.region_rect.size.y > r0, "%s: the scaffold rises as it builds" % k)
		check(absf(b.bar_top() - (b.sprite.position.y + (Building.body_offset(k, b.sprite.texture).y
			+ g._tex_top(b.sprite.texture)) * b.sprite.scale.y + 2.0)) < 0.5, "%s: its bars stay over the whole picture" % k)
		b.progress = 0.6
		b._update_sprite()
		check(not b.sprite.region_enabled, "%s: all of the scaffold stands past half way" % k)
		b.add_progress(float(b.d["time"]))
		await physics_frame
		check(b.built and b.sprite.texture.resource_path.ends_with("%s_built.png" % k) and not b.sprite.region_enabled
			and b.sprite.modulate.a > 0.99, "%s: the finished building" % k)
		b.hp = b.max_hp * 0.3
		b._update_sprite()
		check(b.sprite.texture.resource_path.ends_with("%s_damaged.png" % k), "%s: damaged still draws" % k)
	# a building with no strip of its own borrows the nearest one (scaled): never no crate at all
	var fb := Building.crate_art("no_such_building")
	check(not (fb[1] as Array).is_empty(), "a building without a strip borrows one (%s)" % fb[0])
	print("FAILS: %d" % fails if fails else "ALL PASS")
	quit()
