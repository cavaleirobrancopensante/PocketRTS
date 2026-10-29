class_name Spectator
extends Node
## Watching computers play (a demo match: no "you" in the lobby). The VIEW dropdown on
## the HUD (or the keys 0-4) picks how:
##   all     free camera, no fog (the default)
##   free    free camera, one player's fog of war
##   follow  a director drives the camera to show what that player is doing, under its fog
## Touching the camera while following drops to "free" with the same player's vision.

const THINK := 1.0          # seconds between looks for a point of interest
const HOLD := 3.0           # seconds a point is held before the camera may switch
const FIGHT_R := 300.0      # px: units this close count as one fight
const FIGHT_KEEP := 450.0   # px: a fight that drifts this far is still the same fight
const FADE := 0.16          # seconds to fade out (and in) on a long cut
const QUIET := 3.0          # seconds a watched fight must stay quiet before it's over

## Remembered for the session: the next demo match opens in the same view.
static var last_mode := "all"
static var last_team := 0

var game: Game
var mode := "all"
var team := 0

var poi := Vector2.INF      # where the follow camera is heading
var poi_kind := ""          # fight, attack, defend, build, army, hall
var poi_t := 0.0            # seconds on this point
var history: Array = []     # [clock, kind, point, camera] each time the point changes (for tests)
var fade := 0.0             # 0..1: black over the map during a cut
var _fade_dir := 0          # 1 fading out, -1 fading in
var _think_t := 0.0
var _quiet := 0.0           # how long the watched fight has been quiet


func _ready() -> void:
	if last_mode != "all" and last_team < game.n_players():
		set_mode(last_mode, last_team, true)


func label_for(m: String, t: int) -> String:
	if m == "all":
		return "Free · all vision"
	var who := "P%d %s" % [t + 1, game.faction_of(t).capitalize()]
	return ("Follow · " + who) if m == "follow" else ("Free · %s vision" % who)


func label() -> String:
	return label_for(mode, team)


## The dropdown's rows: [label, mode, team, enabled].
func options() -> Array:
	var out: Array = [[label_for("all", 0), "all", 0, true]]
	for t in game.n_players():
		out.append([label_for("follow", t), "follow", t, not game.eliminated[t]])
	for t in game.n_players():
		out.append([label_for("free", t), "free", t, not game.eliminated[t]])
	return out


func set_mode(m: String, t: int, quiet := false) -> void:
	if not game.demo:
		return              # (only ever while watching computers: never in a game you play)
	if m != "all" and (t < 0 or t >= game.n_players()):
		return
	mode = m
	team = t
	last_mode = m
	last_team = t
	game.view_team = -1 if m == "all" else t
	game.refresh_fog()
	if m == "follow":
		poi = Vector2.INF
		poi_kind = ""
		_think_t = 0.0
	if not quiet and game.hud:
		game.hud.toast(label(), false)


## Keys 0-4 (computer): 0 all vision, 1-4 follow that player. True if used.
func hotkey(n: int) -> bool:
	if n == 0:
		set_mode("all", 0)
		return true
	if n >= 1 and n <= game.n_players():
		if game.eliminated[n - 1]:
			game.hud.toast("P%d is out." % n, false)
		else:
			set_mode("follow", n - 1)
		return true
	return false


## The player moved the camera (drag, edge or arrow pan, minimap, a jump): following stops.
func user_moved() -> void:
	if game.replay and game.replay.cam_team >= 0:
		game.replay.follow_camera(-1)        # (a replay: moving the camera yourself lets go of the recorded one)
	if mode != "follow":
		return
	set_mode("free", team, true)
	fade = 0.0
	_fade_dir = 0
	if game.hud:
		game.hud.toast("Free camera · P%d's vision (pick Follow again to resume)" % (team + 1), false)


func _process(delta: float) -> void:
	if game == null or game.over:
		return
	if mode != "all" and game.eliminated[team]:
		var gone := team
		set_mode("all", 0, true)
		if game.hud:
			game.hud.toast("P%d is out: back to all vision." % (gone + 1), false)
		return
	if mode != "follow":
		return
	poi_t += delta
	_think_t -= delta
	if _think_t <= 0.0:
		_think_t = THINK
		_choose()
	_move(delta)


# ------------------------------------------------------------------ the director

func _choose() -> void:
	var c := _candidate()
	if c.is_empty():
		return
	var kind: String = c[0]
	var at: Vector2 = c[1]
	if poi == Vector2.INF:
		_switch(kind, at)
		return
	if kind == poi_kind and at.distance_to(poi) < FIGHT_KEEP:
		poi = at        # the same thing, moved on: keep tracking it
		return
	# hold every point long enough to watch; a quiet look home waits longer before
	# taking the camera away from something
	if poi_t < (HOLD * 2.0 if kind in ["army", "hall"] else HOLD):
		return
	_switch(kind, at)


func _switch(kind: String, at: Vector2) -> void:
	_quiet = 0.0
	poi_kind = kind
	poi = at
	poi_t = 0.0
	history.append([game.clock, kind, at, game.camera.position])


