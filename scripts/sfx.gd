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
static var hush := false     # (a replay jumping to another time: the pictures in between make no sound)
var camera: Camera2D
var _streams := {}          # name -> Array of streams ([] = none)
var _players := {}
var _last := {}
var _voice: AudioStreamPlayer
var _announcer: AudioStreamPlayer
var _starts: Array = []        # when the latest sounds began (the cap on the din)
var _duck_until := 0
var _said := {}             # announcer line -> time last said


func _ready() -> void:
	me = self
	_voice = _new_player(1)
	_announcer = _new_player(1)
	_announcer.process_mode = Node.PROCESS_MODE_ALWAYS     # ("Game paused." is said while paused)


func _new_player(poly: int) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
	p.max_polyphony = poly
	# In the browser every sound goes through the engine's own mixer, like the music: played
	# as separate Web Audio "samples" they were silent in some browsers (Brave), while the
	# music, mixed by the engine, played fine.
	if OS.has_feature("web"):
		p.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	add_child(p)
	return p


## Every stream for a name: the plain file and/or its numbered variants.
func _find(name: String) -> Array:
	# spoken lines: assets/voice_<lang>/... (pt, es) first, the English assets/voice/... as the fallback
	var key := name if Loc.lang == "en" or not name.begins_with("voice/") else Loc.lang + ":" + name
	if _streams.has(key):
		return _streams[key]
	var out: Array = []
	var bases: Array = ["res://assets/audio/" + name, "res://assets/" + name]
	if key != name:
		bases.push_front("res://assets/voice_%s/%s" % [Loc.lang, name.trim_prefix("voice/")])
	for base in bases:
		for ext in [".wav", ".ogg"]:
			if ResourceLoader.exists(base + ext):
				out.append(load(base + ext))
			for i in range(1, 6):
				if ResourceLoader.exists("%s_%d%s" % [base, i, ext]):
					out.append(load("%s_%d%s" % [base, i, ext]))
		if not out.is_empty():
			break
	_streams[key] = out
	return out


## In the browser Godot plays sounds as Web Audio "samples", and a stream only becomes a
## sample when it's registered; a stream put on a player after start-up isn't, and stays
## silent. So everything we play goes through here first.
static func prep(s: AudioStream) -> AudioStream:
	return s          # (sounds are mixed by the engine now: nothing to register)


static func has(name: String) -> bool:
	return me != null and not me._find(name).is_empty()


## Faction-flavoured sound: Sfx.play_f("ready", "brood") plays brood/ready, else ready_brood.
static func play_f(base: String, faction: String, pos := Vector2.INF) -> void:
	var s: String = SHORT.get(faction, "crown")
	play_any(["%s/%s" % [s, base], "%s_%s" % [base, s]], pos)


## The same, but at most once every `gap` seconds (sounds that would otherwise repeat
## all match long: a soldier trained, a building finished).
static func play_f_once(base: String, faction: String, gap: float, vol := 0.0) -> void:
	if me == null:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(me._said.get("sfx:" + base, -999.0)) < gap:
		return
	me._said["sfx:" + base] = now
	var s: String = SHORT.get(faction, "crown")
	play_any(["%s/%s" % [s, base], "%s_%s" % [base, s]], Vector2.INF, vol)


## The first of these names that has a sound.
static func play_any(names: Array, pos := Vector2.INF, vol := 0.0) -> void:
	if me == null or hush:
		return
	for n in names:
		if has(n):
			play(n, pos, vol)
			return


