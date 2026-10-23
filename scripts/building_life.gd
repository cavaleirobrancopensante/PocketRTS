class_name BuildingLife
extends RefCounted
## The little lives of the second-generation Crown buildings (tools/import_buildings_v2.py
## makes their art), each shown only while the building is in use, like the Powder Mill's
## horse (Building.MILL_ART):
##  - the Town Hall's and the Church's bell swings in the belfry while it trains (BELL_ART);
##  - a Musketeer drills on the Barracks' yard while it trains (DRILL_ART);
##  - horses walk about the Horse Breeder's paddock while it trains, one stands idle (PADDOCK_ART);
##  - the inventor plays the experiment of the research at the head of the Armoury queue on its roof (ARMOURY_ART; the old cannon test INVENTOR_ART is the fallback);
##  - the Church's windows glow while one of its side's Missionaries heals nearby (CHURCH_ART).
## Each part is a child of the building over its body (hidden with it under the fog), shown in
## the states that keep it (`states`: none while it's built up or a ruin), and only moves while
## the building is on screen and its side or the player sees it now (a building remembered
## under the fog stands still: its drilling man and its glow aren't shown). Nothing is
## allocated per frame.

## The bell (the Town Hall sheet's 4 frames: straight, tilted, straight, tilted the other way),
## per building scaled to its belfry: it hangs in the middle, behind the central pillar (where the
## yoke's top middle, `pivot` in the strip's cell, hangs per state, from the base point), and
## swings `swing` px out to both sides, into both of the belfry's openings; the belfry round the
## openings (its pillars and roof: `belfry` % state) is drawn over it, so at rest it is mostly
## hidden. While the building trains, a frame
## every BELL_DT s; idle it hangs still (frame 0: a swing under way finishes first). When a unit
## comes out, the hall's bell rings once, softly (the Town Hall's select sound).
const BELL_ART := {
	"town_hall": {"strip": "res://assets/buildings/town_hall_bell.png", "pivot": Vector2(10, 0),
		"belfry": "res://assets/buildings/town_hall_belfry_%s.png", "swing": 2.3, "lean": -1,
		"states": {"built": Vector2(2.4, -153.8), "damaged": Vector2(-1.8, -144.2)}},
	"church": {"strip": "res://assets/buildings/church_bell.png", "pivot": Vector2(5.5, 0),
		"belfry": "res://assets/buildings/church_belfry_%s.png", "swing": 1.3, "lean": -1,
		"states": {"built": Vector2(-26.3, -85.9)}},
}
## How far the bell is swung out of the middle in each of its 4 frames (of `swing`, towards the
## side frame 1 leans: `lean`): straight, out, straight, out the other way.
const BELL_SHIFT := [0.0, 1.0, 0.0, -1.0]
const BELL_FRAMES := 4
const BELL_DT := 0.25
const BELL_SOUND := "select/town_hall"
const BELL_VOLUME := -14.0

## The Barracks' yard: a straw DUMMY stands where the painted target was (the intact art; it
## flashes the ripped one for `flash` s when it is hit) and, while its side has a built Horse
## Breeder, a wooden vaulting-horse PROP stands on the yard's patch (checked twice a second).
## While it trains, the man being trained (the queue's first entry, his own sprites, team-coloured,
## shrunk to the building) drills there, a round of `every` s at least, looping, and the drill
## switches at once when the first entry changes (DRILL_MEN, _drill_plan):
##  - "shoot" (Musketeer, Guardsman: musket; Officer, Armoured Officer: pistol): he stands on the
##    patch facing the dummy (`feet`; `feet_prop` with the prop up, out of its way) and aims,
##    fires (a little smoke at his `muzzle` from his feet, a puff on the dummy; no damage, a very
##    quiet shot), reloads and stands;
##  - "sabre" (Horseman, Cuirassier): he mounts the prop (the mount strip with the horse taken
##    out: tools/import_barracks_props.py), swings his sabre at the dummy `swings` times (the
##    dummy shows the ripped art on each hit) and dismounts (the strip backwards). With no prop
##    (no breeder) he is the Officer on foot swinging his sabre at the dummy from `sabre`;
##  - "mount" (Dragoon, Armoured Dragoon): he climbs on the prop and off again, then stands next
##    to it (`side`) and shoots like a Musketeer (a Guardsman, armoured). With no prop he just shoots.
## `strip`: (art, anim); the frame counts are the unit art's (ArtData). `states`: where things
## stand per state, from the base point: `feet` / `feet_prop` / `side` / `sabre` the man's feet,
## `prop` the prop's floor middle (the mounted man's cell is put there: `floor`), `dummy` its
## foot, `target` what the shots hit. Only drawn while the building is on screen and seen,
## nothing is allocated per frame.
const DRILL_ART := {
	"strip": "res://assets/buildings/drill_%s/%s.png", "anchor": Vector2(32.4, 24.5), "floor": Vector2(42, 56),
	"prop": "res://assets/buildings/barracks_props/horse_prop.png",
	"dummy": ["res://assets/buildings/barracks_props/dummy_intact.png", "res://assets/buildings/barracks_props/dummy_damaged.png"],
	"states": {
		"built": {"feet": Vector2(15, -31), "feet_prop": Vector2(14, -15), "side": Vector2(14, -15), "sabre": Vector2(40, -30),
			"prop": Vector2(31, -22), "dummy": Vector2(54, -37), "target": Vector2(54, -50)},
		"damaged": {"feet": Vector2(16, -31), "feet_prop": Vector2(15, -15), "side": Vector2(15, -15), "sabre": Vector2(40, -30),
			"prop": Vector2(32, -22), "dummy": Vector2(53, -37), "target": Vector2(53, -50)},
	},
	"every": 3.0, "volume": -22.0, "flash": 0.35, "swings": 2,
}
## Who drills for what the Barracks trains (the queue's key; "art" / "foot" when armoured:
## "art_a" / "foot_a"). "art": the strips of the man himself; "foot": the man on foot he is
## with no prop.
const DRILL_MEN := {
	"musketeer": {"act": "shoot", "art": "musketeer", "art_a": "musketeer_armoured", "muzzle": Vector2(22, -15),
		"anims": [["aim_e", 0.25], ["fire_e", 0.15], ["reload_e", 0.2], ["idle_e", 0.35]]},
	"dismounted": {"act": "shoot", "art": "dismounted", "art_a": "dismounted_armoured", "muzzle": Vector2(9, -14), "muzzle_a": Vector2(17, -16),
		"anims": [["aim_e", 0.55], ["fire_e", 0.15], ["idle_e", 0.35]]},
	"cuirassier": {"act": "sabre", "art": "horseman", "art_a": "cuirassier", "foot": "dismounted", "foot_a": "dismounted_armoured"},
	"dragoon": {"act": "mount", "art": "dragoon", "art_a": "dragoon_armoured", "foot": "musketeer", "foot_a": "musketeer_armoured"},
}
## where a round's events fall
const EV_SHOT := 1
const EV_HIT := 2
const PLACE_FEET := 0       # on the patch (or out of the prop's way)
const PLACE_MOUNT := 1      # the mounted man's cell on the prop
const PLACE_SIDE := 2       # next to the prop
const PLACE_SABRE := 3      # beside the dummy

