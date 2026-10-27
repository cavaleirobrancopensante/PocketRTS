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
	"menu": "Holdfast Overture",
	"crown_peace": "The King's Muster", "crown_battle": "Pike and Shot",
	"brood_peace": "The Warm Swamp", "brood_battle": "Hunger",
	"clock_peace": "Winding the Spring", "clock_battle": "Brass and Steam",
}
const MODES := ["vanilla", "faction", "all", "picked"]
const MODE_NAMES := {"vanilla": "YOUR FACTION + A LITTLE OF THE ENEMY", "faction": "YOUR FACTION ONLY",
	"all": "EVERYTHING, SHUFFLED", "picked": "ONLY THE TICKED PIECES"}
const ENEMY_CHANCE := 0.2
const HEAT_HIGH := 14.0   # a fight this hot gets the full battle pieces; a milder one a skirmish piece
## Pieces with a job of their own, whatever their name says: "open" starts a match (with the calm
## pieces in OPEN_CALM), "skirmish" is the lighter fighting music. Everything else follows its name:
## <faction>_peace* for calm, <faction>_battle* for the full battle.
const ROLES := {"crown_battle_6": "open", "crown_battle_7": "skirmish", "crown_battle_9": "skirmish",
	"crown_battle_11": "skirmish"}
const OPEN_CALM := ["crown_peace", "crown_peace_4"]
var _skirmish := false    # the battle piece playing is a skirmish piece, to be raised when the fight heats up
var _piece_t := 0.0
const FADE := 2.5
const VOL := -8.0       # (the game sounds are levelled to this: tools/audio/make_mix.py)
const HEAT_ON := 7.0      # combat heat that starts the battle music
const HEAT_OFF := 1.5     # ...and the calm it takes to go back

static var me: Music
var music_on := true
var sound_on := true
var amb_on := true             # the landscape's background loop (wind, leaves, surf...)
const AMB_VOL := -20.0
var music_vol := 0.5           # the sliders (0 to 1): music sat too loud over the game sounds, so it starts at half
var sound_vol := 1.0
var amb_vol := 1.0
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
## PICKED-PIECE RULE (the in-game menu's music player, ui/menu_music.gd): a piece chosen from the list plays through to
## its end, and the fight / calm switching waits meanwhile; then the normal choice (open / skirmish / battle / calm by
## the heat) resumes. NEXT hands back to it at once. The list and NEXT follow the music setting (player_pieces, _pool).
var picked := false


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
		music_vol = cfg.get_value("audio", "music_vol", 0.5)
		sound_vol = cfg.get_value("audio", "sound_vol", 1.0)
		amb_vol = cfg.get_value("audio", "amb_vol", 1.0)
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
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(maxf(music_vol, 0.0001)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(maxf(sound_vol, 0.0001)))
	if _amb:
		_amb.volume_db = _amb_db()


func _amb_db() -> float:
	return AMB_VOL + linear_to_db(maxf(amb_vol, 0.0001)) if amb_on and amb_vol > 0.0 else -80.0


## Which of "music", "sound", "ambience", set from 0 to 1.
func set_volume(which: String, v: float) -> void:
	v = clampf(v, 0.0, 1.0)
	match which:
		"music": music_vol = v
		"sound": sound_vol = v
		_: amb_vol = v
	_apply()
	_save_soon()


func get_volume(which: String) -> float:
	return music_vol if which == "music" else (sound_vol if which == "sound" else amb_vol)


var _save_t := 0.0


func _save_soon() -> void:
	if _save_t <= 0.0:
		_save_t = 0.6


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
	_amb.volume_db = _amb_db()
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
	cfg.set_value("audio", "music_vol", music_vol)
	cfg.set_value("audio", "sound_vol", sound_vol)
	cfg.set_value("audio", "amb_vol", amb_vol)
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


## Every piece of a faction (calm and battle, whatever its job), in catalogue order.
static func all_pieces(fkey: String) -> Array:
	var out: Array = []
	for stem in titles():
		var s: String = stem
		if (s.begins_with(fkey + "_peace") or s.begins_with(fkey + "_battle")) and has_piece(s):
			out.append(s)
	return out


## Pieces for a faction key ("crown", "brood", "clock") and a mood: "peace", "battle" (the full
## fight), "skirmish" (a lighter fight) or "open" (the start of a match).
static func pieces(fkey: String, mood: String) -> Array:
	var out: Array = []
	for stem in all_pieces(fkey):
		var s: String = stem
		var r: String = ROLES.get(s, "")
		match mood:
			"open":
				if r == "open" or OPEN_CALM.has(s):
					out.append(s)
			"skirmish":
				if r == "skirmish":
					out.append(s)
			"battle":
				if s.contains("_battle") and r == "":
					out.append(s)
			"peace":
				if s.contains("_peace"):
					out.append(s)
	return out


