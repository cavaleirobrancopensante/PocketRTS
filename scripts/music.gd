class_name Music
extends Node
## Music: on the menu a shuffle of the overtures (menu, menu_2, ...) - each played once, then
## another, never the same one twice in a row; in a match a shuffled playlist of calm pieces that
## cross-fades to battle pieces while fighting is hot near you; a sting at the end.
##
## Modes (Settings > Music):
##   "vanilla"  your faction's music, now and then a piece from an enemy faction
##   "faction"  only your faction's music
##   "all"      everything, shuffled
##   "picked"   only the pieces ticked in the music player
## Also owns the Music / SFX buses and the on/off settings (saved in user://settings.cfg).

const FACTION_KEY := {"crown": "crown", "brood": "brood", "clockwork": "clock"}
const BASE_TITLES := {
	"menu": "PocketRTS Overture",
	"crown_peace": "The King's Muster", "crown_battle": "Pike and Shot",
	"brood_peace": "The Warm Swamp", "brood_battle": "Hunger",
	"clock_peace": "Winding the Spring", "clock_battle": "Brass and Steam",
}
const MODES := ["vanilla", "faction", "all", "picked"]
const MODE_NAMES := {"vanilla": "YOUR FACTION + A LITTLE OF THE ENEMY", "faction": "YOUR FACTION ONLY",
	"all": "EVERYTHING, SHUFFLED", "picked": "ONLY THE TICKED PIECES"}
const ENEMY_CHANCE := 0.2
const FADE := 2.5
const VOL := -12.0      # music sits under the battle (the guns must cut through)
const HEAT_ON := 7.0      # combat heat that starts the battle music
const HEAT_OFF := 1.5     # ...and the calm it takes to go back

static var me: Music
var music_on := true
var sound_on := true
var amb_on := true             # the landscape's background loop (wind, leaves, surf...)
const AMB_VOL := -20.0
var mode := "vanilla"
var off_list: Array = []  # pieces left out in "picked" mode
var _a: AudioStreamPlayer
var _b: AudioStreamPlayer
var _sting: AudioStreamPlayer
var _amb: AudioStreamPlayer
var _current := ""
var _faction := ""
var _enemies: Array = []
var _battle := false
var _calm_t := 0.0
var _recent: Array = []
var _preview := false
var _in_menu := false     # the menu shuffle is running
var _menu_bag: Array = [] # overtures not yet played in this round of the shuffle
var _last_menu := ""
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
	_amb = AudioStreamPlayer.new()
	_web_stream(_amb)
	_amb.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
	add_child(_amb)
	var cfg := ConfigFile.new()
	if cfg.load("user://settings.cfg") == OK:
		music_on = cfg.get_value("audio", "music", true)
		sound_on = cfg.get_value("audio", "sound", true)
		amb_on = cfg.get_value("audio", "ambience", true)
		mode = cfg.get_value("audio", "music_mode", "vanilla")
		off_list = cfg.get_value("audio", "music_off", [])
	_apply()


## On the web, music and ambience are streamed through the engine's mixer instead of being
## turned into Web Audio samples: each piece as a sample is a fully decoded copy of tens
## of megabytes that is never freed, which phone browsers run out of after a few pieces.
static func _web_stream(p: AudioStreamPlayer) -> void:
	if OS.has_feature("web"):
		p.playback_type = AudioServer.PLAYBACK_TYPE_STREAM


func _player() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	_web_stream(p)
	p.bus = "Music"
	p.volume_db = -80.0
	p.finished.connect(_on_finished.bind(p))
	add_child(p)
	return p


func _apply() -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), not music_on)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("SFX"), not sound_on)


func toggle_music() -> void:
	music_on = not music_on
	_apply()
	_save()
	MatchLog.sound("MUSIC " + ("ON" if music_on else "OFF"))


func toggle_sound() -> void:
	sound_on = not sound_on
	_apply()
	_save()
	MatchLog.sound("SOUND " + ("ON" if sound_on else "OFF"))