## The Horse Breeder's paddock: `busy` horses walk slowly about it while it trains, stopping now
## and then to stand or graze (`rest` s, from .. to); idle, `idle` of them stands still. They
## keep to an ellipse on the ground (`centre`, `radius`, from the base point) behind the fences'
## top rails, so nothing of the stable is in front of them. Loose horses, nobody's: the riderless
## horse's strips and coat masks shrunk to the building, team-neutral (Defs.NEUTRAL_CLOTH), each
## in a coat picked by the building's cell. `anchor`: the hooves in the strip's cell.
const PADDOCK_ART := {
	"strip": "res://assets/buildings/paddock_horse/%s_%s.png", "mask": "res://assets/buildings/paddock_horse/mask/%s_%s.png",
	"anchor": Vector2(20.6, 27.7),
	"states": {"built": {"centre": Vector2(14.2, -35.1), "radius": Vector2(22.0, 5.3)},
		"damaged": {"centre": Vector2(20.6, -34.0), "radius": Vector2(18.4, 5.0)}},
	"busy": 2, "idle": 1, "speed": 6.0, "walk_fps": 5.0, "graze_fps": 1.5, "rest": Vector2(1.5, 4.5),
}
const HORSE_ANIMS := ["idle", "walk", "graze"]
const HORSE_DIRS := ["s", "se", "e", "ne", "n"]

## The Armoury's inventor on its flat roof by the bench and the test stand (6 frames: tinkering,
## inspecting a part, lighting the fuse, the bang, stunned and sooty, scratching his head), one
## every `dt` s while it researches; on the bang a little flash and smoke at the test barrel's
## `muzzle` (from his feet) and a very quiet shot. Every `clean_every`th round the shot goes off
## cleanly: he isn't stunned (frame 5 skipped). Idle he isn't there. `feet`: where the
## bottom middle of his frame stands per state, from the base point.
const INVENTOR_ART := {
	"strip": "res://assets/buildings/armoury_inventor.png", "frames": 6, "anchor": Vector2(25.3, 53.3),
	"states": {"built": Vector2(8, -81), "damaged": Vector2(11, -81)},
	"dt": 0.6, "bang": 3, "stunned": 4, "clean_every": 3, "muzzle": Vector2(11.5, -31.2), "volume": -20.0,
}

## The Armoury's research experiments (tools/import_armoury_anims.py): while the research at the
## head of its queue ("@id") is worked on, the inventor plays that research's own 6-frame
## experiment (`strip` % id), one frame every `dt` s (the last, his gag, held `last_hold` x as long),
## round and round (a research takes 20-50 s, the loop about 5 s). `anchor`: his patch's bottom
## middle in the cell (every strip's patch is the old inventor's size, so it sits on the roof patch
## at INVENTOR_ART's `states` just like the old one). `fx`: effects on arriving at a frame, `at`
## from his feet; `shot` and `boom` are very quiet sounds, `splash` a small puff (the art draws
## the smoke, flashes and sparks itself). A research with no entry plays the old cannon test.
const ARMOURY_ART := {
	"strip": "res://assets/buildings/armoury_anim_%s.png", "frames": 6, "dt": 0.7, "last_hold": 1.6,
	"anims": {
		"armour": {"anchor": Vector2(24.7, 49.5), "fx": [{"f": 2, "kind": "shot", "vol": -22.0}]},
		"matchlock": {"anchor": Vector2(28.0, 58.9), "fx": [{"f": 3, "kind": "shot", "vol": -28.0}]},
		"flintlock": {"anchor": Vector2(24.6, 44.9), "fx": [{"f": 3, "kind": "shot", "vol": -22.0}]},
		"caplock": {"anchor": Vector2(24.6, 47.5), "fx": [{"f": 3, "kind": "shot", "vol": -22.0}]},
		"bayonet": {"anchor": Vector2(29.8, 41.1),
			"fx": [{"f": 3, "kind": "splash", "at": Vector2(14, -24), "tint": Color(1.0, 0.7, 0.2, 0.7)}]},
		"pouch": {"anchor": Vector2(25.2, 42.5), "fx": []},
		"charges": {"anchor": Vector2(26.7, 69.9), "fx": [{"f": 3, "kind": "boom", "vol": -22.0}]},
		"quadrant": {"anchor": Vector2(25.4, 72.5), "fx": [{"f": 3, "kind": "boom", "vol": -22.0},
			{"f": 4, "kind": "splash", "at": Vector2(12, -26), "tint": Color(0.7, 0.85, 1.0, 0.7)}]},
		"charge": {"anchor": Vector2(32.0, 51.8), "fx": []},
	},
}

