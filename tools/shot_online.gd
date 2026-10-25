extends SceneTree
## Screenshots of the ONLINE screens (needs a relay: node tools/relay/local_relay.mjs 8787):
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --script res://tools/shot_online.gd -- out.png menu|online|host|guest [wait_seconds]
var main


func _initialize() -> void:
	Settings.load_all()
	Settings.device = "pc"
	Settings.relay_url = "ws://127.0.0.1:8787"
	Settings.apply()
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred()


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	var role: String = a[1] if a.size() > 1 else "menu"
	var wait: float = float(a[2]) if a.size() > 2 else 3.0
	var code: String = a[3] if a.size() > 3 else "KQXZ"
	var lang: String = a[4] if a.size() > 4 else "en"
	var mode: String = a[5] if a.size() > 5 else "1v1"
	if lang != "en":
		Loc.set_lang(lang)
	await create_timer(1.0).timeout
	if role != "menu":
		main.show_online()
		await create_timer(0.5).timeout
	if role == "host" or role == "guest":
		var mm = _find(main)
		var l := NetLobby.new()
		main.add_child(l)
		main.net_lobby = l
		l.changed.connect(mm._on_changed)
		l.failed.connect(mm._on_failed)
		if role == "host":
			l.host(Settings.relay_url, code)
			l.set_mode(mode)
		else:
			l.join(Settings.relay_url, code)
		mm._draw()
	await create_timer(wait).timeout
	root.get_viewport().get_texture().get_image().save_png(a[0])
	quit()


func _find(n: Node) -> Node:
	if n is MultiplayerMenu:
		return n
	for c in n.get_children():
		var r := _find(c)
		if r != null:
			return r
	return null
