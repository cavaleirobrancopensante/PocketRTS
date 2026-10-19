class_name Sfx
extends Node
## Sound effects, quieter the further they are from the camera.

const NAMES := ["musket", "cannon", "boom", "click", "done", "error", "alarm"]
static var me: Sfx
var camera: Camera2D
var _players := {}
var _last := {}


func _ready() -> void:
	me = self
	for n in NAMES:
		var p := AudioStreamPlayer.new()
		p.stream = load("res://assets/audio/%s.wav" % n)
		p.max_polyphony = 6
		add_child(p)
		_players[n] = p


static func play(name: String, pos := Vector2.INF) -> void:
	if me == null or not me._players.has(name):
		return
	var now := Time.get_ticks_msec()
	if now - int(me._last.get(name, 0)) < 40:
		return   # don't stack dozens of identical sounds in one frame
	me._last[name] = now
	var db := 0.0
	if pos != Vector2.INF and me.camera and is_instance_valid(me.camera):
		var dist := pos.distance_to(me.camera.get_screen_center_position()) * me.camera.zoom.x
		if dist > 1100.0:
			return
		db = -3.0 - dist / 70.0
	var p: AudioStreamPlayer = me._players[name]
	p.volume_db = db
	p.pitch_scale = randf_range(0.9, 1.1)
	p.play()