## The Church's windows (the lit sheet's glow, `lit` % state, drawn over the body) light up while
## one of its side's Missionaries bandages or raises somebody within `radius` tiles of it:
## fading in and out over `fade` s, flickering a little like candles, and a thin wisp of smoke
## rises from the nave's chimney (`chimney`, from the base point) every `smoke_every` s.
const CHURCH_ART := {
	"lit": "res://assets/buildings/church_lit_%s.png",
	"states": {"built": Vector2(12, -88), "damaged": Vector2(14, -85)},
	"radius": 20.0, "fade": 0.8, "smoke_every": 1.1,
}

var b: Building
var rng := RandomNumberGenerator.new()
var _on := false              # on screen, and seen now (looked at every tick)
var training := false         # (twice a second) its queue isn't empty
var healing := false          # (twice a second) Church: a Missionary of its side heals nearby

# the bell
var bell: Sprite2D = null
var belfry: Sprite2D = null
var bell_state := ""
var bell_t := 0.0
var bell_dx := 0.0            # how far it is swung out of the middle (px)
var _bell: Dictionary = {}

# the Barracks' yard: the drilling man, the dummy and the horse prop
var man: Sprite2D = null
var dummy: Sprite2D = null
var prop: Sprite2D = null
var man_state := ""
var man_t := 0.0
var has_breeder := false      # (twice a second) its side has a built Horse Breeder
var _prop_on := false         # the prop stands (a breeder, and a state that keeps the yard)
var _dummy_t := 0.0           # (> 0) the dummy shows its ripped art for this many more seconds
var _plan_head := "-"         # what the round was planned for: the queue's first entry,
var _plan_armour := false     # whether it is armoured,
var _plan_prop := false       # and whether the prop stood
var _plan_muzzle := Vector2.ZERO
var _seg_tex: Array[Texture2D] = []     # the round, an anim at a time:
var _seg_n := PackedInt32Array()        #   its frames,
var _seg_dt := PackedFloat32Array()     #   seconds per frame,
var _seg_end := PackedFloat32Array()    #   when it ends in the round,
var _seg_flag := PackedInt32Array()     #   where he stands (PLACE_*) + 8 if played backwards + 16 if it loops
var _ev_t := PackedFloat32Array()       # when the round's events fall (EV_*)
var _ev_k := PackedInt32Array()
var _man_shown := -1

# the paddock's horses
var horses: Array[Sprite2D] = []
var pad_state := ""
var _pad_c := Vector2.ZERO
var _pad_r := Vector2.ONE
var _h_pos := PackedVector2Array()
var _h_goal := PackedVector2Array()
var _h_mode := PackedInt32Array()      # 0 standing, 1 walking, 2 grazing
var _h_wait := PackedFloat32Array()
var _h_f := PackedFloat32Array()
var _h_key := PackedInt32Array()       # the strip shown: anim * 8 + direction (-1: none yet)
var _h_flip: Array[bool] = []
var _h_default := PackedStringArray()    # the coat each wears with nothing queued (the building's own)
var _h_coat := PackedStringArray()       # the coat it wears now
var _h_tex: Array = []                  # [anim][dir] -> Texture2D
var _h_mask: Array = []
var _h_n: Array = []                    # [anim][dir] -> frames

# the inventor
var inv: Sprite2D = null
var inv_state := ""
var inv_t := 0.0
var inv_round := 0
var inv_frame := 0
var inv_head := ""            # the queue entry he is playing ("@id"); "" none
var inv_key := ""             # its experiment ("" the old cannon test)
var _inv_tex := {}            # research id -> its strip

# the Church's glow
var lit: Sprite2D = null
var lit_state := ""
var lit_v := 0.0
var _smoke_t := 0.0
var _clock := 0.0

# the Queen (Brood Burrows: shown at the capital only)
var queen: Sprite2D = null
var queen_state := ""


## The Brood Queen (tools/import_queen.py) sits at the front corner of the CAPITAL Burrow
## (Game.capital: the first one; if it falls she is at the next), whatever its level, while it
## is built (or damaged): a still sprite for now (no animation yet). `feet`: where her bottom
## middle stands, from the base point (x towards the right), scaled with the hall's level.
const QUEEN_ART := {"tex": "res://assets/buildings/brood_queen.png", "feet": Vector2(46, 6)}

static func has_life(kind: String) -> bool:
	return BELL_ART.has(kind) or kind == "hive" or kind == "barracks" or kind == "horse_breeder" or kind == "armoury"