## The shortest gap (ms) before the same sound plays again (default 40).
const GAP := {"ui/chat": 500, "combat/raptor_attack": 220, "combat/grub_attack": 220, "combat/spitter_attack": 150,
	"combat/windup_soldier_attack": 180, "combat/brood_death": 120, "combat/grub_death": 250, "combat/spitter_death": 200, "combat/bloater_death": 250,
	"combat/mist_toad_death": 250, "combat/skywing_death": 200, "combat/brute_death": 300, "combat/spore_mother_death": 400, "combat/raptor_death": 150, "combat/crown_death": 120,
	# recorded gunfire: a volley of ten muskets is a few overlapping shots, not a wall of noise
	"combat/musketeer_attack": 110, "combat/cannon_attack": 160, "combat/cannon_canister": 160,
	"combat/mortar_attack": 200, "combat/cuirassier_attack": 120, "combat/cuirassier_move": 1500,
	"combat/cuirassier_death": 150, "horse/whinny": 6000, "horse/neigh": 2500, "voice/crown_recruit/horse_breeder": 2500, "voice/crown_bugle/move": 9000, "voice/crown_bugle/amove": 7000,
	"voice/crown_bugle/charge": 7000, "voice/crown_bugle/patrol": 9000, "voice/crown_bugle/trained": 6000,
	"voice/crown_recruit/town_hall": 2500, "voice/crown_recruit/barracks": 2500, "voice/crown_recruit/foundry": 2500,
	"voice/crown_bugle/stop": 6000, "voice/crown_bugle/hold": 6000, "select/*": 250, "select/town_hall": 400, "select/horse_breeder": 1500, "work/crown_build": 700, "work/clock_build": 700, "work/brood_build": 700, "work/winder_crank": 900, "work/hoe": 180,
	# the Clockwork's sounds cut from the owner's recordings (tools/audio/make_clockwork_sounds.py): quick repeating hits
	# get a gap so a crowd of them is a clatter, not a wall
	"combat/clock_soldier_attack": 120, "combat/jack_attack": 110, "combat/ratchet_turret_attack": 120, "combat/cuckoo_attack": 100,
	"combat/ticking_owl_attack": 150, "combat/pendulum_attack": 150, "combat/winder_attack": 150, "combat/netter_hit": 200,
	"combat/jack_jump": 150, "combat/jack_land": 150, "combat/jack_crouch": 150, "combat/owl_bomb": 200, "combat/owl_drop": 150,
	"combat/clock_soldier_death": 150, "combat/jack_death": 200, "combat/cuckoo_death": 200, "combat/ticking_owl_death": 300,
	"combat/pendulum_death": 400, "combat/netter_death": 250, "combat/winder_death": 200, "select/clocktower": 400,
	"select/cog_press": 400, "select/mainspring": 400, "select/escapement": 400, "select/regulator": 400}

## How far a sound's pitch may wander from one play to the next (default 7%).
const JITTER := {"combat/musketeer_attack": 0.04, "combat/cannon_attack": 0.04,
	"combat/cannon_canister": 0.04, "combat/mortar_attack": 0.04, "select/town_hall": 0.0}


## The level that brings this sound file to the music's loudness (SoundMix, generated by
## tools/audio/make_mix.py), so every game sound sits with the music, none buried or blaring.
static func gain(st: AudioStream) -> float:
	if st == null:
		return 0.0
	var path := st.resource_path
	if path.begins_with("res://assets/voice_"):      # a translated line: the English line's mix level
		var rest := path.substr(path.find("/", 18) + 1)
		for ext in [".wav", ".ogg"]:
			var k: String = "res://assets/voice/" + rest.get_basename() + ext
			if SoundMix.GAIN.has(k):
				return float(SoundMix.GAIN[k])
	return float(SoundMix.GAIN.get(path, 0.0))


## 3: the announcer and the interface; 2: unit voices, bugle, horse and recruit calls; 1: the rest.
static func _tier(name: String) -> int:
	if name == "ui/chat":
		return 1          # (the chat tick: the lowest tier, it never hushes the fight)
	if name.begins_with("ui/") or name.begins_with("voice/announcer") or name == "click" or name.ends_with("/alert") or name.ends_with("/base_alert"):
		return 3          # (a faction's own alarm, the Clockwork's alarm clock, as the shared one)
	if name.begins_with("voice/") or name.begins_with("horse/") or name.begins_with("select/"):
		return 2
	return 1


static func play(name: String, pos := Vector2.INF, vol := 0.0) -> void:
	if me == null or hush:
		return
	var list := me._find(name)
	if list.is_empty():
		return
	var now := Time.get_ticks_msec()
	if now - int(me._last.get(name, 0)) < int(GAP.get(name, 40)):
		return   # don't stack dozens of identical sounds (a swarm's bites) on top of each other
	# PRIORITIES (so a big fight is not a wall of noise, as in StarCraft II): voices, the
	# announcer, bugle and horse calls (tier 2/3) always sound and hush the fight for a moment;
	# the din of the fight (tier 1) is capped at a few new sounds per instant, and sits lower
	# while something more important speaks.
	var tier := _tier(name)
	me._starts = me._starts.filter(func(t: int) -> bool: return now - t < 250)
	if tier == 1 and me._starts.size() >= 6:
		return
	me._last[name] = now
	me._starts.append(now)
	var db := vol
	if tier == 1 and now < me._duck_until:
		db -= 5.0
	elif tier >= 2:
		me._duck_until = now + (1800 if tier == 3 else 1200)
	if pos != Vector2.INF and me.camera and is_instance_valid(me.camera):
		var dist := pos.distance_to(me.camera.get_screen_center_position()) * me.camera.zoom.x
		if dist > 1100.0:
			return
		db += -2.0 - dist / 110.0
	if not me._players.has(name):
		me._players[name] = me._new_player(6)
	var p: AudioStreamPlayer = me._players[name]
	var st: AudioStream = list[randi() % list.size()]
	p.stream = prep(st)
	p.volume_db = db + gain(st)
	var j := float(JITTER.get(name, 0.07))
	p.pitch_scale = randf_range(1.0 - j, 1.0 + j)
	p.play()
	MatchLog.sound(name)