func toggle_ambience() -> void:
	amb_on = not amb_on
	_amb.volume_db = AMB_VOL if amb_on else -80.0
	_save()
	MatchLog.sound("AMBIENCE " + ("ON" if amb_on else "OFF"))


func set_mode(m: String) -> void:
	mode = m
	_save()


func set_enabled(track: String, on: bool) -> void:
	off_list.erase(track)
	if not on:
		off_list.append(track)
	_save()


func is_enabled(track: String) -> bool:
	return not off_list.has(track)


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.load("user://settings.cfg")     # keep the other sections
	cfg.set_value("audio", "music", music_on)
	cfg.set_value("audio", "sound", sound_on)
	cfg.set_value("audio", "ambience", amb_on)
	cfg.set_value("audio", "music_mode", mode)
	cfg.set_value("audio", "music_off", off_list)
	cfg.save("user://settings.cfg")


# ------------------------------------------------------------------ the catalogue

## Every piece: stem -> title (the generated list when there is one).
static func titles() -> Dictionary:
	var path := "res://scripts/music_tracks.gd"
	if ResourceLoader.exists(path):
		var s: GDScript = load(path)
		var c: Dictionary = s.get_script_constant_map()
		if c.has("TRACKS"):
			return c["TRACKS"]
	return BASE_TITLES


## Pieces for a faction key ("crown", "brood", "clock") and mood ("peace", "battle").
static func pieces(fkey: String, mood: String) -> Array:
	var out: Array = []
	for stem in titles():
		var s: String = stem
		if s == "%s_%s" % [fkey, mood] or s.begins_with("%s_%s_" % [fkey, mood]):
			if ResourceLoader.exists("res://assets/music/%s.ogg" % s):
				out.append(s)
	return out


## The menu overtures: "menu" and every "menu_*" piece in the catalogue.
static func menu_pieces() -> Array:
	var out: Array = []
	for stem in titles():
		var s: String = stem
		if s == "menu" or s.begins_with("menu_"):
			if ResourceLoader.exists("res://assets/music/%s.ogg" % s):
				out.append(s)
	return out


## The next overture: a shuffled round of all of them, never the one that just played.
func _next_menu() -> String:
	var all := menu_pieces()
	if all.is_empty():
		return ""
	_menu_bag = _menu_bag.filter(func(m: String) -> bool: return all.has(m) and m != _last_menu)
	if _menu_bag.is_empty():
		_menu_bag = all.filter(func(m: String) -> bool: return m != _last_menu)
		if _menu_bag.is_empty():
			_menu_bag = all.duplicate()
		_menu_bag.shuffle()
	var pick: String = _menu_bag.pop_back()
	_last_menu = pick
	return pick


func _pool(mood: String) -> Array:
	var own := pieces(_faction, mood)
	match mode:
		"faction":
			return own
		"all", "picked":
			var all: Array = []
			for f in FACTION_KEY.values():
				all += pieces(f, mood)
			if mode == "picked":
				all = all.filter(func(s: String) -> bool: return is_enabled(s))
				if all.is_empty():
					all = own
			return all
	# vanilla: mostly ours, sometimes theirs
	if not _enemies.is_empty() and randf() < ENEMY_CHANCE:
		var theirs := pieces(_enemies[randi() % _enemies.size()], mood)
		if not theirs.is_empty():
			return theirs
	return own


func _next(mood: String) -> String:
	var pool := _pool(mood)
	if pool.is_empty():
		return ""
	var fresh := pool.filter(func(s: String) -> bool: return not _recent.has(s))
	if fresh.is_empty():
		fresh = pool.filter(func(s: String) -> bool: return s != _current)
		if fresh.is_empty():
			fresh = pool
	var pick: String = fresh[randi() % fresh.size()]
	_recent.append(pick)
	while _recent.size() > maxi(1, pool.size() - 1):
		_recent.pop_front()
	return pick