func setup(building: Building) -> void:
	b = building
	rng.seed = hash(b.cell) + 77
	if BELL_ART.has(b.kind):
		_bell = BELL_ART[b.kind]
		bell = _sprite(Game.tex(_bell["strip"]), BELL_FRAMES, -Vector2(_bell["pivot"]))
		belfry = _sprite(null, 1, Vector2.ZERO)
	match b.kind:
		"barracks":
			_drill_setup()
		"horse_breeder":
			_paddock_setup()
		"armoury":
			inv = _sprite(Game.tex(INVENTOR_ART["strip"]), int(INVENTOR_ART["frames"]), -Vector2(INVENTOR_ART["anchor"]))
			inv.material = b.team_material()
			for k: String in ARMOURY_ART["anims"]:
				var path: String = String(ARMOURY_ART["strip"]) % k
				if ResourceLoader.exists(path):
					_inv_tex[k] = Game.tex(path)
		"church":
			lit = _sprite(null, 1, Vector2.ZERO)
		"hive":
			var qt := Game.tex(QUEEN_ART["tex"])
			if qt:
				queen = _sprite(qt, 1, -Vector2(qt.get_width() * 0.5, qt.get_height()))


func _sprite(t: Texture2D, frames: int, offset: Vector2) -> Sprite2D:
	var s := Sprite2D.new()
	s.centered = false
	s.texture = t
	s.hframes = frames
	s.offset = offset
	s.visible = false
	b.add_child(s)
	return s


## The building's picture changed (its state): which parts it shows.
func show(state: String) -> void:
	var alive := b.seeded and not b.dead
	if bell:
		var bs := state if alive and Dictionary(_bell["states"]).has(state) else ""
		if bs != bell_state:
			bell_state = bs
			bell.visible = bs != ""
			belfry.visible = bs != ""
			bell_dx = 0.0
			if bs != "":
				bell.position = _bell["states"][bs]
				belfry.texture = Game.tex(String(_bell["belfry"]) % bs)
		if bs != "":
			belfry.position = b.sprite.position
			belfry.offset = b.sprite.offset
	if man:
		var ms := state if alive and Dictionary(DRILL_ART["states"]).has(state) else ""
		if ms != man_state:
			man_state = ms
			man.visible = false      # (shown by tick while it trains)
			_man_shown = -1
			_dummy_t = 0.0
			dummy.visible = ms != ""
			dummy.texture = Game.tex(DRILL_ART["dummy"][0])
			if ms != "":
				dummy.position = DRILL_ART["states"][ms]["dummy"]
				prop.position = DRILL_ART["states"][ms]["prop"]
			_show_prop()
	if not horses.is_empty():
		var ps := state if alive and Dictionary(PADDOCK_ART["states"]).has(state) else ""
		if ps != pad_state:
			pad_state = ps
			if ps != "":
				_pad_c = PADDOCK_ART["states"][ps]["centre"]
				_pad_r = PADDOCK_ART["states"][ps]["radius"]
				for i in horses.size():
					_h_pos[i] = _in_paddock(0.8)
					_h_goal[i] = _h_pos[i]
					_h_mode[i] = 0
					_h_wait[i] = rng.randf_range(0.0, 2.0)
					_place_horse(i, true)
			_show_horses()
			_paddock_coats()
	if inv:
		var s := state if alive and Dictionary(INVENTOR_ART["states"]).has(state) else ""
		if s != inv_state:
			inv_state = s
			inv.visible = false
			if s != "":
				inv.position = INVENTOR_ART["states"][s]
	if queen:
		queen_state = state if alive and b.built and (state == "built" or state == "damaged") else ""
		_show_queen()
	if lit:
		var s := state if alive and Dictionary(CHURCH_ART["states"]).has(state) else ""
		if s != lit_state:
			lit_state = s
			if s != "":
				lit.texture = Game.tex(String(CHURCH_ART["lit"]) % s)
			lit.visible = s != "" and lit_v > 0.0
		if s != "":
			lit.position = b.sprite.position
			lit.offset = b.sprite.offset


## The Queen is shown while this is the capital and built; at the hall's level scale.
func _show_queen() -> void:
	var on := queen_state != "" and b.game.capital(b.team) == b
	queen.visible = on
	if on:
		var k := float(b.level_info().get("scale", 1.0))
		queen.scale = Vector2(k, k)
		queen.position = Vector2(QUEEN_ART["feet"]) * k


## (twice a second, after Building._check_use) what drives the parts.
func check() -> void:
	training = b.built and not b.dead and not b.queue.is_empty()
	if queen:
		_show_queen()
	if lit and lit_state != "":
		healing = false
		var r2 := pow(float(CHURCH_ART["radius"]) * Defs.TILE, 2.0)
		var c := b.center()
		for u in b.game.units:
			if u.team == b.team and not u.dead and (u.work == "bandaging" or u.work == "reviving") \
					and u.position.distance_squared_to(c) <= r2:
				healing = true
				break
	if man:
		var pv := false
		for o: Building in b.game.buildings:
			if o.team == b.team and o.kind == "horse_breeder" and o.built and not o.dead:
				pv = true
				break
		if pv != has_breeder:
			has_breeder = pv
			_show_prop()
	if not horses.is_empty():
		_show_horses()
		_paddock_coats()


