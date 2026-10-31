extends SceneTree
## Pictures of every Settings tab (computer layout) into docs/shots/settings/<tab>.jpg:
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --script res://tools/shot_settings_tabs.gd
## (the player's settings file is not changed)
var main


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var dev := Settings.device
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/shots/settings"))
	for d in ["pc", "mobile"]:
		Settings.device = d
		for t in main.SETTINGS_TABS:
			if d == "mobile" and t != "GAMEPLAY":
				continue
			main.show_settings(t)
			await create_timer(0.5).timeout
			var img := root.get_viewport().get_texture().get_image()
			var name := String(t).to_lower() + ("_phone" if d == "mobile" else "")
			img.save_jpg(ProjectSettings.globalize_path("res://docs/shots/settings/%s.jpg" % name), 0.85)
			print("saved ", name)
	# the match menu's volume bars with their small mute buttons (music muted for the picture)
	Settings.device = "pc"
	main._preset("1v1")
	main.start(main.lobby.duplicate(true))
	await create_timer(1.5).timeout
	var g = main.game
	g.hud.toggle_menu(true)
	var was_muted: bool = Music.me.is_muted("music")
	if not was_muted:
		Music.me.music_on = false
		Music.me._apply()
	await create_timer(0.6).timeout
	root.get_viewport().get_texture().get_image().save_jpg(ProjectSettings.globalize_path("res://docs/shots/settings/match_menu.jpg"), 0.85)
	print("saved match_menu")
	if not was_muted:
		Music.me.music_on = true
		Music.me._apply()
	Settings.device = dev
	quit()
