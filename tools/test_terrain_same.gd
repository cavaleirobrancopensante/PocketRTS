extends SceneTree
## The cliff drawing (game.gd _render_ground) must never change the map itself: for every
## named map the height map, cliff cells, ramps and passability (solid) hash to the values
## recorded on main before the cliff work (re-recorded after the tree and rock thinning, which changes `solid`, for the bigger maps of 0.15.0, and for the ramp funnels of 0.15.2 and 0.15.3, and for the straight
## cliff edges beside the ramps of 0.15.4: docs/ramp_funnel.md).
##   godot --headless --script res://tools/test_terrain_same.gd           (checks)
##   godot --headless --script res://tools/test_terrain_same.gd -- record (prints a fresh table)
const HASHES := {
	"ashford_crossing": 11398611767819354,
	"kestrel_rise": 59023519470312897,
	"thornwood_maze": 51640270744633374,
	"redrock_canyon": 33900078242744739,
	"saltmarsh_isles": 54479303555539885,
	"glimmerdeep": 51540519794376706,
	"frostmere": 11549185577736908,
	"cinder_steps": 2240983781091551,
	"hollowfen": 60758310486730044,
	"amberfall_vale": 36706074788920109,
	"twin_crowns": 57241338116203788,
	"jade_wilds": 35144092320456335,
	"shattered_coast": 20546441178535453,
	"ember_reach": 12610540732520404,
	"whitecap_pass": 19262670605313020,
	"kingsfield": 29192932344664255,
	"pinewall_marches": 45625348309028903,
	"sundered_realm": 22130424894095145,
	"greenhold": 51164169690776328,
	"highmoor": 2709249503353819,
	"dune_sea": 30316965007391167,
	"frostfang": 3761057170305138,
	"twin_fords": 59109986388107360,
	"ashfall": 47261122500208519,
	"mirewood": 66410409799454828,
	"border_march": 38275522845544405,
	"red_coast": 31797835694548688,
}


func _initialize() -> void:
	_run.call_deferred(OS.get_cmdline_user_args())


func _run(args: Array) -> void:
	var record := args.has("record")
	var fails := 0
	var ids: Array = MapData.NAMED.keys() + MapGen.MAPS.keys()
	for id in ids:
		var n := maxi(MapGen.max_players(id), 2)
		var g := Game.new()
		g.map_id = id
		g.demo = true
		g.rng.seed = 4242
		g.edit_mode = true
		var facs: Array = []
		var sides: Array = []
		for i in n:
			facs.append("crown")
			sides.append(0 if i < n / 2 else 1)
		g.factions = facs
		g.sides = sides
		root.add_child(g)
		await process_frame
		var buf := PackedByteArray()
		buf.append_array(g.height)
		buf.append_array(g.ramp)
		buf.append_array(g.cliff)
		buf.append_array(g.solid)
		var h := hash_bytes(buf)
		if record:
			print('\t"%s": %d,' % [id, h])
		else:
			var ok: bool = HASHES.get(id, -1) == h
			print(("PASS  " if ok else "FAIL  ") + "%s terrain hash %d" % [id, h])
			if not ok:
				fails += 1
		g.queue_free()
		await process_frame
	if not record:
		print("%d failures" % fails)
	quit(1 if fails > 0 else 0)


func hash_bytes(b: PackedByteArray) -> int:
	var c := HashingContext.new()
	c.start(HashingContext.HASH_SHA256)
	c.update(b)
	var d := c.finish()
	var v := 0
	for i in 7:
		v = (v << 8) | d[i]
	return v