## A building you pick answers with its own short sound (select/<kind>, else the faction's).
## One at a time: picking building after building (or a box of them) doesn't pile them up.
static func building_selected(kind: String, faction: String) -> void:
	if me == null:
		return
	var now := Time.get_ticks_msec()
	if now - int(me._last.get("select/*", -99999)) < int(GAP.get("select/*", 40)):
		return
	me._last["select/*"] = now
	# (the Town Hall is picked for every worker: its note sits a little under the rest)
	play_any(["select/" + kind, "%s/select_building" % SHORT.get(faction, "crown")], Vector2.INF, -4.0 if kind == "town_hall" else 0.0)


## Sounds that come with a unit's answer: kind -> {what: [[sound, chance], ...]} (each sound's
## GAP keeps it from repeating: the horse at most every 6 s).
const VOICE_EXTRA := {"dragoon": {"select": [["horse/neigh", 0.7]], "move": [["horse/neigh", 0.25]]},
	"horseman": {"select": [["horse/neigh", 0.7]], "move": [["horse/neigh", 0.25]]},
	"horse": {"select": [["horse/neigh", 0.8]]},
	"cuirassier": {
	"select": [["horse/neigh", 0.7]],
	"move": [["combat/cuirassier_move", 1.0], ["horse/whinny", 0.33]],
	"attack": [["combat/cuirassier_move", 1.0], ["horse/whinny", 0.33]]}}


## The Crown's bugle (Brazilian Army Manual de Toques calls, tools/audio/make_bugle.py): "move",
## "amove", "charge", "patrol" or "trained". Crown only, and rarely (each call has its own GAP).
static func bugle(faction: String, what: String) -> void:
	if faction == "crown" and not me._voice.playing:        # (a unit's voice has priority over the bugle)
		play("voice/crown_bugle/" + what, Vector2.INF, -8.0)


## What the Crown plays when a building finishes a recruit: its own voice per building (the town
## hall the bugle, the Barracks a fife, the Foundry kettledrums). False for any other building.
static func recruit(b_kind: String, faction: String) -> bool:
	if faction != "crown" or me == null or me._find("voice/crown_recruit/" + b_kind).is_empty():
		return false
	play("voice/crown_recruit/" + b_kind, Vector2.INF, -6.0)
	return true


## A unit answering you: "select", "move" or "attack". One voice at a time.
static func voice(kind: String, what: String) -> void:
	if me == null:
		return
	# a mount answers too: hooves when sent off, and now and then the horse itself
	var extra: Dictionary = VOICE_EXTRA.get(kind, {})
	for x in extra.get(what, []):
		if randf() < float(x[1]):
			play(x[0], Vector2.INF, -4.0)
	if me._voice.playing:
		return
	var list := me._find("voice/%s/%s" % [kind, what])
	if list.is_empty() and what == "attack":
		list = me._find("voice/%s/move" % kind)
	if list.is_empty():
		return
	me._duck_until = Time.get_ticks_msec() + 1200
	var vs: AudioStream = list[randi() % list.size()]
	me._voice.stream = prep(vs)
	me._voice.volume_db = gain(vs)
	me._voice.play()
	MatchLog.sound("voice/%s/%s" % [kind, what])


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
	var an: AudioStream = list[randi() % list.size()]
	me._announcer.stream = prep(an)
	me._announcer.volume_db = gain(an)
	me._announcer.play()
	MatchLog.sound("announcer/%s/%s" % [s, line])


## An enemy AI commander's taunt.
static func taunt(faction: String) -> void:
	if me == null:
		return
	var list := me._find("voice/taunt/%s/taunt" % SHORT.get(faction, "crown"))
	if list.is_empty() or me._announcer.playing:
		return
	var ts: AudioStream = list[randi() % list.size()]
	me._announcer.stream = prep(ts)
	me._announcer.volume_db = gain(ts)
	me._announcer.play()