## The most interesting thing the followed player is doing: [kind, point], in order:
## its fight (the biggest, but the one being watched until it ends), its army on the
## attack, raiders at home, a building it just placed, its army, its hall.
func _candidate() -> Array:
	var fights := _fights()
	if poi_kind == "fight":
		# stay with the fight being watched while it goes on (a lull between volleys
		# doesn't end it)
		for f in fights:
			if (f[0] as Vector2).distance_to(poi) < FIGHT_KEEP:
				_quiet = 0.0
				return ["fight", f[0]]
		_quiet += THINK
		if _quiet < QUIET:
			return ["fight", poi]
	if not fights.is_empty():
		var best: Array = fights[0]
		for f in fights:
			if float(f[1]) > float(best[1]):
				best = f
		return ["fight", best[0]]
	var ai := _ai()
	var army := game.army(team).filter(func(u: Unit) -> bool: return not u.off_field)
	if ai and ai._attacking and army.size() >= 2:
		var mass := _densest(army)
		var tgt: Vector2 = ai._wave_target
		if tgt != Vector2.ZERO:
			mass += (tgt - mass).limit_length(140.0)     # a little ahead, where it's going
		return ["attack", mass]
	if ai:
		var th: Vector2 = ai._threat()
		if th != Vector2.INF:
			return ["defend", th]
	var lp: Dictionary = game.last_placed[team]
	if not lp.is_empty():
		var hall := String(lp["kind"]) == game.faction_hall(team)
		if game.clock - float(lp["t"]) < (14.0 if hall else 7.0):
			return ["build", lp["at"]]
	if army.size() >= 3:
		return ["army", _densest(army)]
	var h := game._own_hall(team)
	if h:
		return ["hall", h.center()]
	return []


func _ai() -> AI:
	for a in game.ais:
		if a.team == team:
			return a
	return null


static func _worth(e: Entity) -> float:
	if e is Unit:
		var d: Dictionary = (e as Unit).d
		return float(d.get("cost", 50)) / maxf(1.0, float(d.get("spawn", 1))) + 10.0
	return 60.0


## Fights the followed player is in: [[centre, value]]. A unit is fighting when it was
## hit in the last 3 s or has an enemy target close by; a building when it was hit.
func _fights() -> Array:
	var mine: Array = []
	var foes: Array = []
	for u in game.units:
		if u.dead or u.off_field or u.aboard != null:
			continue
		var ours: bool = u.team == team
		if not ours and not game.hostile(u.team, team):
			continue
		var busy: bool = game.clock - u.hit_clock < 3.0
		if not busy and u.target != null and is_instance_valid(u.target) and not u.target.dead \
				and game.hostile(u.target.team, u.team) and u.position.distance_to(u.target.global_position) < FIGHT_R:
			busy = true
		if busy:
			(mine if ours else foes).append(u)
	for b in game.buildings:
		if b.team == team and not b.dead and game.clock - b.hit_clock < 3.0:
			mine.append(b)
	var out: Array = []
	var used := {}
	for s0 in mine:
		if used.has(s0):
			continue
		var sp: Vector2 = s0.center() if s0 is Building else s0.global_position
		var c := Vector2.ZERO
		var n := 0
		var value := 0.0
		var enemy := false
		for e in mine + foes:
			if used.has(e):
				continue
			var p: Vector2 = e.center() if e is Building else e.global_position
			if p.distance_to(sp) < FIGHT_R:
				used[e] = true
				c += p
				n += 1
				value += _worth(e)
				if e.team != team or e is Building:
					enemy = true
		if n > 0 and enemy:
			out.append([c / n, value])
	return out


## The centre of the thickest part of a group (not the average of a strung-out line).
func _densest(list: Array) -> Vector2:
	var best := Vector2.ZERO
	var bn := -1
	var step := maxi(1, list.size() / 30)
	for i in range(0, list.size(), step):
		var p: Vector2 = list[i].global_position
		var c := Vector2.ZERO
		var n := 0
		for u in list:
			if (u.global_position as Vector2).distance_to(p) < 260.0:
				c += u.global_position
				n += 1
		if n > bn:
			bn = n
			best = c / n
	return best


## Pan smoothly to the point; a long jump is a quick fade instead of a whip across the map.
func _move(delta: float) -> void:
	if poi == Vector2.INF:
		return
	var cam := game.camera
	if _fade_dir == 1:
		fade = minf(fade + delta / FADE, 1.0)
		if fade >= 1.0:
			cam.position = poi
			_fade_dir = -1
		return
	if _fade_dir == -1:
		fade = maxf(fade - delta / FADE, 0.0)
		if fade <= 0.0:
			_fade_dir = 0
	var view_w: float = game.get_viewport().get_visible_rect().size.x / cam.zoom.x
	var d := cam.position.distance_to(poi)
	if _fade_dir == 0 and d > view_w * 1.5:
		_fade_dir = 1
		return
	# ease out, but never faster than about a screen a second
	var step := minf(d * (1.0 - exp(-2.4 * delta)), view_w * 1.1 * delta)
	if d > 0.5:
		cam.position += (poi - cam.position) / d * step
