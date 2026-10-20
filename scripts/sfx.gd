class_name Sfx
extends Node
## Sound effects, quieter the further they are from the camera, plus unit voices and the
## faction announcer.
##
## A sound name is a path under res://assets/audio/ without the extension ("musket",
## "ui/click", "combat/musketeer_attack"). Variants name_1, name_2 ... are picked at random.
## play_any() takes a list and plays the first name that exists, so new files dropped into
## the folders (see AUDIO_PROMPTS.md) replace the built-in synth sounds by themselves.

const SHORT := {"crown": "crown", "brood": "brood", "clockwork": "clock"}
static var me: Sfx
var camera: Camera2D
var _streams := {}          # name -> Array of streams ([] = none)
var _players := {}
var _last := {}
var _voice: AudioStreamPlayer
var _announcer: AudioStreamPlayer
var _said := {}             # announcer line -> time last said


func _ready() -> void:
	me = self
	_voice = _new_player(1)
	_announcer = _new_player(1)


func _new_player(poly: int) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
	p.max_polyphony = poly
	add_child(p)
	return p


## Every stream for a name: the plain file and/or its numbered variants.
func _find(name: String) -> Array:
	if _streams.has(name):
		return _streams[name]
	var out: Array = []
	for base in ["res://assets/audio/" + name, "res://assets/" + name]:
		for ext in [".wav", ".ogg"]:
			if ResourceLoader.exists(base + ext):
				out.append(load(base + ext))
			for i in range(1, 6):
				if ResourceLoader.exists("%s_%d%s" % [base, i, ext]):
					out.append(load("%s_%d%s" % [base, i, ext]))
		if not out.is_empty():
			break
	_streams[name] = out
	return out


static func has(name: String) -> bool:
	return me != null and not me._find(name).is_empty()


## Faction-flavoured sound: Sfx.play_f("ready", "brood") plays brood/ready, else ready_brood.
static func play_f(base: String, faction: String, pos := Vector2.INF) -> void:
	var s: String = SHORT.get(faction, "crown")
	play_any(["%s/%s" % [s, base], "%s_%s" % [base, s]], pos)


## The first of these names that has a sound.
static func play_any(names: Array, pos := Vector2.INF, vol := 0.0) -> void:
	if me == null:
		return
	for n in names:
		if has(n):
			play(n, pos, vol)
			return


static func play(name: String, pos := Vector2.INF, vol := 0.0) -> void:
	if me == null:
		return
	var list := me._find(name)
	if list.is_empty():
		return
	var now := Time.get_ticks_msec()
	if now - int(me._last.get(name, 0)) < 40:
		return   # don't stack dozens of identical sounds in one frame
	me._last[name] = now
	var db := vol
	if pos != Vector2.INF and me.camera and is_instance_valid(me.camera):
		var dist := pos.distance_to(me.camera.get_screen_center_position()) * me.camera.zoom.x
		if dist > 1100.0:
			return
		db += -3.0 - dist / 70.0
	if not me._players.has(name):
		me._players[name] = me._new_player(6)
	var p: AudioStreamPlayer = me._players[name]
	p.stream = list[randi() % list.size()]
	p.volume_db = db
	p.pitch_scale = randf_range(0.93, 1.07)
	p.play()


## A unit answering you: "select", "move" or "attack". One voice at a time.
static func voice(kind: String, what: String) -> void:
	if me == null or me._voice.playing:
		return
	var list := me._find("voice/%s/%s" % [kind, what])
	if list.is_empty() and what == "attack":
		list = me._find("voice/%s/move" % kind)
	if list.is_empty():
		return
	me._voice.stream = list[randi() % list.size()]
	me._voice.volume_db = -2.0
	me._voice.play()


## The faction announcer ("unit_ready", "under_attack" ...), not repeated within `gap` seconds.
## Falls back to the faction's alert sound when there's no voice line.
static func announce(faction: String, line: String, gap := 4.0, fallback := "") -> void:
	if me == null:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(me._said.get(line, -999.0)) < gap:
		return
	me._said[line] = now
	var s: String = SHORT.get(faction, "crown")
	var list := me._find("voice/announcer/%s/%s" % [s, line])
	if list.is_empty():
		if fallback != "":
			play_f(fallback, faction)
		return
	if fallback != "":
		play_f(fallback, faction)
	me._announcer.stream = list[randi() % list.size()]
	me._announcer.volume_db = 0.0
	me._announcer.play()


## An enemy AI commander's taunt.
static func taunt(faction: String) -> void:
	if me == null:
		return
	var list := me._find("voice/taunt/%s/taunt" % SHORT.get(faction, "crown"))
	if list.is_empty() or me._announcer.playing:
		return
	me._announcer.stream = list[randi() % list.size()]
	me._announcer.volume_db = -1.0
	me._announcer.play()