# ------------------------------------------------------------------ playing

## Cross-fade to a piece. `loop` for previews (the menu shuffles instead).
func play(track: String, loop := false) -> void:
	if track == _current or track == "":
		return
	_current = track
	_sting.stop()
	var stream: AudioStream = load("res://assets/music/%s.ogg" % track)
	if stream is AudioStreamOggVorbis:
		stream = (stream as AudioStreamOggVorbis).duplicate()
		(stream as AudioStreamOggVorbis).loop = loop
	var old := _a
	_a = _b
	_b = old
	_a.stream = stream
	_a.volume_db = -40.0
	_a.play()
	MatchLog.sound("MUSIC " + track)
	_fade(_a, VOL)
	_fade(_b, -80.0, true)


func _fade(p: AudioStreamPlayer, to: float, stop_after := false) -> void:
	var tw := create_tween()
	tw.tween_property(p, "volume_db", to, FADE).set_trans(Tween.TRANS_SINE)
	if stop_after:
		tw.tween_callback(p.stop)


## A piece ended: on the menu the next overture, in a match the next one from the same mood.
func _on_finished(p: AudioStreamPlayer) -> void:
	if p != _a or _preview:
		return
	MatchLog.sound("MUSIC ended " + _current)
	if _in_menu:
		_current = ""
		play(_next_menu())
		return
	if _faction == "":
		return
	_current = ""
	play(_next("battle" if _battle else "peace"))


## The main menu: keep the overture that is playing (coming back from a sub-page), or start the
## shuffle with one that is not the last one heard.
func menu() -> void:
	_amb.stop()
	_faction = ""
	_preview = false
	if _in_menu and _current != "" and _a.playing and menu_pieces().has(_current):
		return
	_in_menu = true
	_current = ""
	play(_next_menu())


## Try a piece from the music player (loops until another is picked or the menu resumes).
func preview(track: String) -> void:
	_preview = true
	_in_menu = false
	_faction = ""
	_current = ""
	play(track, true)


func now_playing() -> String:
	return titles().get(_current, "")


func match_started(faction: String, enemies: Array = []) -> void:
	_faction = FACTION_KEY.get(faction, "crown")
	_in_menu = false
	_enemies = []
	for e in enemies:
		var k: String = FACTION_KEY.get(e, "")
		if k != "" and k != _faction and not _enemies.has(k):
			_enemies.append(k)
	_preview = false
	_battle = false
	heat = 0.0
	_current = ""
	_recent.clear()
	play(_next("peace"))


## The land's background sound (wind, frogs, lava) under the music, quietly.
func ambience(biome: String) -> void:
	var path := "res://assets/audio/ambience/%s.ogg" % biome
	if biome == "" or not ResourceLoader.exists(path):
		_amb.stop()
		return
	var s: AudioStream = load(path)
	if s is AudioStreamOggVorbis:
		s = (s as AudioStreamOggVorbis).duplicate()
		(s as AudioStreamOggVorbis).loop = true
	_amb.stream = s
	_amb.volume_db = AMB_VOL if amb_on else -80.0
	_amb.play()
	MatchLog.sound("AMBIENCE " + biome)


## End of a match: fade the music and play the sting.
func match_ended(won: bool, faction: String) -> void:
	_amb.stop()
	_current = ""
	_in_menu = false
	_faction = ""
	_fade(_a, -80.0, true)
	_fade(_b, -80.0, true)
	_sting.stream = (load("res://assets/music/%s.ogg" % ("win_" + FACTION_KEY.get(faction, "crown").replace("clock", "clockwork") if won else "defeat")))
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
		play(_next("battle"))
	elif _battle:
		_calm_t = _calm_t + delta if heat < HEAT_OFF else 0.0
		if _calm_t > 10.0:
			_battle = false
			_calm_t = 0.0
			play(_next("peace"))