## A unit came out of it.
func trained() -> void:
	if bell and bell_state != "" and b.visible and b._seen_now and b.game.view_rect.has_point(b.global_position):
		Sfx.play(BELL_SOUND, b.center(), BELL_VOLUME)


func tick(delta: float) -> void:
	_on = b._seen_now and b.game.view_rect.intersects(b.sprite_rect())
	if bell and bell_state != "":
		_swing_bell(delta)
	if man:
		_drill(delta)
	if pad_state != "":
		_paddock(delta)
	if inv:
		_invent(delta)
	if lit:
		_glow(delta)


# ---------------------------------------------------------------- the bell

func _swing_bell(delta: float) -> void:
	if not _on:
		return
	if training or bell.frame != 0:
		bell_t += delta
		if bell_t >= BELL_DT:
			bell_t -= BELL_DT
			bell.frame = (bell.frame + 1) % BELL_FRAMES
	else:
		bell_t = 0.0
	# (it swings out and back with the frames, at a steady pace: a frame's time to cross over)
	var swing: float = float(_bell["swing"])
	var goal: float = swing * float(_bell["lean"]) * float(BELL_SHIFT[bell.frame])
	bell_dx = move_toward(bell_dx, goal, swing / BELL_DT * delta)
	bell.position.x = Vector2(_bell["states"][bell_state]).x + bell_dx


# ---------------------------------------------------------------- the drill

func _drill_setup() -> void:
	dummy = _sprite(Game.tex(DRILL_ART["dummy"][0]), 1, Vector2.ZERO)
	dummy.offset = _foot_offset(dummy.texture)
	prop = _sprite(Game.tex(DRILL_ART["prop"]), 1, Vector2.ZERO)
	prop.offset = _foot_offset(prop.texture)
	man = _sprite(null, 1, -Vector2(DRILL_ART["anchor"]))
	man.material = b.sprite.material          # (his side's colours; the props keep their own)


## A prop's offset: its bottom middle on its position.
func _foot_offset(t: Texture2D) -> Vector2:
	return -Vector2(floorf(t.get_width() / 2.0), t.get_height())


## The horse prop stands while the side has a breeder (and the yard is whole enough to keep it).
func _show_prop() -> void:
	var on := has_breeder and man_state != ""
	if on != _prop_on:
		_prop_on = on
		_man_shown = -1
	prop.visible = on


## Adds an anim to the round (after `t`); returns when it ends. `hold`: s it stays on its last
## frame; `fill`: it lasts to the end of the round (at least); `loop`: its frames repeat.
func _seg(art: String, anim: String, dt: float, place: int, t: float, back := false, hold := 0.0, fill := false, loop := false) -> float:
	var n := int(ArtData.UNITS[art]["frames"].get(anim, 1))
	_seg_tex.append(Game.tex(String(DRILL_ART["strip"]) % [art, anim]))
	_seg_n.append(n)
	_seg_dt.append(dt)
	var e := t + dt * n + hold
	if fill:
		e = maxf(e, float(DRILL_ART["every"]))
	_seg_end.append(e)
	_seg_flag.append(place + (8 if back else 0) + (16 if loop else 0))
	return e


func _ev(t: float, kind: int) -> void:
	_ev_t.append(t)
	_ev_k.append(kind)


## The round for the man being trained (`key`: the queue's first entry), armoured or not, with
## or without the prop: see DRILL_ART.
func _drill_plan(key: String, armoured: bool) -> void:
	_seg_tex.clear()
	_seg_n.clear()
	_seg_dt.clear()
	_seg_end.clear()
	_seg_flag.clear()
	_ev_t.clear()
	_ev_k.clear()
	man_t = 0.0
	_man_shown = -1
	var info: Dictionary = DRILL_MEN.get(key, DRILL_MEN["musketeer"])
	var act := String(info["act"])
	var art := String(info["art_a"] if armoured else info["art"])
	var foot := String(info.get("foot_a" if armoured else "foot", art))
	var t := 0.0
	if act == "sabre" and _prop_on:
		t = _seg(art, "mount_e", 0.13, PLACE_MOUNT, t)
		for k in int(DRILL_ART["swings"]):
			t = _seg(art, "idle_e", 0.15, PLACE_MOUNT, t)
			_ev(t + 0.22, EV_HIT)
			t = _seg(art, "attack_e", 0.11, PLACE_MOUNT, t)
		t = _seg(art, "idle_e", 0.15, PLACE_MOUNT, t)
		t = _seg(art, "mount_e", 0.1, PLACE_MOUNT, t, true, 0.8, true)
	elif act == "sabre":
		# no prop to get on: the Officer on foot swings the sabre at the dummy
		for k in int(DRILL_ART["swings"]):
			t = _seg(foot, "idle_e", 0.2, PLACE_SABRE, t)
			_ev(t + 0.12, EV_HIT)
			t = _seg(foot, "melee_e", 0.12, PLACE_SABRE, t)
		t = _seg(foot, "idle_e", 0.35, PLACE_SABRE, t, false, 0.0, true, true)
	else:
		var place := PLACE_FEET
		var shoot: Dictionary = info
		if act == "mount":
			shoot = DRILL_MEN["musketeer"]
			art = foot
			if _prop_on:
				t = _seg(String(info["art_a"] if armoured else info["art"]), "mount_e", 0.13, PLACE_MOUNT, t, false, 0.4)
				t = _seg(String(info["art_a"] if armoured else info["art"]), "mount_e", 0.1, PLACE_MOUNT, t, true)
				place = PLACE_SIDE
		_plan_muzzle = shoot["muzzle_a"] if armoured and shoot.has("muzzle_a") else shoot["muzzle"]
		var anims: Array = shoot["anims"]
		for i in anims.size():
			var last := i == anims.size() - 1
			t = _seg(art, String(anims[i][0]), float(anims[i][1]), place, t, false, 0.0, last, last)
			if i == 0:
				_ev(t, EV_SHOT)
	_seg_end[_seg_end.size() - 1] = maxf(t, float(DRILL_ART["every"]) if act != "sabre" else 0.0)