## The menu overtures: "menu" and every "menu_*" piece in the catalogue.
static func menu_pieces() -> Array:
	var out: Array = []
	for stem in titles():
		var s: String = stem
		if s == "menu" or s.begins_with("menu_"):
			if has_piece(s):
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
	if not _menu_bag.is_empty():
		_fetch.call_deferred(_menu_bag.back())   # on the web: the next overture downloads after this one
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
	if pool.is_empty() and mood == "open":
		mood = "peace"
		pool = _pool(mood)
	if pool.is_empty() and mood == "skirmish":
		mood = "battle"
		pool = _pool(mood)
	if pool.is_empty():
		return ""
	var fresh := pool.filter(func(s: String) -> bool: return not _recent.has(s))
	if fresh.is_empty():
		fresh = pool.filter(func(s: String) -> bool: return s != _current)
		if fresh.is_empty():
			fresh = pool
	var ready := fresh.filter(func(s: String) -> bool: return is_ready(s))
	if not ready.is_empty() and ready.size() < fresh.size():
		# on the web: play one that is already here, and fetch another for next time
		var later: Array = fresh.filter(func(s: String) -> bool: return not is_ready(s))
		_fetch(later[randi() % later.size()])
		fresh = ready
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
	var stream := _stream(track)
	if stream == null:
		# on the web the piece is still downloading: the old one plays on until it arrives
		_want = track
		_want_loop = loop
		return
	_want = ""
	_piece_t = 0.0
	_sting.stop()
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


var _tweens := {}     # player -> its running fade


func _fade(p: AudioStreamPlayer, to: float, stop_after := false) -> void:
	# (one fade per player: an older fade-out would otherwise stop a piece that has since come back as the playing
	# one, when NEXT is pressed twice within a couple of seconds)
	if _tweens.has(p) and (_tweens[p] as Tween).is_valid():
		(_tweens[p] as Tween).kill()
	var tw := create_tween()
	_tweens[p] = tw
	tw.tween_property(p, "volume_db", to, FADE).set_trans(Tween.TRANS_SINE)
	if stop_after:
		tw.tween_callback(func() -> void:
			if p != _a or _current == "":
				p.stop())


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
	if picked:
		_resume_auto(false)
		return
	play(_next(("skirmish" if _skirmish else "battle") if _battle else "peace"))


## Back to the automatic music for the fight as it is now (a picked piece ended, or NEXT).
func _resume_auto(force_new: bool) -> void:
	picked = false
	_battle = heat > HEAT_ON
	_skirmish = _battle and heat < HEAT_HIGH and not pieces(_faction, "skirmish").is_empty()
	_calm_t = 0.0
	_piece_t = 0.0
	if force_new:
		_current = ""
	play(_next(("skirmish" if _skirmish else "battle") if _battle else "peace"))


## The in-game player: play this piece now, to its end (PICKED-PIECE RULE).
func play_picked(track: String) -> void:
	if _faction == "" or track == "" or not player_pieces().has(track):
		return
	picked = true
	_current = ""
	play(track)


## NEXT: the automatic music's next piece for the fight as it is (it ends a picked piece too).
func skip() -> void:
	if _faction == "":
		return
	_resume_auto(true)


func current_stem() -> String:
	return _current


## The pieces the in-game player lists: every piece of every faction (the owner: "a list of all songs to pick"), your
## faction's first, then the enemies', then the rest. (NEXT still follows the music setting: _next / _pool.)
func player_pieces() -> Array:
	if _faction == "":
		return []
	var out: Array = all_pieces(_faction)
	for e in _enemies:
		for st in all_pieces(e):
			if not out.has(st):
				out.append(st)
	for f in FACTION_KEY.values():
		for st in all_pieces(f):
			if not out.has(st):
				out.append(st)
	return out


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


## The music player's controls: where the playing piece is, how long it is, seek, pause.
func track_length() -> float:
	return _a.stream.get_length() if _a.stream else 0.0


func track_pos() -> float:
	return _a.get_playback_position() if _a.playing or _a.stream_paused else 0.0


func is_paused() -> bool:
	return _a.stream_paused


func set_paused(on: bool) -> void:
	if _a.stream == null:
		return
	if not on and not _a.playing:
		_a.play()
	_a.stream_paused = on


func seek_to(t: float) -> void:
	if _a.stream == null:
		return
	if not _a.playing:
		_a.play()
	_a.seek(clampf(t, 0.0, maxf(track_length() - 0.5, 0.0)))


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
	picked = false
	heat = 0.0
	_current = ""
	_recent.clear()
	_skirmish = false
	play(_next("open"))
	# on the web: fetch the end-of-match stings and a fighting piece ahead of time
	for s in [_sting_name(faction, true), _sting_name(faction, false)] + pieces(_faction, "skirmish").slice(0, 1) + pieces(_faction, "battle").slice(0, 1):
		_fetch(s)


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
	_amb.volume_db = _amb_db()
	_amb.play()
	MatchLog.sound("AMBIENCE " + biome)


## End of a match: fade the music and play the sting.
func match_ended(won: bool, faction: String) -> void:
	picked = false
	_amb.stop()
	_current = ""
	_in_menu = false
	_faction = ""
	_fade(_a, -80.0, true)
	_fade(_b, -80.0, true)
	_want = ""
	_sting.stream = _stream(_sting_name(faction, won))
	if _sting.stream == null:
		return
	_sting.volume_db = VOL
	_sting.play()


