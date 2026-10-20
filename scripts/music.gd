class_name Music
extends Node
## Music: the overture on the menu; in a match your faction's calm piece, cross-fading to its
## battle piece while fighting is hot near you; a victory or defeat sting at the end.
## Also owns the Music / SFX buses and the on/off settings (saved in user://settings.cfg).

const FACTION_KEY := {"crown": "crown", "brood": "brood", "clockwork": "clock"}
const TITLES := {
	"menu": "PocketRTS Overture",
	"crown_peace": "The King's Muster", "crown_battle": "Pike and Shot",
	"brood_peace": "The Warm Swamp", "brood_battle": "Hunger",
	"clock_peace": "Winding the Spring", "clock_battle": "Brass and Steam",
}
const FADE := 2.5
const VOL := -6.0
const HEAT_ON := 7.0      # combat heat that starts the battle piece
const HEAT_OFF := 1.5     # ...and the calm it takes to go back

static var me: Music
var music_on := true
var sound_on := true
var _a: AudioStreamPlayer
var _b: AudioStreamPlayer
var _sting: AudioStreamPlayer
var _current := ""
var _faction := ""
var _battle := false
var _calm_t := 0.0
var heat := 0.0           # raised by hits near the player, decays over a few seconds


func _ready() -> void:
	me = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
			AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
	_a = _player()
	_b = _player()
	_sting = _player()
	var cfg := ConfigFile.new()
	if cfg.load("user://settings.cfg") == OK:
		music_on = cfg.get_value("audio", "music", true)
		sound_on = cfg.get_value("audio", "sound", true)
	_apply()


func _player() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = "Music"
	p.volume_db = -80.0
	add_child(p)
	return p


func _apply() -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), not music_on)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("SFX"), not sound_on)


func toggle_music() -> void:
	music_on = not music_on
	_apply()
	_save()


func toggle_sound() -> void:
	sound_on = not sound_on
	_apply()
	_save()


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "music", music_on)
	cfg.set_value("audio", "sound", sound_on)
	cfg.save("user://settings.cfg")


## Cross-fade to a looping piece.
func play(track: String) -> void:
	if track == _current:
		return
	_current = track
	_sting.stop()
	var stream: AudioStream = load("res://assets/music/%s.ogg" % track)
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	var old := _a
	_a = _b
	_b = old
	_a.stream = stream
	_a.volume_db = -40.0
	_a.play()
	_fade(_a, VOL)
	_fade(_b, -80.0, true)


func _fade(p: AudioStreamPlayer, to: float, stop_after := false) -> void:
	var tw := create_tween()
	tw.tween_property(p, "volume_db", to, FADE).set_trans(Tween.TRANS_SINE)
	if stop_after:
		tw.tween_callback(p.stop)


func menu() -> void:
	_faction = ""
	play("menu")


func match_started(faction: String) -> void:
	_faction = FACTION_KEY.get(faction, "crown")
	_battle = false
	heat = 0.0
	_current = ""
	play(_faction + "_peace")


## End of a match: fade the music and play the sting.
func match_ended(won: bool, faction: String) -> void:
	_current = ""
	_faction = ""
	_fade(_a, -80.0, true)
	_fade(_b, -80.0, true)
	_sting.stream = load("res://assets/music/%s.ogg" % ("win_" + FACTION_KEY.get(faction, "crown").replace("clock", "clockwork") if won else "defeat"))
	_sting.volume_db = VOL
	_sting.play()


func add_heat(v: float) -> void:
	heat = minf(heat + v, 30.0)


func _process(delta: float) -> void:
	if _faction == "":
		return
	heat *= exp(-delta / 5.0)
	if not _battle and heat > HEAT_ON:
		_battle = true
		play(_faction + "_battle")
	elif _battle:
		_calm_t = _calm_t + delta if heat < HEAT_OFF else 0.0
		if _calm_t > 10.0:
			_battle = false
			_calm_t = 0.0
			play(_faction + "_peace")


func now_playing() -> String:
	return TITLES.get(_current, "")