## Is the planned round still the right one? (the queue's first entry, armour, the prop)
func _drill_check_plan() -> void:
	var head := ""
	var armoured := false
	if not b.queue.is_empty():
		head = b.queue[0]
		if not b.kits.is_empty() and b.kits[0] is Dictionary:
			armoured = bool(b.kits[0].get("armour", false))
	if head == _plan_head and armoured == _plan_armour and _prop_on == _plan_prop:
		return
	_plan_head = head
	_plan_armour = armoured
	_plan_prop = _prop_on
	_drill_plan(head, armoured)


func _drill(delta: float) -> void:
	var want := man_state != "" and b._in_use and b._seen_now
	if not want:
		if man.visible:
			man.visible = false
		man_t = 0.0
		if _dummy_t > 0.0:
			_dummy_t = 0.0
			dummy.texture = Game.tex(DRILL_ART["dummy"][0])
		return
	if not _on:
		return
	_drill_check_plan()
	if _dummy_t > 0.0:
		_dummy_t -= delta
		if _dummy_t <= 0.0:
			dummy.texture = Game.tex(DRILL_ART["dummy"][0])
	man.visible = true
	var prev := man_t
	var total: float = _seg_end[_seg_end.size() - 1]
	man_t = fmod(man_t + delta, total)
	for e in _ev_t.size():
		var et := _ev_t[e]
		if (et > prev and et <= man_t) or (man_t < prev and (et > prev or et <= man_t)):
			_drill_event(_ev_k[e])
	var i := 0
	var start := 0.0
	while i < _seg_end.size() - 1 and man_t >= _seg_end[i]:
		start = _seg_end[i]
		i += 1
	if i != _man_shown:
		_man_shown = i
		_drill_place(i)
	var fl := _seg_flag[i]
	var n := _seg_n[i]
	var f := int((man_t - start) / _seg_dt[i])
	f = f % n if fl & 16 else mini(f, n - 1)
	man.frame = n - 1 - f if fl & 8 else f


## The man's strip and where he stands for anim `i` of the round.
func _drill_place(i: int) -> void:
	var fl := _seg_flag[i]
	var st: Dictionary = DRILL_ART["states"][man_state]
	man.texture = _seg_tex[i]
	man.hframes = _seg_n[i]
	match fl & 7:
		PLACE_MOUNT:
			man.position = st["prop"]
			man.offset = -Vector2(DRILL_ART["floor"])
			return
		PLACE_SIDE:
			man.position = st["side"]
		PLACE_SABRE:
			man.position = st["sabre"]
		_:
			man.position = st["feet_prop"] if _prop_on else st["feet"]
	man.offset = -Vector2(DRILL_ART["anchor"])


func _drill_event(kind: int) -> void:
	var st: Dictionary = DRILL_ART["states"][man_state]
	var tp := b.global_position + Vector2(st["target"])
	if kind == EV_SHOT:
		var p := b.global_position + man.position + _plan_muzzle
		var fx := b.game.spawn_effect("smoke", p + Vector2(4, 0), 1.2)
		fx.scale = Vector2(0.35, 0.35)
		fx.modulate = Color(1, 1, 1, 0.75)
		Sfx.play_any(["combat/musketeer_attack", "musket"], p, float(DRILL_ART["volume"]))
	else:
		Sfx.play_any(["combat/cuirassier_attack", "combat/horseman_attack"], tp, float(DRILL_ART["volume"]) - 2.0)
	var hit := b.game.spawn_effect("dust", tp + Vector2(0, 4), 1.6)
	hit.scale = Vector2(0.22, 0.22)
	hit.modulate = Color(1.0, 0.92, 0.6, 0.8)
	_dummy_t = float(DRILL_ART["flash"])
	dummy.texture = Game.tex(DRILL_ART["dummy"][1])


# ---------------------------------------------------------------- the paddock

func _paddock_setup() -> void:
	var frames: Dictionary = ArtData.UNITS["horse"]["frames"]
	for a in HORSE_ANIMS:
		var tr: Array[Texture2D] = []
		var mr: Array[Texture2D] = []
		var nr := PackedInt32Array()
		for d in HORSE_DIRS:
			tr.append(Game.tex(String(PADDOCK_ART["strip"]) % [a, d]))
			mr.append(Game.tex(String(PADDOCK_ART["mask"]) % [a, d]))
			nr.append(int(frames.get("%s_%s" % [a, d], 1)))
		_h_tex.append(tr)
		_h_mask.append(mr)
		_h_n.append(nr)
	var n := maxi(int(PADDOCK_ART["busy"]), int(PADDOCK_ART["idle"]))
	var shader: Shader = (b.sprite.material as ShaderMaterial).shader
	# two different coats, by the cell (the same every time)
	var first := posmod(hash(b.cell), HorseCoat.COATS.size())
	for i in n:
		var s := _sprite(null, 1, -Vector2(PADDOCK_ART["anchor"]))
		var m := ShaderMaterial.new()
		m.shader = shader
		m.set_shader_parameter("team", Defs.NEUTRAL_CLOTH)
		var coat: String = HorseCoat.COATS[(first + i * 2) % HorseCoat.COATS.size()]
		m.set_shader_parameter("coat", -1 if coat == HorseCoat.NATIVE["horse"] else HorseCoat.COATS.find(coat))
		m.set_shader_parameter("coat_ramps", HorseCoat.RAMPS)
		s.material = m
		_h_default.append(coat)
		_h_coat.append(coat)
		horses.append(s)
		_h_pos.append(Vector2.ZERO)
		_h_goal.append(Vector2.ZERO)
		_h_mode.append(0)
		_h_wait.append(0.0)
		_h_f.append(0.0)
		_h_key.append(-1)
		_h_flip.append(false)


