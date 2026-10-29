extends SceneTree
## Film of the Mist Toad's hop (scripts/toad_hop.gd) for docs/shots/toad_hop/: eight toads hop out from a centre in the eight
## directions and back, so every view (and the mirrored west ones) shows; a still and the GIF's raw frames.
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1600x900 --fixed-fps 30 --script res://tools/shot_toad_hop.gd -- docs/shots/toad_hop [frames=<dir>]
##   python3 tools/toad_hop_gif.py <frames dir> docs/shots/toad_hop
## The GIF's raw frames go to <frames dir> (default user://toad_hop_frames: never into the repo).
const U := preload("res://tools/gear_test_util.gd")
var g: Game
var out := "docs/shots/toad_hop"
var frames_dir := ""
var t := 0.0
var started := false


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("frames="):
			frames_dir = a.substr(7)
		else:
			out = a
	DirAccess.make_dir_recursive_absolute(out)
	if frames_dir == "":
		frames_dir = ProjectSettings.globalize_path("user://toad_hop_frames")
	DirAccess.make_dir_recursive_absolute(frames_dir)
	print("frames in ", frames_dir)
	seed(7)
	g = U.make(root, ["brood", "crown"], "ashford_crossing", true)


func _process(delta: float) -> bool:
	t += delta
	if not started and t > 0.5:
		started = true
		_run()
	return false


func _snap(path: String, wait := 0.0) -> void:
	if wait > 0.0:
		await create_timer(wait).timeout
	await process_frame
	var img := root.get_viewport().get_texture().get_image()
	if path.ends_with(".jpg"):
		img.save_jpg(path, 0.85)
	else:
		img.save_png(path)


func _open_spot(near: Vector2) -> Vector2:
	for r in range(0, 400, 20):
		for k in 12:
			var p := near + Vector2.from_angle(TAU * k / 12.0) * r
			var ok := true
			for a in 8:
				var q := p + Vector2.from_angle(TAU * a / 8.0) * Vector2(170, 110)
				if not g._clear_at(q, 16.0, 0):
					ok = false
					break
			if ok and g._clear_at(p, 40.0, 0):
				return p
	return near


func _run() -> void:
	g.reveal = true
	var hall := U.hall(g, 0)
	var c := _open_spot(hall.center() + Vector2(0, 260))
	var toads: Array = []
	var ways: Array = []
	for a in 8:
		var way := Vector2.from_angle(TAU * a / 8.0) * Vector2(1.0, 0.62)
		var u: Unit = g._add_unit("mist_toad", 0, c + way * 40.0)
		u.auto_work = false
		toads.append(u)
		ways.append(way)
	g.camera.position = c
	g.camera.zoom = Vector2(2.2, 2.2)
	await create_timer(0.8).timeout
	for i in toads.size():
		toads[i].cmd_move(c + ways[i] * 160.0)
	var n := 0
	for i in 48:
		await _snap("%s/f%03d.png" % [frames_dir, n], 1.0 / 15.0)
		n += 1
		if i == 20:
			await _snap("%s/toad_hop_out.jpg" % out)
	for i in toads.size():
		toads[i].cmd_move(c + ways[i] * 40.0)
	for i in 50:
		await _snap("%s/f%03d.png" % [frames_dir, n], 1.0 / 15.0)
		n += 1
	await _snap("%s/toad_hop_back.jpg" % out)
	print("frames: ", n)
	quit()