static func _sting_name(faction: String, won: bool) -> String:
	return "win_" + FACTION_KEY.get(faction, "crown").replace("clock", "clockwork") if won else "defeat"


func add_heat(v: float) -> void:
	heat = minf(heat + v, 30.0)


func _process(delta: float) -> void:
	if _save_t > 0.0:
		_save_t -= delta
		if _save_t <= 0.0:
			_save()
	if _faction == "":
		return
	heat *= exp(-delta / 5.0)
	if picked:
		return          # a picked piece is not cut off by a fight or by calm
	_piece_t += delta
	if not _battle and heat > HEAT_ON:
		_battle = true
		_skirmish = heat < HEAT_HIGH and not pieces(_faction, "skirmish").is_empty()
		play(_next("skirmish" if _skirmish else "battle"))
	elif _battle and _skirmish and heat > HEAT_HIGH and _piece_t > 20.0:
		_skirmish = false              # the fight has grown: the full battle music
		play(_next("battle"))
	elif _battle:
		_calm_t = _calm_t + delta if heat < HEAT_OFF else 0.0
		if _calm_t > 10.0:
			_battle = false
			_calm_t = 0.0
			play(_next("peace"))


# ------------------------------------------------------------------ music on the web

## The web build leaves the music out of its packs (it was half the download): the page lists
## every piece in window.HOLDFAST_MUSIC (stem -> {"u": "music/<stem>.ogg?h=<hash>"}) and each one
## is downloaded when it is first wanted. The page keeps what it downloaded in the browser's cache,
## so a piece is fetched once, until it changes. On Android and the desktop the pieces are in the
## pack as usual. See docs/web_load.md.
const MUSIC_PATH := "res://assets/music/%s.ogg"
const KEEP := 6                      # downloaded pieces kept decoded-ready in memory
static var _web: Dictionary = {}
static var _web_read := false
var _got: Dictionary = {}            # stem -> AudioStreamOggVorbis (downloaded)
var _got_order: Array = []
var _queue: Array = []               # stems waiting to be downloaded, first = next
var _http: HTTPRequest
var _http_stem := ""
var _tries: Dictionary = {}
var _want := ""                      # the piece play() is waiting for
var _want_loop := false


static func _web_list() -> Dictionary:
	if not _web_read:
		_web_read = true
		if OS.has_feature("web"):
			var s: Variant = JavaScriptBridge.eval("JSON.stringify(window.HOLDFAST_MUSIC || {})", true)
			var d: Variant = JSON.parse_string(str(s)) if s != null else null
			if d is Dictionary:
				_web = d
	return _web


## The piece is part of this build (in the pack, or on the web server).
static func has_piece(stem: String) -> bool:
	return ResourceLoader.exists(MUSIC_PATH % stem) or _web_list().has(stem)


## The piece can play right now (always true outside the web).
func is_ready(stem: String) -> bool:
	return _got.has(stem) or ResourceLoader.exists(MUSIC_PATH % stem) or not _web_list().has(stem)


## The piece's stream, or null while it is being downloaded (it is asked for first in the queue).
func _stream(stem: String) -> AudioStream:
	if ResourceLoader.exists(MUSIC_PATH % stem):
		return load(MUSIC_PATH % stem)
	if _got.has(stem):
		_got_order.erase(stem)
		_got_order.append(stem)
		return _got[stem]
	_fetch(stem, true)
	return null


func _fetch(stem: String, urgent := false) -> void:
	if is_ready(stem) or stem == _http_stem:
		return
	_queue.erase(stem)
	if urgent:
		_queue.push_front(stem)
	else:
		_queue.push_back(stem)
	_fetch_next()


func _fetch_next() -> void:
	if _http_stem != "" or _queue.is_empty():
		return
	if _http == null:
		_http = HTTPRequest.new()
		_http.accept_gzip = false
		_http.request_completed.connect(_on_fetched)
		add_child(_http)
	_http_stem = _queue.pop_front()
	var base: Variant = JavaScriptBridge.eval("new URL('.', window.location.href).href", true)
	var err := _http.request(str(base) + String(_web_list()[_http_stem].get("u", "")))
	if err != OK:
		_http_stem = ""


func _on_fetched(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var stem := _http_stem
	_http_stem = ""
	var s: AudioStreamOggVorbis = null
	if result == HTTPRequest.RESULT_SUCCESS and code == 200:
		s = AudioStreamOggVorbis.load_from_buffer(body)
	if s == null:
		_tries[stem] = int(_tries.get(stem, 0)) + 1
		MatchLog.sound("MUSIC download failed %s (%d, %d)" % [stem, result, code])
		if _tries[stem] < 3:
			_queue.push_back(stem)
	else:
		_got[stem] = s
		_got_order.append(stem)
		while _got_order.size() > KEEP:
			var old: String = _got_order.pop_front()
			if old != _current and old != _want:
				_got.erase(old)
			else:
				_got_order.append(old)
				break
		if stem == _want:
			_want = ""
			_current = ""
			play(stem, _want_loop)
	_fetch_next()