## How many horses stand in it now: `busy` while it trains, else `idle`.
func horses_shown() -> int:
	if pad_state == "":
		return 0
	return int(PADDOCK_ART["busy"]) if b._in_use else int(PADDOCK_ART["idle"])


## The paddock's busy horses wear the coats of the horses queued at the breeder (the first
## queued horse's on the first one, ...; the rest, and idle ones, keep the building's own).
func _paddock_coats() -> void:
	for i in horses.size():
		var coat := _h_default[i]
		if b._in_use:
			var k := 0
			for q in b.queue.size():
				if String(b.queue[q]) != "horse":
					continue
				if k == i:
					if q < b.kits.size() and b.kits[q] is Dictionary and HorseCoat.COATS.has(String(b.kits[q].get("coat", ""))):
						coat = String(b.kits[q]["coat"])
					break
				k += 1
		if coat != _h_coat[i]:
			_h_coat[i] = coat
			(horses[i].material as ShaderMaterial).set_shader_parameter("coat", -1 if coat == HorseCoat.NATIVE["horse"] else HorseCoat.COATS.find(coat))


func _show_horses() -> void:
	var n := horses_shown()
	for i in horses.size():
		var v := i < n
		if horses[i].visible != v:
			horses[i].visible = v
			if not v:
				_h_mode[i] = 0


## A point inside the paddock's ellipse (`k` of its size).
func _in_paddock(k: float) -> Vector2:
	var a := rng.randf() * TAU
	var r := sqrt(rng.randf()) * k
	return _pad_c + Vector2(_pad_r.x * cos(a), _pad_r.y * sin(a)) * r


func _paddock(delta: float) -> void:
	if not _on:
		return
	var busy := b._in_use
	var spd := float(PADDOCK_ART["speed"])
	for i in horses.size():
		if not horses[i].visible:
			continue
		if not busy:
			# idle: it stands still where it is
			if _h_mode[i] != 0:
				_h_mode[i] = 0
				_place_horse(i, true)
			continue
		match _h_mode[i]:
			1:
				var to := _h_goal[i] - _h_pos[i]
				var step := spd * delta
				if to.length() <= step:
					_h_pos[i] = _h_goal[i]
					_h_mode[i] = 2 if rng.randf() < 0.5 else 0
					_h_wait[i] = rng.randf_range(PADDOCK_ART["rest"].x, PADDOCK_ART["rest"].y)
					_h_f[i] = 0.0
				else:
					_h_pos[i] += to / to.length() * step
					_h_f[i] += delta * float(PADDOCK_ART["walk_fps"])
			_:
				_h_wait[i] -= delta
				if _h_mode[i] == 2:
					_h_f[i] += delta * float(PADDOCK_ART["graze_fps"])
				if _h_wait[i] <= 0.0:
					_h_goal[i] = _goal_for(i)
					_h_mode[i] = 1
		_place_horse(i, false)
	# the nearer horse over the farther one
	if horses.size() >= 2 and horses[0].visible and horses[1].visible:
		var front0 := _h_pos[0].y > _h_pos[1].y
		if front0 != (horses[0].get_index() > horses[1].get_index()):
			var i0 := horses[0].get_index()
			var i1 := horses[1].get_index()
			b.move_child(horses[0], i1)
			b.move_child(horses[1], i0)


## Somewhere to walk to: inside the paddock, not where the other horse is going.
func _goal_for(i: int) -> Vector2:
	var p := _in_paddock(0.9)
	for k in 6:
		var ok := true
		for j in horses.size():
			if j != i and horses[j].visible and (p.distance_to(_h_goal[j]) < 12.0 or p.distance_to(_h_pos[j]) < 10.0):
				ok = false
		if ok and p.distance_to(_h_pos[i]) > 6.0:
			break
		p = _in_paddock(0.9)
	return p


## The horse's strip for what it's doing and where it faces, and its frame.
func _place_horse(i: int, still: bool) -> void:
	var s := horses[i]
	var mode := _h_mode[i]
	var anim := 1 if mode == 1 else (2 if mode == 2 else 0)
	var key := _h_key[i]
	var o := key % 8 if key >= 0 else (2 if rng.randf() < 0.5 else 6)      # (first: side on)
	if mode == 1:
		var v := _h_goal[i] - _h_pos[i]
		if v.length_squared() > 0.01:
			o = posmod(int(round(v.angle() / (PI / 4.0))), 8)
	var nk := anim * 8 + o
	if nk != key:
		_h_key[i] = nk
		var df: Array = Unit.DIR_FLIP[o]
		var di := HORSE_DIRS.find(String(df[0]))
		s.texture = _h_tex[anim][di]
		s.hframes = int(_h_n[anim][di])
		s.flip_h = df[1]
		(s.material as ShaderMaterial).set_shader_parameter("horse_mask", _h_mask[anim][di])
		if df[1]:
			s.offset.x = -(float(s.texture.get_width()) / s.hframes - Vector2(PADDOCK_ART["anchor"]).x)
		else:
			s.offset.x = -Vector2(PADDOCK_ART["anchor"]).x
	s.frame = 0 if still or mode == 0 else int(_h_f[i]) % s.hframes
	s.position = _h_pos[i].round()


