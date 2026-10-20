class_name Sfx
extends Node
## Sound effects, quieter the further they are from the camera.

const NAMES := ["musket", "cannon", "boom", "click", "done", "error", "alarm",
	"clash", "bite", "gear_hit", "acid", "bolt", "steam", "roar", "hatch",
	"ready_crown", "ready_brood", "ready_clock", "built_crown", "built_brood", "built_clock",
	"ratchet", "burrow", "death_crown", "death_brood", "death_clock", "collapse", "zap"]
const SHORT := {"crown": "crown", "brood": "brood", "clockwork": "clock"}
static var me: Sfx
var camera: Camera2D
var _players := {}
var _last := {}


func _ready() -> void:
	me = self
	for n in NAMES:
		var p := AudioStreamPlayer.new()
		p.stream = load("res://assets/audio/%s.wav" % n)
		p.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
		p.max_polyphony = 6
		add_child(p)
		_players[n] = p


## Faction-flavoured sound: Sfx.play_f("ready", "brood") plays ready_brood.
static func play_f(base: String, faction: String, pos := Vector2.INF) -> void:
	play("%s_%s" % [base, SHORT.get(faction, "crown")], pos)


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