# ---------------------------------------------------------------- the inventor

func _invent(delta: float) -> void:
	var want := inv_state != "" and b._in_use and b._seen_now and not b.queue.is_empty() \
			and Building.is_research(String(b.queue[0]))
	if not want:
		if inv.visible:
			inv.visible = false
		inv_t = 0.0
		inv_frame = 0
		inv_head = ""
		return
	var head: String = b.queue[0]
	if head != inv_head:
		_invent_switch(head)
	if not _on:
		return
	if not inv.visible:
		inv.visible = true
		inv.frame = inv_frame
	inv_t += delta
	var dt := float(INVENTOR_ART["dt"])
	var n := int(INVENTOR_ART["frames"])
	if inv_key != "":
		dt = float(ARMOURY_ART["dt"])
		if inv_frame == n - 1:
			dt *= float(ARMOURY_ART["last_hold"])
	if inv_t < dt:
		return
	inv_t -= dt
	var f := inv_frame + 1
	if inv_key == "" and f == int(INVENTOR_ART["stunned"]) and inv_round % int(INVENTOR_ART["clean_every"]) == int(INVENTOR_ART["clean_every"]) - 1:
		f += 1                    # a clean shot: not stunned this time
	if f >= n:
		f = 0
		inv_round += 1
	inv_frame = f
	inv.frame = f
	if inv_key != "":
		_invent_fx(f)
	elif f == int(INVENTOR_ART["bang"]):
		var p := b.global_position + inv.position + Vector2(INVENTOR_ART["muzzle"])
		var fl := b.game.spawn_effect("blast", p, 1.6)
		fl.scale = Vector2(0.3, 0.3)
		var sm := b.game.spawn_effect("smoke", p + Vector2(3, -2), 1.0)
		sm.scale = Vector2(0.4, 0.4)
		sm.modulate = Color(1, 1, 1, 0.8)
		Sfx.play_any(["combat/musketeer_attack", "musket"], p, float(INVENTOR_ART["volume"]))


## The head of the queue changed: his experiment is that research's (or the old cannon test).
func _invent_switch(head: String) -> void:
	inv_head = head
	var id := head.substr(1)
	inv_t = 0.0
	inv_frame = 0
	inv_round = 0
	if _inv_tex.has(id):
		inv_key = id
		inv.texture = _inv_tex[id]
		inv.offset = -Vector2(ARMOURY_ART["anims"][id]["anchor"])
	else:
		inv_key = ""
		inv.texture = Game.tex(INVENTOR_ART["strip"])
		inv.offset = -Vector2(INVENTOR_ART["anchor"])
	inv.frame = 0


func _invent_fx(f: int) -> void:
	for e: Dictionary in ARMOURY_ART["anims"][inv_key]["fx"]:
		if int(e["f"]) != f:
			continue
		var p: Vector2 = b.global_position + inv.position + Vector2(e.get("at", Vector2.ZERO))
		match String(e["kind"]):
			"shot":
				Sfx.play_any(["combat/musketeer_attack", "musket"], p, float(e["vol"]))
			"boom":
				Sfx.play_any(["combat/mortar_attack", "boom"], p, float(e["vol"]))
			"splash":
				var d := b.game.spawn_effect("dust", p, 1.4)
				d.scale = Vector2(0.3, 0.3)
				d.modulate = e["tint"]


# ---------------------------------------------------------------- the Church's glow

func _glow(delta: float) -> void:
	var want := lit_state != "" and healing and b._seen_now
	if not b._seen_now:
		lit_v = 0.0          # (remembered under the fog: dark)
	if not _on:
		if lit.visible != (lit_v > 0.0 and lit_state != ""):
			lit.visible = lit_v > 0.0 and lit_state != ""
		return
	_clock += delta
	lit_v = move_toward(lit_v, 1.0 if want else 0.0, delta / float(CHURCH_ART["fade"]))
	var show := lit_v > 0.0 and lit_state != ""
	if lit.visible != show:
		lit.visible = show
	if not show:
		return
	# candles: a slow wavering and a quicker flutter
	var fl := 0.88 + 0.07 * sin(_clock * 5.3) + 0.05 * sin(_clock * 13.7 + 1.3)
	lit.modulate.a = smoothstep(0.0, 1.0, lit_v) * fl
	if lit_v >= 0.5:
		_smoke_t -= delta
		if _smoke_t <= 0.0:
			_smoke_t = float(CHURCH_ART["smoke_every"])
			var p := b.global_position + Vector2(CHURCH_ART["states"][lit_state]) + Vector2(rng.randf_range(-1, 1), 0)
			var sm := b.game.spawn_effect("smoke", p, 0.6)
			sm.scale = Vector2(0.22, 0.3)
			sm.modulate = Color(0.85, 0.85, 0.85, 0.45)
