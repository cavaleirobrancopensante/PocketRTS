class_name AI
extends Node
## Computer opponent. Runs its faction's own economy (crews every economy structure,
## builds up to its limits and expands when they're full), techs up, trains a mixed army,
## attacks in growing waves and defends when its buildings are hit.
## Difficulty: 0 easy, 1 normal, 2 hard, 3 brutal. Brutal plays like Hard but faster and
## sharper (focus fire, kiting, pulling back hurt units, retreating from fights it can't win)
## and it cheats: +50% income from everything (set by the match) and it always knows where
## you are.

var game: Game
var team := 1
var difficulty := 1
var strategy := "balanced"      # one of STRATEGIES (picked in the skirmish lobby)
## Debug/benchmark only (tools/econ_bench.gd): never attack, raid or drop; the army just
## gathers at home. Off in every real match.
var peaceful := false

## How each strategy plays.
##  wave: army supply for the first attack (then each wave waits for `step` more)
##  expand: when to take more halls (x the normal time; lower = sooner) and how many at most
##  tech: when to get tech buildings (x the normal time)
##  workers: how many workers (x normal)
##  timing: (timing attack) no attacks before this many seconds, then everything goes
const STRATEGIES := {
	"balanced": {"name": "Balanced", "wave": 14, "step": 8, "expand": 1.0, "halls": 3, "tech": 1.0, "workers": 1.0},
	"rush": {"name": "Rush", "wave": 6, "step": 2, "expand": 2.5, "halls": 2, "tech": 2.0, "workers": 0.75},
	"economy": {"name": "Economy", "wave": 34, "step": 10, "expand": 0.45, "halls": 4, "tech": 1.1, "workers": 1.25},
	"timing": {"name": "Timing attack", "wave": 999, "step": 6, "expand": 0.9, "halls": 3, "tech": 0.75, "workers": 1.0, "timing": 270.0},
	"air": {"name": "Air rush", "wave": 10, "step": 4, "expand": 1.6, "halls": 2, "tech": 0.5, "workers": 0.9, "brood_only": true},
	# a "six-pool": a Spawning Den first, about 8 workers, every coin on Raptors, the first wave of 6 as
	# soon as it hatches. A gamble: a wall, a few Musketeers and the workers stop it (then it
	# falls back to a normal game).
	"xrush": {"name": "Extreme rush", "wave": 6, "step": 2, "expand": 99.0, "halls": 1, "tech": 99.0, "workers": 0.4, "brood_only": true},
}


## Which strategies this faction can use ("air" needs flyers: only the Brood has them).
static func strategies_for(faction: String) -> Array:
	var out: Array = []
	for k in STRATEGIES:
		if STRATEGIES[k].get("brood_only", false) and faction != "brood":
			continue
		out.append(k)
	return out


func _s(key: String) -> Variant:
	if scout != null and scout.mod.has(key):
		return scout.mod[key]       # (what the scout's report changed: AIScout)
	return STRATEGIES.get(strategy, STRATEGIES["balanced"]).get(key, STRATEGIES["balanced"].get(key))


## Crown: the opening this game: "mill" (Powder Mill first, a Musketeer line: the default) or
## "breeder" (Horse Breeder first, a Horseman rush: on Rush, and else about 3 games in 10).
var opening := "mill"
var scout: AIScout = null       # scouts the enemy first and picks the plan from what it saw (unless rushing)
## The Brood's own judgement (scripts/ai_brood.gd): essence, supply ahead of need, when a wave may go and
## when it pulls back. null for the other factions (and with AIBrood.enabled off: the Brood as it was,
## for a "before" number); every Brood branch below then runs as before.
var brood: AIBrood = null
## AI round 5 (scripts/ai_round5.gd, docs/ai_round5.md): the Crown against the Clockwork, the Clockwork against Horsemen.
const AIRound5 := preload("res://scripts/ai_round5.gd")
var r5 = AIRound5.new(self)      # (made with the AI: tests that build one by hand get it too)


func _ready() -> void:
	if not strategies_for(game.faction_of(team)).has(strategy):
		strategy = "balanced"
	_opened = strategy
	if game.faction_of(team) == "crown" and (strategy == "rush" or randf() < r5.breeder_chance(0.3)):
		opening = "breeder"
	if game.mlog and game.faction_of(team) == "crown":
		game.mlog.add("%s opens with a %s" % [game.mlog.who(team), "Horse Breeder (Horseman rush)" if opening == "breeder" else "Powder Mill (Musketeers)"])
	scout = AIScout.new(self)
	if game.faction_of(team) == "brood" and AIBrood.enabled:
		brood = AIBrood.new(self)
	_attack_at = int(_s("wave"))
	if opening == "breeder" and strategy == "rush":
		_attack_at = maxi(_attack_at, RUSH_HORSEMEN * int(Defs.UNITS["cuirassier"]["supply"]))   # (the first 3 Horsemen ride out together)


## A wave goes out: remember what it's worth, to judge it when it's over.
func _wave_start(army: Array) -> void:
	_trade.clear()
	_wave_value = 0.0
	for u in army:
		_wave_value += float(u.d["cost"]) / maxf(1.0, float(u.d.get("spawn", 1)))
	_wave_sup = _army_supply(army)
	_wave_kill0 = int(game.stats[team]["value_killed"])
	_siege_clear()
	_siege_said = ""
	_siege_next = 0.0
	_hold_back.clear()
	_dive_wait.clear()


## A wave is over (it died or fell back). One that killed less than it was worth failed:
## the next must be bigger. A rush (or air rush) that fails doesn't keep trickling in: the
## computer switches to a balanced game (workers, expansions, tech), gathers a real army
## and only then attacks again, in force.
func _wave_end() -> void:
	var gained := int(game.stats[team]["value_killed"]) - _wave_kill0
	if _wave_value <= 0.0 or gained >= _wave_value * 0.6:
		_failed = 0
		return
	_failed += 1
	_attack_at = maxi(_attack_at, int(ceil(_wave_sup * 1.4)))
	if _brood() and strategy in ["xrush", "rush"]:
		_xrush_over("its first wave failed")
		return
	if strategy in ["rush", "air"]:
		strategy = "balanced"
		_attack_at = maxi(_attack_at, 30 if _brood() else 24)
		_regroup_until = game.clock + _lv([240.0, 180.0, 150.0])
		if game.mlog:
			game.mlog.add("%s's %s failed: it builds up (economy, tech) and comes back in force" % [game.mlog.who(team), String(STRATEGIES[_opened]["name"]).to_lower()])

var _think := 0.0
var _attack_at := 14            # army supply needed for the next wave
var _attacking := false
var _wave_target := Vector2.ZERO
var _saving := false            # holding gold back for an expansion
var _escort: Array = []         # Clockwork: Winders that follow the army to repair it
var _reserve := 0               # gold held back for the next economy structure
var _swarm: Array = []          # Brood: the groups of a wave, each [units, staging point]
var _swarm_phase := ""          # "", "flank" (getting into position), "strike"
var _swarm_t := 0.0
var _tight := false            # Brood: this wave packs tight (the enemy has little splash damage)
var _no_room := {}              # economy kinds with no free spot, and when we looked
var _hall_bad := {}            # Crown: a new hall's spot -> until when not to try it again (its builders fled from raiders there)
var _abandoned := {}            # kind -> when a site of it was last dropped as "abandoned" (its builder fled): AIBrood.supply waits a little
# how the last wave went: what it was worth going out, and the enemy value killed before it
var _wave_value := 0.0
var _wave_sup := 0
var _fled: Dictionary = {}       # workers pulled out of a raid: Unit -> {"since": clock}
var _wave_kill0 := 0
var _failed := 0                # waves in a row that died without paying for themselves
var _regroup_until := 0.0       # after a failed rush: no attack before this (building up)
var _opened := ""               # the strategy it started with (a failed rush switches it)
var _first_wave := false        # (the match log notes the first attack)


# ---- the rush's result: what to send after the first rush resolves ----
## An early rush (the Horseman rush, the Brood Raptor rush, the Clockwork/any "rush" plan) is judged
## from facts while it runs: our riders alive, the enemy value killed against what the rush cost,
## the armed defenders seen, the workers still seen, the time since it began. The verdict is
##  ONGOING   no change;
##  FAILED    the riders ride home and stay as defence; no unit goes out alone; the plan switches to
##            economy/army/walls and attacks again only with a proper force (the usual army rules);
##  SUCCEEDED the economy is crippled. Few workers left and no defenders: a small group (2+)
##            of fresh cavalry may finish them (mode "finish"). Otherwise (mode "mop") the riders
##            pull back to the rally point out of the defenders' reach and one mop-up force
##            (Musketeers and cavalry, RUSH_MOP_MIN supply or more) goes out as ONE group.
## Whatever the phase, nothing goes into the enemy's land alone (scouts excepted).
const RUSH_MIN_T := 12.0        # no verdict before the rush has been at it this long
const RUSH_FINISH_WORKERS := 3  # at most this many enemy workers left (seen) for cavalry to finish
const RUSH_FINISH_DEF := 40.0   # ... and armed defenders worth less than this
const RUSH_MOP_MIN := 12        # the least supply of a mop-up force
const GROUP_MIN := 2            # the fewest units that ever go out together as reinforcements
const GROUP_SUPPLY := 6         # ... and the least supply of a reinforcing group in an ordinary wave
var _rush_state := ""           # "", "ongoing", "succeeded", "failed"
var _rush_mode := ""            # succeeded: "finish" or "mop"
var _rush_t0 := 0.0
var _rush_n0 := 0               # riders at the start
var _rush_wave := false         # the first wave out is the rush
var _rush_raid := false         # the rush is the raiding party (the Horse Breeder opening on another plan)
var _rush_def := 0.0            # armed defenders last seen (value) ...
var _rush_def_t := -999.0       # ... and when
var _rush_wk_peak := 0
var _rush_why := ""
var _mop_pending := false       # the mop-up force has not gone out yet (a Brood swarm then needs no 30 supply)
var _raid_block := 0.0          # no raiding party forms before this
var _raid_peak := 0             # the biggest the party has been since it formed
var _wave_set: Dictionary = {}  # Unit -> true: the units sent in the wave out (the rest wait at home)


func _front() -> Vector2:
	var hall: Array = _halls()
	return _rally_front(hall[0]) if not hall.is_empty() else game.center_of_team(team)


## The Horse Breeder rush is still the plan at this moment: horses and Horsemen first.
func _rush_open() -> bool:
	return opening == "breeder" and game.clock < 600.0 and (_rush_state == "" or _rush_state == "ongoing" or (_rush_state == "succeeded" and _rush_mode == "finish"))


## A rush begins (a party of at least two goes out): remember what it is worth.
func _rush_begin(party: Array, raid: bool) -> void:
	_rush_state = "ongoing"
	_rush_mode = ""
	_rush_t0 = game.clock
	_rush_n0 = party.size()
	_rush_raid = raid
	_rush_wave = not raid
	_rush_def = 0.0
	_rush_def_t = -999.0
	_rush_wk_peak = 0
	if raid:
		_wave_value = 0.0
		for u in party:
			_wave_value += float(u.d["cost"]) / maxf(1.0, float(u.d.get("spawn", 1)))
		_wave_sup = _army_supply(party)
		_wave_kill0 = int(game.stats[team]["value_killed"])


## Armed defenders seen around the party / the enemy base (value), remembered for 25 s; 0 when none.
func _rush_defenders(party: Array) -> float:
	var spots: Array = [_enemy_base()]
	if not party.is_empty():
		var c := Vector2.ZERO
		for u in party:
			c += u.position
		spots.append(c / party.size())
	var best := -1.0
	for s in spots:
		var a := _assess(s)
		if a["value"] != DEF_UNSEEN:
			best = maxf(best, float(a["value"]))
	if best >= 0.0:
		_rush_def = best
		_rush_def_t = game.clock
		return best
	return _rush_def if game.clock - _rush_def_t < 25.0 else 0.0


func _rush_workers_left() -> int:
	var foe := _foe()
	if foe < 0:
		return 0
	var n := 0
	for o in game.workers(foe):
		if _sighted(o):
			n += 1
	_rush_wk_peak = maxi(_rush_wk_peak, n)
	return n


## "ongoing", "failed" or "succeeded" from the facts (party = the riders still alive).
func _rush_verdict(party: Array) -> String:
	var t := game.clock - _rush_t0
	var alive := party.size()
	var mine := 0.0
	for u in party:
		mine += _unit_value(u)
	var wv := maxf(1.0, _wave_value)
	var gained := float(int(game.stats[team]["value_killed"]) - _wave_kill0)
	var defv := _rush_defenders(party)
	var left := _rush_workers_left()
	if t < RUSH_MIN_T and alive > 0:
		return "ongoing"
	if alive == 0:
		if gained >= wv and defv < 100.0:
			return "succeeded"
		_rush_why = "the riders are dead"
		return "failed"
	if float(alive) <= float(_rush_n0) * 0.4 and gained < wv * 0.8:
		_rush_why = "the riders were beaten back (%d of %d left)" % [alive, _rush_n0]
		return "failed"
	if defv >= 100.0 and defv > mine * 1.15 and gained < wv * 0.8 or r5.rush_beaten(defv, mine, gained, wv):
		_rush_why = "the defenders are worth more than the riders"
		return "failed"
	if t > 90.0 and gained < wv * 0.3:
		_rush_why = "no headway in %d s" % int(t)
		return "failed"
	if gained >= wv * 0.7 or (_rush_wk_peak >= 6 and left <= RUSH_FINISH_WORKERS and gained >= wv * 0.5):
		return "succeeded"
	if t > 150.0:
		if gained >= wv * 0.5:
			return "succeeded"
		_rush_why = "out of time"
		return "failed"
	return "ongoing"


## finish (cavalry can ride down the last workers) or mop (a real force must go).
func _rush_mode_now(party: Array) -> String:
	var defv := _rush_defenders(party)
	return "finish" if _rush_workers_left() <= RUSH_FINISH_WORKERS and defv < RUSH_FINISH_DEF else "mop"


## The mop-up force: sized by the defenders seen, never under RUSH_MOP_MIN supply.
func _rush_mop_size() -> int:
	return clampi(int(ceil(1.5 * _rush_def / 40.0)), RUSH_MOP_MIN, 40)


## Ride home and stay: the party is over.
func _rush_recall(party: Array) -> void:
	var front := _front()
	for u in party:
		if is_instance_valid(u) and not u.dead:
			u.cmd_move(_home_spot(front))


func _rush_log(msg: String) -> void:
	if game.mlog:
		game.mlog.add("%s's rush: %s" % [game.mlog.who(team), msg])


## FAILED: ride home, stay as defence, build up (economy, army, walls) and come back in force.
func _rush_failed(party: Array) -> void:
	_rush_state = "failed"
	_rush_recall(party)
	_rush_log("FAILED (%s): the riders ride home, no more go out alone; it builds up and attacks only with a proper force" % _rush_why)
	_failed += 1
	_rush_wave = false
	_attacking = false
	_wave_set.clear()
	_raiders.clear()
	_raid_peak = 0
	_raid_block = game.clock + _lv([240.0, 180.0, 150.0])
	_regroup_until = maxf(_regroup_until, game.clock + _lv([150.0, 120.0, 90.0]))
	_attack_at = maxi(maxi(_attack_at, int(ceil(_wave_sup * 1.4))), 30 if _brood() else 14)
	if _brood() and strategy in ["xrush", "rush"]:
		_xrush_over(_rush_why)
	elif strategy == "rush":
		strategy = "balanced"
		_attack_at = maxi(_attack_at, 24)


## SUCCEEDED, mop-up (the usual case): the riders pull back out of the defenders' reach, the
## economy goes on, and one force of at least RUSH_MOP_MIN supply goes out together.
func _rush_mop(party: Array) -> void:
	_rush_mode = "mop"
	_rush_recall(party)
	var need := _rush_mop_size()
	_rush_log("SUCCEEDED, mop-up: the riders regroup at home; a force of %d+ supply goes out as one group" % need)
	_rush_wave = false
	_attacking = false
	_wave_set.clear()
	_raiders.clear()
	_raid_peak = 0
	_raid_block = game.clock + 600.0
	_regroup_until = 0.0
	_attack_at = need
	_mop_pending = true
	if _brood() and strategy in ["xrush", "rush"]:
		strategy = "balanced"
		_xr_wave.clear()


## One tick of the verdict on a rush party; returns true when the party is disbanded.
func _rush_tick(party: Array) -> bool:
	if _rush_state == "ongoing":
		var v := _rush_verdict(party)
		if v == "failed":
			_rush_failed(party)
			return true
		if v == "succeeded":
			_rush_state = "succeeded"
			_rush_mode = _rush_mode_now(party)
			if _rush_mode == "mop":
				_rush_mop(party)
				return true
			_rush_log("SUCCEEDED, %d workers left and no defenders: a small cavalry group may finish them" % _rush_workers_left())
	elif _rush_state == "succeeded" and _rush_mode == "finish":
		if _rush_mode_now(party) == "mop":
			_rush_mop(party)
			return true
	return false


## Fresh cavalry (or riders) idle near home that are not in the party: they go out only as a group.
func _rush_pool(candidates: Array) -> Array:
	var front := _front()
	return candidates.filter(func(u: Unit) -> bool: return u.kind == "cuirassier" and not _horse_coming(u) and u.position.distance_to(front) < 420.0)


func _physics_process(delta: float) -> void:
	var _p0 := Time.get_ticks_usec()
	_tick_ai(delta)
	Prof.add("ai", _p0)


func _tick_ai(delta: float) -> void:
	if game == null or game.over:
		return
	_think -= delta
	if _stage < STAGES:
		_think_stage(_stage)       # (a think goes on over the next ticks, a part each)
		_stage += 1
		return
	if _think > 0.0:
		return
	_think_dt = [2.2, 1.2, 0.7, 0.4][difficulty]
	_think = _think_dt
	_think_stage(0)
	_stage = 1


## A think, in parts on consecutive physics ticks (all in one tick, it made a long frame):
## workers and economy, building, research and training, raids, the army, horses and the
## rest. Each part sees what the parts before it did, as before.
const STAGES := 5
var _stage := STAGES
var _think_dt := 0.0             # the time between thinks (what the parts that count time add)


func _think_stage(i: int) -> void:
	var pt := Time.get_ticks_usec()
	match i:
		0:
			_cottage_wall()
			_workers()
			if _clock() and Defs.line_mode:
				LineAI.tick(self)           # the Clockwork Line (scripts/line_ai.gd; shelved unless Defs.line_mode)
			pt = _lap("ai/workers", pt)
			_econ_build()
			_lap("ai/econ", pt)
		1:
			_supply()
			_build_up()
			_lap("ai/build", pt)
		2:
			_research()
			_produce()
			pt = _lap("ai/produce", pt)
			if difficulty >= 1 and _crown() and not peaceful:
				_raid()
				_balloon_drop()
			_lap("ai/raid", pt)
		3:
			scout.tick()
			if brood != null:
				brood.tick()                # (what the eyes show, the income, the grubs harvesting)
			_army()
			_lap("ai/army", pt)
		4:
			if _crown():
				_tend_wagon()
				_horses()
			pt = _lap("ai/horses", pt)
			_loose_horses()
			pt = _lap("ai/loose", pt)
			if difficulty >= 1:
				_abilities()
			pt = _lap("ai/abil", pt)
			if difficulty >= 2:
				_micro()
			_lap("ai/micro", pt)
			_gg_tick()
			_lap("ai/gg", pt)


# ------------------------------------------------------------------ gg (ai_resign.gd)
## Like a human giving up: when the position is hopeless (AIResign.verdict) for long enough it
## says "gg" in the chat. If the player answers gg within AIResign.REPLY_WINDOW it says "gg wp" and
## resigns (every building falls: a win for the player); if not, it plays on and may say gg once more.

var gg_since := -1.0            # clock when the position first looked hopeless (without a break), -1 = not
var gg_reason := ""
var gg_said := 0                # gg's said so far
var gg_last := -9999.0          # clock of the last one
var _gg_check := 0.0            # clock of the last look
var _halls_peak := 0
var _workers_peak := 0
var _enemy_mem := 0.0           # the biggest enemy army seen lately, fading when it is out of sight
var resigned := false


## What the computer knows and has now (the input of AIResign.verdict).
func gg_view(dt := 0.0) -> Dictionary:
	var halls := game.halls_of(team).size()
	var workers := game.worker_count(team)
	_halls_peak = maxi(_halls_peak, halls)
	_workers_peak = maxi(_workers_peak, workers)
	# the enemy army it can see right now (its own fog of war), remembered while out of sight
	var seen := 0.0
	for u in game.units:
		if u.dead or u.off_field or u.is_worker() or not game.hostile(u.team, team):
			continue
		if game.is_visible_to(team, u.position):
			seen += Game.unit_value(u)
	_enemy_mem = maxf(seen, _enemy_mem - _enemy_mem * dt / AIResign.MEMORY_SECS)
	var production := 0
	for b in game.buildings:
		if b.team == team and b.built and not b.dead and not b.ghost:
			for k in Defs.BUILDINGS[b.kind].get("trains", []):
				if not Defs.is_worker(String(k)):
					production += 1
					break
	return {"clock": game.clock, "halls": halls, "halls_peak": _halls_peak, "workers": workers, "workers_peak": _workers_peak,
		"army": game.army_value(team), "enemy_army": _enemy_mem, "production": production,
		"gold": int(game.players[team]["gold"]), "hall_cost": int(Defs.BUILDINGS[game.faction_hall(team)]["cost"])}


## Does the computer talk to this player at all (a computer against the player, in a real match)?
func _gg_talks() -> bool:
	return not peaceful and not game.demo and game.chat != null and not game.eliminated[team] and game.hostile(team, game.human)


func _gg_tick() -> void:
	if resigned or not _gg_talks() or game.clock - _gg_check < AIResign.CHECK_EVERY:
		return
	var dt := minf(game.clock - _gg_check, 30.0)
	_gg_check = game.clock
	var why := AIResign.verdict(gg_view(dt))
	if why == "":
		gg_since = -1.0
		gg_reason = ""
		return
	if gg_since < 0.0:
		gg_since = game.clock
	gg_reason = why
	if game.clock - gg_since < AIResign.sustain_for(why):
		return
	if gg_said >= AIResign.MAX_SAYS:
		return
	if gg_said >= 1 and game.clock - gg_last < AIResign.REPEAT_AFTER:
		return
	gg_said += 1
	gg_last = game.clock
	game.chat.post(team, "gg")
	if game.hud:
		game.hud.chat_banner("%s says gg: reply gg to end the match" % game.chat.name_of(team))
	if game.mlog:
		game.mlog.add("%s thinks it is hopeless (%s: %s)" % [game.mlog.who(team), why, game.standing_text(team)])


## Its gg is waiting for an answer.
func gg_pending() -> bool:
	return not resigned and gg_said > 0 and game.clock - gg_last <= AIResign.REPLY_WINDOW


## The player said gg while one was pending: gg wp, and every building falls.
func gg_reply() -> void:
	if resigned:
		return
	resigned = true
	game.resigned.append(team)
	game.end_note = "ai_resigned"
	game.chat.post(team, "gg wp")
	if game.mlog:
		game.mlog.add("%s resigned after gg (%s)" % [game.mlog.who(team), game.standing_text(team)])
	for b in game.buildings.duplicate():
		if b.team == team:
			b.take_damage(99999, null)


## Everything at once (tests and tools that call it).
func _think_all() -> void:
	for i in STAGES:
		_think_stage(i)


## (the match log's "busy with": each part of the computer's think on its own)
func _lap(zone: String, since: int) -> int:
	Prof.add(zone, since)
	return Time.get_ticks_usec()


# ------------------------------------------------------------------ helpers

## Pick the value for this level from [easy, normal, hard]; Brutal is Hard, but sooner.
func _lv(v: Array) -> Variant:
	if difficulty >= 3:
		var h: Variant = v[2]
		return h * 0.8 if h is float else h
	return v[difficulty]


func _mine(kind: String) -> Array:
	# (a plain loop: the same buildings in the same order as a filter with a lambda, cheaper)
	var out: Array = []
	for b in game.buildings:
		if b.team == team and b.kind == kind and not b.dead:
			out.append(b)
	return out


func _f() -> Dictionary:
	return Defs.FACTIONS[game.faction_of(team)]


## Gear mode: a Ratchet Turret or two for the home base (Defs.TURRET): the first once a Light Works stands and the
## first soldiers are paid for (or at once when an enemy is at the door), a second on Normal and Hard later with money in
## the bank. They go up near the Clocktower like any gear building (they must link to the field).
func _turrets() -> void:
	var k := Defs.CW_TURRET
	if not game.requirement_met(team, k) or _busy_building(k) or _gold() < int(Defs.BUILDINGS[k]["cost"]):
		return
	var have := _mine(k).size()
	var want := 0
	if game.clock > _lv([420.0, 300.0, 240.0]) or (_threat() != Vector2.INF and game.clock > 150.0):
		want = 1
	# (0.14.94: not in the minute the Mainspring and the Escapement are saved for, unless the army cannot hold the line: a
	# turret laid then by the Clocktower took the room the pair needed on a cramped plateau, and the Escapement came three
	# minutes late, kestrel_rise seed 14)
	if have == 0 and _mine("mainspring").is_empty() and game.clock >= _tier2_at() - 20.0 and _holds_line():
		want = 0
	if difficulty > 0 and game.clock > _lv([9999.0, 540.0, 420.0]) and _gold() > 300:
		want = 2
	if have < want:
		_construct(k)


## Gear mode, TIER 2: once a Light Works stands, a Mainspring (idle Winders crew it, so it winds Tension), then an
## Escapement whose ring meshes with that Mainspring's (the Tension rule: placed by GearNet.ring_spot round it).
## _produce mixes Springers into the army while the Tension lasts. (No HIGH LEAP: its Springers only jump away from melee, on the
## flat or down: Springer.ai_tick.)
var _tier2_t := 0.0
var _research_keep := 0.0      # gear mode: Tension kept for a research that is wanted (SHIELD WALL, HIGH LEAP)
var _esc_blocked := false       # gear mode: no room for the Escapement by any Mainspring (another Mainspring is saved for)
var _tech_hold := false         # gear mode: the gold put by is for the Mainspring or the Escapement (the army pauses sooner)


## Gear mode: when the tier-2 tech starts (the plan's tech clock, AI._build_up's `t`). Hard: about 2:50, so the
## Mainspring stands by ~3:30 and the Escapement by ~4:40: the first Springers, Netters and SHIELD WALL are out for the
## first big fight (docs/clockwork_ai.md). Sooner against a walled enemy: melee alone cannot take a wall that is mended.
func _tier2_at() -> float:
	var at: float = _lv([560.0, 300.0, 170.0])
	if _foe_walled():
		at -= _lv([0.0, 40.0, 40.0])
	return at


## The scout has seen an enemy wall or gate (a walled ramp).
func _foe_walled() -> bool:
	if scout == null:
		return false
	for b in scout._seen_b.keys():
		if is_instance_valid(b) and not b.dead and (b.kind == "wall" or b.kind == "gate"):
			return true
	return false


## Under attack, but the army holds the line: worth at least 1.3 times the armed enemies seen at the threat.
func _holds_line() -> bool:
	var th := _threat()
	if th == Vector2.INF:
		return true
	var a := _assess(th)
	var mine := 0.0
	for u in game.army(team):
		if not u.dead and not u.is_worker():
			mine += _unit_value(u)
	return mine >= float(a["value"]) * 1.3 + 50.0


func _meshed_none() -> bool:
	return not _mine(_works()).any(func(b: Building) -> bool: return game.gear_net.spring_for(b) != null)


func _tier2(t: float) -> void:
	# (the clock, not only the plan's tech factor: a scout report of a "rush" (a Horseman, a Musketeer line at home) put
	# the tech off by a quarter, and melee alone is what loses to that defence)
	if _mine(_works()).filter(func(b: Building) -> bool: return b.built).is_empty() or maxf(t, game.clock) < _tier2_at():
		return
	var springs := _mine("mainspring")
	var esc := _mine(Defs.CW_TECH)
	# (what comes next is saved up for: the army pauses once it holds the line, like for an economy building; a raid it
	# can beat does not stop the saving: a Horseman at the door used to put the tech off for minutes, 2026-10-27)
	# (the Escapement is laid as soon as its Mainspring's site is: it holds the room by the spring, which other buildings
	# took in the minute the spring took to stand up; it works once the spring does)
	var next := "mainspring" if springs.is_empty() else (Defs.CW_TECH if esc.is_empty() else "")
	var next_cost := int(Defs.BUILDINGS[next]["cost"]) if next != "" else 0
	if next == "mainspring":
		next_cost += int(Defs.BUILDINGS[Defs.CW_TECH]["cost"])      # (the pair is laid at once: _tier2)
	if next == Defs.CW_TECH and _esc_blocked:
		next_cost += int(Defs.BUILDINGS["mainspring"]["cost"])      # (no room for it: another Mainspring first, saved for too)
	if next != "" and _gold() < next_cost + 20 and (_threat() == Vector2.INF or _holds_line()):
		_reserve = maxi(_reserve, next_cost + 20)
		_tech_hold = true
	_esc_spring(esc)       # (an Escapement laid first gets its Mainspring)
	_esc_spring(_mine(Defs.CW_HEAVY), true)      # (and a Heavy Works laid with no Mainspring by it)
	_heavy_hold()          # (the Heavy Works' cogs, held back on every think)
	_springer_works()          # (its own clock; the gold it wants is held back on every think)
	_research_keep = 0.0
	if not springs.is_empty():
		_shield_research()
		_leap_research()
	if game.clock < _tier2_t:
		return
	_tier2_t = game.clock + 3.0
	if springs.is_empty():
		# the Mainspring and the Escapement are laid together: the room by the spring went to Regulators and a turret
		# in the minute before the Escapement's cogs came in, and three games in eight had no Escapement for minutes
		if _gold() >= int(Defs.BUILDINGS["mainspring"]["cost"]) + int(Defs.BUILDINGS[Defs.CW_TECH]["cost"]) + 20:
			var msc := _spring_spot()
			_construct("mainspring", msc)
			for sp in _mine("mainspring"):
				var ce := GearEcon.room_spot(game, team, Defs.CW_TECH, [sp])
				if ce.x >= 0 and game.requirement_met(team, Defs.CW_TECH):
					_construct(Defs.CW_TECH, ce)
					break
			if msc.x >= 0 and _busy_building("mainspring"):
				# (0.14.94: the spots by the new Mainspring are KEPT for what goes beside it: the Escapement, when it could
				# not be laid with it (a ring touching only the Mainspring's site does not link until it stands, and its room
				# went to Regulators and a turret meanwhile: kestrel_rise seed 14 waited three minutes), and the Heavy
				# Works' big ring when _spring_spot found room for it too; the Escapement then goes on its kept spot)
				var users: Array = _spring_users if _spring_heavy else [Defs.CW_TECH]
				_keep_heavy(msc, users)
				if _busy_building(Defs.CW_TECH):
					_unkeep(Defs.CW_TECH)
				if game.mlog and _spring_heavy:
					game.mlog.add("%s keeps room for a Heavy Works by its first Mainspring" % game.mlog.who(team))
		return
	if not esc.is_empty():
		_unkeep(Defs.CW_TECH)
	if esc.is_empty():
		if _gold() < int(Defs.BUILDINGS[Defs.CW_TECH]["cost"]) + 20 or not game.requirement_met(team, Defs.CW_TECH):
			return
		# (the spot kept for it by its Mainspring, worked out with the Heavy Works' spot: _keep_heavy)
		var ke := _kept(Defs.CW_TECH)
		if not ke.is_empty():
			var kc2: Vector2i = ke["cell"]
			if game.placement_problem(team, Defs.CW_TECH, kc2, true) == "" and game.gear_net.candidate(team, Defs.CW_TECH, kc2)["state"] == "ok":
				_construct(Defs.CW_TECH, kc2)
				if _busy_building(Defs.CW_TECH):
					_unkeep(Defs.CW_TECH)
					return
			elif _busy_building("mainspring"):
				return          # (its Mainspring is still going up: the spot waits for it)
		for sp in springs:
			if not sp.dead:
				var c := GearEcon.room_spot(game, team, Defs.CW_TECH, [sp], [Defs.CW_AIR])
				if c.x < 0:
					c = GearEcon.room_spot(game, team, Defs.CW_TECH, [sp])
				# (round the Mainspring every way: one cramped game never placed its Escapement, 0.14.72 Hollowfen)
				for deg in [90.0, 270.0, 0.0, 180.0, 45.0, 135.0, 225.0, 315.0]:
					if c.x >= 0:
						break
					c = GearNet.ring_spot(game, team, Defs.CW_TECH, sp, deg, true)
				if c.x >= 0:
					_construct(Defs.CW_TECH, c)
					return
		# (no room by any Mainspring: the Escapement goes first where a Mainspring can still go beside it, by a hall or a
		# Works, and the Mainspring follows by it (_esc_spring); cramped bases waited up to ten minutes, 0.14.79
		# Hollowfen and Kestrel Rise)
		if _gold() >= int(Defs.BUILDINGS[Defs.CW_TECH]["cost"]) + 20:
			var pair: Array = _halls() + _mine(_works())
			for b in pair:
				if b.built:
					var r6: Array = GearEcon.room_spot_n(game, team, Defs.CW_TECH, [b], ["mainspring"])
					if int(r6[1]) >= 1:
						_construct(Defs.CW_TECH, r6[0])
						if game.mlog:
							game.mlog.add("%s lays its Escapement where a Mainspring can go beside it (no room by its Mainsprings)" % game.mlog.who(team))
						return
		# (else another Mainspring where there is room, then the Escapement by it; its cogs are held back like the
		# Escapement's, _esc_blocked)
		_esc_blocked = springs.size() < 3 and not _busy_building("mainspring")
		if _esc_blocked and _gold() >= int(Defs.BUILDINGS["mainspring"]["cost"]) + int(Defs.BUILDINGS[Defs.CW_TECH]["cost"]):
			var ss := _spring_spot()
			if ss.x >= 0:
				_construct("mainspring", ss)
				_esc_blocked = false
			else:
				_esc_blocked = false           # (no room for a spring either: nothing is held back for it)
		_tier2_t = game.clock + 20.0        # (look again later)
		return
	_air(t)
	_tier3()


## Gear mode: an Escapement with no Mainspring meshing with it (laid first, _tier2) gets one beside it; `heavy`: the same for
## a Heavy Works (_tier3).
func _esc_spring(esc: Array, heavy := false) -> void:
	if esc.is_empty() or (not heavy and game.has_working(team, Defs.CW_TECH)) or _busy_building("mainspring"):
		return
	for e in esc:
		if not e.dead and (not heavy or e.built) and game.gear_net.spring_for(e) == null:
			var c := GearEcon.room_spot(game, team, "mainspring", [e])
			if c.x < 0:
				return
			if _gold() >= int(Defs.BUILDINGS["mainspring"]["cost"]) + 20:
				_construct("mainspring", c)
			elif _threat() == Vector2.INF or _holds_line():
				_reserve = maxi(_reserve, int(Defs.BUILDINGS["mainspring"]["cost"]) + 20)
				_tech_hold = true
			return


## Gear mode: SHIELD WALL (the Clock Soldiers' SHIELD FORWARD, scripts/shield_wall.gd) once it meets a ranged army
## (3+ enemy shooters seen in the last 90 s: Musketeers, Spitters, Springers...) and has Clock Soldiers to use it, at a
## Light Works whose ring meshes with a Mainspring's (it costs Tension), with the Tension to spare.
var _ranged_seen := 0
var _ranged_seen_t := -999.0


func _shield_research() -> void:
	if game.has_tech(team, ShieldWall.TECH) or game.researching(team, ShieldWall.TECH):
		return
	var n := 0
	for u in game.units:
		if game.hostile(u.team, team) and ShieldWall.shooter(u) and game.side_sees(team, u.position):
			n += 1
	if n > 0:
		_ranged_seen = maxi(n, _ranged_seen if game.clock - _ranged_seen_t < 90.0 else 0)
		_ranged_seen_t = game.clock
	if _ranged_seen < 3 or game.clock - _ranged_seen_t > 90.0:
		return
	if game.army(team).filter(func(u: Unit) -> bool: return u.kind == ShieldWall.KIND).size() < 4:
		return
	var info: Dictionary = Defs.RESEARCH[ShieldWall.TECH]
	if _meshed_none():
		return
	_research_keep = maxf(_research_keep, float(Defs.tension_cost(info)) + 10.0)     # (its Tension is kept from the Springers: _produce)
	_research_cogs(int(info["cost"]))
	if game.tension(team) < float(Defs.tension_cost(info)) + 10.0 or _gold() < int(info["cost"]) + 20:
		return
	for w in _mine(_works()):
		if game.research_problem(w, ShieldWall.TECH) == "":
			game.start_research(w, ShieldWall.TECH)
			if game.mlog:
				game.mlog.add("%s researches SHIELD WALL (it met %d shooters)" % [game.mlog.who(team), _ranged_seen])
			return


## Gear mode: HIGH LEAP at the Escapement (its Springers then JUMP UP onto high ground: over a walled ramp onto the workers
## mending the wall and the shooters on the edge, _springer_leaps), on Normal and Hard, once it has a few Springers and the
## enemy has walls or stands on high ground. Its Tension is kept from the Springers meanwhile (_produce).
func _leap_research() -> void:
	if difficulty < 1 or game.has_tech(team, "high_leap") or game.researching(team, "high_leap"):
		return
	if not game.has_working(team, Defs.CW_TECH):
		return
	var springers := game.army(team).filter(func(u: Unit) -> bool: return u.kind == Defs.SPRINGER).size()
	if springers < 5 or not (_foe_walled() or _foe_high()):
		return
	if not game.has_tech(team, ShieldWall.TECH) and _ranged_seen >= 3 and game.army(team).filter(func(u: Unit) -> bool: return u.kind == ShieldWall.KIND).size() >= 4:
		return          # (SHIELD WALL first: cheaper, and every Clock Soldier walking up under fire needs it)
	var info: Dictionary = Defs.RESEARCH["high_leap"]
	_research_keep = maxf(_research_keep, float(Defs.tension_cost(info)) + 10.0)
	_research_cogs(int(info["cost"]))
	if game.tension(team) < float(Defs.tension_cost(info)) + 5.0 or _gold() < int(info["cost"]) + 20:
		return
	for e in _mine(Defs.CW_TECH):
		if e.built and game.research_problem(e, "high_leap") == "":
			game.start_research(e, "high_leap")
			if game.mlog:
				game.mlog.add("%s researches HIGH LEAP (%d Springers, %s)" % [game.mlog.who(team), springers, "a walled enemy" if _foe_walled() else "an enemy on high ground"])
			return


## A wanted research's cogs are held back too, like a building's (the army pauses for them once it holds the line): it
## costs cogs and Tension, and with every cog spent on Clock Soldiers its Tension was kept from the Springers for nothing.
func _research_cogs(cost: int) -> void:
	if _gold() < cost + 20 and (_threat() == Vector2.INF or _holds_line()):
		_reserve = maxi(_reserve, cost + 20)
		_tech_hold = true


## The enemy's main hall stands on high ground.
func _foe_high() -> bool:
	var f := _foe()
	if f < 0:
		return false
	var h: Building = game._own_hall(f)
	return h != null and game.on_high(h.center())


## Gear mode, THE HEAVY WORKS (0.14.94, docs/gear_rules.md; scripts/pendulum.gd, scripts/ballista.gd): the Pendulums and
## the Spring Ballistas are made only there (the Light Works no longer makes them), so as soon as its Escapement works it
## lays ONE Heavy Works whose BIG ring
## meshes with a Mainspring's (it is a Tension user: idle otherwise): by a Mainspring with room; with no room by any, a new
## Mainspring first where its big ring will fit beside it; its cogs are held back like the tech's (_heavy_hold). _produce then mixes a few
## Pendulums and Ballistas into the army from it. (Before 0.14.94 a Movement Works, now the Light Works, was swapped onto its big gear for the
## Pendulum, and the Ballista came from any Works meshing with a Mainspring.)
var _heavy_t := 0.0
var _heavy_no_room := false         # no room for the Heavy Works by any Mainspring: a Mainspring with room for it is saved for


func _tier3() -> void:
	if not _mine(Defs.CW_HEAVY).is_empty():
		_unkeep(Defs.CW_HEAVY)        # (laid: the spot kept for it is free again)
		return
	if not game.has_working(team, Defs.CW_TECH):
		return
	# (laid as soon as the Escapement works: before 0.14.94 the first Ballista came from any Works meshing with a Mainspring
	# about two minutes after the Escapement; waiting for Springers first put it three minutes later, greenhold seed 11)
	var cost := int(Defs.BUILDINGS[Defs.CW_HEAVY]["cost"])
	if _gold() < mini(cost, int(Defs.BUILDINGS["mainspring"]["cost"])) + 20:
		return          # (its cogs are held back on every think: _heavy_hold)
	if game.clock < _heavy_t or _busy_building(Defs.CW_HEAVY):
		return
	_heavy_t = game.clock + 6.0
	# the spot kept for it by a Mainspring (_keep_heavy): there once that Mainspring stands; meanwhile it waits for it
	var keep := _kept(Defs.CW_HEAVY)
	if not keep.is_empty():
		var kc: Vector2i = keep["cell"]
		var st: Dictionary = game.gear_net.candidate(team, Defs.CW_HEAVY, kc)
		var pp: String = game.placement_problem(team, Defs.CW_HEAVY, kc, true)
		if pp == "" and st["state"] == "ok" and st.get("spring") != null:
			_construct(Defs.CW_HEAVY, kc)
			if game.mlog:
				game.mlog.add("%s lays a Heavy Works on the spot it kept by a Mainspring" % game.mlog.who(team))
			return
		if pp == "" or _busy_building("mainspring"):
			return          # (its Mainspring is still going up, or has only just stood: the spot waits for it)
		_unkeep(Defs.CW_HEAVY)          # (the spot was taken after all: look again)
		if game.mlog:
			game.mlog.add("%s lost the spot it kept for a Heavy Works: %s" % [game.mlog.who(team), pp])
	var c := _heavy_spot()
	_heavy_no_room = c.x < 0
	if c.x >= 0:
		if _gold() < cost + 20:
			return
		_construct(Defs.CW_HEAVY, c)
		if game.mlog:
			game.mlog.add("%s lays a Heavy Works (Pendulums and Spring Ballistas)" % game.mlog.who(team))
	else:
		_heavy_t = game.clock + 15.0
		# (no room by any Mainspring, nor for a Mainspring beside it: another Mainspring where a Heavy Works' big ring can
		# still go beside it; it goes there next time)
		if game.mlog:
			game.mlog.add("%s finds no room for a Heavy Works by its Mainsprings" % game.mlog.who(team))
		if _mine("mainspring").size() < 4 and not _busy_building("mainspring") and _gold() >= int(Defs.BUILDINGS["mainspring"]["cost"]) + 20:
			for b in _gear_neighbours():
				var r7: Array = GearEcon.room_spot_n(game, team, "mainspring", [b], [Defs.CW_HEAVY])
				if int(r7[1]) >= 1:
					_construct("mainspring", r7[0])
					_keep_heavy(r7[0], [Defs.CW_HEAVY])
					if game.mlog:
						game.mlog.add("%s builds a Mainspring with room for a Heavy Works beside it" % game.mlog.who(team))
					return


## The Heavy Works' cogs are saved up for on every think (the army pauses for them once it holds the line, like the tech's):
## _tier3 runs only every few seconds, and a reserve set there was gone by the next think (the Heavy Works came three
## minutes after the Escapement).
func _heavy_hold() -> void:
	if not game.has_working(team, Defs.CW_TECH) or not _mine(Defs.CW_HEAVY).is_empty():
		return
	var cost := int(Defs.BUILDINGS[Defs.CW_HEAVY]["cost"])
	if _heavy_no_room:
		cost += int(Defs.BUILDINGS["mainspring"]["cost"])      # (no room by a Mainspring: one with room for it first)
	if _gold() < cost + 20 and (_threat() == Vector2.INF or _holds_line()):
		_reserve = maxi(_reserve, cost + 20)
		_tech_hold = true


## Where the Heavy Works goes: its big ring meshing with a built Mainspring's. (-1, -1) when there is no room by any.
func _heavy_spot() -> Vector2i:
	for sp in _mine("mainspring"):
		if sp.built and not sp.dead:
			var c := GearEcon.room_spot(game, team, Defs.CW_HEAVY, [sp])
			for deg in [90.0, 270.0, 0.0, 180.0, 45.0, 135.0, 225.0, 315.0]:
				if c.x >= 0:
					break
				c = GearNet.ring_spot(game, team, Defs.CW_HEAVY, sp, deg, true)
			if c.x >= 0:
				return c
	# (no spot by a Mainspring: _tier3 builds a Mainspring with room for it first; a Heavy Works laid elsewhere waiting for a
	# Mainspring stood idle for good in a crowded base, frostmere seed 12)
	return Vector2i(-1, -1)


## Keep the spot for the Heavy Works by a Mainspring laid at cell `spring_cell` (Game.ai_keep): the cell _room's greedy
## placing found for it, with `users` (the Escapement first when it is laid with the first Mainspring), so the computer's
## Regulators, presses and turrets do not take it in the minute before the Heavy Works may be laid (0.14.94: room by a
## Mainspring for its big ring was gone in most games).
func _keep_heavy(spring_cell: Vector2i, users: Array) -> void:
	if not _mine(Defs.CW_HEAVY).is_empty():
		return
	if not game.ai_keep.has(team):
		game.ai_keep[team] = {}
	for uc in GearEcon.room_cells(game, team, "mainspring", spring_cell, users):
		var uk := String(uc[0])
		if (uk == Defs.CW_HEAVY or uk == Defs.CW_TECH) and _mine(uk).is_empty():
			game.ai_keep[team][uk] = {"cell": uc[1], "t": game.clock, "spring": spring_cell}


## The spot kept for a `kind` ({"cell", "t", "spring"}), {} when none or when it is let go: kept too long (KEEP_FOR s), or its
## Mainspring was never laid or is gone.
const KEEP_FOR := 240.0


func _kept(kind: String) -> Dictionary:
	if not game.ai_keep.has(team) or not game.ai_keep[team].has(kind):
		return {}
	var keep: Dictionary = game.ai_keep[team][kind]
	var sc: Vector2i = keep.get("spring", Vector2i(-1, -1))
	var has_spring := _mine("mainspring").any(func(b: Building) -> bool: return b.cell == sc)
	if game.clock - float(keep["t"]) > KEEP_FOR or not has_spring:
		_unkeep(kind)
		if game.mlog:
			game.mlog.add("%s lets go of the spot it kept for a %s (%s)" % [game.mlog.who(team), String(Defs.BUILDINGS[kind]["name"]), "too long" if has_spring else "no Mainspring there"])
		return {}
	return keep


func _unkeep(kind: String) -> void:
	if game.ai_keep.has(team):
		game.ai_keep[team].erase(kind)


## Our finished gear buildings a new ring may hang on, the halls and the Works first (not a Ratchet Turret: nothing else
## should crowd its circle).
func _gear_neighbours() -> Array:
	var out: Array = _halls() + _mine(_works())
	for b in game.buildings:
		if b.team == team and not b.dead and b.built and GearNet.has_gear(b) and b.kind != Defs.CW_TURRET and not out.has(b):
			out.append(b)
	return out.filter(func(b: Building) -> bool: return b.built and not b.dead)


## Gear mode: a building whose work DRIVE scales (GearEcon: a Cog Press, the Works, a Mainspring...) goes where its ring
## meshes with a Clocktower's (100%), nearest the main Clocktower first; (-1, -1) when there is no room (the usual search).
## The first Light Works keeps room beside it for a Mainspring (its Springers, later); a Works built while no Works meshes
## with a Mainspring goes by a Mainspring first (THE TENSION RULE).
func _drive_spot(kind: String) -> Vector2i:
	if not _clock() or not Defs.gear_mode or not GearEcon.uses_drive(kind) or kind == String(_f()["hall"]):
		return Vector2i(-1, -1)
	# (and the next ones too, up to three that may make Springers: one Works makes a Springer every 25 s, too few)
	if kind == _works() and _mine(_works()).filter(func(b: Building) -> bool: return game.gear_net.spring_for(b) != null).size() < 3:
		for sp in _mine("mainspring"):
			if sp.built:
				var cs := GearEcon.room_spot(game, team, kind, [sp])
				if cs.x >= 0:
					return cs
	var users: Array = ["mainspring"] if kind == _works() and _mine(_works()).is_empty() else []
	var halls: Array = _halls().filter(func(h: Building) -> bool: return h.built)
	if game.starts.size() > team:
		var home := Vector2(game.starts[team]) * Defs.TILE
		halls.sort_custom(func(a: Building, b: Building) -> bool: return a.center().distance_to(home) < b.center().distance_to(home))
	for h in halls:
		var c := GearEcon.room_spot(game, team, kind, [h], users, h.center(), true, 8)
		if c.x >= 0:
			return c
	return Vector2i(-1, -1)


## Gear mode: where the Mainspring goes. Its ring meshes with a Light Works' (so that Works may make Springers: anything that
## costs Tension is made only where a Mainspring meshes, GearEcon) and keeps room round it for an Escapement and a Clock
## Aviary; with no room by a Works, by the Clocktower; `spare`: a second one, only room for the Escapement and the Aviary.
var _spring_heavy := false          # _spring_spot chose a spot with room for the Escapement AND the Heavy Works
var _spring_users: Array = []       # ... and in which order its greedy count placed them (GearEcon.room_cells)


func _spring_spot(spare := false) -> Vector2i:
	_spring_heavy = false
	if spare:
		# (a second one for the Clock Aviary: room for it)
		for h in _halls():
			if h.built:
				var r: Array = GearEcon.room_spot_n(game, team, "mainspring", [h], [Defs.CW_AIR])
				if int(r[1]) >= 1:
					return r[0]
		return Vector2i(-1, -1)
	var works: Array = _mine(_works()).filter(func(b: Building) -> bool: return b.built and game.gear_net.spring_for(b) == null)
	var fall := Vector2i(-1, -1)
	# (0.14.94: beside a Works with room for the Escapement AND the Heavy Works' big ring, when there is such a spot: the
	# Heavy Works must mesh with a Mainspring too, and a crowded plateau had no room left for it by any)
	if _mine(Defs.CW_HEAVY).is_empty():
		for users in [[Defs.CW_TECH, Defs.CW_HEAVY], [Defs.CW_HEAVY, Defs.CW_TECH]]:
			# (both orders: the greedy count gives the first kind the first pick of the room)
			for w in works + _halls().filter(func(h: Building) -> bool: return h.built):
				var rh: Array = GearEcon.room_spot_n(game, team, "mainspring", [w], users)
				if int(rh[1]) >= 2:
					_spring_heavy = true
					_spring_users = users
					return rh[0]
	for w in works:
		# (room for the Escapement itself: a count of 1 over [Escapement, Aviary] was the Aviary's room in one game, and
		# the Escapement never found a place, 0.14.72 Hollowfen)
		var r2: Array = GearEcon.room_spot_n(game, team, "mainspring", [w], [Defs.CW_TECH])
		if int(r2[1]) >= 1:
			return r2[0]          # (beside a Works, room for the Escapement at least)
	# no room by a Works: by a Clocktower, with room for the Escapement AND a Works that may make Springers (_springer_works)
	for h in _halls():
		if h.built:
			var r3: Array = GearEcon.room_spot_n(game, team, "mainspring", [h], [Defs.CW_TECH, _works()])
			if int(r3[1]) >= 2:
				return r3[0]
			if fall.x < 0:
				var r4: Array = GearEcon.room_spot_n(game, team, "mainspring", [h], [Defs.CW_TECH])
				if int(r4[1]) >= 1:
					fall = r4[0]
	if fall.x < 0:
		# (a cramped corner base: by any building of ours on the field, with room for the Escapement; 0.14.73 Kestrel
		# Rise waited nine minutes for one)
		for b in game.buildings:
			if fall.x >= 0:
				break
			if b.team == team and b.built and not b.dead and b.kind != "mainspring" and GearEcon.uses_drive(b.kind):
				var r5: Array = GearEcon.room_spot_n(game, team, "mainspring", [b], [Defs.CW_TECH])
				if int(r5[1]) >= 1:
					fall = r5[0]
	if fall.x < 0:
		for h in _halls():
			if h.built and fall.x < 0:
				fall = GearEcon.room_spot(game, team, "mainspring", [h])
	return fall


## Gear mode: Works that may make Springers, Netters and Pendulums (their ring meshes with a Mainspring's: THE TENSION RULE).
## None: the first comes at once, as soon as a Mainspring stands: a second Mainspring right beside a Works that has none
## (it winds Tension too), else a new Works by a Mainspring. Once the Escapement works, a second one on Normal and Hard
## (one Works makes a Springer every 25 s: too few for the army it backs), a third on Hard with money in the bank.
## (0.14.72 games: a Works that could make Springers was never built in one game in two, and no Springer came all game.)
var _springer_works_t := 0.0
var _jw_plan := {}              # {"kind", "cell"}: the next Mainspring or Works that would let a Works make Springers


func _springer_works() -> void:
	if not _mine("mainspring").any(func(b: Building) -> bool: return b.built):
		return
	var works := _mine(_works())
	var meshed: int = works.filter(func(b: Building) -> bool: return game.gear_net.spring_for(b) != null).size()
	var want := 1
	if game.has_working(team, Defs.CW_TECH):
		want = _lv([1, 2, 2])
		if difficulty >= 2 and _gold() > 400:
			want = 3
	if meshed >= want or _busy_building(_works()) or _busy_building("mainspring"):
		_jw_plan = {}
		return
	if game.clock >= _springer_works_t:
		_springer_works_t = game.clock + 6.0
		_jw_plan = _jw_find(works)
	if _jw_plan.is_empty():
		return          # (no room for either: nothing is held back for it)
	var kind: String = _jw_plan["kind"]
	var cost := int(Defs.BUILDINGS[kind]["cost"])
	if _gold() >= cost + 20:
		_construct(kind, _jw_plan["cell"])
		if game.mlog and kind == "mainspring":
			game.mlog.add("%s builds a Mainspring by a Light Works (so it may make Springers)" % game.mlog.who(team))
		_jw_plan = {}
		_springer_works_t = game.clock + 6.0
		return
	# (saved up for like the tech: the army pauses for it once it holds the line, _produce)
	if _threat() == Vector2.INF or _holds_line():
		_reserve = maxi(_reserve, cost + 20)
		_tech_hold = true


## Where the next Springer Works comes from: a Mainspring beside a Works that has none (it winds Tension too), else a new
## Works by a Mainspring; {} when there is no room for either.
func _jw_find(works: Array) -> Dictionary:
	for w in works:
		if w.built and game.gear_net.spring_for(w) == null:
			var c := GearEcon.room_spot(game, team, "mainspring", [w])
			if c.x >= 0:
				return {"kind": "mainspring", "cell": c}
	for sp in _mine("mainspring"):
		if sp.built:
			var c2 := GearEcon.room_spot(game, team, _works(), [sp])
			if c2.x < 0:
				for deg in [90.0, 270.0, 0.0, 180.0]:
					c2 = GearNet.ring_spot(game, team, _works(), sp, deg, true)
					if c2.x >= 0:
						break
			if c2.x >= 0:
				return {"kind": _works(), "cell": c2}
	for w in works:
		if w.built and game.gear_net.spring_for(w) == null:
			for deg in [90.0, 270.0, 0.0, 180.0]:
				var c3 := GearNet.ring_spot(game, team, "mainspring", w, deg, true)
				if c3.x >= 0:
					return {"kind": "mainspring", "cell": c3}
	return {}


## Gear mode, THE AIR (Defs.CW_AIR; scripts/cw_air.gd), kept simple: once its Escapement works, ONE Clock Aviary when the
## enemy shows flyers (or late anyway); Swifts against the flyers it has seen (_produce); TICKING OWL researched late with
## Tension to spare; then, while no enemy flyer is about, one Swift at a time morphed into a Ticking Owl where it is safe
## (not fighting, no armed enemy near; the nearest home) (the Owls go with the army and bomb buildings).
var _air_seen := 0
var _air_seen_t := -999.0


## Enemy flyers this side sees now, the most seen at once remembered for 90 s.
func _foe_air() -> int:
	var n := 0
	for u in game.units:
		if not u.dead and not u.off_field and u.is_air() and game.hostile(u.team, team) and game.side_sees(team, u.position):
			n += 1
	if n > 0:
		_air_seen = maxi(n, _air_seen if game.clock - _air_seen_t < 90.0 else 0)
		_air_seen_t = game.clock
	elif game.clock - _air_seen_t > 90.0:
		_air_seen = 0
	return _air_seen


var _want_aviary := false           # (its Tension price is kept: no Springers eat into it, _produce)


func _air(t: float) -> void:
	var av := _mine(Defs.CW_AIR)
	_want_aviary = av.is_empty() and (_foe_air() > 0 or t > _lv([1300.0, 780.0, 660.0])) and game.requirement_met(team, Defs.CW_AIR)
	if av.is_empty():
		var cost := int(Defs.BUILDINGS[Defs.CW_AIR]["cost"])
		if (_foe_air() > 0 or t > _lv([1300.0, 780.0, 660.0])) and _gold() >= cost + 20 and game.requirement_met(team, Defs.CW_AIR) \
				and game.tension(team) >= float(Defs.tension_cost(Defs.BUILDINGS[Defs.CW_AIR])):
			# (all it makes costs Tension: its ring must mesh with a Mainspring's; no room by one, a second Mainspring first)
			var spot := Vector2i(-1, -1)
			for sp in _mine("mainspring"):
				if sp.built and spot.x < 0:
					spot = GearEcon.room_spot(game, team, Defs.CW_AIR, [sp])
			if spot.x >= 0:
				_construct(Defs.CW_AIR, spot)
			elif _mine("mainspring").size() < 3 and not _busy_building("mainspring") and _gold() >= cost + int(Defs.BUILDINGS["mainspring"]["cost"]):
				var ss := _spring_spot(true)
				if ss.x >= 0:
					_construct("mainspring", ss)
		return
	var built: Array = av.filter(func(b: Building) -> bool: return b.built)
	if built.is_empty():
		return
	var home: Building = built[0]
	if not game.has_tech(team, "owl_morph"):
		if t > _lv([1500.0, 900.0, 780.0]) and not home.queue.has("@owl_morph") and game.tension(team) >= float(Defs.RESEARCH["owl_morph"]["tension"]) + 25.0 \
				and game.research_problem(home, "owl_morph") == "":
			game.start_research(home, "owl_morph")
		return
	if _foe_air() > 0 or _threat() != Vector2.INF or game.tension(team) < float(Defs.OWL_MORPH["tension"]) + 25.0:
		return          # (Swifts are needed as they are; or no Tension to spare)
	var army := game.army(team)
	if army.any(func(u: Unit) -> bool: return u.owl_t >= 0.0):
		return          # (one at a time)
	# the safest Swift: not fighting, no armed enemy within 10 tiles, the nearest home (it hovers helpless for the morph)
	var hall := _halls()
	var home_at: Vector2 = (hall[0] as Building).center() if not hall.is_empty() else Vector2.ZERO
	var best: Unit = null
	var bd := INF
	for u in army:
		if u.kind != Defs.CUCKOO or u.owl_t >= 0.0 or (u.target != null and is_instance_valid(u.target)) or CwAir.morph_problem(u) != "":
			continue
		var unsafe := false
		for o in game.units_near(u.position, 10.0 * Defs.TILE):
			if not o.dead and game.hostile(o.team, team) and not o.is_worker() and o.has_attack():
				unsafe = true
				break
		if unsafe:
			continue
		var dd: float = u.position.distance_to(home_at)
		if dd < bd:
			bd = dd
			best = u
	if best != null:
		CwAir.start_morph(best)


## Our supply building (the Clockwork's Regulator in gear mode: Defs.supply_kind).
func _sup() -> String:
	return Defs.supply_kind(game.faction_of(team))


## The Clockwork's army works: the Light Works in gear mode, else the Assembly Works.
func _works() -> String:
	return Defs.CW_WORKS if Defs.gear_mode else "assembly_works"


func _brood() -> bool:
	return game.faction_of(team) == "brood"


func _clock() -> bool:
	return game.faction_of(team) == "clockwork"


func _crown() -> bool:
	return game.faction_of(team) == "crown"


func _halls() -> Array:
	return _mine(_f()["hall"])


func _busy_building(kind: String) -> bool:
	return _mine(kind).any(func(b: Building) -> bool: return not b.built)


func _gold() -> int:
	return game.players[team]["gold"]


func _res2() -> float:
	return float(game.players[team]["res2"])


# ------------------------------------------------------------------ economy

## Brood: the Spawning Den is due (no Den yet, enough hands to spare): the grubs wait for its
## 150 biomass instead of eating every coin (the Den is the only door to Raptors).
func _warren_due() -> bool:
	if not _brood() or not _mine("warren").is_empty():
		return false
	return game.workers(team).size() >= _warren_hands()


## Hands the Brood wants before the Den goes down (the rushing plans open with it sooner).
func _warren_hands() -> int:
	if strategy in ["xrush", "rush"]:
		return 4          # (the pit takes one grub: the Den goes down with the rest, as soon as 150 is there)
	var n: int = _lv([8, 7, 6])
	if strategy in ["rush", "air"]:
		n = mini(n, 5)
	return n


## Brood: the army value the plan wants by now (a curve per plan: start second, full second,
## value), or more when we SEE a bigger enemy army (1.2x its value; only what our eyes show).
## Under it, the eggs come before grubs beyond a working minimum. No cheating: unseen
## enemies count for nothing.
const ARMY_CURVE := {
	"rush": [40.0, 120.0, 300.0], "xrush": [30.0, 110.0, 400.0], "air": [100.0, 260.0, 330.0], "timing": [70.0, 200.0, 300.0],
	"balanced": [70.0, 200.0, 260.0], "economy": [100.0, 260.0, 200.0],
}


func _army_value() -> float:
	var v := 0.0
	for u in game.army(team):
		if not u.dead:
			v += float(u.d.get("cost", 50)) / maxf(1.0, float(u.d.get("spawn", 1))) + float(u.d.get("cost2", 0)) * 0.5
	for h in _halls():
		for k in h.queue:
			if Defs.UNITS.has(k) and not bool(Defs.UNITS[k].get("worker", false)):
				v += float(Defs.UNITS[k]["cost"]) / maxf(1.0, float(Defs.UNITS[k].get("spawn", 1)))
	return v


func _army_want() -> float:
	var c: Array = ARMY_CURVE.get(strategy, ARMY_CURVE["balanced"])
	var want := clampf((game.clock - float(c[0])) / (float(c[1]) - float(c[0])), 0.0, 1.0) * float(c[2])
	var foe := _foe()
	if foe >= 0:
		var seen := 0.0
		for u in game.army(foe):
			if not u.dead and game.is_visible_to(team, u.position):
				seen += float(u.d.get("cost", 50)) / maxf(1.0, float(u.d.get("spawn", 1)))
		want = maxf(want, seen * 1.2)
	return want


## Brood: the army is under its curve and the Den stands: eggs before more grubs.
func _army_behind() -> bool:
	return _brood() and game._has_built(team, "warren") and _army_value() < _army_want()


func _workers() -> void:
	var labs := game.workers(team)
	var cap := 0
	for b in game.buildings:
		if b.team == team and not b.dead and b.crew_max() > 0:
			cap += b.crew_max()
	var fill: float = 0.75 if difficulty == 0 else 1.0
	var extra := 2
	if _brood():
		extra = 3          # grubs get used up as buildings
	elif _clock():
		extra = 1 + (2 if game.army(team).size() >= 4 else 0)   # builder + escorts
		if Defs.gear_mode:
			extra = 1 + _escort_want(game.army(team))          # (the Winders that go with the army are extra hands, not taken from the presses)
	var want := mini(int((cap * fill + extra) * float(_s("workers"))), 46 if difficulty >= 3 else _lv([16, 30, 40]))
	if _clock():
		# a base is saturated at ~13 Winders (Clocktower 4, 4-5 a Boiler; gear mode: two Cog Presses of 6 and a
		# Mainspring of 3): the rest of the supply is for the army
		want = mini(want, (16 if Defs.gear_mode else 14) * _halls().size() + extra + 2)
		want = mini(want, 36 if difficulty >= 3 else _lv([16, 26, 32]))
	if strategy == "xrush":
		want = mini(want, 8)       # (a six-pool: about eight hands, everything else is Raptors)
	var worker: String = _f()["worker"]
	var queued := 0
	for h in _halls():
		queued += h.queue.filter(func(k: String) -> bool: return k == worker).size()
	# (the Barracks and the Mill first, then the wall, before the crew grows further)
	var hold_gold: bool = _crown() and difficulty > 0 and labs.size() + queued >= 6 and not _mine("cottage").is_empty() and game.clock < 200.0 and \
			((opening == "mill" and (_mine("barracks").is_empty() or _mine("powder_mill").is_empty())) or (not _walled and (_wall_wanted() or _cw_active())))
	# (a feared rush with a Barracks standing: the first Musketeers before more labourers)
	if _army_first() and labs.size() >= (6 if safe_opening else 8) + (4 if opening == "breeder" else 0) and not _mine("barracks").filter(func(b: Building) -> bool: return b.built).is_empty():
		hold_gold = true
	if r5.hold_labourers(labs.size() + queued):
		hold_gold = true            # (round 5: against the Clockwork the army catches up first)
	if _clock() and _mine(_works()).is_empty() and game.clock > _lv([90.0, 60.0, 40.0]) and labs.size() >= 7 \
			and _gold() < int(Defs.BUILDINGS[_works()]["cost"]) + 20:
		hold_gold = true            # (the Winders wait for the Works' 200)
	if _brood():
		# the Den first (save its 150), then the army before more grubs than a working minimum
		if _warren_due() and _gold() < int(Defs.BUILDINGS["warren"]["cost"]) + 25:
			hold_gold = true
		elif brood != null and strategy != "xrush":
			# (the army before more grubs, but the economy never stands still: AIBrood.army_first; and the
			# biomass put by for a Clutch Mound, the Pen or the Gorge Pit: AIBrood.reserve)
			if brood.army_first(labs.size() + queued) or (labs.size() + queued >= 4 and brood.holding(int(Defs.UNITS[worker]["cost"]))):
				hold_gold = true
		elif _army_behind() and labs.size() + queued >= (5 if strategy == "xrush" else ((6 if not _first_wave else 10) if strategy == "rush" else (9 if strategy != "economy" else 10))):
			hold_gold = true
		elif brood != null and labs.size() + queued >= 4 and brood.holding(int(Defs.UNITS[worker]["cost"])):
			hold_gold = true      # (biomass put by for a Clutch Mound, the Pen or the Gorge Pit: scripts/ai_brood.gd)
	for h in _halls():
		if h.built and not hold_gold and labs.size() + queued < want and (h.uses_eggs() or h.queue.size() < 2):
			if game.train(h, worker) == "":
				queued += 1
	# Everyone idle goes to a post with room (escorts excepted).
	_escort = _escort.filter(func(u) -> bool: return is_instance_valid(u) and not u.dead)
	_repair_wall()
	_worker_safety()
	for u in labs:
		if u.order == "idle" and u.can_gather() and not _escort.has(u) and not _fled.has(u):
			var site := _farm_first(u) if _crown() else null
			if site == null:
				site = _safe_site(u)
			if site:
				u.cmd_gather(site)
	if _crown():
		_balance_mill(labs)
		_fill_farm(labs)
	if _crown() or _brood():
		_move_off_tired_soil(labs)
	if _clock():
		_tend_sites(labs)


# ---- worker safety (a good player keeps mining, pulls the hands out of reach of what they
# cannot beat, fights only with a clear majority, and sends everybody back afterwards) ----
const FLEE_R := 250.0           # a worker this close to armed enemies he cannot beat runs
const SAFE_R := 380.0           # ... and goes back when nothing armed is this near him or his post
const FLEE_MAX := 60.0          # a post still unsafe after this long: the hands look for another
const FIGHT_RATIO := 3.0        # the hands fight only with this much more strength than the raiders
const CLUSTER_R := 300.0        # armed enemies this close together are one raid

var _danger_pts: Array = []     # [position, reach] of the armed enemies (and known guns) near the economy
var _fighters: Dictionary = {}  # Unit -> true: the workers sent to fight


func _dps(u: Unit, armor: float) -> float:
	var dmg := float(u.d.get("damage", 0))
	if dmg <= 0.0:
		return 0.0
	return maxf(dmg - armor, 1.0) / maxf(float(u.d.get("cooldown", 1.0)), 0.3)


## Lanchester strength of a group: total hit points x total damage per second.
func _power(list: Array, armor: float) -> float:
	var hp := 0.0
	var dps := 0.0
	for u in list:
		hp += maxf(u.hp, 1.0)
		dps += _dps(u, armor)
	return hp * dps


## Is this ground (or the walk to it from `from`) under the armed enemies seen near the economy?
func _unsafe(p: Vector2, from := Vector2.INF) -> bool:
	for d in _danger_pts:
		var q: Vector2 = d[0]
		if p.distance_to(q) < SAFE_R:
			return true
		if from != Vector2.INF:
			var seg := Geometry2D.get_closest_point_to_segment(q, from, p)
			if seg.distance_to(q) < FLEE_R * 0.7:
				return true
	return false


func _safe_site(u: Unit) -> Building:
	var site := game.free_site(team, u.position)
	if site and not _unsafe(site.center(), u.position):
		return site
	return null


func _worker_safety() -> void:
	_note_guns()
	for id in _known_foes.keys():
		if game.clock - float(_known_foes[id]) > 60.0:
			_known_foes.erase(id)
	for w in _fled.keys():
		if not is_instance_valid(w) or w.dead:
			_fled.erase(w)
	for w in _fighters.keys():
		if not is_instance_valid(w) or w.dead:
			_fighters.erase(w)
	var labs: Array = game.workers(team)
	var foes := {}
	for w in labs:
		for o in game.units_near(w.position, FLEE_R + 100.0):
			if not foes.has(o) and game.hostile(o.team, team) and not o.dead and not o.off_field and _armed(o) and _sighted(o):
				foes[o] = true
	_danger_pts = []
	var clusters: Array = []        # each {"foes": [], "c": centre}
	for o in foes:
		_danger_pts.append([o.position, FLEE_R])
		var placed := false
		for c in clusters:
			if (c["c"] as Vector2).distance_to(o.position) < CLUSTER_R:
				c["foes"].append(o)
				var n: int = c["foes"].size()
				c["c"] = (c["c"] as Vector2) * float(n - 1) / float(n) + o.position / float(n)
				placed = true
				break
		if not placed:
			clusters.append({"foes": [o], "c": o.position})
	for id in _known_guns:
		var e: Dictionary = _known_guns[id]
		_danger_pts.append([e["p"], float(e["u"].d.get("range", 200)) + 40.0])
	var army: Array = game.army(team).filter(func(u: Unit) -> bool: return not _raiders.has(u) and u.kind != "powder_wagon" and u.kind != Defs.GREAT_WINDER_KIND)
	var stand: Dictionary = {}      # workers kept out of the flee list because they fight
	for c in clusters:
		_raid_workers(c, labs, army, stand)
	# an unarmed intruder (a scout, a worker) with no soldiers about: two hands deal with it, the rest keep working
	if clusters.is_empty() and game.army(team).size() < 3:
		var spot := _threat()
		if spot != Vector2.INF:
			var intr: Array = game.units_near(spot, 260.0).filter(func(o: Unit) -> bool: return game.hostile(o.team, team) and not o.dead and not o.off_field and not o.is_air() and game.is_visible_to(team, o.position))
			if not intr.is_empty():
				var hands: Array = labs.filter(func(w: Unit) -> bool: return (_fighters.has(w) or w.order == "gather") and w.position.distance_to(spot) < 260.0 and not w.keg)
				hands.sort_custom(func(a: Unit, b: Unit) -> bool: return (not _fighters.has(a) and _fighters.has(b)) if _fighters.has(a) != _fighters.has(b) else a.position.distance_to(spot) < b.position.distance_to(spot))
				for w in hands.slice(0, 2):
					stand[w] = true
					_fighters[w] = true
					w.set_meta("guard", true)
					if w.order != "attack" or w.target == null or w.target.dead:
						var best: Unit = null
						for o in intr:
							if best == null or o.position.distance_to(w.position) < best.position.distance_to(w.position):
								best = o
						w.cmd_attack(best)
	# fighters whose raid is over (or who are no longer picked) go back to work
	for w in _fighters.keys():
		if not stand.has(w):
			_fighters.erase(w)
			w.set_meta("guard", false)
			_resume(w)
	_fled_back()


## One raid: fight with a clear majority, else run (to the army, or away from the raiders).
func _raid_workers(c: Dictionary, labs: Array, army: Array, stand: Dictionary) -> void:
	var foes: Array = c["foes"]
	var centre: Vector2 = c["c"]
	var near: Array = labs.filter(func(w: Unit) -> bool: return foes.any(func(o: Unit) -> bool: return o.position.distance_to(w.position) < FLEE_R))
	# (a labourer mending the ramp wall behind it stays while _repair_wall finds him safe there)
	near = near.filter(func(w: Unit) -> bool: return not (_repairers.has(w) and w.order == "repair"))
	if near.is_empty():
		return
	if r5.worker_raid(c, labs, stand):
		return          # (round 5: Winders against riders group up and fight together)
	var armor := 0.0
	var fast := 0.0
	var ground := 0
	for o in foes:
		armor += float(o.d.get("armor", 0))
		fast = maxf(fast, float(o.d.get("speed", 60)))
		if not o.is_air():
			ground += 1
	armor /= foes.size()
	var strength := _power(foes, 0.0)
	for o in foes:
		if float(o.d.get("range", 0)) > 60.0:
			strength += _power([o], 0.0) * 0.5      # shooters hit hands that cannot close in
	var fighters := near.filter(func(w: Unit) -> bool: return float(w.d.get("damage", 0)) > 0.0 and not w.keg)
	var mine := _power(fighters, armor) if ground > 0 else 0.0
	var ratio := mine / maxf(strength, 1.0)
	var help := 0
	for u in army:
		if u.position.distance_to(centre) < 550.0 or _det.has(u):
			help += 1
	var fight: Array = []
	if ratio >= FIGHT_RATIO and (game.army(team).size() < 3 or help == 0):
		# only as many hands as it takes (two at least); the rest keep working
		fighters.sort_custom(func(a: Unit, b: Unit) -> bool: return a.position.distance_to(centre) < b.position.distance_to(centre))
		for w in fighters:
			fight.append(w)
			if fight.size() >= 2 and _power(fight, armor) >= FIGHT_RATIO * strength:
				break
	elif ratio >= 1.0 and fast > 74.0 and help == 0:
		fight = fighters          # cannot outrun them and nobody is coming: stand together
	if not fight.is_empty():
		var targets: Array = foes.filter(func(o: Unit) -> bool: return not o.is_air())
		for w in fight:
			stand[w] = true
			_fighters[w] = true
			w.set_meta("guard", true)
			_fled.erase(w)
			if w.order != "attack" or w.target == null or w.target.dead:
				var best: Unit = null
				for o in targets:
					if best == null or o.position.distance_to(w.position) < best.position.distance_to(w.position):
						best = o
				if best:
					w.cmd_attack(best)
		near = near.filter(func(w: Unit) -> bool: return not stand.has(w) and foes.any(func(o: Unit) -> bool: return o.position.distance_to(w.position) < 110.0))
	# the rest run (a worker at the edge of a fight he is not in is hit anyway)
	if fight.is_empty() or not near.is_empty():
		var halls: Array = _halls().filter(func(h: Building) -> bool: return h.built)
		for w in near:
			if stand.has(w):
				continue
			var near_foe := INF
			for o in foes:
				near_foe = minf(near_foe, o.position.distance_to(w.position))
			if not _fled.has(w):
				_fled[w] = {"since": game.clock, "site": w.home_mine if w.order == "gather" else null, "build": w.order_target if w.order == "build" else null}
				w.set_meta("guard", false)
				w.cmd_move(_flee_spot(w, centre, army, halls, help))
			elif w.order != "move" or near_foe < FLEE_R * 0.8:
				w.cmd_move(_flee_spot(w, centre, army, halls, help))


## Where a worker runs: out of reach of the raiders (a hall or open ground), never towards the fight.
func _flee_spot(w: Unit, centre: Vector2, army: Array, halls: Array, help: int) -> Vector2:
	# else: the safest of the halls and eight points round him (open ground, far from the raiders)
	var cands: Array = []
	for h in halls:
		cands.append(h.center() + (h.center() - centre).normalized() * 90.0)
	for k in 8:
		cands.append(w.position + Vector2.RIGHT.rotated(k * TAU / 8.0) * 320.0)
	var best := Vector2.INF
	var bs := -INF
	for p in cands:
		if not game.passable(Vector2i(p / float(Game.T)), team):
			continue
		var score: float = minf(p.distance_to(centre), 500.0) - 0.35 * p.distance_to(w.position)
		for d in _danger_pts:
			if p.distance_to(d[0]) < FLEE_R:
				score -= 300.0
			if Geometry2D.get_closest_point_to_segment(d[0], w.position, p).distance_to(d[0]) < 130.0:
				score -= 400.0        # (the way out must not run past them)
		if score > bs:
			bs = score
			best = p
	if best == Vector2.INF:
		return w.position + (w.position - centre).normalized() * 200.0
	return best + Vector2(randf_range(-25, 25), randf_range(-25, 25))


## Back to work once nothing armed is near the post, or somewhere else if the post stays unsafe.
func _fled_back() -> void:
	for w in _fled.keys():
		var e: Dictionary = _fled[w]
		var nearest := INF
		for d in _danger_pts:
			nearest = minf(nearest, (d[0] as Vector2).distance_to(w.position))
		var site = e["site"]
		var post: Vector2 = w.position
		if is_instance_valid(site) and site is Building and not site.dead:
			post = site.center()
		elif is_instance_valid(e["build"]) and e["build"] is Building:
			post = (e["build"] as Building).center()
		var calm := not _unsafe(post, w.position) and nearest >= SAFE_R
		if calm:
			_fled.erase(w)
			_resume(w, e)
		elif game.clock - float(e["since"]) > FLEE_MAX and nearest >= FLEE_R:
			var alt := _safe_site(w)
			_fled.erase(w)
			if alt:
				w.cmd_gather(alt)
			else:
				w.cmd_stop()


func _resume(w: Unit, e := {}) -> void:
	var site = e.get("site", w.home_mine)
	var build = e.get("build", null)
	if is_instance_valid(build) and build is Building and not build.dead and not build.built:
		w.cmd_build(build)
	elif is_instance_valid(site) and site is Building and not site.dead and site.built and not site.barren():
		w.cmd_gather(site)
	else:
		var alt := game.free_site(team, w.position)
		if alt:
			w.cmd_gather(alt)
		else:
			w.cmd_stop()


## Crown, the first minutes: gold (the farms' harvests: 380 each, faster with every hand on
## them) pays for the wall, the Barracks and every Musketeer; the Powder Mill only has to
## grind the 10 powder a Musketeer costs. So the Mill gets a small crew while the bank of powder
## is healthy, and the rest tend the farms (a farm with 1-2 hands ripens in two minutes).
func _mill_cap() -> int:
	if game.clock > 300.0 or difficulty == 0:
		if difficulty > 0 and _res2() > 300.0 and _gold() < 150:
			# powder piling up while gold runs out (2,000 powder banked and no gold, coach round 3): two hands a think
			# back from the Mills to the farms, never below one a Mill
			var crew := 0
			var mills := 0
			for m in _mine("powder_mill"):
				if m.built:
					crew += m.crew.size()
					mills += 1
			return maxi(mills, crew - 2)
		return 99
	if _mine("barracks").is_empty():
		return 0
	return 3 if _res2() < (20.0 if safe_opening else 50.0) else 1        # (powder for the first two Musketeers: 10 each; more hands belong on the farms)


func _farm_first(u: Unit) -> Building:
	var best: Building = null
	var bd := INF
	for f in _mine("farm"):
		if not f.built or f.barren() or f.crew.size() >= f.crew_max():
			continue
		# (fill one farm before the next: a full crew ripens it in 40 s, the gold comes in sooner)
		var dd: float = f.center().distance_to(u.position) - f.crew.size() * 120.0
		if dd < bd:
			bd = dd
			best = f
	if best == null:
		return null
	var mills := _mine("powder_mill").filter(func(m: Building) -> bool: return m.built and not m.barren())
	var mill_crew := 0
	for m in mills:
		mill_crew += m.crew.size()
	# (the Mill takes its small share first)
	if mill_crew < _mill_cap() and not mills.is_empty():
		return null
	return best


## Crown, the first minutes (one hall): the hands of a young farm go to the farm that is nearest
## its harvest until that one has its full crew of 8 (two at a time): the crew ripens one farm
## in 40 s, so the gold comes in sooner (a lump the wall and the Barracks are waiting for).
func _fill_farm(labs: Array) -> void:
	if difficulty == 0 or game.clock > 360.0 or _halls().size() > 1:
		return
	var farms := _mine("farm").filter(func(f: Building) -> bool: return f.built and not f.barren())
	if farms.size() < 2:
		return
	farms.sort_custom(func(a: Building, b: Building) -> bool: return a.growth > b.growth)
	var to: Building = farms[0]
	if to.crew.size() >= to.crew_max() or to.growth > 0.97:
		return
	var moved := 0
	for u in labs:
		if moved >= 2 or to.crew.size() + moved >= to.crew_max():
			break
		var site = u.home_mine
		if u.order != "gather" or not (site is Building) or site == to or (site as Building).kind != "farm" or u.carrying > 0:
			continue
		if (site as Building).growth > to.growth - 0.2:
			continue          # (only from a farm clearly farther from its harvest)
		u.cmd_gather(to)
		moved += 1


## Hands on the Mill beyond its cap go to the farms (one or two at a time, never one carrying).
func _balance_mill(labs: Array) -> void:
	var cap := _mill_cap()
	var mills := _mine("powder_mill").filter(func(m: Building) -> bool: return m.built)
	if mills.is_empty() or cap >= 99:
		return
	var crew := 0
	var room := 0
	for m in mills:
		crew += m.crew.size()
		room += m.crew_max() - m.crew.size()
	if crew < cap and room > 0:
		# the first Musketeers need powder: farm hands walk over to the Mill (two at a time)
		var sent := 0
		for u in labs:
			if sent >= 2 or crew + sent >= cap:
				break
			var farm = u.home_mine
			if u.order != "gather" or not (farm is Building) or (farm as Building).kind != "farm" or u.carrying > 0:
				continue
			var m: Building = mills[0]
			if m.crew.size() < m.crew_max():
				u.cmd_gather(m)
				sent += 1
		return
	if crew <= cap:
		return
	var moved := 0
	for u in labs:
		if moved >= 2 or crew - moved <= cap:
			break
		var site = u.home_mine
		if u.order != "gather" or not (site is Building) or (site as Building).kind != "powder_mill" or u.carrying > 0:
			continue
		var to := _farm_first(u)
		if to == null:
			break
		u.cmd_gather(to)
		moved += 1


## Clockwork: a site nobody is starting (its Winder was killed or pulled away, dropping the
## crate on the way): the nearest Winder that isn't building goes to fetch or carry its crate.
func _tend_sites(labs: Array) -> void:
	for b in game.buildings:
		if b.team != team or b.dead or b.built or b.seeded or b.d["faction"] != "clockwork":
			continue
		if game.units.any(func(u: Unit) -> bool: return u.team == team and not u.dead and u.order == "build" and u.order_target == b):
			continue
		var at: Vector2 = b.crate_obj.position if b.crate == "ground" and b.crate_obj else b.center()
		var best: Unit = null
		var bd := INF
		for u in labs:
			if u.dead or u.order == "build" or _escort.has(u):
				continue
			var dd: float = u.position.distance_to(at)
			if dd < bd:
				bd = dd
				best = u
		if best:
			best.cmd_build(b)


## Crown: farmers on spent soil walk over to fresh farms with room (a couple at a time);
## Brood: grubs on pits whose Hive's ground is spent, to pits on fresh ground.
func _move_off_tired_soil(labs: Array) -> void:
	var site_kind := "farm" if _crown() else "feeding_pit"
	var fresh := _mine(site_kind).filter(func(f: Building) -> bool: return f.built and f.soil_left() > 0.0 and f.crew.size() < f.crew_max())
	if fresh.is_empty():
		return
	var moved := 0
	for u in labs:
		if moved >= 2 or fresh.is_empty():
			break
		var site = u.home_mine
		if u.order != "gather" or not (site is Building) or (site as Building).kind != site_kind or (site as Building).soil_left() > 0.0:
			continue
		var to: Building = fresh[0]
		u.cmd_gather(to)
		moved += 1
		if to.crew.size() >= to.crew_max():
			fresh.erase(to)


func _econ_build() -> void:
	if _hall_reserve:
		return
	# (a feared rush: the wall and the Barracks first, once the first farm and Mill stand)
	if _turtling() and game.econ_count(team, "farm") >= 1 and game.econ_count(team, "powder_mill") >= 1:
		return
	if _halls().filter(func(h: Building) -> bool: return h.built).is_empty():
		return
	_recycle_spent()
	var order: Array = []
	if _crown():
		# the second farm, then the mill; a new hall gets its farms before its mill, the farm on
		# the freshest soil (see _econ_spot). The opening decides what comes first: the Mill for
		# Musketeers, or the Horse Breeder (a production building, one is enough) for Horsemen.
		order = ["farm", "powder_mill"]
		var early := game.workers(team).size() < 7 and game.clock < 100.0     # (the first hands farm: gold for labourers first)
		var barracks_up := not _mine("barracks").filter(func(b: Building) -> bool: return b.built).is_empty()
		var no_breeder := _mine("horse_breeder").is_empty()
		if safe_opening and difficulty > 0 and game.econ_count(team, "farm") >= 1 and game.workers(team).size() < 8 and game.clock < 150.0:
			order.erase("farm")      # (one farm takes eight hands: the second comes with the ninth labourer; its 50 gold is a hand now)
		if opening == "breeder" and _mine("barracks").is_empty() and game.clock < 150.0 and game.econ_count(team, "farm") >= 1 and _halls().size() == 1:
			order.erase("farm")      # (a Horseman rush: the second farm once the Barracks is going up)
		if opening == "mill":
			if game.econ_count(team, "powder_mill") == 0 and (((early and _mine("barracks").is_empty()) or (not safe_opening and early)) or (difficulty > 0 and _mine("barracks").is_empty() and game.clock < 200.0)):
				order.erase("powder_mill")      # (the Mill right after the Barracks: it grinds for Musketeers)
			if no_breeder and barracks_up and game.econ_count(team, "powder_mill") > 0 and not _tech_wait():
				order.append("horse_breeder")      # (after the Barracks: the Musketeers first)
		else:
			if no_breeder and not early:
				order.push_front("horse_breeder")
			# no Mill until the rush is out: the first few Horsemen (or the rush is over)
			if game.econ_count(team, "powder_mill") == 0 and (no_breeder or not barracks_up or _rushing()):
				order.erase("powder_mill")
	elif _brood():
		order = ["feeding_pit"]
		# (the Pen turns the fallen into essence: after the Den and a first army, not before; the first one
		# as soon as the army has caught up, its biomass put by: scripts/ai_brood.gd)
		if brood != null and brood.pen_due():
			order.append("brood_pen")
		elif _mine("warren").is_empty() or (_army_behind() and not _horse_alert()):
			pass
		else:
			order.append("brood_pen")
		if _warren_due() and _mine("feeding_pit").size() >= 2:
			order.erase("feeding_pit")
	else:
		# batteries need somewhere to go: a crusher first, then Boilers, a crusher per Boiler
		var mill := Defs.GEAR_PRESS if Defs.gear_mode else ("ore_drill" if Defs.rail_econ else "ore_crusher")      # (gear mode: Cog Presses; rails: Drills dig, trains haul)
		var crushers := _mine(mill).size()
		order = [mill, "boiler"] if crushers <= _mine("boiler").size() else ["boiler", mill]
		if Defs.gear_mode:
			order = [mill]      # (no power in gear mode: no Boilers)
	_reserve = 0
	_tech_hold = false
	for k in _no_room.keys():
		if game.clock - float(_no_room[k]) > 20.0:
			_no_room.erase(k)
	for kind in order:
		if _no_room.has(kind):
			continue
		if not Defs.is_econ(kind) and not _mine(kind).is_empty():
			continue                 # (the Horse Breeder: one)
		if (Defs.is_econ(kind) and game.econ_count(team, kind) >= game.econ_limit(team, kind)) or _busy_building(kind):
			continue
		if _brood() and kind == "feeding_pit" and (not _pit_wanted() or (strategy == "xrush" and _mine("feeding_pit").size() >= 2)):
			continue
		if _gold() < int(Defs.BUILDINGS[kind]["cost"]):
			if _threat() == Vector2.INF:
				_reserve = int(Defs.BUILDINGS[kind]["cost"])    # save up for it first
			return
		var spot := _econ_spot(kind)
		if spot.x >= 0:
			_construct(kind, spot)
			return
		_no_room[kind] = game.clock      # nowhere to put it right now; look again later
		if kind == "feeding_pit":
			_spread_swamp()
	if _brood() and _mine("clutch_mound").size() < _halls().size() + 1 and game.clock > 120.0 and not _warren_due() and not _army_behind():
		_spread_swamp()


## Brood: another Feeding Pit is wanted when the ones we have are nearly full (fewer than 3 free
## places) and the grub limit isn't reached; pits have no count cap, only the swamp's reach and their
## ground circles (Defs.PIT_CLAIM). A pit whose own ground is spent counts for nothing: it is replaced.
func _pit_wanted() -> bool:
	var room := 0
	var live: Array = _mine("feeding_pit").filter(func(p: Building) -> bool: return not p.built or not p.barren())
	for p in live:
		room += p.crew_max() - p.crew.size() if p.built else p.crew_max()
	var limit: int = 46 if difficulty >= 3 else _lv([16, 30, 40])
	var total := 0
	for p in live:
		total += p.crew_max()
	return room < 3 and total < limit + 6


## Crown, a Horseman rush: the Mill waits until this many Horsemen are out.
const RUSH_HORSEMEN := 3


## Horsemen we have out (mounted or not, light or armoured).
func _horsemen() -> int:
	return game.army(team).filter(func(u: Unit) -> bool: return u.kind == "cuirassier" or u.kind == "dismounted").size()


## Crown: the Horseman rush is on (the Breeder opening, until its first horsemen are out):
## one Barracks, every spare coin on horses and horsemen.
func _rushing() -> bool:
	return _crown() and opening == "breeder" and strategy == _opened and _horsemen() < RUSH_HORSEMEN and game.clock < 420.0


func _econ_spot(kind: String) -> Vector2i:
	var ds := _drive_spot(kind)
	if ds.x >= 0:
		return ds
	var halls := _halls()
	var lodes := kind == "powder_mill" or kind == "ore_crusher" or kind == "ore_drill" or kind == Defs.GEAR_PRESS
	if kind == "feeding_pit":
		# Brood: the pit hauls to the capital and must stand on swamp joined to it, as far out as pays most
		var cap := game.capital(team)
		if cap == null or not cap.built:
			return Vector2i(-1, -1)
		# (find_spot keeps the pits' ground circles apart and prefers fresh ground; once the best stretch
		# is taken, a pit goes as far out as the swamp reaches)
		var sp := game.find_spot(team, kind, cap, 7, mini(int(Defs.FOOD_PEAK), int(game.swamp_reach[team])), "far_safe")
		if sp.x < 0 and int(game.swamp_reach[team]) > int(Defs.FOOD_PEAK):
			sp = game.find_spot(team, kind, cap, int(Defs.FOOD_PEAK) - 2, int(game.swamp_reach[team]), "near")
		return sp
	if kind == "farm":
		# farms (pits) go where the soil (the Hive's ground) is freshest: tired land pays a third
		halls.sort_custom(func(a: Building, b: Building) -> bool: return a.soil_left() > b.soil_left())
	elif lodes:
		# a Mill (Crusher) goes by the freshest saltpetre (ore); by a spent hall only if it's the first
		halls.sort_custom(func(a: Building, b: Building) -> bool: return a.lode_left() > b.lode_left())
		if game.econ_count(team, kind) > 0:
			halls = halls.filter(func(h: Building) -> bool: return h.lode_left() > 0.05)
	for h in halls:
		if not h.built:
			continue
		var spot: Vector2i
		if kind == "feeding_pit":
			# far from the Hive pays more (best from ~18 to 22 tiles); stay on our side of the map
			spot = game.find_spot(team, kind, h, 7, int(Defs.FOOD_PEAK), "far_safe")
		elif kind == "brood_pen":
			spot = game.find_spot(team, kind, h, 3, 12, "near")
		else:
			# (on the hall's own ground first: never down below the ramp while there's room up top)
			spot = game.find_spot(team, kind, h, 4, Defs.ECON_RANGE - 2, "behind", true)
			if spot.x < 0:
				spot = game.find_spot(team, kind, h, 4, Defs.ECON_RANGE - 2, "behind")
		if spot.x >= 0:
			return spot
	return Vector2i(-1, -1)


## Brood: a Clutch Mound planted at the edge of the swamp pushes it out for richer pits (it is also
## the supply building: it only goes up while supply is below the cap).
func _spread_swamp() -> void:
	var sup: String = _sup()
	if _busy_building(sup) or _mine(sup).size() >= 2 * _halls().size() + 1:
		return
	if int(game.players[team]["cap"]) >= game.max_supply(team):
		return
	if _no_room.has(sup):
		return
	_no_room[sup] = game.clock
	if _gold() < int(Defs.BUILDINGS[sup]["cost"]) + 40:
		return
	var spot := _mound_spot()
	if spot.x >= 0:
		_construct(sup, spot)


## Brood: where a Clutch Mound goes. The swamp only reaches the low ground joined to the Burrow's if
## a mound stands by the ramp, so: the FIRST mound goes on the plateau close to the top of the ramp;
## the next ones go down on the low ground, at the swamp's edge nearest the enemy, so the swamp keeps
## walking toward them. Falls back to the old rule (out from the capital, safe side) when the map
## has no ramp or no room. (-1, -1): no room.
func _mound_spot() -> Vector2i:
	var cap := game.capital(team)
	if cap == null or not cap.built:
		return Vector2i(-1, -1)
	var sup: String = _sup()
	var spot := Vector2i(-1, -1)
	var h0 := int(game.height[game.idx(game.cell_of(cap.center()))])
	if _mine(sup).is_empty() or not _swamp_on_low_ground(h0):
		var top := game.ramp_top(cap)
		if top != Vector2.INF:
			spot = game.find_spot(team, sup, cap, 3, 10, "near", true, top)
	else:
		spot = _forward_low_spot(cap, h0, sup)
	if spot.x >= 0:
		return spot
	var reach := int(game.swamp_reach[team])
	spot = game.find_spot(team, sup, cap, maxi(8, reach - 4), reach, "far_safe")
	if spot.x < 0:
		spot = game.find_spot(team, sup, cap, 8, reach, "far_safe")
	return spot


## Brood: does our swamp already cover a stretch of low ground (not the capital's height) joined to the Burrow?
func _swamp_on_low_ground(h0: int) -> bool:
	var join: PackedByteArray = game.swamp_hall_conn[team] if game.swamp_hall_conn.size() > team else PackedByteArray()
	if join.size() != game.W * game.H:
		return false
	var n := 0
	for i in join.size():
		if join[i] == 1 and int(game.height[i]) != h0 and game.ramp[i] == 0 and game.cliff[i] == 0:
			n += 1
			if n >= 12:
				return true
	return false


## Brood: a spot on the low ground at the edge of the joined swamp, as near the enemy as the swamp goes.
func _forward_low_spot(cap: Building, h0: int, sup: String) -> Vector2i:
	var join: PackedByteArray = game.swamp_hall_conn[team]
	var foe := _enemy_base() / float(Defs.TILE)
	var cands: Array[Vector2i] = []
	for i in join.size():
		if join[i] == 1 and int(game.height[i]) != h0 and game.ramp[i] == 0 and game.cliff[i] == 0:
			cands.append(Vector2i(i % game.W, i / game.W))
	cands.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return Vector2(a).distance_squared_to(foe) < Vector2(b).distance_squared_to(foe))
	var tried := 0
	var i := 0
	while i < cands.size() and tried < 8:
		var c := cands[i]
		tried += 1
		var spot := game.find_spot(team, sup, cap, 0, 14, "near", false, Vector2(c) + Vector2(0.5, 0.5))
		if spot.x >= 0:
			return spot
		i += maxi(1, cands.size() / 40)     # (try a few well-spread cells, not 8 neighbours)
	return Vector2i(-1, -1)


func _energy_split() -> void:
	# Ore while building up, a balance while an attack is out, all-out war only at home.
	var want := "ECONOMY"
	if _threat() != Vector2.INF:
		want = "WAR"
	elif _attacking or game.clock > _lv([600.0, 420.0, 360.0]):
		want = "BALANCED"
	if game.players[team]["split_name"] != want:
		game.set_split(team, want)


func _supply() -> void:
	if brood != null:
		brood.supply()            # (Clutch Mounds ahead of need, judged from the income and the eggs: scripts/ai_brood.gd)
		return
	var cap: int = game.players[team]["cap"]
	if cap >= game.max_supply(team):
		return
	var used := game.supply_used(team)
	var sup: String = _sup()
	var prod := _halls().size() * 3 if _brood() else 3 * _mine("barracks").size() + 2 * _mine("foundry").size()
	if _clock():
		prod = (3 * _mine(_works()).size()) if Defs.gear_mode else 6 * _mine("assembly_works").size() + 5 * _mine("engine_hall").size()
	var margin := 3 + prod
	var building := _mine(sup).filter(func(b: Building) -> bool: return not b.built).size()
	if _crown() and opening == "breeder" and game.clock < 600.0 and not _mine("barracks").is_empty():
		# a Horseman rush: horsemen (3 supply each) and labourers come out together and every
		# coin goes on them, so the Cottages go up ahead (a second one at once when it's tight)
		margin += 3 + 3 * _mine("barracks").size()
		if cap - used <= margin and building < (2 if cap - used <= 6 else 1):
			_construct(sup)
		return
	if cap - used <= margin and building == 0:
		# Brood: the first mound goes by the ramp, later ones on the low ground toward the enemy (_mound_spot)
		_construct(sup, _mound_spot() if _brood() else Vector2i(-1, -1))


func _build_up() -> void:
	if _hall_first():
		return
	var labs := game.workers(team).size()
	# tech comes sooner or later by strategy (and sooner with money in the bank)
	var t := game.clock / float(_s("tech")) + (60.0 if _gold() > 500 else 0.0)
	var gold := _gold()
	if _clock() and Defs.gear_mode:
		# gear mode: the new-style army only (Light Works, Clock Soldiers); more Works with money in the bank below
		var mw := _mine(_works()).size()
		if mw == 0 and game.clock > _lv([90.0, 60.0, 40.0]) and labs >= 7:
			_construct(_works())
		elif mw == 1 and t > _lv([600.0, 300.0, 220.0]) and gold > 300:
			_construct(_works())
		_turrets()
		_tier2(t)
	elif _clock():
		var works := _mine("assembly_works").size()
		# (the first Works comes by the clock, not the plan's tech factor: every plan needs a line by ~2:00)
		if works == 0 and game.clock > _lv([90.0, 60.0, 40.0]) and labs >= 7:
			_construct("assembly_works")
		elif works == 1 and t > _lv([600.0, 300.0, 220.0]) and gold > 300:
			_construct("assembly_works")
		if works > 0 and _mine("engine_hall").is_empty() and game.requirement_met(team, "engine_hall") and t > _lv([620.0, 340.0, 270.0]) and gold > 250:
			_construct("engine_hall")
		if works > 0 and _mine("charging_pylon").is_empty() and t > _lv([520.0, 280.0, 220.0]):
			_construct("charging_pylon")
		if works > 0 and _mine("capacitor_works").is_empty() and game.requirement_met(team, "capacitor_works") and (t > _lv([700.0, 400.0, 320.0]) or gold > 450):
			_construct("capacitor_works")
	elif _brood():
		_horse_tech()
		if _mine("warren").is_empty() and labs >= _warren_hands():
			_construct("warren")
		if brood != null:
			if brood.gorge_due(t):
				_construct("gorge_pit")         # (after the Pen; its biomass is put by: AIBrood.reserve)
		elif _mine("gorge_pit").is_empty() and game.requirement_met(team, "gorge_pit") and t > _lv([480.0, 250.0, 190.0]):
			_construct("gorge_pit")
		if _mine("roost").is_empty() and game.requirement_met(team, "roost") and t > _lv([560.0, 320.0, 260.0]) and (brood == null or brood.roost_ok()):
			_construct("roost")
		elif strategy == "air" and _mine("roost").is_empty() and game.requirement_met(team, "roost"):
			_construct("roost")
		_grow_hall()
	else:
		# the wall comes before anything else is paid for (a standard moment, or at once when a
		# rush is feared); the rest waits for its gold
		if _cw_active() and not _walled:
			return          # (the ramp Cottage and its gate come before anything else: _cottage_wall)
		if _wall_wanted():
			_wall_off()
			if not _walled:
				_tend_wall()
				return
		var barracks := _mine("barracks").size()
		# the Barracks (and the palisade) need a Cottage
		if barracks == 0 and labs >= _lv([7, 6, 5]) and _mine("cottage").is_empty():
			_construct("cottage")
		if barracks == 0 and (labs >= _lv([9, 8, 7]) or (difficulty > 0 and labs >= 5 and _walled and opening == "mill")):
			_construct("barracks")
		elif barracks == 1 and (t > _lv([420.0, 200.0, 150.0]) or strategy == "rush") and gold > 150 and not _rushing() and not _tech_wait():
			_construct("barracks")
		elif barracks == 2 and difficulty >= 2 and t > _lv([9999.0, 9999.0, 330.0]) and gold > 300:
			_construct("barracks")
		if _tech_wait():
			pass          # (soldiers before tech: the Musketeers' gold is not spent on buildings)
		elif _mine("foundry").is_empty() and game.requirement_met(team, "foundry") and t > _lv([480.0, 260.0, 200.0]):
			_construct("foundry")
		# the Armoury: all the Crown's research (and a second place to refit at)
		if _mine("armoury").is_empty() and game.requirement_met(team, "armoury") and (t > _lv([450.0, 240.0, 180.0]) or gold > 400) and gold >= 150 and not _rushing() and not _tech_wait():
			_construct("armoury")
		if _mine("church").is_empty() and game.requirement_met(team, "church") and t > _lv([500.0, 280.0, 220.0]) and not _tech_wait():
			_construct("church")
		_tend_wall()
	_bank_spend()
	# Money in the bank: more production (and for the Brood, more Hives to lay eggs).
	var at_cap: bool = _crown() and bank_spend_on and game.supply_used(team) >= game.max_supply(team) - 2      # (at the real cap of 200 more production would idle)
	if gold > 400 and not _saving and not _rushing() and not at_cap:
		if _crown() and _mine("foundry").size() < 3 and gold > 700 and not _mine("foundry").is_empty() and not _busy_building("foundry"):
			_construct("foundry")
		elif _crown() and _mine("barracks").size() < 9 and not _busy_building("barracks") and not _mine("barracks").is_empty() and not _tech_wait():
			_construct("barracks")
		elif _clock() and _mine(_works()).size() < 5 and not _busy_building(_works()) and not _mine(_works()).is_empty() and not _tech_hold:
			_construct(_works())
		elif _brood() and gold > 700:
			_more_halls(true)
	# Expand once our economy structures are all up (a new hall brings more slots).
	var hall: String = _f()["hall"]
	var full := true
	for kind in _f()["econ"]:
		if not Defs.build_list(game.faction_of(team)).has(kind):
			continue        # (another mode's economy building: the Clockwork's crushers, drills or Boilers)
		if game.econ_count(team, kind) < game.econ_limit(team, kind):
			full = false
	var expand_t: float = _lv([9999.0, 420.0, 330.0]) * (0.7 if _brood() else 1.0) * float(_s("expand"))
	# Crown: tired soil makes expanding urgent (from ~40% of the best hall's reserve left
	# the wait shrinks to nothing as it runs out)
	var soil := _best_soil()
	if soil < 0.4:
		expand_t *= soil / 0.4
	if _halls().size() >= 2 and (game.clock > expand_t * 1.8 or soil < 0.4) and gold > int(Defs.BUILDINGS[hall]["cost"]) + (150 if soil >= 0.4 else 0):
		_more_halls(false)
	_saving = false
	# (with the soil nearly spent, the next hall is worth saving for even under attack)
	var urgent := soil < 0.25 and not _busy_building(hall)
	if _brood():
		# no far expansions: more Burrows at home for more eggs
		if t > expand_t and gold > int(Defs.BUILDINGS[hall]["cost"]) + 150:
			_more_halls(true)
	elif _halls().size() == 1 and ((full and t > expand_t * 0.6) or t > expand_t):
		var spot: Vector2i = game.expansions[team]
		if game.placement_problem(team, hall, spot, true) == "":
			if gold >= int(Defs.BUILDINGS[hall]["cost"]) + 50:
				_construct(hall, spot)
			elif _threat() == Vector2.INF or urgent:
				_saving = true
		elif urgent:
			_more_halls(false)          # our usual spot is taken: any free ground will do
			_saving = gold < int(Defs.BUILDINGS[hall]["cost"])
	elif _halls().size() >= 2 and urgent and gold < int(Defs.BUILDINGS[hall]["cost"]):
		_saving = _halls().filter(func(h: Building) -> bool: return _land(h) > 0.0).size() < int(_s("halls"))


## Brood: grow the main hall (the highest level, the oldest first) a level at a time: a
## Warren once there's a Spawning Den and a first army out (with biomass to spare), a
## Broodmound later (a Gorge Pit and 300 biomass in the bank). One upgrade at a time.
func _grow_hall() -> void:
	if _saving or _rushing() or game.over or strategy == "xrush":
		return
	var main: Building = null
	for h in _halls():
		if not h.built or h.dead:
			continue
		if h.upgrade_t >= 0.0:
			return                      # already growing
		if main == null or h.level > main.level:
			main = h
	if main == null or main.next_level().is_empty():
		return
	var nl := main.next_level()
	if main.level == 1:
		var army_out: bool = _wave_sup > 0 or _army_supply(game.army(team)) >= _lv([16, 12, 10])
		if not army_out or _gold() < int(nl["cost"]) + _lv([200, 120, 60]):
			return
	elif main.level == 2:
		if _gold() < 300 or _res2() < float(nl.get("cost2", 0)) + 20.0:
			return
	if game.hall_upgrade_problem(main) == "":
		game.start_hall_upgrade(main)


## Brood: a Warren that could grow into a Broodmound (a Gorge Pit, 300 biomass banked)
## waits only for the essence: meanwhile the eggs go to creatures that cost none, and spare
## Raptors are offered up for it (_offer).
func _mound_saving() -> bool:
	if not _brood() or _gold() < 300 or not game._has_built(team, "gorge_pit"):
		return false
	var top := 0
	for h in _halls():
		if h.built and not h.dead:
			if h.upgrade_t >= 0.0:
				return false
			top = maxi(top, h.level)
	return top == 2 and _res2() < float(Defs.HALL_LEVELS[2]["cost2"]) + 20.0


var _walled := false
var _hall_reserve := false      # Crown: holding gold for a Town Hall on fresh land
var _new_hall: Building = null  # Crown: the expansion the guards stand over
var _guards: Array = []         # Crown: the part of the army guarding it
const HALL_FIRST_SOIL := 0.65   # Crown/Brood: the next hall comes first from this share of soil left
var _stage_spot := Vector2i(-1, -1)   # where the next hall goes (the escort walks there first)
var _stage_t := 0.0


## Crown (and Brood): once the freshest soil (ground) is under HALL_FIRST_SOIL and there's no second
## fresh hall coming, a new hall comes before anything else: gold is held for it whatever
## the army's size (training, tech and new buildings wait; the army keeps what it has), it
## goes on the safest free ground and (Crown) part of the army walks over to guard it.
## True while saving.
func _hall_first() -> bool:
	_hall_reserve = false
	var hall: String = _f()["hall"]
	_note_lost_halls()
	if r5.hold_hall():
		return false        # (round 5: against the Clockwork the next hall waits for an army to hold it)
	if _halls().size() >= 7:
		return false
	# halls with a fair share of soil left (one going up counts: it's fresh land)
	var fresh := _halls().filter(func(h: Building) -> bool: return not h.built or _land(h) > 0.25).size()
	# how many fresh halls it needs: a second once the best soil is under HALL_FIRST_SOIL; the Crown also one for every
	# 16 Labourers (a hall's farms and mill hold about that many: with more on one hall's land they stood idle or
	# crowded a tired farm while the main went barren, coach round 2)
	var need := 1 if _best_soil() >= HALL_FIRST_SOIL else 2
	if _crown():
		need = maxi(need, mini(3, ceili(game.workers(team).size() / 16.0)))     # (three fresh halls at most: more halls only grew more hands, round 3)
	elif _clock() and Defs.gear_mode and difficulty >= 1 and (not _mine(Defs.CW_TECH).is_empty() or game.clock > 360.0):
		# (the Clockwork too, one for every 15 Winders: two presses of six and a Mainspring's crew a hall; it sat on two
		# halls with 32 Winders while its main ran dry, and the coached Crown out-earned it from 10:00, clockwork-ai.
		# Once the Escapement is laid: saving for a hall pauses the rest, and an expansion at 2:50 put the Escapement off
		# by up to ten minutes)
		need = maxi(need, mini(3, ceili(game.workers(team).size() / 15.0)))
	if fresh >= need or _busy_building(hall):
		return false
	_hall_reserve = true
	_saving = true
	var cost := int(Defs.BUILDINGS[hall]["cost"])
	if _stage_spot.x < 0 or game.placement_problem(team, hall, _stage_spot, true) != "":
		_stage_spot = _safe_hall_spot()
		_stage_t = game.clock
		if _stage_spot.x < 0:
			_hall_reserve = false
			_saving = false
			return false
	if _gold() < cost:
		return true
	var spot := _stage_spot
	if game.clock - float(_abandoned.get(hall, -99.0)) < 20.0:
		return true                # (a hall site just dropped, its builders chased off: a moment before the next try)
	if _crown():
		# the escort walks over first; the hall goes down once it's there (or after a while)
		var site := (Vector2(spot) + Vector2(Defs.BUILDINGS[hall]["size"]) * 0.5) * Defs.TILE
		var there := _guards.filter(func(u) -> bool: return is_instance_valid(u) and not u.dead and u.position.distance_to(site) < 300.0).size()
		if there < _guards.size() * 0.6 and game.clock - _stage_t < 35.0:
			return true
		# three labourers build it together (faster: less time at 10% health)
		var builders: Array = []
		var labs := game.workers(team).filter(func(u: Unit) -> bool: return u.order != "build" and not u.dead)
		labs.sort_custom(func(a: Unit, b: Unit) -> bool: return a.position.distance_squared_to(site) < b.position.distance_squared_to(site))
		builders = labs.slice(0, 3)
		if not builders.is_empty():
			game.place_building(team, hall, spot, builders)
	else:
		_construct(hall, spot)
	_stage_spot = Vector2i(-1, -1)
	for b in _mine(hall):
		if not b.built and b.cell == spot:
			_new_hall = b
			_guards.clear()
			if game.mlog:
				game.mlog.add("%s is expanding to fresh %s (left at its best hall: %d%%), %d tiles from its main" % [game.mlog.who(team), "land" if _crown() else ("ore" if _clock() else "ground"),
					int(round(_best_soil() * 100)), int(b.center().distance_to(Vector2(game.starts[team]) * Defs.TILE) / Defs.TILE)])
	return true


## A hall of ours that stood and is gone (razed): its spot is left be for LOST_HALL_WAIT s, like one whose builders
## were chased off (the enemy holds that ground: a gear-mode Clockwork laid five Clocktowers on one far spot and lost
## each one, 0.14.79 Frostmere).
const LOST_HALL_WAIT := 240.0
var _hall_cells := {}           # cell of a finished hall of ours -> true


func _note_lost_halls() -> void:
	if not (_clock() and Defs.gear_mode):
		return
	var now := {}
	for h in _halls():
		# (an unfinished Clocktower razed counts too: the enemy holds that ground; 0.14.82, 8:22 "lost a Clocktower
		# (unfinished)")
		now[h.cell] = true
	for c in _hall_cells.keys():
		if not now.has(c):
			note_lost_site(c)
			_hall_cells.erase(c)
	for c in now:
		_hall_cells[c] = true


## A hall of ours (or its crate on the way there) was lost at this cell: the spot waits LOST_HALL_WAIT s, and the
## ground round it (LOST_NEAR tiles) counts as the enemy's while it does (_safe_hall_spot), so the next try isn't the
## next base site over in the same enemy's yard (0.14.84 Greenhold: four Clocktower crates in a row lost by the
## Crown's base). Called from _note_lost_halls (a hall gone) and by Crate.die (a Clocktower's crate shot on the road).
const LOST_NEAR := 16.0
const ENEMY_YARD := 22.0        # tiles: a hall spot on the enemy's side this close to its main, natural or a hall of its is never taken
var _lost_spots := {}           # cell -> until when its ground counts as the enemy's


func note_lost_site(c: Vector2i) -> void:
	_hall_bad[c] = game.clock + LOST_HALL_WAIT
	_lost_spots[c] = game.clock + LOST_HALL_WAIT
	if _stage_spot == c:
		_stage_spot = Vector2i(-1, -1)


## Where the enemy is, for choosing hall ground (in tiles): its mains (known from the start), its natural expansions
## (where anyone expands first), the halls of its we have seen or see now, and the ground where we lost a hall lately.
func _foe_ground(lost := true) -> Array:
	var pts: Array = []
	var hk: String = _f()["hall"]
	for o in game.n_players():
		if not game.hostile(team, o) or game.eliminated[o]:
			continue
		pts.append(Vector2(game.starts[o]) + Vector2(2.5, 2.0))
		if game.expansions.size() > o and game.expansions[o].x >= 0:
			pts.append(Vector2(game.expansions[o]) + Vector2(Defs.BUILDINGS[game.faction_hall(o)]["size"]) * 0.5)
	for b in game.buildings:
		if b.dead or b.team < 0 or not game.hostile(team, b.team) or b.kind != game.faction_hall(b.team):
			continue
		if scout._seen_b.has(b) or game.is_visible_to(team, b.center()):
			pts.append(b.center() / Defs.TILE)
	for c in (_lost_spots.keys() if lost else []):
		if float(_lost_spots[c]) > game.clock:
			pts.append(Vector2(c) + Vector2(Defs.BUILDINGS[hk]["size"]) * 0.5)
		else:
			_lost_spots.erase(c)
	return pts


## Where a new hall is safest: free ground near our main (the usual expansion
## first), away from the enemy's side and from enemies in sight.
func _safe_hall_spot() -> Vector2i:
	var hall: String = _f()["hall"]
	var cands: Array = []
	var ex: Vector2i = game.expansions[team] if game.expansions.size() > team else Vector2i(-1, -1)
	if ex.x >= 0 and game.placement_problem(team, hall, ex, true) == "":
		cands.append(ex)
	# the map's base sites
	for bs in game.base_sites:
		if not cands.has(bs) and game.placement_problem(team, hall, bs, true) == "":
			cands.append(bs)
	for h in _halls():
		if not h.built:
			continue
		for pref in ["near", "far_safe"]:
			var sp := game.find_spot(team, hall, h, Defs.HALL_SPACING, Defs.HALL_SPACING + 12, pref)
			if sp.x >= 0 and not cands.has(sp):
				cands.append(sp)
	if _clock():
		# the Clockwork lives on ore: a Clocktower where one fell with its ore spent is wasted
		cands = cands.filter(func(c: Vector2i) -> bool: return _lode_value(c) > 1.0)
	if cands.is_empty():
		return Vector2i(-1, -1)
	var home := Vector2(game.starts[team]) + Vector2(2.5, 2.0)
	var foe := _foe_ground()
	var foe_real := _foe_ground(false)
	var best := Vector2i(-1, -1)
	var bs := INF
	for c in cands:
		var cc := Vector2(c) + Vector2(Defs.BUILDINGS[hall]["size"]) * 0.5
		var home_d := cc.distance_to(home)
		var score := home_d
		var foe_d := INF
		for fp in foe:
			foe_d = minf(foe_d, cc.distance_to(fp))
		score += maxf(0.0, home_d - foe_d * 0.8) * 3.0
		# never on the enemy's side: closer to an enemy hall (or its natural, or ground where we lost one lately) than
		# to our own main or our nearest hall, only when nothing else is left (0.14.82 / 0.14.84 Greenhold: the
		# Clockwork's next Clocktower went "60 tiles from its main", by the Crown's base, its crate lost each time)
		var own_d := home_d
		for h in _halls():
			own_d = minf(own_d, cc.distance_to(h.center() / Defs.TILE))
		if foe_d < home_d and foe_d < ENEMY_YARD:
			continue               # (in the enemy's yard: its crate or its builders only walk to their deaths)
		if foe_d < home_d or foe_d < own_d + 8.0:
			score += 600.0 + maxf(0.0, home_d - foe_d) * 4.0
		if foe_d < LOST_NEAR:
			score += 300.0
		# nearer the enemy's own halls than ours weighs more than ground near a recent loss of ours: with more base sites
		# (0.15.0) the losses by our own halls left a site on the enemy's half the least bad (test_clock_hall_spot)
		var real_d := INF
		for fp in foe_real:
			real_d = minf(real_d, cc.distance_to(fp))
		if real_d < own_d:
			score += 900.0
		for u in game.units_near(cc * Defs.TILE, 14.0 * Defs.TILE):
			if game.hostile(u.team, team) and not u.dead and not u.is_worker() and game.is_visible_to(team, u.position):
				score += float(u.d["supply"]) * 3.0
		if c == ex:
			score -= 4.0           # (the map's own expansion spot: open ground, near a ramp of ours)
		if float(_hall_bad.get(c, -1.0)) > game.clock:
			continue               # (its builders were just chased off it, or one was lost there: not until the wait is over,
			                       # even if nothing else is left: a crate sent back there was lost again, 0.14.84)
		score -= _lode_value(c)
		if score < bs:
			bs = score
			best = c
	return best


## Crown: two thirds of the army (at least 4) escort a new Town Hall: they walk to its spot
## before it's laid down and stand guard until it's been up a minute; then a third stays
## there as its garrison while it stands. Returns the army without them.
var _guard_until := 0.0


func _guard_new_hall(army: Array) -> Array:
	if _new_hall != null and (not is_instance_valid(_new_hall) or _new_hall.dead):
		_new_hall = null
	var staging := _new_hall == null and _hall_reserve and _stage_spot.x >= 0
	if _new_hall == null and not staging:
		_guards.clear()
		return army
	var site: Vector2 = _new_hall.center() if _new_hall else (Vector2(_stage_spot) + Vector2(Defs.BUILDINGS[_f()["hall"]]["size"]) * 0.5) * Defs.TILE
	if staging:
		_guard_until = 0.0
	if _new_hall and _new_hall.built and _guard_until <= 0.0:
		_guard_until = game.clock + 60.0
	_guards = _guards.filter(func(u) -> bool: return is_instance_valid(u) and not u.dead)
	# two thirds while it goes up and for its first minute, then a third stays as its garrison
	var want := maxi(4, army.size() * 2 / 3)
	if _new_hall and _new_hall.built and game.clock > _guard_until:
		want = maxi(3, army.size() / 3)
		while _guards.size() > want:
			_guards.pop_back()
	if _guards.size() < want:
		var pool := army.filter(func(u: Unit) -> bool: return not _guards.has(u) and u.kind != "powder_wagon" and u.kind != Defs.GREAT_WINDER_KIND and not u.is_air())
		pool.sort_custom(func(a: Unit, b: Unit) -> bool: return a.position.distance_squared_to(site) < b.position.distance_squared_to(site))
		for u in pool.slice(0, want - _guards.size()):
			_guards.append(u)
	for u in _guards:
		if u.position.distance_to(site) > 180.0 and (u.order == "idle" or (u.order != "attack" and u.target == null and u.order_point.distance_to(site) > 200.0)):
			u.cmd_move(site + Vector2(randf_range(-70, 70), randf_range(-70, 70)), true)
	return army.filter(func(u: Unit) -> bool: return not _guards.has(u))


## The share of soil (Crown), ground (Brood) or ore (Clockwork) left at our freshest hall.
func _best_soil() -> float:
	if _brood():
		return 1.0          # (the Brood's ground is the capital's alone: no fresh ground to expand to)
	var best := 0.0
	for h in _halls():
		if h.built:
			best = maxf(best, _land(h))
	return best if not _halls().is_empty() else 1.0


## What's left of what a hall lives on: its soil (Crown), its ground (Brood), its ore (Clockwork).
func _land(h: Building) -> float:
	# (Clockwork: its ore, or its Boilers' coal if that runs out first)
	return minf(h.lode_left(), h.soil_left()) if _clock() else h.soil_left()


## How much a hall spot is worth for the lode a hall there would find (fresh, unless a hall of
## ours fell there), in tiles of walking: the Clockwork lives on ore, the Crown wants fresh
## saltpetre for powder, the Brood has none. Only the map's own base sites count (they have
## room for a hall's whole economy); other free ground is a last resort.
func _lode_value(c: Vector2i) -> float:
	if _brood() or not game.base_sites.has(c):
		return 0.0
	return game.lode_at_spot(c, _f()["hall"]) * (16.0 if _clock() else 6.0)


## Crown / Clockwork: a Mill (Crusher) on spent saltpetre (ore) is pulled down when the limit
## leaves no room for one by a hall that still has fresh saltpetre (ore) and none working it.
func _recycle_spent() -> void:
	for kind in ["powder_mill", "ore_crusher", "ore_drill"]:
		if Defs.BUILDINGS[kind]["faction"] != game.faction_of(team) or game.econ_count(team, kind) < game.econ_limit(team, kind):
			continue
		var dep: String = Defs.LODE_NAME[Defs.LODE_FOR[kind]]
		var spent: Array = _mine(kind).filter(func(b: Building) -> bool: return b.built and b.lode_left() <= 0.0)
		if spent.is_empty():
			continue
		for h in _halls():
			if not h.built or h.lode_left() < 0.15:
				continue
			var worked := _mine(kind).any(func(b: Building) -> bool: return game.lode_hall(b) == h)
			if not worked:
				game.demolish(spent[0])
				if game.mlog:
					game.mlog.add("%s pulled down a %s by spent %s (fresh %s by another hall)" % [game.mlog.who(team), Defs.BUILDINGS[kind]["name"], dep, dep])
				return


## Take more ground: a new hall at a free spot on our side of the map, 18-30 tiles from one
## of ours. `macro`: the Brood just needs more Hives to spend its food (eggs come from Hives).
func _more_halls(macro: bool) -> void:
	var hall: String = _f()["hall"]
	if r5.hold_hall():
		return
	# (halls on spent soil don't count toward the strategy's limit: the land has run out)
	var live := _halls().filter(func(h: Building) -> bool: return _brood() or _land(h) > 0.0).size()
	if live >= int(_s("halls")) + (1 if macro else 0) or _halls().size() >= 7 or _busy_building(hall):
		return
	if _gold() < int(Defs.BUILDINGS[hall]["cost"]):
		return
	if _brood():
		# Burrows only lay eggs: they go close round the capital (no ground of their own to find)
		var cap := game.capital(team)
		if cap == null or not cap.built:
			return
		var home := game.find_spot(team, hall, cap, Defs.BROOD_HALL_SPACING, Defs.BROOD_HALL_SPACING + 8, "near", true)
		if home.x < 0:
			home = game.find_spot(team, hall, cap, Defs.BROOD_HALL_SPACING, Defs.BROOD_HALL_SPACING + 12, "near")
		if home.x >= 0:
			_construct(hall, home)
		return
	if not macro and not _brood():
		# a base site with a fresh lode first (the Clockwork lives on ore)
		var sp := _safe_hall_spot()
		if sp.x >= 0 and _lode_value(sp) > 0.0:
			_construct(hall, sp)
			return
		if _clock():
			return          # (a Clocktower away from ore only adds Boilers with nowhere to crush)
	for h in _halls():
		if not h.built:
			continue
		var spot := game.find_spot(team, hall, h, Defs.HALL_SPACING, Defs.HALL_SPACING + 12, "far_safe")
		if spot.x >= 0:
			_construct(hall, spot)
			return


## Research once the army it's for is there and the money allows (never with an expansion
## to save for). Crown, at the Armoury, roughly in this order: the Socket Bayonet from 3
## Musketeers, the Matchlock from 4, the Cavalry Charge from 2 horsemen, Armour from 6
## soldiers, Prepared Charges from 1 gun (cannon or mortar), Flintlock from 8 Musketeers,
## the Gunner's Quadrant from 2 guns, Caplock from 12. [what's counted, how many]
const RESEARCH_AT := {"bayonet": ["musket", 3], "matchlock": ["musket", 4], "charge": ["horse", 2], "pouch": ["musket", 6],
	"armour": ["soldier", 6], "charges": ["gun", 1], "flintlock": ["musket", 8], "quadrant": ["gun", 2],
	"caplock": ["musket", 12]}


func _research() -> void:
	_refit_army()
	if _hall_reserve:
		return
	var army := game.army(team)
	var n := {"musket": 0, "horse": 0, "soldier": 0, "gun": 0}
	for u in army:
		if Defs.MUSKETS.has(u.kind):
			n["musket"] += 1
		elif u.kind == "cuirassier":
			n["horse"] += 1
		elif u.kind in ["cannon", "mortar"]:
			n["gun"] += 1
	n["soldier"] = n["musket"] + n["horse"]
	for key in Defs.RESEARCH:
		var info: Dictionary = Defs.RESEARCH[key]
		if info["faction"] != game.faction_of(team) or game.has_tech(team, key) or game.researching(team, key):
			continue
		var at: Array = RESEARCH_AT.get(key, ["musket", 0])
		if int(n[at[0]]) < int(at[1]) * (1.5 if difficulty == 0 else 1.0):
			continue
		if _gold() < int(info["cost"]) + _lv([150, 60, 20]) or _res2() < float(info.get("cost2", 0)) + 20.0:
			continue
		for b in _mine(info["at"]):
			if game.research_problem(b, key) == "":
				game.start_research(b, key)
				break


## Crown: research only unlocks the soldiers' equipment; each man is refitted at a Barracks,
## an Armoury or a Powder Wagon. AUTO REFIT stays on at our Barracks and Armouries, and
## between attacks (nothing on our base) idle soldiers that lack an upgrade walk back to get
## it while the money allows. (Light soldiers kept light on purpose, against an enemy strong
## against armour, aren't sent for Armour: _want_armour.)
func _refit_army() -> void:
	if not _crown():
		return
	for k in Defs.REFIT_AT:
		for b in _mine(k):
			b.auto_refit = true
	if _attacking or _gold() < _lv([200, 120, 80]) or _threat() != Vector2.INF:
		return
	var sent := 0
	for u in game.army(team):
		if sent >= 6 or _gold() < _lv([200, 120, 80]):
			break
		if not Defs.ARMOURED.has(u.kind) or u.order != "idle" or u.target != null or _on_errand(u):
			continue
		var went := false
		for w in game.refit_options(u):
			if w == "armour" and not _want_armour():
				continue
			if int(game.refit_order([u], w, true)[0]) > 0:
				went = true
		if went:
			sent += 1
	if sent > 0 and game.mlog:
		game.mlog.add("%s sent %d soldier%s back to refit" % [game.mlog.who(team), sent, "" if sent == 1 else "s"])
var _raiders: Array = []        # Crown: cuirassiers out hunting the enemy's workers
var _raid_home := 0.0


## Crown: up to four Cuirassiers ride out to hunt the enemy's workers and economy, the
## farther from the enemy's main the better (Brood grubs hauling from distant pits,
## undefended farms). They avoid armies and ride home to mend when badly hurt.
## The raiding party is (or may become) the rush: the Horse Breeder opening on a plan whose first
## wave is not the rush itself.
func _rush_raid_or_new() -> bool:
	return _rush_raid or _rush_state == ""


func _raid() -> void:
	_raiders = _raiders.filter(func(u) -> bool: return is_instance_valid(u) and not u.dead)
	if opening == "breeder" and strategy == "rush":
		_raiders.clear()             # (a Horseman rush: they ride out together with the wave)
		return
	var rush_raid := opening == "breeder" and game.clock < 600.0 and (_rush_state == "" or _rush_state == "ongoing" or _rush_state == "succeeded") and _rush_raid_or_new()
	# a party cut down to one rider is over: he rides home (never a lone rider in the enemy's land)
	if _raid_peak >= 2 and _raiders.size() < 2:
		var rest := _raiders.duplicate()
		_raiders.clear()
		_raid_peak = 0
		if rush_raid and _rush_state == "ongoing":
			_rush_why = "the raiding party was cut down"
			_rush_failed(rest)
		else:
			_rush_recall(rest)
			_raid_block = game.clock + 120.0
		return
	if _raiders.is_empty():
		# a party forms at home with at least two riders, together (never one by one)
		if game.clock < _raid_block:
			return
		var pool := _rush_pool(game.army(team).filter(func(u: Unit) -> bool: return not _on_errand(u)))
		if pool.size() < GROUP_MIN:
			return
		for u in pool:
			if _raiders.size() < 4:
				_raiders.append(u)
		_raid_peak = _raiders.size()
		if rush_raid and _rush_state == "":
			_rush_begin(_raiders, true)
			_rush_log("goes out (%d Horsemen together)" % _raiders.size())
	elif rush_raid and _rush_state == "succeeded" and _rush_mode == "finish":
		# the last workers: a pair or more of fresh cavalry may ride out together to finish them
		var pool2 := _rush_pool(game.army(team).filter(func(u: Unit) -> bool: return not _raiders.has(u) and not _on_errand(u)))
		if pool2.size() >= GROUP_MIN:
			for u in pool2:
				if _raiders.size() < 6:
					_raiders.append(u)
			_raid_peak = maxi(_raid_peak, _raiders.size())
	if _raiders.size() < 2:
		return
	if rush_raid and _rush_tick(_raiders):
		return
	var foe := _foe()
	if foe < 0:
		return
	var c := Vector2.ZERO
	var hp := 0.0
	for u in _raiders:
		c += u.position
		hp += u.hp / u.max_hp
	c /= _raiders.size()
	hp /= _raiders.size()
	var home: Vector2 = _halls()[0].center() if not _halls().is_empty() else c
	# badly hurt, or an army closing in: ride home
	var danger := 0
	for o in game.units_near(c, 260.0):
		if game.hostile(o.team, team) and not o.dead and not o.is_worker() and o.kind != "grub":
			danger += int(o.d["supply"])
	if hp < 0.45 or danger >= 6:
		_raid_home = 12.0
	if _raid_home > 0.0:
		_raid_home -= 1.0
		for u in _raiders:
			if u.position.distance_to(home) > 200.0:
				u.cmd_move(home + Vector2(randf_range(-60, 60), randf_range(-60, 60)))
		return
	var best := _prey_spot(c)
	for u in _raiders:
		_hunt(u, best)


## Where cavalry finds its prey: the enemy's workers we can see (the farther from its main
## the better: grubs hauling from distant pits, labourers at outlying farms), else the
## economy buildings they work at (Farms, Feeding Pits, Mills...), else its base.
func _prey_spot(from: Vector2) -> Vector2:
	var foe := _foe()
	if foe < 0:
		return _enemy_base()
	var their_main: Vector2 = Vector2(game.starts[foe]) * Defs.TILE if game.starts.size() > foe else from
	var best := Vector2.INF
	var score := -INF
	for o in game.units:
		if o.dead or o.off_field or not game.hostile(o.team, team) or not o.is_worker() or not game.is_visible_to(team, o.position):
			continue
		var s: float = o.position.distance_to(their_main) - o.position.distance_to(from) * 0.5
		if s > score:
			score = s
			best = o.position
	if best == Vector2.INF:
		for b in game.buildings:
			if b.dead or b.ghost or not game.hostile(b.team, team) or not Defs.is_econ(b.kind):
				continue
			var s: float = b.center().distance_to(their_main) - b.center().distance_to(from) * 0.5
			if s > score:
				score = s
				best = b.center()
	if best == Vector2.INF:
		best = _enemy_base()
	return best


## Cavalry on a raid (or the Horseman rush) hunts workers first, then fights what fights
## it, and goes for buildings only with no prey left: a worker it can see within 10 tiles is
## ridden down; a fight with soldiers goes on; a building it set about on the way (a Hive,
## a Town Hall) is left for the prey still farther on: it rides there (not an attack-move,
## which would stop at every building) and only attack-moves once it's there.
func _hunt(u: Unit, prey: Vector2) -> void:
	if u.dead or u.off_field or u.order == "mount" or u.order == "dismount" or _on_errand(u):
		return
	var T := Defs.TILE
	var w: Unit = null
	var wd := 10.0 * T
	for o in game.units_near(u.position, wd):
		if o.dead or o.off_field or not o.is_worker() or not game.hostile(o.team, team) or not u.can_hit(o) or not game.is_visible_to(team, o.position):
			continue
		var dd: float = o.position.distance_to(u.position)
		if dd < wd:
			wd = dd
			w = o
	w = _party_prey(u, w)
	var tgt = u.target if u.target != null and is_instance_valid(u.target) and not u.target.dead else null
	var fighting: bool = tgt is Unit and not (tgt as Unit).is_worker() and (tgt as Unit).kind != "horse"
	if w and not fighting:
		if u.order != "attack" or u.order_target == null or not is_instance_valid(u.order_target) or u.order_target.dead or not (u.order_target is Unit and (u.order_target as Unit).is_worker()):
			u.cmd_attack(w)
		return
	if fighting or (u.order == "attack" and u.order_target is Unit):
		return                           # (soldiers: the fight goes on; a worker: run him down)
	var far := u.position.distance_to(prey) > 5.0 * T
	if far and (tgt is Building or u.order == "idle" or u.order_point.distance_to(prey) > 160.0 or u.order == "attack"):
		u.cmd_move(prey + Vector2(randf_range(-30, 30), randf_range(-30, 30)))
	elif not far and (u.order == "idle" or u.order == "move"):
		u.cmd_move(prey + Vector2(randf_range(-30, 30), randf_range(-30, 30)), true)



## (ride-by, scripts/ride_by.gd) riders hunting together ride down the same hand: they fight on the move in loops round
## their prey, and each going for the hand nearest him split the party up. The worker a mate within 300 px is already
## riding down, if this one can see it within 10 tiles; else his own pick `w`.
func _party_prey(u: Unit, w: Unit) -> Unit:
	if w == null:
		return w
	for o in game.units_near(u.position, 300.0):
		if o == u or o.team != team or o.kind != "cuirassier" or o.dead or o.order != "attack":
			continue
		var p = o.order_target
		if p is Unit and is_instance_valid(p) and not p.dead and (p as Unit).is_worker() and u.can_hit(p) \
				and p.position.distance_to(u.position) < 10.0 * Defs.TILE and game.is_visible_to(team, p.position):
			return p
	return w



# ---- the ramp wall costs the defender something while a rush lasts (docs/design_principles.md, 5):
# a labourer mends a damaged palisade piece, gate or the ramp Cottage when it is safe where he
# stands (see _repair_safe), the nearest free one first; a full repair costs a quarter of the price
# (Defs.REPAIR_COST), so a Gate is 12 gold. Never at the price of the hands: they stop and flee
# (_worker_safety) the moment the spot is not safe.
const REPAIR_BELOW := 0.85       # a piece below this share of its hit points is mended
const REPAIR_HANDS := 2          # at most this many labourers at it at once
var _repairers: Dictionary = {}  # Unit -> the piece he was sent to


func _wall_piece(b: Building) -> bool:
	return b.kind == "wall" or b.kind == "gate" or (b.kind == "cottage" and not _cw_plan.is_empty() and b.cell == _cw_plan["cottage"])


## Is it safe for a labourer to stand behind this piece? No ranged enemy that reaches the spot
## (unless our soldiers stand near the piece: they cover him), and no melee enemy right at it
## (a palisade between them keeps the claws off; one inside or at the foot of the gate does not).
func _repair_safe(b: Building) -> bool:
	var home := Vector2(game.starts[team]) * Defs.TILE + Vector2(2.5, 2.0) * Defs.TILE
	var spot := b.center() + (home - b.center()).normalized() * 40.0
	var cover := 0
	for u in game.army(team):
		if not u.dead and u.position.distance_to(b.center()) < 300.0:
			cover += 1
	for o in game.units_near(b.center(), 320.0):
		if not game.hostile(o.team, team) or o.dead or o.off_field or not _armed(o):
			continue
		var rng := float(o.d.get("range", 0))
		if rng > 60.0:
			if cover < 2 and o.position.distance_to(spot) < rng + 60.0:
				return false
		elif o.position.distance_to(spot) < 50.0 or (o.position.distance_to(b.center()) > 50.0 and o.position.distance_to(spot) < o.position.distance_to(b.center())):
			return false          # (past the piece, on our side of it)
	return true


func _repair_wall() -> void:
	if not _crown() or difficulty == 0:
		return
	for w in _repairers.keys():
		var piece = _repairers[w]
		if not is_instance_valid(w) or w.dead or w.order != "repair":
			_repairers.erase(w)
		elif not is_instance_valid(piece) or piece.dead or not _repair_safe(piece):
			_repairers.erase(w)
			w.cmd_stop()          # (the flight logic of _worker_safety takes him from here)
	if _gold() < 2:
		return
	var hurt: Array = game.buildings.filter(func(b: Building) -> bool:
		return b.team == team and b.built and not b.dead and _wall_piece(b) and b.hp < b.max_hp * REPAIR_BELOW)
	if hurt.is_empty() or _repairers.size() >= REPAIR_HANDS:
		return
	hurt.sort_custom(func(a: Building, b: Building) -> bool: return a.hp / a.max_hp < b.hp / b.max_hp)
	var b: Building = hurt[0]
	if not _repair_safe(b):
		return
	var home_h: int = int(game.height[game.idx(game.cell_of(Vector2(game.starts[team]) * Defs.TILE))])
	var best: Unit = null
	var bd := 700.0
	for u in game.workers(team):
		if u.dead or u.order == "build" or u.order == "repair" or u.keg or _escort.has(u) or _fled.has(u) or _fighters.has(u) or (scout != null and scout.is_scout(u)):
			continue
		if u.carrying > 0 or int(game.height[game.idx(game.cell_of(u.position))]) != home_h:
			continue          # (a hand on the plateau with his hands free)
		var dd: float = u.position.distance_to(b.center())
		if dd < bd:
			bd = dd
			best = u
	if best != null:
		best.cmd_repair(b)
		_repairers[best] = b
		repair_orders += 1


var repair_orders := 0           # (measured by the tests)


# ---------------------------------------------------------------- Crown safe opening
# The first Cottage goes up AT THE RAMP and is part of the wall; one Gate next to it (and a
# palisade piece only for a band cell still open) seals the mouth. A good human Crown does
# this (the owner's log: Cottage 0:35, Gate 0:40, Mill and Barracks 0:53): it is far cheaper
# and earlier than a palisade line over every band cell. docs/ai_build_timelines.md.
var _cw_plan := {}              # plan_cottage_wall(): {"cottage": cell, "pieces": [[kind, cell]...], "cost", "band", "covered"}
var _cw_off := false            # no Cottage plan on this map (or it failed): the palisade wall of old
var _cw_built_t := -1.0         # when the ramp Cottage stood (a gate that cannot be laid for long gives the plan up)
const LINE_GATE_WIDTH := 2      # gate cells of a palisade-line wall (one place to widen the gate for limbered cannons)
const CW_GATE_WIDTH := 1        # gate cells beside the ramp Cottage (the Cottage covers the rest of the mouth)
var _cw_gate_width := CW_GATE_WIDTH         # gate pieces in the mouth: one (a Cottage covers the rest), more on a wide mouth
var safe_opening := true        # false: the opening before the Cottage wall (tests of other systems that need the old layout)


func _cw_active() -> bool:
	return safe_opening and _crown() and difficulty >= 1 and not _cw_off


## Every ramp near the home hall: its cells, the high-ground cells that touch it (the "band"
## the wall has to cover: nothing may slip past) and its middle. Nearest ramp first.
func _ramp_bands() -> Array:
	var out: Array = []
	if game.starts.size() <= team:
		return out
	var home := Vector2(game.starts[team]) + Vector2(2.5, 2.0)
	var left := {}
	for y in range(int(home.y) - 22, int(home.y) + 23):
		for x in range(int(home.x) - 22, int(home.x) + 23):
			var c := Vector2i(x, y)
			if game.in_map(c) and game.ramp[game.idx(c)] == 1:
				left[c] = true
	while not left.is_empty():
		var start: Vector2i = left.keys()[0]
		var ramp_cells: Array = []
		var todo: Array = [start]
		left.erase(start)
		while not todo.is_empty():
			var c: Vector2i = todo.pop_back()
			ramp_cells.append(c)
			for dd2 in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n: Vector2i = c + dd2
				if left.has(n):
					left.erase(n)
					todo.append(n)
		var band := {}
		for rc in ramp_cells:
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var c: Vector2i = rc + Vector2i(dx, dy)
					if game.in_map(c) and game.height[game.idx(c)] == 1 and game.ramp[game.idx(c)] == 0 and game.is_free(c):
						band[c] = true
		if band.size() < 2:
			continue
		var mid := Vector2.ZERO
		for rc in ramp_cells:
			mid += Vector2(rc)
		mid /= ramp_cells.size()
		out.append({"ramp": ramp_cells, "band": band.keys(), "mid": mid})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return (a["mid"] as Vector2).distance_to(home) < (b["mid"] as Vector2).distance_to(home))
	return out


## Flood fill over the walkable cells (8 ways, no corner cutting, a gate counts as open when `gates_open`) from
## the ramp's cells: the high-ground cells it reaches. Used to prove a plan seals the ramp.
func cw_reach(ramp_cells: Array, blocked: Dictionary, gates: Array, gates_open: bool) -> Dictionary:
	var home := Vector2(game.starts[team]) + Vector2(2.5, 2.0)
	var seen := {}
	var todo: Array = []
	for rc in ramp_cells:
		seen[rc] = true
		todo.append(rc)
	var open := func(n: Vector2i) -> bool:
		if not game.in_map(n) or absi(n.x - int(home.x)) > 26 or absi(n.y - int(home.y)) > 26:
			return false
		if not game.is_free(n) or blocked.has(n) or (not gates_open and gates.has(n)):
			return false
		return game.ramp[game.idx(n)] != 1 or ramp_cells.has(n)
	while not todo.is_empty():
		var c: Vector2i = todo.pop_back()
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				if dx == 0 and dy == 0:
					continue
				var n: Vector2i = c + Vector2i(dx, dy)
				if seen.has(n) or not open.call(n):
					continue
				# (no cutting a corner: both cells beside a diagonal step are open too)
				if dx != 0 and dy != 0 and not (open.call(c + Vector2i(dx, 0)) and open.call(c + Vector2i(0, dy))):
					continue
				seen[n] = true
				todo.append(n)
	return seen


## The cheapest complete seal of the nearest ramp that is built round a Cottage: the Cottage
## footprint (2x2, legal, on the high ground) covers as many band cells as it can, a Gate
## goes in the first cell left next to it (the army files out through it), and a palisade
## piece fills any other band cell still open. Proven with a flood fill: nothing walks from the
## ramp to the hall except through the gate. Other ramps (if the hall has more) get the old
## line (gate and palisade). {} if no Cottage site seals it.
func plan_cottage_wall() -> Dictionary:
	var bands := _ramp_bands()
	if bands.is_empty():
		return {}
	var b0: Dictionary = bands[0]
	var band: Array = b0["band"]
	var band_set := {}
	for c in band:
		band_set[c] = true
	var mid: Vector2 = b0["mid"]
	var home := Vector2(game.starts[team]) + Vector2(2.5, 2.0)
	var csize: Vector2i = Defs.BUILDINGS["cottage"]["size"]
	var minc: Vector2i = band[0]
	var maxc: Vector2i = band[0]
	for c in band:
		minc = Vector2i(mini(minc.x, c.x), mini(minc.y, c.y))
		maxc = Vector2i(maxi(maxc.x, c.x), maxi(maxc.y, c.y))
	var best := {}
	var best_score := INF
	for ty in range(minc.y - csize.y + 1, maxc.y + 1):
		for tx in range(minc.x - csize.x + 1, maxc.x + 1):
			var tl := Vector2i(tx, ty)
			var fp: Dictionary = {}
			var covered := 0
			var ok := true
			for dy in csize.y:
				for dx in csize.x:
					var c := tl + Vector2i(dx, dy)
					if not game.in_map(c) or not game.is_free(c) or game.ramp[game.idx(c)] != 0 or game.height[game.idx(c)] != 1:
						ok = false
					fp[c] = true
					if band_set.has(c):
						covered += 1
			if not ok or covered == 0 or game.placement_problem(team, "cottage", tl) != "":
				continue
			var rest: Array = band.filter(func(c: Vector2i) -> bool: return not fp.has(c))
			if rest.is_empty():
				continue          # (no way out: the gate needs a cell)
			# the gate: the left-over cells touching the Cottage, nearest the ramp's middle first
			rest.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
				var ta := _cw_touches(a, fp)
				var tb := _cw_touches(b, fp)
				if ta != tb:
					return ta
				return Vector2(a).distance_to(mid) < Vector2(b).distance_to(mid))
			var n_gate := mini(_cw_gate_width, rest.size())
			if rest.size() >= 4:
				n_gate = maxi(n_gate, 2)
			var gates: Array = []
			var walls: Array = []
			for i in rest.size():
				if i < n_gate:
					gates.append(rest[i])
				else:
					walls.append(rest[i])
			var blocked := fp.duplicate()
			for c in walls:
				blocked[c] = true
			var shut := cw_reach(b0["ramp"], blocked, gates, false)
			var leak := false
			for c in shut:
				if game.height[game.idx(c)] == 1 and game.ramp[game.idx(c)] == 0 and Vector2(c).distance_to(home) < 24.0:
					leak = true
					break
			if leak:
				continue
			var opened := cw_reach(b0["ramp"], blocked, gates, true)
			var gets_home := false
			for c in opened:
				if game.ramp[game.idx(c)] == 0 and game.height[game.idx(c)] == 1 and Vector2(c).distance_to(home) < 9.0:
					gets_home = true
					break
			if not gets_home:
				continue
			var score := float(rest.size()) * 100.0 + (0.0 if _cw_touches(gates[0], fp) else 50.0) + (Vector2(tl) + Vector2(csize) * 0.5).distance_to(mid) + float(tx + ty * 1000) * 0.00001
			if score < best_score:
				best_score = score
				var pieces: Array = []
				for c in gates:
					pieces.append(["gate", c])
				for c in walls:
					pieces.append(["wall", c])
				best = {"cottage": tl, "pieces": pieces, "band": band.size(), "covered": covered}
	if best.is_empty():
		return {}
	var cost := 0
	for e in best["pieces"]:
		cost += int(Defs.BUILDINGS[e[0]]["cost"])
	best["cost"] = cost
	# any other ramp of the home plateau: the line of old (a gate and palisade over the band)
	var extra: Array = []
	for i in range(1, bands.size()):
		var cells: Array = bands[i]["band"]
		var m: Vector2 = bands[i]["mid"]
		cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return Vector2(a).distance_to(m) < Vector2(b).distance_to(m))
		var gates2: Array = _gate_cells(cells)
		for c in cells:
			extra.append(["gate" if gates2.has(c) else "wall", c])
	for e in extra:
		best["pieces"].append(e)
		best["cost"] = int(best["cost"]) + int(Defs.BUILDINGS[e[0]]["cost"])
	return best


## The gate cells of a palisade line: LINE_GATE_WIDTH cells in a row, from the one nearest the
## ramp's middle (`cells` is sorted nearest first).
func _gate_cells(cells: Array) -> Array:
	var gates: Array = [cells[0]]
	for c in cells.slice(1):
		if gates.size() >= LINE_GATE_WIDTH:
			break
		if (c - gates[gates.size() - 1]).length() <= 1.01:
			gates.append(c)
	return gates


func _cw_touches(c: Vector2i, fp: Dictionary) -> bool:
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if fp.has(c + d):
			return true
	return false


## The ramp Cottage, if it stands (or is going up) on its planned cell.
func _cw_cottage() -> Building:
	for b in _mine("cottage"):
		if b.cell == _cw_plan["cottage"]:
			return b
	return null


## Every think from the first second: the Cottage at the ramp as soon as its 100 gold is there,
## then (the Gate needs a finished Cottage) the Gate and any palisade piece, laid together by a
## short crew. Nothing else is paid for until it stands (the Barracks and the Mill come next).
func _cottage_wall() -> void:
	if not _cw_active() or _walled or _hall_reserve:
		return
	if _cw_plan.is_empty():
		_cw_plan = plan_cottage_wall()
		if _cw_plan.is_empty():
			_cw_off = true
			if game.mlog:
				game.mlog.add("%s has no Cottage wall plan here: the palisade wall" % game.mlog.who(team))
			return
	var cot := _cw_cottage()
	if cot == null:
		if _gold() < int(Defs.BUILDINGS["cottage"]["cost"]):
			return
		if game.placement_problem(team, "cottage", _cw_plan["cottage"]) != "":
			_cw_plan = plan_cottage_wall()          # (something stands there now: plan again)
			if _cw_plan.is_empty():
				_cw_off = true
			return
		_construct("cottage", _cw_plan["cottage"])
		return
	if not cot.built:
		return
	if _cw_built_t < 0.0:
		_cw_built_t = game.clock
	var todo: Array = []
	var cost := 0
	for e in _cw_plan["pieces"]:
		if game._own_gate_at(team, e[1]) == null and game._own_wall_at(team, e[1]) == null:
			todo.append(e)
			cost += int(Defs.BUILDINGS[e[0]]["cost"])
	if todo.is_empty():
		_walled = true
		return
	if _gold() < cost:
		_wall_cost = cost
		if game.clock - _cw_built_t > 90.0:
			_cw_off = true          # (it never comes: the old line, which waits for its gold the same way, takes over)
		return
	var at: Vector2 = Vector2((todo[0][1] as Vector2i)) * Defs.TILE
	var crew_n := 2 if (todo.size() >= 2 or _wall_urgent()) else 1
	var labs: Array = game.workers(team).filter(func(u: Unit) -> bool:
		return not u.dead and u.order != "build" and not _escort.has(u) and not (scout != null and scout.is_scout(u)) and not _fled.has(u))
	labs.sort_custom(func(a: Unit, b: Unit) -> bool:
		return a.position.distance_to(at) + (150.0 if a.carrying > 0 else 0.0) < b.position.distance_to(at) + (150.0 if b.carrying > 0 else 0.0))
	var crew: Array = labs.slice(0, crew_n)
	if crew.is_empty():
		return
	var made: Array = []
	for e in todo:
		var nb: Building = game.place_building(team, e[0], e[1], [])
		if nb != null:
			made.append(nb)
	if made.is_empty():
		if game.clock - _cw_built_t > 40.0:
			_cw_off = true
		return
	_walled = true
	_wall_pieces = made
	_wall_start_t = game.clock
	_wall_done_t = -1.0
	_assign_wall(crew, made)
	if game.mlog:
		game.mlog.add("%s walled its ramp with a Cottage (%d pieces, %d labourers on it%s)" % [game.mlog.who(team), made.size(), crew.size(), ", feared rush" if _wall_urgent() else ""])


## Crown: wall the top of each ramp up to the main base, with a two-wide gate in the
## middle. The wall is every free high-ground cell touching the ramp, so nothing slips by.
## Like an SC2 wall-off it is laid in one go and built by a CREW (2, or 3 when a rush is
## feared) pulled off the farms, each with its own share of the pieces, so it stands before
## the enemy can arrive; _tend_wall keeps it going. Waits (returns false) until the gold for
## the whole line is in the bank: half a wall is no wall.
func _wall_off() -> bool:
	if game.starts.size() <= team:
		_walled = true
		return false
	var home := Vector2(game.starts[team]) + Vector2(2.5, 2.0)
	var left := {}
	for y in range(int(home.y) - 22, int(home.y) + 23):
		for x in range(int(home.x) - 22, int(home.x) + 23):
			var c := Vector2i(x, y)
			if game.in_map(c) and game.ramp[game.idx(c)] == 1:
				left[c] = true
	var plan: Array = []         # [kind, cell]
	var mids: Array = []
	while not left.is_empty():
		# one ramp: the cells joined to the first one left
		var start: Vector2i = left.keys()[0]
		var ramp_cells: Array = []
		var todo: Array = [start]
		left.erase(start)
		while not todo.is_empty():
			var c: Vector2i = todo.pop_back()
			ramp_cells.append(c)
			for dd2 in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n: Vector2i = c + dd2
				if left.has(n):
					left.erase(n)
					todo.append(n)
		var band := {}
		for rc in ramp_cells:
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var c: Vector2i = rc + Vector2i(dx, dy)
					if game.in_map(c) and game.height[game.idx(c)] == 1 and game.ramp[game.idx(c)] == 0 and game.is_free(c):
						band[c] = true
		if band.size() < 2:
			continue
		var mid := Vector2.ZERO
		for rc in ramp_cells:
			mid += Vector2(rc)
		mid /= ramp_cells.size()
		mids.append(mid)
		var cells: Array = band.keys()
		cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return Vector2(a).distance_to(mid) < Vector2(b).distance_to(mid))
		# (a two-wide gate: the army files out to meet a raid without jamming; test_ai_army_response
		# fails with a one-tile gate)
		var gates: Array = _gate_cells(cells)
		for c in cells:
			plan.append(["gate" if gates.has(c) else "wall", c])
	if plan.is_empty():
		_walled = true
		return false
	var cost := 0
	for e in plan:
		cost += int(Defs.BUILDINGS[e[0]]["cost"])
	if _gold() < cost:
		_wall_cost = cost
		return false
	# the crew: the labourers nearest the ramp (a farmer who is not carrying first)
	var at: Vector2 = Vector2(mids[0]) * Defs.TILE
	var crew_n := (4 if scout != null and scout.rush_units_seen() > 0 else 3) if _wall_urgent() else 2
	var labs: Array = game.workers(team).filter(func(u: Unit) -> bool:
		return not u.dead and u.order != "build" and not _escort.has(u) and not (scout != null and scout.is_scout(u)))
	labs.sort_custom(func(a: Unit, b: Unit) -> bool:
		return a.position.distance_to(at) + (150.0 if a.carrying > 0 else 0.0) < b.position.distance_to(at) + (150.0 if b.carrying > 0 else 0.0))
	var crew: Array = labs.slice(0, crew_n)
	if crew.is_empty():
		return false
	var made: Array = []
	for e in plan:
		var nb: Building = game.place_building(team, e[0], e[1], [])
		if nb != null:
			made.append(nb)
	if made.is_empty():
		return false
	_walled = true
	_wall_pieces = made
	_wall_start_t = game.clock
	_wall_done_t = -1.0
	_assign_wall(crew, made)
	if game.mlog:
		game.mlog.add("%s walled its ramp (%d pieces, %d labourers on it%s)" % [game.mlog.who(team), made.size(), crew.size(), ", feared rush" if _wall_urgent() else ""])
	return true


## Split the pieces over the crew (nearest first, taking turns); each labourer gets his own
## line to build, one after the other.
func _assign_wall(crew: Array, pieces: Array) -> void:
	if crew.is_empty() or pieces.is_empty():
		return
	var mine: Array = []
	for _i in crew.size():
		mine.append([])
	var from: Vector2 = (crew[0] as Unit).position
	var rest := pieces.duplicate()
	rest.sort_custom(func(a: Building, b: Building) -> bool: return a.center().distance_to(from) < b.center().distance_to(from))
	for i in rest.size():
		mine[i % crew.size()].append(rest[i])
	for i in crew.size():
		if not (mine[i] as Array).is_empty():
			(crew[i] as Unit).give({"o": "wall", "pieces": mine[i]})


var _wall_cost := 0
var _wall_pieces: Array = []
var _wall_start_t := -1.0
var _wall_done_t := -1.0
var _adopted := {}              # wall site (instance id) -> times a labourer was found for it


## A feared rush (scouted or unseen enemy): the wall and the first soldiers come before the economy grows.
func _wall_urgent() -> bool:
	if scout != null and scout.enabled and (scout.verdict == "rush" or scout.verdict == "uncertain"):
		return true
	return strategy == "rush" and _crown()


## Crown: is it time to wall the ramp? At a standard moment even unscouted (right after the first
## Cottage opens the palisade, about a minute in on Hard), at once when a rush is feared.
func _wall_wanted() -> bool:
	if _walled or not _crown() or not game.requirement_met(team, "wall") or _hall_reserve:
		return false
	if _cw_active():
		return false          # (the Cottage wall is laid by _cottage_wall, from the first seconds)
	if difficulty == 0:
		return game.clock / float(_s("tech")) > 300.0 and _gold() >= 140
	if opening == "breeder":
		return game.clock >= _lv([9999.0, 75.0, 50.0])      # (the Horseman rush walls early too: it keeps the enemy's scout out)
	# The Musketeer opening: the Barracks and the Mill come first (the farms pay in big lumps,
	# and a wall alone cannot hold: the first Musketeers must be ready when the next harvest
	# is in, see docs and tools/test_ai_wall_vs_rush.gd), the wall with the first gold after
	# them: the very next harvest at the latest, and at once if a rush is feared.
	var armed := not _mine("barracks").is_empty() and not _mine("powder_mill").is_empty()
	return armed or game.clock >= _lv([9999.0, 170.0, 150.0])


## Crown: a feared rush (scouted, or the enemy not seen) early on: the first Musketeers come before
## tech buildings, a Horse Breeder or a second Barracks are paid for.
func _army_first() -> bool:
	if not _crown() or difficulty == 0 or game.clock > 420.0 or scout == null or not scout.enabled:
		return false
	if not (scout.verdict == "rush" or scout.verdict == "uncertain"):
		return false
	# (the defenders it has: Musketeers, and Horsemen when it opened with the Breeder: a Horseman opening makes no
	# Musketeers for minutes, and counting only those held its Labourers at eight for seven minutes; coach round 1)
	var muskets := game.army(team).filter(func(u: Unit) -> bool: return Defs.MUSKETS.has(u.kind) or u.kind == "cuirassier").size()
	for b in _mine("barracks"):
		muskets += b.queue.size()
	return muskets < 6


## Crown: a scout report with nothing to fear, early on: labourers (a hand on a farm pays its
## own price back in under a minute) before the tech and extra production buildings.
func _eco_first() -> bool:
	if not _crown() or difficulty == 0 or game.clock > 330.0 or scout == null or not scout.enabled or strategy == "rush":
		return false
	if not (scout.verdict == "balanced" or scout.verdict == "greedy"):
		return false
	return game.workers(team).size() < 14


func _tech_wait() -> bool:
	return _army_first() or _eco_first()


## The wall is the first thing to pay for (and the first soldiers): the economy structures wait.
func _turtling() -> bool:
	if not _crown() or difficulty == 0 or _hall_reserve:
		return false
	if not (_wall_urgent() or (scout != null and scout.enabled and scout.foe_opening() == "unknown" and game.clock > 75.0)):
		return false
	return not _walled or _mine("barracks").is_empty()


## A labourer for a wall site nobody is coming to (Game.sweep_ghosts asks before it drops a
## ghost): the nearest free one takes it up. True if one did.
func adopt_site(b: Building) -> bool:
	if not Defs.BUILDINGS[b.kind].get("line", false) or peaceful:
		return false
	var id := b.get_instance_id()
	if int(_adopted.get(id, 0)) >= 8:
		return false
	var best: Unit = null
	var bd := INF
	for u in game.workers(team):
		if u.dead or u.order == "build" or _escort.has(u) or (scout != null and scout.is_scout(u)):
			continue
		var dd: float = u.position.distance_to(b.center()) + (150.0 if u.carrying > 0 else 0.0)
		if dd < bd:
			bd = dd
			best = u
	if best == null:
		return false
	_adopted[id] = int(_adopted.get(id, 0)) + 1
	best.give({"o": "build", "e": b})
	return true


## Every think: note when the wall stands; the pieces nobody is coming to (a builder killed,
## re-ordered) go to the nearest free labourer. The farm hands do the wall; once it stands
## they go back to the fields (the idle ones are sent by _workers).
func _tend_wall() -> void:
	if _wall_pieces.is_empty() or _wall_done_t >= 0.0:
		return
	var open := 0
	var alive := 0
	for b in _wall_pieces:
		if not is_instance_valid(b) or b.dead:
			continue
		alive += 1
		if not b.built:
			open += 1
			var served := game.units.any(func(u: Unit) -> bool:
				return u.team == team and not u.dead and ((u.order == "build" and u.order_target == b) or u.line_rest.has(b)))
			if not served:
				adopt_site(b)
	if alive > 0 and open == 0:
		_wall_done_t = game.clock
		if game.mlog:
			game.mlog.add("%s's ramp wall stands (%d pieces, %d s after it was laid)" % [game.mlog.who(team), alive, int(game.clock - _wall_start_t)])


## One of our ghost sites couldn't start (blocked): plan again. A wall piece: the ramp gets
## walled again (only its gaps); anything else is simply missing and gets placed anew.
## "abandoned" (its builder was pulled off, e.g. fled from raiders): the kind's look-again wait (_no_room) stays, or the
## site would be placed again at once in the same danger and dropped again a second later, over and over (0.14.53 QA
## soak: a Brood Clutch Mound placed and refunded every second while raiders stood near).
func site_failed(b: Building, why := "blocked") -> void:
	if Defs.BUILDINGS[b.kind].get("line", false):
		_walled = false
	if why != "abandoned":
		_no_room.erase(b.kind)
	else:
		_abandoned[b.kind] = game.clock
		if b.kind == String(_f()["hall"]):
			_hall_bad[b.cell] = game.clock + 90.0     # (raiders there: another spot, or this one later; coach round 2)


func _construct(kind: String, at := Vector2i(-1, -1)) -> void:
	if _gold() < int(Defs.BUILDINGS[kind]["cost"]):
		return
	if game.clock - float(_abandoned.get(kind, -99.0)) < AIBrood.ABANDON_WAIT:
		return          # (a site of this kind was just dropped, its builder fled: not again at once into the same danger)
	if game.tension(team) < float(Defs.tension_cost(Defs.BUILDINGS[kind])):
		return          # (gear mode: a Tension price, the Clock Aviary's)
	if not game.requirement_met(team, kind):
		return
	var spot := at if at.x >= 0 else _find_spot(kind)
	if spot.x < 0:
		return
	# Brood: the grub is used up, so don't eat into a tiny economy.
	if _brood() and game.workers(team).size() <= 3 and kind != _sup():
		return
	# The nearest worker that isn't busy building; idle ones first.
	var best: Unit = null
	var bd := INF
	var target := Vector2(spot) * Defs.TILE
	# Clockwork: the Winder fetches the crate from a Clocktower first, so the trip that
	# counts is to the nearest Clocktower and on to the site (Defs.CRATE)
	var towers: Array = _halls().filter(func(h: Building) -> bool: return h.built and h.kind == "clocktower") if _clock() else []
	for u in game.workers(team):
		if u.order == "build" or _escort.has(u) or (scout != null and scout.is_scout(u)):
			continue
		var trip: float = u.position.distance_to(target)
		if not towers.is_empty():
			trip = INF
			for h in towers:
				trip = minf(trip, u.position.distance_to(h.center()) + h.center().distance_to(target))
		var dd: float = trip + (0.0 if u.order == "idle" else 150.0) + (200.0 if u.carrying > 0 else 0.0)
		if dd < bd:
			bd = dd
			best = u
	if best:
		game.place_building(team, kind, spot, [best])


## Where a building goes: by the main hall, on its own ground (up on the main's plateau,
## inside its walls: any room there, even close to the hall or along the cliff edge, beats
## lower ground), then by another hall on that hall's ground. Only when no hall's plateau has
## room does it go down, and then to the foot of the nearest ramp (a short walk from the hall,
## never over a cliff, never in the ramp's way), else anywhere by a hall.
func _find_spot(kind: String) -> Vector2i:
	var ds := _drive_spot(kind)
	if ds.x >= 0:
		return ds
	var halls: Array = _halls().filter(func(h: Building) -> bool: return h.built)
	if game.starts.size() > team:
		var home := Vector2(game.starts[team]) * Defs.TILE
		halls.sort_custom(func(a: Building, b: Building) -> bool: return a.center().distance_to(home) < b.center().distance_to(home))
	for h in halls:
		# (on the main's own plateau it looks a little farther: all of it is safe ground)
		var far := 26 if h == halls[0] else 20
		# (supply buildings tuck in behind the hall, away from the middle of the map: the room
		# close to the hall is for the production and tech buildings)
		var spot := game.find_spot(team, kind, h, 3, far, "behind" if kind == String(_sup()) else "near", true)
		if spot.x >= 0:
			return spot
	# the plateau is full: the foot of the nearest ramp, hall by hall
	for h in halls:
		var foot := game.ramp_foot(h)
		if foot != Vector2.INF:
			var spot := game.find_spot(team, kind, h, 3, 14, "near", false, foot)
			if spot.x < 0:
				spot = game.find_spot(team, kind, h, 3, 24, "near", false, foot)
			if spot.x >= 0:
				return spot
	for h in halls:
		var spot := game.find_spot(team, kind, h, 5, 18, "near")
		if spot.x >= 0:
			return spot
	return Vector2i(-1, -1)


# ------------------------------------------------------------------ army

func _produce() -> void:
	# Saving up only pauses the army once there is a minimum army to hold the line.
	var minimum := mini(40, 6 + int(game.clock / 20.0))
	if _reserve > 0 and _horse_alert():
		minimum = mini(minimum, 6)      # (Horsemen seen: more Raptors would not hold the line; the Pen and the Gorge Pit first)
	if _hall_reserve and _gold() < int(Defs.BUILDINGS[_f()["hall"]]["cost"]) + 30:
		return          # (Crown: the new Town Hall first, whatever the army)
	if _tech_hold:
		minimum = mini(minimum, _lv([12, 8, 6]))     # (gear mode: the tech before more Clock Soldiers: _tier2)
	if (_saving or (_reserve > 0 and _gold() < _reserve + 60)) and _army_supply(game.army(team)) >= minimum:
		return
	var army := game.army(team)
	if _clock() and Defs.gear_mode:
		# gear mode: Clock Soldiers from every Light Works, and Tension units from the Works that may make them (a ring
		# that meshes with a Mainspring's): a Springer for about every 1.5 Clock Soldiers (the shooters behind the line: they
		# kill the workers mending a wall and the Musketeers over it), a Netter for every 7 others (up to 3, from 8 in
		# the army), and from the Heavy Works (_tier3) a Pendulum for every 6 others (up to 4) and the Spring Ballistas. Tension piling up
		# (60% of what the Mainsprings store) goes on Tension units first: it is not left at its cap. A Works that may make
		# a Springer waits for the cogs rather than spend them on another Clock Soldier (docs/clockwork_ai.md).
		var n_of := func(kind: String) -> int:
			var n: int = army.filter(func(u: Unit) -> bool: return u.kind == kind).size()
			for w in _mine(_works()) + _mine(Defs.CW_HEAVY):
				n += w.queue.count(kind)
			return n
		var springers: int = n_of.call(Defs.SPRINGER)
		var pends: int = n_of.call(Defs.PENDULUM)
		var netters: int = n_of.call(Defs.NETTER)
		var soldiers: int = n_of.call("clock_soldier")
		var others: int = soldiers + springers
		var bals: int = n_of.call(Defs.BALLISTA_KIND)
		var bal_want := _ballista_want()
		var gws: int = n_of.call(Defs.GREAT_WINDER_KIND)      # (one Great Winder: _great_winder_due)
		var cap_t := _tension_cap()
		var flush: bool = cap_t > 0.0 and game.tension(team) >= cap_t * 0.6
		# (the Works that may make Tension units first: one waiting for the cogs of a Springer stops the others spending them
		# on Clock Soldiers)
		# (the Heavy Works first: its Pendulums and Spring Ballistas, 0.14.94; a Pendulum for every 6 others, up to 4, once
		# three Springers are out or Tension piles up; the Ballistas as _ballista_want says)
		var want_p: bool = pends < mini(4, 1 + others / 6) and (springers >= 3 or flush)
		var keep0 := 0.0
		if _want_aviary:
			keep0 += float(Defs.tension_cost(Defs.BUILDINGS[Defs.CW_AIR]))       # (the Aviary's Tension price is kept too)
		if _research_keep > 0.0:
			keep0 += _research_keep        # (SHIELD WALL or HIGH LEAP is wanted: its Tension is kept)
		var heavy_keep := 0.0             # (Tension kept from the Springers for a heavy machine that waits for its cogs)
		var heavy_wait := false
		for hw in _mine(Defs.CW_HEAVY):
			if hw.built and hw.queue.size() < (2 if _gold() > 600 else 1):
				var hk := ""
				# (the first Ballista before the Pendulums, as when it came from the Works: then the Great Winder, the
				# Pendulums, the other Ballistas)
				if bals == 0 and bal_want > 0 and others >= 3 and _tension_ok(hw, Defs.BALLISTA_KIND, keep0):
					hk = Defs.BALLISTA_KIND
				elif _great_winder_due(hw, gws, others, keep0):
					hk = Defs.GREAT_WINDER_KIND          # (its one Great Winder, from the Heavy Works too, after the first Ballista)
				elif want_p and _tension_ok(hw, Defs.PENDULUM, 0.0):
					hk = Defs.PENDULUM
				elif bals < bal_want and others >= 3 and _tension_ok(hw, Defs.BALLISTA_KIND, keep0):
					hk = Defs.BALLISTA_KIND
				if hk == "":
					# (a heavy machine is wanted but its Tension is short: it is kept from the Springers meanwhile; the
					# Springers used to eat every bit of it, and no Ballista nor Pendulum came all game)
					var want_k := Defs.BALLISTA_KIND if bals == 0 and bal_want > 0 and others >= 3 else \
							(Defs.GREAT_WINDER_KIND if gws < 1 and others >= GREAT_WINDER_ARMY else (Defs.PENDULUM if want_p else ""))
					if want_k != "" and game.gear_net.spring_for(hw) != null:
						heavy_keep = maxf(heavy_keep, float(Defs.tension_cost(Defs.UNITS[want_k])))
					continue
				if game.train(hw, hk) != "":
					heavy_keep = maxf(heavy_keep, float(Defs.tension_cost(Defs.UNITS[hk])))
					heavy_wait = true
					continue          # (saving up for it: its cogs and Tension are kept from the Light Works)
				if hk == Defs.PENDULUM:
					pends += 1
					want_p = pends < mini(4, 1 + others / 6)
				elif hk == Defs.GREAT_WINDER_KIND:
					gws += 1
				else:
					bals += 1
		var wl: Array = _mine(_works())
		wl.sort_custom(func(a: Building, b: Building) -> bool: return game.gear_net.spring_for(a) != null and game.gear_net.spring_for(b) == null)
		for w in wl:
			if heavy_wait:
				break          # (the heavy machine's cogs first, as a Works waiting for a Springer's: not on Clock Soldiers)
			if w.built and w.queue.size() < (3 if _gold() > 600 else 2):
				var k := "clock_soldier"
				var keep := keep0 + heavy_keep
				if army.size() >= 8 and netters == 0 and others >= 7 and _tension_ok(w, Defs.NETTER, keep):
					k = Defs.NETTER          # (the first Netter before the rest: one stopper with the army early)
				elif army.size() >= 8 and netters < mini(3, others / 7) and springers >= 4 and _tension_ok(w, Defs.NETTER, keep):
					k = Defs.NETTER
				elif (springers * 3 < soldiers * 2 + 3 or flush) and _tension_ok(w, Defs.SPRINGER, keep):
					k = Defs.SPRINGER
				var why := game.train(w, k)
				if why != "":
					break         # (saving up for it, or the supply is full)
				if k == Defs.SPRINGER:
					springers += 1
					others += 1
				elif k == Defs.NETTER:
					netters += 1
				else:
					soldiers += 1
					others += 1
		# the air (a Clock Aviary): Swifts against the enemy's flyers, one more than it has shown (up to 6); two once the
		# Owls are researched (to be morphed)
		for av in _mine(Defs.CW_AIR):
			if av.built and av.queue.size() < 2:
				var swifts: int = army.filter(func(u: Unit) -> bool: return u.kind == Defs.CUCKOO).size() + av.queue.count(Defs.CUCKOO)
				var fa := _foe_air()
				var want := mini(6, fa + 1) if fa > 0 else (2 if game.has_tech(team, "owl_morph") else 0)
				if swifts < want and game.can_train(av, Defs.CUCKOO) == "":
					game.train(av, Defs.CUCKOO)
		return
	if _clock():
		var n_of := func(kind: String) -> int: return army.filter(func(u: Unit) -> bool: return u.kind == kind).size()
		var walkers: int = n_of.call("steam_walker")
		var carts: int = n_of.call("tesla_cart")
		var callers: int = n_of.call("stormcaller")
		var topters: int = n_of.call("ornithopter")
		var threshers: int = n_of.call("thresher")
		var shields: int = n_of.call("bulwark")
		var arcs: int = n_of.call("arc_thrower")
		var tins: int = n_of.call("windup_soldier")
		var big := army.size() - tins
		# the line: wind-ups early (cheap, three an order), then Threshers, Bulwarks and Arc
		# Throwers; wind-ups stay a share of it all game
		for w in _mine("assembly_works"):
			if w.built and w.queue.size() < (3 if _gold() > 600 else 2):
				var k := "windup_soldier"
				# against a swarm the saws (Threshers cut crowds that stand); against
				# musket lines Arc Throwers behind Bulwarks
				var swarm := _foe() >= 0 and game.faction_of(_foe()) == "brood"
				if game.clock > _lv([300.0, 200.0, 160.0]) or big >= 2:
					var r := randf()
					if tins < (3 + big / 2 if swarm else 3 + big / 3) or r < (0.12 if swarm else 0.06):
						k = "windup_soldier"
					elif arcs * (4 if swarm else 2) < big + 1 and game.can_train(w, "arc_thrower") == "":
						k = "arc_thrower"
					elif shields * (10 if swarm else 4) < big and game.can_train(w, "bulwark") == "":
						k = "bulwark"
					else:
						k = "thresher"
				var why := game.can_train(w, k)
				if why.begins_with("Not enough") or why.begins_with("Need more supply") or why.begins_with("Supply"):
					continue          # save up for it (don't spend it all on tin soldiers)
				if why != "":
					k = "thresher" if game.can_train(w, "thresher") == "" else "windup_soldier"
				if game.train(w, k) == "":
					match k:
						"windup_soldier":
							tins += 3
						"thresher":
							threshers += 1
							big += 1
						"bulwark":
							shields += 1
							big += 1
						"arc_thrower":
							arcs += 1
							big += 1
		# the big engines (they cost stored batteries too)
		for w in _mine("engine_hall"):
			if w.built and w.queue.size() < (2 if _gold() > 600 else 1):
				var k := ""
				if walkers * 5 < big + 2 and game.can_train(w, "steam_walker") == "":
					k = "steam_walker"
					walkers += 1
				elif carts * 6 < big and game.can_train(w, "tesla_cart") == "":
					k = "tesla_cart"
					carts += 1
				elif topters * 6 < big and game.can_train(w, "ornithopter") == "" and randf() < 0.4:
					k = "ornithopter"
					topters += 1
				elif difficulty >= 1 and callers * 8 < big and game.can_train(w, "stormcaller") == "":
					k = "stormcaller"
					callers += 1
				if k != "":
					game.train(w, k)
		return
	if _brood():
		var brutes := army.filter(func(u: Unit) -> bool: return u.kind == "brute").size()
		var wings := army.filter(func(u: Unit) -> bool: return u.kind == "skywing").size()
		var mothers := army.filter(func(u: Unit) -> bool: return u.kind == "spore_mother").size()
		var toads := army.filter(func(u: Unit) -> bool: return u.kind == "mist_toad").size()
		for h in _halls():
			toads += (h.queue as Array).count("mist_toad")     # (hatching ones too)
		var saving_mound := _mound_saving()
		for h in _halls():
			if not h.built:
				continue
			while h.eggs > 0:
				if brood != null and brood.holding(int(Defs.UNITS["raptor"]["cost"])):
					break           # (biomass put by for a Clutch Mound, the Pen or the Gorge Pit: AIBrood.reserve)
				if strategy == "xrush":
					if game.train(h, "raptor") != "":      # (only Raptors, all the income)
						break
					continue
				var k := "raptor" if randf() < 0.6 or game.can_train(h, "spitter") != "" else "spitter"
				if k == "spitter" and brood != null and not brood.spitter_ok():
					k = "raptor"    # (the essence is kept for the next Brute or Mist Toad)
				# a Roost and too few Skywings: they come first whenever the essence is there
				# (spare raptors are offered up at the Brood Pen for it: see _offer)
				var want_wing: bool = game._has_built(team, "roost") and wings * (2 if strategy == "air" else 6) < army.size() + (6 if strategy == "air" else 0)
				if want_wing and game.can_train(h, "skywing") == "":
					k = "skywing"
					wings += 1
				elif army.size() >= 12 and toads < (1 if army.size() < 24 else 2) and game.can_train(h, "mist_toad") == "":
					# a Mist Toad or two in the middle game: fog for the swarm, a tongue for their guns
					k = "mist_toad"
					toads += 1
				elif game.can_train(h, "brute") == "" and brutes * 12 < army.size() + 6:
					k = "brute"
					brutes += 1
				elif game.can_train(h, "bloater") == "" and army.filter(func(u: Unit) -> bool: return u.kind == "bloater").size() * 10 < army.size() and randf() < 0.3:
					k = "bloater"
				elif game.can_train(h, "spore_mother") == "" and mothers * 14 < army.size():
					k = "spore_mother"
					mothers += 1
				if randf() < 0.75:
					k = _horse_counter(h, army, k)      # (Horsemen seen: Spitters and Brutes)
				if saving_mound and int(Defs.UNITS[k].get("cost2", 0)) > 0:
					k = "raptor"            # (the essence goes to the Broodmound first)
				if brood != null:
					k = brood.egg_choice(h, army, k)      # (Spitters wait for their biomass once the essence is there)
					if k == "":
						break
				if game.train(h, k) != "":
					break
		return
	var cannons := army.filter(func(u: Unit) -> bool: return u.kind == "cannon").size()
	var mortars := army.filter(func(u: Unit) -> bool: return u.kind == "mortar").size()
	var muskets := army.filter(func(u: Unit) -> bool: return Defs.MUSKETS.has(u.kind)).size()
	var short_powder := _res2() < 20.0
	# a horse waits at a Foundry for a gun we want: the Barracks saves the gold for it
	var gun_wait := false
	if not short_powder and army.size() >= 6 and _gold() < int(Defs.UNITS["cannon"]["cost"]):
		for f in _mine("foundry"):
			if f.built and f.queue.is_empty() and game.horses_at(f) > 0 and (cannons * 4 < army.size() + 2 or mortars < mini(2, int(muskets / 6.0))):
				gun_wait = true
	for b in _mine("barracks"):
		if gun_wait:
			break
		# (a little room left for the research going on here)
		if b.built and b.queue.size() < (3 if _gold() > 600 else 2):
			# the line is Musketeers (they stab when the enemy closes); horsemen to raid and
			# to run down guns
			# (light or armoured: _soldier_key)
			var k := _soldier_key(b, "musketeer")
			var horse := army.filter(func(u: Unit) -> bool: return u.kind == "cuirassier").size()
			var hk := _soldier_key(b, "cuirassier")
			var rush := _rush_open()
			var hcap: int = r5.horsemen_cap()      # (round 5: two riders and no more against the Clockwork)
			var horse_ok: bool = (horse < 3 or horse * 6 < army.size() or rush) if hcap < 0 else horse < hcap
			if horse_ok and randf() < (0.85 if rush else (0.6 if short_powder else 0.3)) and hk != "":
				k = hk
			elif k == "":
				k = hk
			if k != "":
				game.train(b, k)
	for f in _mine("foundry"):
		if not f.built or short_powder:
			continue
		# a Mortar or two behind the musketeers (one per 6 of them, 2 at most)
		if f.queue.size() < 2 and mortars < mini(2, int(muskets / 6.0)) and not f.queue.has("mortar") and game.can_train(f, "mortar") == "":
			game.train(f, "mortar")
			mortars += 1
		elif f.queue.size() < (2 if _gold() > 600 else 1) and cannons * 4 < army.size() + 2:
			game.train(f, "cannon")
	# one Powder Wagon once there's a real firing line (6+ musketeers) to keep in powder
	if _wagon() == null and army.filter(func(u: Unit) -> bool: return u.kind == "musketeer").size() >= 6:
		var queued := false
		for f in _mine("foundry"):
			queued = queued or f.queue.has("powder_wagon")
		if not queued:
			for f in _mine("foundry"):
				if f.built and f.queue.size() < 2 and game.can_train(f, "powder_wagon") == "":
					game.train(f, "powder_wagon")
					break
	var balloons := army.filter(func(u: Unit) -> bool: return u.kind == "balloon").size()
	for f in _mine("foundry"):
		if f.built and f.queue.is_empty() and balloons * 8 < army.size() and _gold() > 350 and game.can_train(f, "balloon") == "":
			game.train(f, "balloon")
			balloons += 1
	for c in _mine("church"):
		if c.built and c.queue.is_empty() and r5.missionary_ok() and game.can_train(c, "missionary") == "":
			game.train(c, "missionary")


## Gear mode: what the Mainsprings store at most (their Tension cap).
func _tension_cap() -> float:
	var cap := 0.0
	var gm: Dictionary = Defs.GEAR["mainspring"]
	for sp in _mine("mainspring"):
		if sp.built:
			cap += float((gm["big"] if sp.gear_big else gm["small"])["store"])
	return cap


## Gear mode: Works w may make `kind` now, or waits only for its cogs, with `keep` Tension left over after it.
func _tension_ok(w: Building, kind: String, keep: float) -> bool:
	var why := game.can_train(w, kind)
	if why != "" and not why.begins_with("Not enough cogs"):
		return false
	return game.tension(team) - float(Defs.tension_cost(Defs.UNITS[kind])) >= keep


## Crown: armoured recruits (Guardsmen, Cuirassiers) by default once Armour is researched
## and the money is there; light ones when the enemy fields a lot that is strong against
## armour (_anti_armour).
func _want_armour() -> bool:
	return game.has_tech(team, "armour") and _anti_armour() < 0.35


var _aa_t := -100.0
var _aa := 0.0


## The share (by supply) of the enemy's army that does extra harm to armoured men: guns
## whose round shot hits armour harder (Defs.ROUND_SHOT vs_armored), units whose bonus
## names our soldiers, armour-stripping acid. Counted once every 10 s.
func _anti_armour() -> float:
	if game.clock - _aa_t < 10.0:
		return _aa
	_aa_t = game.clock
	var all := 0.0
	var anti := 0.0
	for u in game.units:
		if u.dead or u.team < 0 or not game.hostile(u.team, team) or u.is_worker() or not u.has_attack():
			continue
		var w := float(u.d["supply"])
		all += w
		var bonus: Dictionary = u.d.get("bonus", {})
		if u.kind == "cannon" or u.d.has("acid") or bonus.has("musketeer") or bonus.has("cuirassier"):
			anti += w
	_aa = anti / all if all > 0.0 else 0.0
	return _aa


## The train button for a soldier of this kind: armoured when we want armour and can pay
## for it, else light; "" if neither can be trained.
func _soldier_key(b: Building, kind: String) -> String:
	if _want_armour():
		var ak := Defs.train_key(kind, true)
		if game.can_train(b, ak) == "" and _gold() >= game.unit_price(team, ak)[0] + _lv([60, 30, 0]):
			return ak
	var lk := Defs.train_key(kind, false)
	return lk if game.can_train(b, lk) == "" else ""


## Units busy with something of their own the army orders must leave alone: a balloon
## drop, an Ornithopter fetching or delivering a battery, a Bloater out of gas.
func _on_errand(u: Unit) -> bool:
	if u.order in ["courier", "overload", "board", "unload", "heal", "revive", "refit", "restock"]:
		return true
	if u.kind == "bloater" and u.deflate != "":
		return true
	if not _drop.is_empty() and (u == _drop.get("b") or (_drop.get("men", []) as Array).has(u)):
		return true
	return false


func _army_supply(list: Array) -> int:
	var n := 0
	for u in list:
		n += int(u.d["supply"])
	return n


## Crown: our Powder Wagon (there's only ever one).
func _wagon() -> Unit:
	for u in game.units:
		if u.team == team and not u.dead and u.kind == "powder_wagon":
			return u
	return null


var _wagon_refill := false


## The Powder Wagon follows a little behind the army (never in front), has SUPPLY on while
## it's out in the field so labourers bring it kegs, and goes back to a Barracks, Mill or Town Hall to fill up when it's
## nearly empty. Musketeers out of powder with nothing to fight fall back to it.
func _tend_wagon() -> void:
	var w := _wagon()
	if w == null:
		return
	# keg runs only while it's out in the field (at home it fills from the buildings itself)
	var away := w._powder_building() == null
	if w.supplying != away:
		w.set_supply(away)
	var army: Array = game.army(team).filter(func(u: Unit) -> bool: return u != w and not _raiders.has(u) and not u.is_air())
	if w.powder < w.max_powder() * 0.25:
		_wagon_refill = true
	elif w.powder > w.max_powder() * 0.9:
		_wagon_refill = false
	if _wagon_refill:
		if w._powder_building() == null and w.order != "move":
			var best: Building = null
			var bd := INF
			for b in game.buildings:
				if b.team == team and b.built and not b.dead and (Defs.POWDER["from"] as Array).has(b.kind):
					var dd: float = b.edge_distance(w.position)
					if dd < bd:
						bd = dd
						best = b
			if best:
				w.cmd_move(game.approach_point(best, w.position))
		return
	if army.is_empty():
		return
	var c := Vector2.ZERO
	for u in army:
		c += u.position
	c /= army.size()
	var halls := _halls()
	var home: Vector2 = halls[0].center() if not halls.is_empty() else game.center_of_team(team)
	var spot := c + (home - c).normalized() * 120.0 if home.distance_to(c) > 120.0 else home
	if w.position.distance_to(spot) > 100.0 and (w.order != "move" or w.order_point.distance_to(spot) > 140.0):
		w.cmd_move(spot)
	if w.powder >= 6.0:
		for u in army:
			if u.kind == "musketeer" and u.powder < 1.0 and u.target == null and u.order != "move":
				var dd: float = u.position.distance_to(w.position)
				if dd > 70.0 and dd < 700.0:
					u.cmd_move(w.position + Vector2(randf_range(-30, 30), randf_range(-30, 30)))


func _army() -> void:
	var army: Array = game.army(team).filter(func(u: Unit) -> bool: return not _raiders.has(u) and not _on_errand(u) and u.kind != "powder_wagon" and u.kind != Defs.GREAT_WINDER_KIND and u.order != "sacrifice")      # (a Great Winder walks behind it: _great_winder_follow)
	if _clock():
		r5.tick(army)                   # (round 5: the guards by the Winders and the ramp post against riders)
		army = army.filter(func(u: Unit) -> bool: return not r5.busy(u))
	if _crown() and not r5.holding():
		army = _guard_new_hall(army)    # (round 5: while it holds behind the wall the hall's guards come home too)
	# Bloaters out of gas float home to fill up again (faster on the swamp)
	for u in game.army(team):
		if u.kind == "bloater" and u.deflate == "flat" and u.order != "move":
			var hall: Array = _halls()
			if not hall.is_empty() and u.position.distance_to(hall[0].center()) > 220.0:
				u.cmd_move(hall[0].center() + Vector2(randf_range(-80, 80), randf_range(-80, 80)))
	# Ornithopters fetch batteries for the constructs that run down
	if _clock():
		for u in army:
			if u.kind == "ornithopter" and not u.courier:
				u.courier = true
	# Defend: enemies near our buildings get everyone's attention.
	var threat := _threat()
	if threat != Vector2.INF:
		# (sized response: only as many soldiers as the visible enemy needs, see _defend)
		var tspots := _threats()
		if r5.hold_behind_wall(army, tspots):
			return              # (round 5: a bigger wave at the gate: the army holds on the high ground behind the wall)
		_defend(army, threat, tspots)
		# (workers: _worker_safety, from the economy think, pulls them out of reach or sends the hands)
		return
	if not _det.is_empty():
		_end_defence()
	_horse_posture(army)
	# Clockwork: constructs running low on charge go back into a field first
	if _clock():
		var fields: Array = game.buildings.filter(func(b: Building) -> bool: return b.team == team and not b.dead and b.built and b.d.has("field"))
		for u in army:
			if u.wind < 0.2 and not u.runs_on_spring() and not u._in_field and not u.powered_down() and u.order != "move" and not fields.is_empty():
				var best: Building = fields[0]
				for f in fields:
					if f.center().distance_to(u.position) < best.center().distance_to(u.position):
						best = f
				u.cmd_move(best.center() + Vector2(randf_range(-40, 40), randf_range(-40, 40)))
		army = army.filter(func(u: Unit) -> bool: return u.wind >= 0.2 or u._in_field or u.runs_on_spring())   # (wind-ups fight on; the escort cranks them)
	var sup := _army_supply(army)
	var swarm_min := 7 if strategy == "rush" else (10 if strategy in ["rush", "air"] or scout.verdict == "greedy" else 30)
	if _brood() and _attack_at < swarm_min and strategy != "xrush" and not _mop_pending:
		_attack_at = swarm_min     # a swarm waits until it's a swarm
	# timing attack: nothing goes out before the timing; then everything does, wave after wave
	if strategy == "timing" and game.clock >= float(_s("timing")) * (1.0 if difficulty >= 2 else 1.25) and _attack_at >= 999:
		_attack_at = scout.timing_wave()    # (6 unless the scout sized the attack from what it saw)
	if peaceful:
		_attack_at = 99999
	# a failed rush: building up again; nothing goes out until the regroup is over (unless
	# the army is already huge)
	var regrouping := game.clock < _regroup_until and sup < 60
	if _brood():
		if strategy in ["xrush", "rush"]:
			_xrush_army(army, sup)
		else:
			_swarm_army(army, sup, regrouping)
		return
	# (riders still on foot, their horses on the way, don't count yet: they follow mounted)
	var ready := army.filter(func(u: Unit) -> bool: return not _horse_coming(u))
	if not _attacking and _army_supply(ready) >= _attack_at and not regrouping and _timing_ok(ready) and _kit_ready(ready) and r5.attack_ok(ready):
		_attacking = true
		_wave_target = _enemy_base()
		_attack_at = mini(_attack_at + int(_s("step")), 70)
		_wave_start(ready)
		_mop_pending = false
		_wave_set.clear()
		for u in ready:
			_wave_set[u] = true      # (only these go; the ones trained later wait for a group)
		# the first wave of a rush plan is the rush: judged from the facts while it runs
		var is_rush := not _first_wave and _rush_state == "" and strategy == "rush" and strategy == _opened
		_rush_wave = false
		if is_rush:
			_rush_begin(ready, false)
		if game.mlog and not _first_wave:
			_first_wave = true
			game.mlog.add("%s's first attack goes out (%d supply, %d Horsemen)" % [game.mlog.who(team), _army_supply(ready), ready.filter(func(u: Unit) -> bool: return u.kind == "cuirassier").size()])
		var prey0 := _prey_spot(game.center_of_team(team)) if _cavalry_wave(ready) else Vector2.INF
		for u in ready:
			if prey0 != Vector2.INF and u.kind == "cuirassier":
				_hunt(u, prey0)
				continue
			u.cmd_move(_wave_target + Vector2(randf_range(-50, 50), randf_range(-50, 50)), true)
	elif _attacking:
		var wave: Array = ready.filter(func(u: Unit) -> bool: return _wave_set.has(u))
		# the wave's own strength (units trained since wait at home: they never trickle in alone)
		if _army_supply(wave) < 6:
			_attacking = false
			_release_escort()
			if _rush_wave and _rush_state == "ongoing":
				if _rush_verdict(wave) != "succeeded":
					_rush_why = _rush_why if _rush_why != "" else "the wave is gone"
					_rush_failed(wave)
					return
				_rush_state = "succeeded"
				_rush_mode = "mop"
				_rush_mop(wave)
				_wave_end()
				return
			for u in wave:
				u.cmd_move(_home_spot(_front()))        # (a lone survivor rides home)
			_rush_wave = false
			_wave_set.clear()
			_wave_end()
			return
		if _rush_wave and _rush_tick(wave):
			return
		_wave_target = _enemy_base()
		# a wall in the way: the army weighs it up as one (break in, or pull back)
		_siege_tick(wave)
		if not _attacking:
			return
		if (_clock() and Defs.gear_mode or r5.retreat_rule() and not _rush_wave) and difficulty >= 1 and _losing_trade(wave):
			return
		# fresh units join only as a group: 2+ cavalry finishing a crippled enemy, or 6+ supply
		var pool: Array = ready.filter(func(u: Unit) -> bool: return not _wave_set.has(u))
		var finishing := _rush_wave and _rush_state == "succeeded" and _rush_mode == "finish"
		if finishing:
			pool = _rush_pool(pool)
		var group_ok: bool = pool.size() >= GROUP_MIN and (finishing or (_rush_wave and _rush_state == "ongoing") or _army_supply(pool) >= GROUP_SUPPLY)
		if group_ok:
			for u in pool:
				_wave_set[u] = true
				wave.append(u)
		var wagon := _wagon() if _crown() else null
		var cav := _cavalry_wave(ready)
		var prey := Vector2.INF
		for u in wave:
			if cav and u.kind == "cuirassier" and u.siege_t <= 0.0 and u.wall_flee_t <= 0.0:
				if prey == Vector2.INF:
					prey = _prey_spot(u.position)
				_hunt(u, prey)
				continue
			if _patch.has(u):
				continue          # (stepped back to the escort to be mended: _patch_up)
			if u.order == "idle" and u.wall_flee_t <= 0.0 and u.siege_t <= 0.0 and not (u.deploys() and u.tesla_mode == "deployed" and u.target):
				# a dry musketeer topping up at the wagon waits there until it can shoot again
				if wagon and u.kind == "musketeer" and u.powder < float(Defs.POWDER["rearm"]) + 2.0 \
						and wagon.powder >= 1.0 and u.position.distance_to(wagon.position) < 120.0 and u.target == null:
					continue
				u.cmd_move(_wave_target + Vector2(randf_range(-60, 60), randf_range(-60, 60)), true)
		if not group_ok:
			var front2 := _front()
			for u in pool:
				if u.order == "idle" and u.position.distance_to(front2) > 160.0:
					u.cmd_move(_home_spot(front2), true)
		if _clock():
			_follow_with_escort(army)
	else:
		# Gather at a rally spot in front of the base.
		var hall: Array = _halls()
		if hall.is_empty():
			return
		var front: Vector2 = _rally_front(hall[0])
		for u in ready:
			if u.order == "idle" and u.position.distance_to(front) > 160.0:
				u.cmd_move(_home_spot(front), true)
			elif u.deploys() and u.order == "idle" and u.tesla_mode == "packed":
				u.cmd_deploy()
		if _clock() and Defs.gear_mode:
			_follow_with_escort(army)       # (the Winders keep the waiting army wound: the rally may be off the gear ground)


## Gear mode's Clockwork against a walled enemy: the first attack waits for its kit, the Springers that shoot the menders
## and the shooters on the edge (Normal 2, Hard 4), until 8:00 at the latest (Clock Soldiers alone at a mended gate
## lost 25 for 1 in the 0.14.72 siege). A rush plan or an enemy without walls goes as before.
func _kit_ready(list: Array) -> bool:
	if not (_clock() and Defs.gear_mode) or difficulty < 1 or strategy == "rush" or _first_wave or game.clock > 480.0 or not _foe_walled():
		return true
	var springers := list.filter(func(u: Unit) -> bool: return u.kind == Defs.SPRINGER).size()
	return springers >= _lv([0, 2, 4])


## A timing attack the scout sized waits while the army is not worth enough against what
## the enemy showed (never into a clearly stronger defence).
func _timing_ok(list: Array) -> bool:
	if strategy != "timing" or scout.verdict != "greedy":
		return true
	var v := 0.0
	for u in list:
		v += float(u.d["cost"]) / maxf(1.0, float(u.d.get("spawn", 1)))
	return scout.timing_ok(v)


## Crown: a wave that's mostly horsemen (the Horseman rush) raids the economy: its riders
## hunt workers (_hunt) rather than ride at the enemy's hall.
func _cavalry_wave(list: Array) -> bool:
	if not _crown():
		return false
	var cav := 0
	var all := 0
	for u in list:
		all += int(u.d["supply"])
		if u.kind == "cuirassier":
			cav += int(u.d["supply"])
	return cav > 0 and cav * 2 >= all


## A rider on foot whose horse is on its way: he's going to get on (or waits at the breeder
## for the one kept for him). The army leaves him be until he's mounted.
func _horse_coming(u: Unit) -> bool:
	return Defs.RIDERS.values().has(u.kind) and (u.order == "mount" or u.horse_rid != 0) and (u.kind == "dismounted" or u.horse_rid != 0 or u.auto_mount)


## Where the army waits at home: a little in front of the hall toward the enemy, but on the
## hall's own ground (same height, same walkable area): the straight line to the enemy can
## cross a cliff, and the men then stood down the hill outside the main.
func _rally_front(hall: Building) -> Vector2:
	var home := hall.center()
	var hc: Vector2i = game.cell_of(home + Vector2(0, hall.rect().size.y * 0.5 + 24.0))
	var h: int = game.height[game.idx(hc)] if game.in_map(hc) else 0
	var reg: int = game.region_of(hc)
	var want: Vector2 = home.lerp(_enemy_base(), 0.15)
	for k in 11:
		var p: Vector2 = want.lerp(home, k / 10.0)
		var c: Vector2i = game.cell_of(p)
		if game.in_map(c) and game.open_cell(c) and game.height[game.idx(c)] == h and (reg < 0 or game.region_of(c) == reg):
			return p
	return game.cell_center(hc)


## A spot near the rally point, scattered a little, but never over the edge of the plateau.
func _home_spot(front: Vector2) -> Vector2:
	var spot: Vector2 = front + Vector2(randf_range(-60, 60), randf_range(-60, 60))
	var sc: Vector2i = game.cell_of(spot)
	var fc: Vector2i = game.cell_of(front)
	if not game.in_map(sc) or not game.in_map(fc) or game.height[game.idx(sc)] != game.height[game.idx(fc)] \
			or game.region_of(sc) != game.region_of(fc):
		return front
	return spot


## Brood: a swarm never walks into the guns in one lump. Each wave splits into groups
## that circle round to different sides of the target, wait until everyone is in place,
## and then all go in at once. Hatchlings that come out mid-attack wait at home for the
## next wave instead of trickling in one by one.
func _swarm_army(army: Array, sup: int, regrouping := false) -> void:
	var hall: Array = _halls()
	var front: Vector2 = _rally_front(hall[0]) if not hall.is_empty() else game.center_of_team(team)
	# don't throw a small swarm at a much bigger army: wait until it's worth as much
	var mine := 0.0
	for u in army:
		mine += float(u.d["cost"]) / maxf(1.0, float(u.d.get("spawn", 1)))
	var theirs := 0.0
	var foe := _foe()
	if foe >= 0:
		for u in game.army(foe):
			if game.is_visible_to(team, u.position):      # (only what our eyes show)
				theirs += float(u.d["cost"])
	var big_enough := mine >= theirs * 0.8 or sup >= 70 or strategy in ["rush", "air"] or (strategy == "timing" and scout.timing_ok(mine))
	# (and never into an enemy army we have seen to be clearly stronger: AIBrood.attack_ok)
	if _swarm_phase == "" and sup >= _attack_at and big_enough and not regrouping and not _horse_hold(army) and (brood == null or brood.attack_ok(mine)):
		_attacking = true
		_wave_target = _enemy_base()
		_attack_at = mini(_attack_at + int(_s("step")), 70)
		_mop_pending = false
		_wave_start(army)
		_plan_swarm(army)
		_swarm_phase = "flank"
		_swarm_t = 0.0
	elif _swarm_phase != "":
		_swarm_t += 1.0
		var alive := 0
		var wave: Array = []
		for g in _swarm:
			g[0] = (g[0] as Array).filter(func(u) -> bool: return is_instance_valid(u) and not u.dead and not _on_errand(u))      # (untyped: a freed Raptor fails a typed lambda's conversion, an error that emptied the group)
			alive += _army_supply(g[0])
			wave.append_array(g[0])
		var sieging := false
		if alive >= 6:
			# a wall in the way: the swarm weighs it up as one (break in, or pull back), and
			# doesn't circle round to flanking spots it can't reach
			sieging = _siege_tick(wave)
			if sieging and _swarm_phase == "flank":
				_swarm_phase = "strike"
		if _swarm_phase == "":
			pass                     # (it just pulled back from a wall)
		elif alive < 6:
			_swarm_phase = ""
			_swarm.clear()
			_attacking = false
			_wave_end()
		elif brood != null and brood.wave_lost(wave, _wave_value):
			# a clearly lost fight: the swarm pulls back home and the next wave waits for a bigger army
			brood.retreat(wave, brood.fight_value(wave))
			_swarm_phase = ""
			_swarm.clear()
			_siege_clear()
			_attacking = false
			_regroup_until = maxf(_regroup_until, game.clock + float(_lv([90.0, 60.0, 45.0])))
			_wave_end()
		elif _swarm_phase == "flank":
			# everyone in place (or it's taking too long, or we were spotted and hit): go
			var ready := true
			var hit := false
			for g in _swarm:
				var there := 0
				for u in g[0]:
					if u.position.distance_to(g[1]) < 200.0:
						there += 1
					if u.target != null:
						hit = true
				if there < (g[0] as Array).size() * 0.6:
					ready = false
			if ready or hit or _swarm_t > (8.0 if strategy == "rush" else 40.0):
				_swarm_phase = "strike"
				_wave_target = _enemy_base()
				# caught a fight on the way: everyone goes there together, not on to the base
				var fs := _fight_spot()
				if fs != Vector2.INF:
					_wave_target = fs
				# a few grubs follow the swarm to harvest the fallen
				var spare := game.workers(team).filter(func(u: Unit) -> bool: return u.kind == "grub" and u.order != "build" and u.cocoon == 0)
				var want_h := 2 if spare.size() > 10 else (1 if spare.size() > 6 else 0)
				var have := game.workers(team).filter(func(u: Unit) -> bool: return u.order == "harvest").size()
				for g2 in spare.slice(0, maxi(0, want_h - have)):
					g2.cmd_harvest()
					g2.harvest_home = (_swarm[0][1] as Vector2) if not _swarm.is_empty() else _wave_target
				var sp := _spread()
				for g in _swarm:
					for u in g[0]:
						u.cmd_move(_wave_target + Vector2(randf_range(-sp, sp), randf_range(-sp, sp)), true)
		else:
			# strike: wherever part of the wave is fighting, the rest joins that fight
			var fs := _fight_spot()
			_wave_target = fs if fs != Vector2.INF else _enemy_base()
			var sp := _spread()
			for g in _swarm:
				for u in g[0]:
					if u.deploys() and u.tesla_mode == "deployed" and u.target:
						continue
					if u.siege_t > 0.0:
						continue             # breaking in at a wall: the siege gives its orders
					var join: bool = fs != Vector2.INF and u.target == null and u.position.distance_to(fs) > 140.0
					if (u.order == "idle" or join) and u.wall_flee_t <= 0.0:
						u.cmd_move(_wave_target + Vector2(randf_range(-sp, sp), randf_range(-sp, sp)), true)
	# everyone not in the wave gathers at home
	var in_wave := {}
	for g in _swarm:
		for u in g[0]:
			in_wave[u] = true
	for u in army:
		if in_wave.has(u):
			continue
		if u.order == "idle" and u.position.distance_to(front) > 160.0:
			u.cmd_move(_home_spot(front), true)
		elif u.deploys() and u.order == "idle" and u.tesla_mode == "packed":
			u.cmd_deploy()


# ---- Brood EXTREME RUSH (the "six-pool")
var _xr_t0 := 0.0
var _xr_wave: Array = []


## The rush is over (it failed, was beaten back, or ran out of time): a normal Brood game
## from here (workers, Pen, tech, expansions) and a bigger army before the next attack.
func _xrush_over(why: String) -> void:
	strategy = "balanced"
	_attack_at = maxi(_attack_at, 30)
	_regroup_until = game.clock + _lv([150.0, 120.0, 90.0])
	_xr_wave.clear()
	if game.mlog:
		game.mlog.add("%s's extreme rush is over (%s): it builds up (workers, tech) and comes back in force" % [game.mlog.who(team), why])


## The first wave is 6 Raptors straight at the enemy's workers (no flanking: speed is the
## point), every new Raptor follows, the fight is left only when it is clearly lost (the enemy
## there is worth over 1.6x the wave and 150+) or when it has made no headway after 75 s.
func _xrush_army(army: Array, sup: int) -> void:
	var hall: Array = _halls()
	var front: Vector2 = _rally_front(hall[0]) if not hall.is_empty() else game.center_of_team(team)
	if not _attacking and _horse_alert():
		_xrush_over("Horsemen seen: Raptors would do little")      # (a normal game: Pen, Spitters, Brutes; _horse_hold keeps the army home)
		return
	if not _attacking:
		if sup >= int(_s("wave")) and not peaceful and game.clock >= _regroup_until and (brood == null or brood.attack_ok(brood.army_value(army), AIBrood.RUSH_RATIO)):
			_attacking = true
			_xr_t0 = game.clock
			_wave_target = _enemy_base()
			_wave_start(army)
			_xr_wave = army.duplicate()
			if _rush_state == "" and not _first_wave:
				_rush_begin(_xr_wave, false)
			if game.mlog and not _first_wave:
				_first_wave = true
				game.mlog.add("%s's first attack goes out (%d supply of Raptors)" % [game.mlog.who(team), sup])
		else:
			for u in army:
				if u.order == "idle" and u.position.distance_to(front) > 160.0:
					u.cmd_move(_home_spot(front), true)
			return
	_xr_wave = _xr_wave.filter(func(u) -> bool: return is_instance_valid(u) and not u.dead)
	# the ones trained since wait at home and join as a group (2+), never one by one
	var fresh: Array = army.filter(func(u: Unit) -> bool: return not _xr_wave.has(u))
	var finishing := _rush_state == "succeeded" and _rush_mode == "finish"
	if fresh.size() >= GROUP_MIN:
		_xr_wave.append_array(fresh)
	else:
		for u in fresh:
			if u.order == "idle" and u.position.distance_to(front) > 160.0:
				u.cmd_move(_home_spot(front), true)
	var alive := _army_supply(_xr_wave)
	var c := Vector2.ZERO
	var mine := 0.0
	for u in _xr_wave:
		c += u.position
		mine += _unit_value(u)
	if not _xr_wave.is_empty():
		c /= _xr_wave.size()
	var gained := int(game.stats[team]["value_killed"]) - _wave_kill0
	var losing := false
	if not _xr_wave.is_empty():
		var a := _assess(c)
		losing = a["value"] >= 100.0 and a["value"] > mine * 1.15 and game.clock - _xr_t0 > 6.0 and a["value"] != DEF_UNSEEN
	var stale: bool = game.clock - _xr_t0 > 75.0 and gained < _wave_value * 0.3
	if _rush_state == "ongoing" and not (alive < 2 or losing or stale):
		var v := _rush_verdict(_xr_wave)
		if v == "failed":
			_rush_failed(_xr_wave)
			return
		elif v == "succeeded":
			_rush_state = "succeeded"
			_rush_mode = _rush_mode_now(_xr_wave)
			if _rush_mode == "mop":
				_rush_mop(_xr_wave)
				return
			_rush_log("SUCCEEDED, %d workers left and no defenders: new Raptors in groups of 2+ may finish them" % _rush_workers_left())
	elif finishing and _rush_mode_now(_xr_wave) == "mop":
		_rush_mop(_xr_wave)
		return
	if alive < 2 or losing or stale:
		if _rush_state == "succeeded":
			_rush_mop(_xr_wave)          # (the finishing party is spent: the mop-up force takes over)
			return
		_rush_why = "wiped out" if alive < 2 else ("clearly outgunned" if losing else "no headway")
		_rush_failed(_xr_wave)
		return
	# a sealed ramp (a Cottage and a Gate, a palisade): the wave breaks the piece in its way, instead of
	# milling about at the foot of the ramp until the wave is called off. The defender pays repairs
	# until its Musketeers are out (docs/design_principles.md, 5).
	var brk := _piece_to_break(_xr_wave, c)
	if brk != null:
		for u in _xr_wave:
			if u.siege_t > 0.0 or u.dead or u.off_field:
				continue
			if u.target != brk or u.order != "attack":
				u.cmd_attack(brk)
		return
	# armed defenders in sight: fight them together (an attack-move; a plain move would run the
	# Raptors past the guns to the workers and they would die without a bite), else hunt workers
	var guard: Unit = null
	var gd := 340.0
	for o in game.units_near(c, 340.0):
		if o.dead or o.off_field or not game.hostile(o.team, team) or not _armed(o) or not game.is_visible_to(team, o.position):
			continue
		var dd: float = o.position.distance_to(c)
		if dd < gd:
			gd = dd
			guard = o
	for u in _xr_wave:
		if u.siege_t > 0.0:
			continue
		if guard != null:
			if u.target == null and (u.order == "idle" or u.order == "move" or u.position.distance_to(guard.position) > 200.0):
				u.cmd_move(guard.position + Vector2(randf_range(-30, 30), randf_range(-30, 30)), true)
		else:
			_hunt(u, _prey_spot(u.position))


## The enemy wall or gate piece nearest the wave that it can walk up to, when the prey (the
## workers) cannot be reached on foot because of the enemy's walls and gates; else null.
func _piece_to_break(wave: Array, c: Vector2) -> Building:
	var rep: Unit = null
	for u in wave:
		if is_instance_valid(u) and not u.dead and not u.off_field and not u.is_air() and float(u.d.get("range", 0)) <= 40.0:
			rep = u
			break
	if rep == null:
		return null
	if rep._walk_reaches_point(_prey_spot(rep.position)):
		return null
	var a: Vector2i = game.cell_of(rep.position)
	if not game.open_cell(a):
		a = game.nearest_free(a, 4)
	if a.x < 0:
		return null
	var best: Building = null
	var bd := 1800.0
	for b in game.buildings:
		if b.dead or not b.built or not (b.kind == "wall" or b.kind == "gate") or not game.hostile(b.team, team):
			continue
		var dd: float = b.center().distance_to(c)
		if dd >= bd or not rep.can_hit(b):
			continue
		for dv in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nb: Vector2i = b.cell + dv
			if game.open_cell(nb) and not game.astar.get_id_path(a, nb).is_empty():
				bd = dd
				best = b
				break
	return best


## Split the army into groups (two or three, mixed: every group gets its share of
## raptors, spitters and brutes) and give each a spot on a different side of the target.
func _plan_swarm(army: Array) -> void:
	_swarm.clear()
	var target := _wave_target
	var home := game.center_of_team(team)
	var n := 1
	_tight = _splash_share() < 0.25
	if _tight:
		n = 1               # single-target shooters: one packed swarm hits all at once
	elif army.size() >= 24:
		n = 3
	elif army.size() >= 10:
		n = 2
	var dir := (home - target).normalized()
	var angles: Array = [0.0] if n == 1 else ([-1.1, 1.1] if n == 2 else [0.0, -1.3, 1.3])
	var dist := 520.0
	for a in angles:
		var p: Vector2 = target + dir.rotated(a) * dist
		var c: Vector2i = game.cell_of(p)
		c = Vector2i(clampi(c.x, 1, game.W - 2), clampi(c.y, 1, game.H - 2))
		c = game.nearest_free(c, 12)
		if c.x < 0:
			c = game.cell_of(target.lerp(home, 0.4))
		_swarm.append([[], Vector2(c) * Defs.TILE + Vector2(16, 16)])
	# deal the units out kind by kind so each group is a mix; slow casters go up the middle
	var by_kind := {}
	for u in army:
		if not by_kind.has(u.kind):
			by_kind[u.kind] = []
		by_kind[u.kind].append(u)
	var i := 0
	for k in by_kind:
		for u in by_kind[k]:
			var gi := 0 if k == "spore_mother" else i % n
			_swarm[gi][0].append(u)
			i += 1
	var sp := _spread()
	for g in _swarm:
		for u in g[0]:
			u.cmd_move(g[1] + Vector2(randf_range(-sp, sp), randf_range(-sp, sp)), false)


## How much of the enemy army (by cost) deals splash damage: against splash the swarm
## spreads out and flanks; against single-target shooters it packs tight and goes in together.
const SPLASH_KINDS := ["cannon", "mortar", "steam_walker", "spore_mother", "bloater", "stormcaller", "thresher", "tesla_cart"]

func _splash_share() -> float:
	var foe := _foe()
	if foe < 0:
		return 0.0
	var all := 0.0
	var splash := 0.0
	for u in game.army(foe):
		var c := float(u.d["cost"])
		all += c
		if SPLASH_KINDS.has(u.kind):
			splash += c
	return splash / all if all > 0.0 else 0.0


func _spread() -> float:
	return 22.0 if _tight else 60.0


## Where the wave is fighting right now (the middle of its engaged units), or INF.
func _fight_spot() -> Vector2:
	var sum := Vector2.ZERO
	var n := 0
	for g in _swarm:
		for u in g[0]:
			if is_instance_valid(u) and not u.dead and u.target != null and is_instance_valid(u.target):
				sum += u.position
				n += 1
	return sum / n if n > 0 else Vector2.INF


# ------------------------------------------------------------------ the trade (gear mode's Clockwork)

## A wave that keeps losing far more than it kills pulls back, whatever the reason (Musketeers on a cliff it walks
## under to reach an open target, a ground it cannot win): over the last TRADE_WINDOW s it lost more than TRADE_MIN of
## value and more than TRADE_RATIO times what it killed. The spot it was going for is left be for TRADE_AVOID s
## (_open_target skips it; a hall there is left like a walled one) and the next wave must be bigger. A siege the
## simulation weighs up (_siege_plan) is left to that. (0.14.72-73 games: one attack ran for 13 minutes and lost 171
## units for 70, a group of six walking in every half minute.)
const TRADE_WINDOW := 30.0
const TRADE_MIN := 300.0
const TRADE_RATIO := 2.2
const TRADE_AVOID := 150.0
var _trade: Array = []          # [clock, value we killed, value we lost] samples while a wave is out
var _bad_spots := {}            # Vector2 -> clock until which waves leave the spot be


func _lost_value() -> float:
	var v := 0.0
	for t in game.enemies_of(team):
		v += float(game.stats[t]["value_killed"])
	return v


func _losing_trade(wave: Array) -> bool:
	if not _siege.is_empty() or siege_no_retreat:
		return false
	var now := game.clock
	if _trade.is_empty() or now - float(_trade[-1][0]) >= 3.0:
		_trade.append([now, float(game.stats[team]["value_killed"]), _lost_value()])
	while _trade.size() > 1 and now - float(_trade[1][0]) >= TRADE_WINDOW:
		_trade.pop_front()
	if now - float(_trade[0][0]) < TRADE_WINDOW * 0.6:
		return false
	var killed: float = float(_trade[-1][1]) - float(_trade[0][1])
	var lost: float = float(_trade[-1][2]) - float(_trade[0][2])
	if lost < TRADE_MIN or lost < killed * TRADE_RATIO:
		return false
	var spot := _wave_target
	_bad_spots[spot] = now + TRADE_AVOID
	var hall := _hall_at(spot)
	if hall:
		_walled_halls[hall] = now + TRADE_AVOID
	_open_t = -99.0          # (look for another target)
	if game.mlog:
		game.mlog.add("%s pulls its wave back: it lost %d for %d in %d s (it leaves that spot be for a while)" % [game.mlog.who(team), int(lost), int(killed), int(now - float(_trade[0][0]))])
	var back := _home_spot(_front())
	for u in wave:
		if is_instance_valid(u) and not u.dead:
			u.siege_t = 0.0
			u.cmd_move(back + Vector2(randf_range(-70, 70), randf_range(-70, 70)))
			u.wall_flee_t = 10.0
	_trade.clear()
	_attacking = false
	_release_escort()
	_wave_end()
	_attack_at = maxi(_attack_at, mini(int(ceil(_wave_sup * 1.3)), _wave_sup + 30))
	return true


# ------------------------------------------------------------------ sieges (every faction)

## When the way to the wave's target is shut by an enemy wall or gate, the army decides as
## one whether to break in, instead of every unit making up its own mind at the wall:
##  * how fast it can knock down one piece (the melee units that fit at the wall face plus
##    every ranged unit that can shoot it, less any repair), against
##  * how fast the defenders in reach of that spot (muskets, canister, round shot...) shoot
##    the men doing it.
## A short simulation races one against the other, for each piece the army can reach that
## opens the way. If one piece falls in time, with enough of the army left to win the fight
## behind it, everything goes for that one piece: melee at its face (only as many as fit,
## the rest waiting out of reach to step up), ranged units standing back off the melee lane
## and shooting the same piece. If none does, the wave pulls back out of range and the
## computer gathers a bigger army (and goes for another of the enemy's halls meanwhile, if
## there's one). Weighed up again every SIEGE_EVAL seconds.
const SIEGE_EVAL := 3.0
const REP_REFILL := 7.0         # (the siege sim) s before another worker takes a fallen mender's place
## Tests and experiments only (tools/shot_ai_match.gd noretreat:1): a siege is never called off, so it plays out to the end.
var siege_no_retreat := false
var _siege := {}                # {"piece", "out" (outward dir), "stage", "cap" (melee at the face), "spots" {unit: point}, "splash", "flood"}
var _siege_next := 0.0          # (match clock) when the siege is weighed up again
var _siege_said := ""           # the last siege decision written to the match log (not said twice running)
var _walled_halls := {}         # enemy hall -> clock until which waves leave it be (walled too strongly)
var _dive_wait := {}            # after a breach: light melee -> [clock, gun]: they follow the tough ones in once
                                # the gun has fired (its canister spent on the Brutes, not on them), or at clock
var _hold_back := {}            # after a breach: unit -> clock when it goes on after the base (the melee walk
                                # through the gap first, the ranged hold a moment so they don't block it)


func _siege_clear() -> void:
	_siege.clear()


## Is this unit out with the attacking wave? (Unit._wall_watch leaves those to the siege.)
func in_wave(u: Unit) -> bool:
	if not _attacking:
		return false
	if not _brood():
		return not _guards.has(u) and not _raiders.has(u)
	for g in _swarm:
		if (g[0] as Array).has(u):
			return true
	return false


func _melee(u: Unit) -> bool:
	return float(u.d["range"]) <= 40.0


## The time one blow takes: aim, strike and reload (as Unit._attack_cycle runs it).
func _cycle(u: Unit) -> float:
	var cd := float(u.d["cooldown"])
	if u.kind == "musketeer":
		cd = u.musket_cooldown()
	return float(u.d.get("aim", 0.25)) + 0.35 + maxf(cd, 0.1)


## The cells reachable on foot from `cells` (4-way, as the pathfinder walks), with gates
## open only to team `t`'s side. 1 = reachable.
func _flood_from(cells: Array, t: int) -> PackedByteArray:
	# (cell indices and the grids read directly: a whole-map flood of Vector2i and calls
	# took the computer's think 40-50 ms)
	var w: int = game.W
	var h: int = game.H
	var solid: PackedByteArray = game.solid
	var seen := PackedByteArray()
	seen.resize(w * h)
	# the gates open to t's side (the only solid cells walkable here)
	var open_gates := {}
	if t >= 0:
		for gi in game.gate_team:
			if solid[int(gi)] == 3 and game.allied(int(game.gate_team[gi]), t):
				open_gates[int(gi)] = true
	var q := PackedInt32Array()
	for c in cells:
		if game.in_map(c) and seen[game.idx(c)] == 0 and _walkable(c, t):
			seen[game.idx(c)] = 1
			q.append(game.idx(c))
	var qi := 0
	while qi < q.size():
		var i: int = q[qi]
		qi += 1
		var x := i % w
		var n: int
		var v: int
		if x + 1 < w:
			n = i + 1
			if seen[n] == 0:
				v = solid[n]
				if v == 0 or v == 5 or (v == 3 and open_gates.has(n)):
					seen[n] = 1
					q.append(n)
		if x > 0:
			n = i - 1
			if seen[n] == 0:
				v = solid[n]
				if v == 0 or v == 5 or (v == 3 and open_gates.has(n)):
					seen[n] = 1
					q.append(n)
		if i + w < w * h:
			n = i + w
			if seen[n] == 0:
				v = solid[n]
				if v == 0 or v == 5 or (v == 3 and open_gates.has(n)):
					seen[n] = 1
					q.append(n)
		if i >= w:
			n = i - w
			if seen[n] == 0:
				v = solid[n]
				if v == 0 or v == 5 or (v == 3 and open_gates.has(n)):
					seen[n] = 1
					q.append(n)
	return seen


func _walkable(c: Vector2i, t: int) -> bool:
	var v: int = game.solid[game.idx(c)]
	if v == 0 or v == 5:
		return true
	return v == 3 and t >= 0 and game.allied(int(game.gate_team.get(game.idx(c), -1)), t)


func _is_piece(b) -> bool:
	return b is Building and (b.kind == "wall" or b.kind == "gate")


## Called every think while a wave is out. True while a siege runs the wave (the caller then
## leaves units with siege_t > 0 alone) or the wave has just pulled back from one.
func _siege_tick(wave: Array) -> bool:
	# after a breach: the melee walk through the gap, the ranged let them by first; then
	# everyone goes on after the base
	for u in _dive_wait.keys():
		if not is_instance_valid(u) or u.dead:
			_dive_wait.erase(u)
		elif game.clock >= float(_dive_wait[u][0]) or not is_instance_valid(_dive_wait[u][1]) or _dive_wait[u][1].dead \
				or _dive_wait[u][1].cooldown > 1.5:
			# (its gun has just fired, on the tough ones: in now, before it's loaded again)
			var gun = _dive_wait[u][1]
			_dive_wait.erase(u)
			if is_instance_valid(gun) and not gun.dead:
				u.cmd_attack(gun)
			else:
				u.cmd_move(_enemy_base() + Vector2(randf_range(-60, 60), randf_range(-60, 60)), true)
	for u in _hold_back.keys():
		if not is_instance_valid(u) or u.dead:
			_hold_back.erase(u)
		elif game.clock >= float(_hold_back[u]) or (u.order == "idle" and u.target == null):
			_hold_back.erase(u)
			u.siege_t = 0.0
			if u.order == "hold" or u.order == "move" or u.order == "idle":
				u.cmd_move(_enemy_base() + Vector2(randf_range(-60, 60), randf_range(-60, 60)), true)
	var ground: Array = wave.filter(func(u) -> bool: return is_instance_valid(u) and not u.dead and not u.is_air() and not u.off_field)
	if ground.is_empty():
		_siege_clear()
		return false
	var piece = _siege.get("piece")
	if piece != null and (not is_instance_valid(piece) or piece.dead):
		# through: the melee go in through the gap after the defenders behind it; the ranged
		# step up to the wall face beside the gap (not into it, in front of the melee) and shoot
		# over the wall; a few seconds on, all after the base
		var at: Vector2 = _siege["at"]
		var out: Vector2 = _siege["out"]
		var flood: PackedByteArray = _siege["flood"]
		var inner: PackedByteArray = _siege["inner"]
		var inside: Vector2 = _flood_point(inner, at - out * 90.0, at)
		_siege_clear()
		_siege_said = ""
		_siege_next = game.clock + 5.0          # (another wall behind it? weigh that up once through)
		var target := _enemy_base()
		# the guns behind the wall (canister, shells) are what kill a crowd in the gap: the
		# melee dive on them first, split between them, then go on after the rest
		var guns: Array = []
		for o in game.units_near(at, 340.0):
			if not o.dead and game.hostile(o.team, team) and not o.is_air() and SPLASH_KINDS.has(o.kind) \
					and inner[game.idx(game.cell_of(o.position))] == 1:
				guns.append(o)
		guns.sort_custom(func(a, b) -> bool: return a.position.distance_to(at) < b.position.distance_to(at))
		var gi := 0
		# tough melee (armoured) go first when there are any: the light ones wait out of reach
		# until the gun they're after has fired (at the tough ones), then rush it while it loads
		var tanks := not guns.is_empty() and wave.any(func(u) -> bool: return is_instance_valid(u) and not u.dead and not u.is_air() \
				and _melee(u) and u.has_attack() and not u.has_tag("light"))
		for u in wave:
			if is_instance_valid(u) and not u.dead:
				u.wall_flee_t = 0.0
				if u.is_air():
					u.siege_t = 0.0
					u.cmd_move(target + Vector2(randf_range(-60, 60), randf_range(-60, 60)), true)
				elif u.has_attack() and not _melee(u) and not u.deploys():
					# up to the wall face beside the gap (not in it): from there they shoot over
					# the wall at the defenders behind it
					var side: Vector2 = out.orthogonal() * (1.0 if randf() < 0.5 else -1.0)
					var face: Vector2 = _flood_point(flood, at + out * 30.0 + side * randf_range(56.0, 90.0), u.position)
					u.cmd_move(face, true)
					u.siege_t = 7.0
					_hold_back[u] = game.clock + 6.0
				else:
					if not guns.is_empty() and u.has_attack() and u.can_hit(guns[gi % guns.size()]):
						if tanks and u.has_tag("light"):
							u.cmd_hold()
							_dive_wait[u] = [game.clock + 5.0, guns[gi % guns.size()]]
						else:
							u.cmd_attack(guns[gi % guns.size()])
						gi += 1
					else:
						u.cmd_move(inside + Vector2(randf_range(-30, 30), randf_range(-30, 30)), true)
					u.siege_t = 8.0
					_hold_back[u] = game.clock + 7.0
		return true
	if game.clock >= _siege_next:
		_siege_next = game.clock + SIEGE_EVAL
		if not _siege_plan(ground, wave):
			return true            # pulled back: the wave is over
	if _siege.is_empty():
		if _clock() and Defs.gear_mode:
			_springer_leaps(ground)
		return false
	if _clock() and Defs.gear_mode:
		_springer_leaps(ground)
	_siege_orders(ground)
	return true


## Weigh up the wall in the way. Returns false when the wave pulls back (it's over).
func _siege_plan(ground: Array, wave: Array) -> bool:
	var objective := _enemy_base()
	var starts: Array = []
	var centre := Vector2.ZERO
	for u in ground:
		starts.append(game.cell_of(u.position))
		centre += u.position
	centre /= ground.size()
	var ours := _flood_from(starts, team)
	# can we walk up to the target? (any open cell next to it)
	var oc: Vector2i = game.cell_of(objective)
	var goal_cells: Array = []
	for dy in range(-3, 4):
		for dx in range(-3, 4):
			var c := oc + Vector2i(dx, dy)
			if game.in_map(c) and _walkable(c, -1):
				goal_cells.append(c)
				if ours[game.idx(c)] == 1:
					_siege_release(ground)
					return true          # an open way in: no siege
	if goal_cells.is_empty():
		_siege_release(ground)
		return true
	var inner := _flood_from(goal_cells, _foe())
	# the enemy walls and gates we can stand against that open the way
	var pieces: Array = []
	var touching: Array = []
	for b in game.buildings:
		if b.dead or not b.built or not _is_piece(b) or not game.hostile(b.team, team):
			continue
		var out_side := false
		var in_side: bool = inner[game.idx(b.cell)] == 1
		for dv in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = b.cell + dv
			if not game.in_map(n):
				continue
			if ours[game.idx(n)] == 1:
				out_side = true
			if inner[game.idx(n)] == 1:
				in_side = true
		if out_side:
			touching.append(b)
			if in_side:
				pieces.append(b)
	if pieces.is_empty():
		# several layers: the piece we can reach nearest to the target
		touching.sort_custom(func(a, b) -> bool: return a.center().distance_to(objective) < b.center().distance_to(objective))
		pieces = touching.slice(0, 1)
	if pieces.is_empty():
		_siege_release(ground)
		return true                  # shut out by something it can't break: carry on as before
	pieces.sort_custom(func(a, b) -> bool: return a.center().distance_to(centre) < b.center().distance_to(centre))
	var best: Dictionary = {}
	var cur = _siege.get("piece")
	if cur != null and (not is_instance_valid(cur) or cur.dead):
		cur = null
	for b in pieces.slice(0, 6):
		var r := _siege_sim(b, ground, ours, centre)
		# once in, it keeps going unless it's clearly lost (no dithering at the wall)
		var ok: bool = r["win"] or (b == cur and r["breach"] and r["left"] >= 0.15)
		if ok and b == cur and _siege_stalled(ground):
			ok = false            # (what happens at the wall is not what the race said: _siege_stalled)
			r["stalled"] = true
		if not ok:
			if best.is_empty() or (not best["ok"] and r["t"] < best["t"]):
				best = r.merged({"ok": false, "piece": b})
			continue
		var score: float = r["t"] + b.center().distance_to(centre) / 90.0 - (4.0 if b == cur else 0.0)
		if best.is_empty() or not best["ok"] or score < best["score"]:
			best = r.merged({"ok": true, "piece": b, "score": score})
	var who: String = game.mlog.who(team) if game.mlog else "AI"
	var forced := false
	if siege_no_retreat and not best.is_empty() and not best["ok"]:
		best["ok"] = true                # (an experiment: it goes on whatever the odds)
		forced = true
	if best["ok"]:
		var piece: Building = best["piece"]
		if piece != cur:
			_siege = {"piece": piece, "out": best["out"], "stage": best["stage"], "cap": best["cap"], "spots": {}, "splash": best["splash"], "flood": ours,
				"since": game.clock, "formed": false, "inner": inner, "at": piece.center(), "mreach": best["mreach"], "hp0": _ground_hp(ground)}
		else:
			_siege["cap"] = best["cap"]
			_siege["mreach"] = best["mreach"]
			_siege["stage"] = best["stage"]
			_siege["flood"] = ours
			_siege["inner"] = inner
		if forced:
			_say("forced", "%s would pull back from the %s (an experiment keeps it going): %s under %d dps of fire (%d dps on it, %d menders)" % [who, String(piece.d["name"]).to_lower(),
				"the wave is dying and the piece stands" if best.get("stalled", false) else (("down in ~%d s, too dear" % int(best["t"])) if best["breach"] else "it can't get through"), int(best["inc"]), int(best["dps"]), int(best.get("menders", 0))])
		else:
			_say("breach", "%s breaks in at a %s: down in ~%d s (%d dps on it) against %d dps of fire, %d menders" % [who, String(piece.d["name"]).to_lower(), int(best["t"]), int(best["dps"]), int(best["inc"]), int(best.get("menders", 0))])
		return true
	# lost: pull back out of reach, gather more, and leave this hall be for a while
	var b0: Building = best["piece"]
	var back: Vector2 = _flood_point(ours, b0.center() + best["out"] * (best["reach"] + 160.0), centre)
	if _clock() and Defs.gear_mode:
		# (gear mode: all the way back to the rally, by the escort. A spot just out of reach was the foot of the ramp: the
		# men packed in there on a plain move order, did not fight back, and died to the Musketeers who came out after
		# them, 24 Clock Soldiers for 9 in one 0.14.72 game)
		back = _home_spot(_front())
	_say("back", "%s pulls back from the %s: %s under %d dps of fire (%d dps on it)" % [who, String(b0.d["name"]).to_lower(),
		"the wave is dying and the piece stands" if best.get("stalled", false) else (("down in ~%d s, too dear" % int(best["t"])) if best["breach"] else "it can't get through"), int(best["inc"]), int(best["dps"])])
	for u in wave:
		if is_instance_valid(u) and not u.dead:
			u.siege_t = 0.0
			u.cmd_move(back + Vector2(randf_range(-70, 70), randf_range(-70, 70)))
			u.wall_flee_t = 10.0
	var hall := _hall_at(objective)
	if hall:
		_walled_halls[hall] = game.clock + 120.0
	_siege_clear()
	_attacking = false
	_swarm_phase = ""
	_swarm.clear()
	_release_escort()
	_wave_end()
	# it comes back only with a bigger army (not straight back at the same wall)
	_attack_at = maxi(_attack_at, mini(int(ceil(_wave_sup * 1.4)), _wave_sup + 40))
	return false


## A siege that is not going the way the race said: 25 s in, the piece has lost under a sixth of its hit points while
## the wave has lost over a third of its own (the men cannot get to the face, or the defence is not what was seen).
## Then the siege is weighed up as lost. (0.14.73 Frostmere: no Clock Soldier reached the gate in 60 s, and the wave
## died at its stage.)
func _siege_stalled(ground: Array) -> bool:
	var piece = _siege.get("piece")
	if piece == null or not is_instance_valid(piece) or game.clock - float(_siege.get("since", game.clock)) < 25.0:
		return false
	var hp0: float = float(_siege.get("hp0", 0.0))
	if hp0 <= 0.0:
		return false
	var lost: float = 1.0 - _ground_hp(ground) / hp0
	return lost > 0.33 and piece.hp > piece.max_hp * 0.84


func _ground_hp(ground: Array) -> float:
	var v := 0.0
	for u in ground:
		if is_instance_valid(u) and not u.dead:
			v += u.hp
	return v


func _say(kind: String, msg: String) -> void:
	if _siege_said == kind:
		return
	_siege_said = kind
	if game.mlog:
		game.mlog.add(msg)


func _hall_at(p: Vector2) -> Building:
	for b in game.buildings:
		if not b.dead and b.kind == game.faction_hall(b.team) and b.center().distance_to(p) < 8.0:
			return b
	return null


## The siege is off (an open way in): the units go back to the wave's ordinary orders.
func _siege_release(ground: Array) -> void:
	if _siege.is_empty():
		return
	_siege_clear()
	_siege_said = ""
	for u in ground:
		if u.siege_t > 0.0:
			u.siege_t = 0.0
			u.cmd_move(_enemy_base() + Vector2(randf_range(-60, 60), randf_range(-60, 60)), true)


## The reachable cell nearest to p (searched outward from p), or `fallback`.
func _flood_point(flood: PackedByteArray, p: Vector2, fallback: Vector2) -> Vector2:
	var c0: Vector2i = game.cell_of(p)
	for r in 14:
		var best := Vector2.INF
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var c := c0 + Vector2i(dx, dy)
				if game.in_map(c) and flood[game.idx(c)] == 1:
					var q: Vector2 = game.cell_center(c)
					if best == Vector2.INF or q.distance_to(p) < best.distance_to(p):
						best = q
		if best != Vector2.INF:
			return best
	return fallback


## Race the army against one piece. Returns {win, breach, t, left, dps, inc, cap, out, stage,
## reach, splash}.
func _siege_sim(piece: Building, ground: Array, flood: PackedByteArray, centre: Vector2) -> Dictionary:
	var pc := piece.center()
	# OUTWARD is the side of the piece we can walk up to (the cells beside it in our flood), not the straight line to the
	# army: a gate at the top of a ramp is reached up the ramp, and an army standing off to one side of it, under the cliff,
	# would otherwise stage (and queue for the face) at the foot of that cliff, under the muskets on the high ground and
	# unable to reach the gate (the owner's screenshots, 2026-10-27)
	var out := _siege_out(piece, flood)
	if out == Vector2.ZERO:
		out = (centre - pc).normalized()
	if out == Vector2.ZERO:
		out = (game.center_of_team(team) - pc).normalized()
	# --- the defenders that reach the wall face, and how far out past it they reach
	var our_armor := 0.0
	for u in ground:
		our_armor += float(u.d["armor"])
	our_armor /= maxf(1.0, ground.size())
	var single := 0.0            # dps on the man in front
	var spray := 0.0             # dps on each man of a crowd (canister, round shot, shells)
	var reach := 0.0             # how far out past the wall their muskets and canister reach
	var art_reach := 0.0         # ... and their round shot and shells
	var their_hp := 0.0
	var their_armor := 0.0
	var all_single := 0.0        # (all of them, in reach of the wall or not: the fight once we're through)
	var all_spray := 0.0
	var splash := false
	var seen_out := 0.0          # how far out past the wall they see (their guns fire on what they see)
	for o in game.units_near(pc, 520.0):
		if o.dead or o.off_field or not game.hostile(o.team, team) or o.is_worker() or not o.has_attack():
			continue
		if o.d.get("air_only", false):
			continue
		var dd: float = o.position.distance_to(pc)
		seen_out = maxf(seen_out, float(o.sight) * Defs.TILE - dd)
		var dps := maxf(1.0, float(o.d["damage"]) - our_armor) / _cycle(o)
		if o.d.has("gunners"):
			dps *= float(o.d["gunners"])
		their_hp += o.hp
		their_armor += float(o.d["armor"]) * o.hp
		var o_out := float(o.d["range"]) - dd + 16.0
		if o.kind == "cannon":
			var can_out: float = float(Defs.CANISTER["range"]) - dd + 16.0
			var can_dps: float = float(Defs.CANISTER["damage"]) * float(Defs.CANISTER["vs_light"]) / (float(Defs.CANISTER["cooldown"]) + 0.95)
			all_spray += can_dps
			if can_out >= 0.0:
				# canister into the crowd at the wall: a cone of balls into every man there
				spray += can_dps
				reach = maxf(reach, can_out)
				splash = true
			elif o_out >= 0.0:
				spray += dps * 0.6       # round shot through a line of men
				art_reach = maxf(art_reach, o_out)
				splash = true
			continue
		if SPLASH_KINDS.has(o.kind):
			all_spray += dps * 0.7
		else:
			all_single += dps
		if o_out < 0.0:
			continue
		if SPLASH_KINDS.has(o.kind):
			spray += dps * 0.7
			splash = true
			if float(o.d["range"]) > 250.0:
				art_reach = maxf(art_reach, o_out)
			else:
				reach = maxf(reach, o_out)
			continue
		single += dps
		reach = maxf(reach, o_out)
	# gear mode's Clockwork: the rest of their army behind the wall, seen lately, comes to the face once the fight
	# starts (at 60%, for the walk): a gate that looked bare at the first look had a dozen Musketeers on it 20 s later
	# (0.14.73 Kestrel Rise: "0 dps of fire", the wave died in 45 s)
	if _clock() and Defs.gear_mode:
		for o in game.units_near(pc, 1000.0):
			if o.dead or o.off_field or not game.hostile(o.team, team) or o.is_worker() or not o.has_attack() or o.is_air():
				continue
			var d2: float = o.position.distance_to(pc)
			if d2 <= 520.0 or flood[game.idx(game.cell_of(o.position))] == 1 or not _sighted(o):
				continue
			var dps2 := maxf(1.0, float(o.d["damage"]) - our_armor) / _cycle(o) * 0.6
			their_hp += o.hp
			their_armor += float(o.d["armor"]) * o.hp
			if SPLASH_KINDS.has(o.kind) or o.kind == "cannon":
				all_spray += dps2
				spray += dps2 * 0.5
			else:
				all_single += dps2
				if float(o.d["range"]) >= 100.0:
					single += dps2
	art_reach = maxf(art_reach, reach)
	their_armor /= maxf(their_hp, 1.0)
	# --- our side: who can hurt the piece (spitter acid strips 2 of its armour)
	var acid := false
	for u in ground:
		if u.kind == "spitter" and u.can_hit(piece):
			acid = true
	var arm := maxf(0.0, piece.armor - (2.0 if acid else 0.0))
	var melee: Array = []       # [hp, dps on the wall, room it takes, how long it lasts there, dps on men]
	var ranged: Array = []      # [hp, dps on the wall, how far back it stands, dps on men]
	var hp_hit := 0.0
	for u in ground:
		if not u.has_attack() or not u.can_hit(piece):
			continue
		var dmg := float(u.d["damage"]) * float(u.d.get("building_bonus", 1.0))
		var wd := maxf(1.0, dmg - arm) / _cycle(u)
		if u.deploys():
			wd *= 0.8            # (it has to set up)
		hp_hit += u.hp
		if _melee(u):
			var side: float = u.radius * 2.0 + 4.0
			# (canister shreds light troops: a tough one lasts longer at the face)
			var lasts: float = u.hp / (float(Defs.CANISTER["vs_light"]) if u.has_tag("light") else 1.0)
			melee.append([u.hp, wd, side * side, lasts, maxf(1.0, float(u.d["damage"]) - their_armor) / _cycle(u)])
		else:
			ranged.append([u.hp, wd, maxf(float(u.d["range"]) * 0.85, float(u.d.get("min_range", 0.0)) + 24.0), maxf(1.0, float(u.d["damage"]) - their_armor) / _cycle(u),
				not u.deploys() and float(u.d["damage"]) > 0.0])
	var none := {"win": false, "breach": false, "t": INF, "left": 0.0, "dps": 0.0, "inc": single + spray, "cap": 0,
		"out": out, "stage": pc + out * 200.0, "reach": art_reach, "splash": splash}
	if melee.is_empty() and ranged.is_empty():
		return none
	# room at the wall face: the reachable cells touching the piece (a second rank reaches past the first)
	var room := 0.0
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var c: Vector2i = piece.cell + Vector2i(dx, dy)
			if (dx != 0 or dy != 0) and game.in_map(c) and flood[game.idx(c)] == 1:
				room += float(Defs.TILE * Defs.TILE) * (1.0 if dx == 0 or dy == 0 else 0.5)
	room *= 2.0
	# the best wall-breakers go to the face first: the most damage for the room they take,
	# for the longest (a Brute before Raptors); the room left is filled with smaller ones,
	# and the rest queue up behind (in that order) to step up as the first fall
	melee.sort_custom(func(a, b) -> bool: return a[1] * a[3] / a[2] > b[1] * b[3] / b[2])
	var at_face: Array = []
	var queue: Array = []
	var used := 0.0
	for m in melee:
		if used + m[2] <= room or at_face.is_empty():
			used += m[2]
			at_face.append(m)
		else:
			queue.append(m)
	var cap := at_face.size()
	melee = at_face + queue
	# repairers on the wall (and those close enough to start); the workers farther back come to take a fallen one's place
	# (one every REP_REFILL s, up to as many as began). Our shooters that can hit them (Springers, Spitters...) shoot them
	# first (_siege_prey), and every Netter keeps one of them in a net a share of the time: a wall mended as fast as it
	# is hit falls once the menders do (the owner, 2026-10-27; the 0.14.72 siege: 25 Clock Soldiers lost for 1 kill)
	var rate := maxf(float(Defs.REPAIR_RATE), piece.max_hp / maxf(float(piece.d.get("time", 10.0)), 1.0))
	var reps: Array = []          # [hp, share of the time at work] of each mender
	var spare_hands := 0
	for o in game.units_near(pc, 700.0):
		if o.dead or not game.hostile(o.team, team) or not o.is_worker() or o.off_field:
			continue
		if o.position.distance_to(pc) < 220.0 and (o.kind == "labourer" or o.kind == "winder"):
			reps.append([o.hp + float(o.d["armor"]) * 5.0, 1.0 if o.work == "repairing" else 0.5])
		else:
			spare_hands += 1
	var rep_max := reps.size()
	var nets := 0
	for u in ground:
		if u.kind == Defs.NETTER:
			nets += 1
	var net_share := clampf(float(nets) * float(Defs.NET["time"]) / 14.6, 0.0, float(rep_max))
	var rep_next := INF
	var rep := 0.0
	for r in reps:
		rep += rate * float(r[1])
	rep = maxf(0.0, rep - rate * net_share)
	# --- the race, half a second at a time. First the wall: the men at the face (the next
	# stepping up as each falls) and the ranged behind against the piece; the defenders in
	# reach fire on the men in front (canister on all of the crowd there), and on the
	# ranged once no melee are left (if they reach that far). Then the fight through the
	# gap: only so many get through at once, against all the defenders behind the wall.
	var mhp: Array = []
	for m in melee:
		mhp.append(m[0])
	var rhp: Array = []
	for r in ranged:
		rhp.append(r[0])
	var wall_hp: float = piece.hp
	var foe_hp := their_hp
	var t := 0.0
	var dt := 0.5
	var limit := 90.0 if single + spray > 0.0 else 200.0
	var next_m := mini(cap, melee.size())
	var active: Array = []
	for i in next_m:
		active.append(i)
	var breached := false
	var t_breach := INF
	var won := false
	var dps0 := -1.0
	while t < limit and not won:
		var dps := 0.0
		for i in active:
			dps += melee[i][1 if not breached else 4]
		var shoot_men := 0.0          # (the shooters' fire on the menders, while there are any)
		for j in ranged.size():
			if rhp[j] > 0.0:
				if not breached and not reps.is_empty() and ranged[j][4]:
					shoot_men += ranged[j][3]
				else:
					dps += ranged[j][1 if not breached else 3]
		if dps0 < 0.0:
			dps0 = dps
		if not breached:
			if not reps.is_empty() and shoot_men > 0.0:
				reps[0][0] = float(reps[0][0]) - shoot_men * dt
				if float(reps[0][0]) <= 0.0:
					reps.pop_front()
					if spare_hands > 0 and rep_next == INF:
						rep_next = t + REP_REFILL
			if rep_next <= t and spare_hands > 0 and reps.size() < rep_max:
				spare_hands -= 1
				reps.append([46.0, 1.0])
				rep_next = t + REP_REFILL if reps.size() < rep_max else INF
			rep = 0.0
			for r in reps:
				rep += rate * float(r[1])
			rep = maxf(0.0, rep - rate * minf(net_share, float(reps.size())))
			dps -= rep
			if dps <= 0.0 and shoot_men > 0.0:
				dps = 0.01            # (the wall holds for now, but the menders are falling: the race goes on)
		if dps <= 0.0:
			break
		t += dt
		if not breached:
			wall_hp -= dps * dt
			if wall_hp <= 0.0:
				breached = true
				t_breach = t
				limit = t + 60.0
				# through the gap: a few more fit than at the wall face
				var cap2 := int(ceil(cap * 1.5))
				while active.size() < cap2 and next_m < melee.size():
					active.append(next_m)
					next_m += 1
				continue
		else:
			foe_hp -= dps * dt
			if foe_hp <= 0.0:
				won = true
				break
		var f_single := single if not breached else all_single
		var f_spray := spray if not breached else all_spray
		var scale := foe_hp / maxf(their_hp, 1.0)
		if not active.is_empty():
			var fire: float = (f_single + f_spray * minf(active.size() + 2.0, 8.0)) * scale * dt     # (canister catches the next in line too)
			while fire > 0.0 and not active.is_empty():
				var i: int = active[0]
				var take: float = minf(fire, mhp[i])
				mhp[i] -= take
				fire -= take
				if mhp[i] <= 0.0:
					active.pop_front()
					if next_m < melee.size():
						active.append(next_m)
						next_m += 1
		else:
			var fire_r: float = (f_single + f_spray * 2.0) * scale * dt
			for j in ranged.size():
				if fire_r <= 0.0:
					break
				if rhp[j] > 0.0 and (breached or ranged[j][2] <= reach):
					var take: float = minf(fire_r, rhp[j])
					rhp[j] -= take
					fire_r -= take
	var hp_left := 0.0
	for v in mhp:
		hp_left += maxf(0.0, v)
	for v in rhp:
		hp_left += maxf(0.0, v)
	var all_hp := 0.0
	for u in ground:
		all_hp += u.hp
	var frac_left := clampf((all_hp - (hp_hit - hp_left)) / maxf(all_hp, 1.0), 0.0, 1.0)
	# through, the defenders beaten, and enough left to go on and raze the base
	var win := breached and won and frac_left >= 0.25
	# the reserve waits out of their muskets' reach, and out of sight of their guns if it can
	var stage: Vector2 = _flood_point(flood, pc + out * clampf(maxf(reach + 70.0, minf(art_reach, seen_out) + 50.0), 130.0, 420.0), centre)
	return {"win": win, "breach": breached, "t": t_breach, "left": frac_left, "dps": maxf(dps0, 0.0), "menders": rep_max,
		"inc": single + spray * minf(cap + 2.0, 8.0), "cap": cap, "out": out, "stage": stage, "reach": art_reach, "mreach": reach, "splash": splash}


## The way out from a wall piece toward our side: from the piece to the middle of the cells within two of it that we can
## walk to (`flood`), ZERO when there are none.
func _siege_out(piece: Building, flood: PackedByteArray) -> Vector2:
	var sum := Vector2.ZERO
	var n := 0
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var c: Vector2i = piece.cell + Vector2i(dx, dy)
			if game.in_map(c) and flood[game.idx(c)] == 1:
				sum += game.cell_center(c)
				n += 1
	if n == 0:
		return Vector2.ZERO
	return (sum / float(n) - piece.center()).normalized()


## Orders while breaking in: first the army forms up out of the defenders' reach (the melee
## at a staging spot, the ranged at their firing spots, which they open fire from), so it
## doesn't arrive at the wall a few at a time; then the melee go to the face (as many as fit;
## the rest wait out of reach and step up as the first fall). All on the one piece; units
## that can't hurt a wall wait with the reserve.
func _siege_orders(ground: Array) -> void:
	var piece: Building = _siege["piece"]
	var pc := piece.center()
	var out: Vector2 = _siege["out"]
	var stage: Vector2 = _siege["stage"]
	var spots: Dictionary = _siege["spots"]
	var flood: PackedByteArray = _siege["flood"]
	var gap := 44.0 if _siege["splash"] else 26.0      # (against splash the waiting men spread)
	var melee: Array = []
	var aimed := {}                # prey -> how many shooters are on it (no overkill on a 46-hp Labourer)
	for u in ground:
		if _leapt.has(u):
			_leapt_fight(u)
			continue
		u.siege_t = SIEGE_EVAL + 2.0
		u.wall_flee_t = 0.0
		if u.kind == Defs.NETTER:
			# (a net on a worker mending the wall stops the mending for its 4 s; else on a shooter on the edge)
			if not spots.has(u):
				spots[u] = _ranged_spot(u, piece, out, flood, spots, gap)
			var nprey := _siege_prey(u, piece, aimed)
			if nprey != null and not Netter.caught(nprey):
				if not (u.order == "attack" and u.order_target == nprey):
					u.cmd_attack(nprey)
			elif u.position.distance_to(spots[u]) > 24.0 and (u.order != "move" or u.order_point.distance_to(spots[u]) > 8.0):
				u.cmd_move(spots[u])
			continue
		if not u.has_attack() or not u.can_hit(piece):
			_to_spot(u, stage, gap * 2.0)
			continue
		if _melee(u):
			melee.append(u)
			continue
		# ranged: to its own spot first, then shoot the piece from there
		if not spots.has(u):
			spots[u] = _ranged_spot(u, piece, out, flood, spots, gap)
		var spot: Vector2 = spots[u]
		var in_reach: bool = piece.edge_distance(u.position) - u.radius <= u._range() - 4.0
		# the workers mending the piece first, then the shooters on the edge: a wall that is mended as fast as it is hit
		# never falls (the owner, 2026-10-27: "the Springers can focus down and kill the workers"); _siege_prey
		if (in_reach or u.position.distance_to(spot) < 40.0) and u.kind != Defs.BALLISTA_KIND:      # (the Ballista's bolt is for the gate)
			var prey := _siege_prey(u, piece, aimed)
			if prey != null:
				aimed[prey] = int(aimed.get(prey, 0)) + 1
				if not (u.order == "attack" and u.order_target == prey):
					u.cmd_attack(prey)
				continue
		if u.order == "attack" and u.order_target == piece and in_reach:
			continue
		if in_reach and (u.position.distance_to(spot) < 28.0 or u.stuck_t > 0.8):
			u.cmd_attack(piece)
		elif u.order != "move" or u.order_point.distance_to(spot) > 8.0:
			u.cmd_move(spot)
	if not _siege["formed"]:
		var there := 0
		for u in melee:
			if u.position.distance_to(stage) < 110.0 or piece.edge_distance(u.position) < 60.0:
				there += 1
		if there >= melee.size() * 0.75 or game.clock - float(_siege["since"]) > 15.0:
			_siege["formed"] = true
		else:
			for u in melee:
				if u.order == "attack" and u.order_target == piece and piece.edge_distance(u.position) < 60.0:
					continue         # (already at it)
				_to_spot(u, stage, gap * 2.0)
			return
	# melee: the best wall-breakers to the face (a Brute before Raptors: the most damage on the
	# piece for the room it takes, for longest under fire), as many as fit; the rest wait at
	# the stage out of reach, holding there (not wandering up to the wall on their own)
	var arm := _piece_armor(piece, ground)
	var val := {}
	for u in melee:
		val[u] = _breaker_value(u, piece, arm)
	melee.sort_custom(func(a, b) -> bool:
		if absf(val[a] - val[b]) > 0.01:
			return val[a] > val[b]
		return a.position.distance_to(pc) < b.position.distance_to(pc))
	var cap: int = maxi(1, int(ceil(float(_siege["cap"]) * 1.15)))
	# a few seconds before the piece falls the reserve moves up to the edge of the defenders'
	# reach, so the whole lot goes through the gap together, not in a trickle from the stage
	var now := game.clock
	if _siege.has("hp_at"):
		var dt: float = now - float(_siege["hp_at"])
		if dt > 0.1:
			var rate: float = (float(_siege["hp_was"]) - piece.hp) / dt
			_siege["rate"] = lerpf(float(_siege.get("rate", rate)), rate, 0.5)
	_siege["hp_at"] = now
	_siege["hp_was"] = piece.hp
	var rate_now: float = float(_siege.get("rate", 0.0))
	var close_in: bool = rate_now > 1.0 and piece.hp / rate_now < 3.0
	var near_pt: Vector2 = _flood_point(flood, pc + out * maxf(float(_siege.get("mreach", 50.0)) + 20.0, 60.0), stage)
	# the chosen ones not at the face yet leave room for those already hacking there
	var spare := 0
	for i in mini(cap, melee.size()):
		if piece.edge_distance(melee[i].position) > 50.0:
			spare += 1
	for i in melee.size():
		var u: Unit = melee[i]
		if i < cap:
			if not (u.order == "attack" and u.order_target == piece):
				u.cmd_attack(piece)
			continue
		if u.order == "attack" and u.order_target == piece and piece.edge_distance(u.position) < 40.0 and spare > 0:
			spare -= 1
			continue                 # (keeps its place until a better breaker gets there)
		_to_spot(u, near_pt if close_in else stage, gap * (1.0 if close_in else 2.0))


## A siege's shooter (a Springer, a Netter, a Spitter...): what to shoot instead of the piece, from where it stands (it does
## not walk after it up the ramp): an enemy worker mending a wall piece (or standing by this one, about to), then an
## enemy shooter on the edge in reach; none: the piece. Only what this side sees (the men at the face see over it).
## `aimed`: shooters already on each one (a Labourer dies to about five screws: the next shooter takes another one).
func _siege_prey(u: Unit, piece: Building, aimed: Dictionary) -> Unit:
	var reach: float = u._range() + u.radius - 2.0
	var best: Unit = null
	var bs := INF
	for o in game.units_near(u.position, reach + 24.0):
		if o.dead or o.off_field or o.is_air() or not game.hostile(o.team, team) or not u.can_hit(o) or o.untouchable():
			continue
		if o.edge_distance(u.position) > reach or not game.is_visible_to(team, o.position):
			continue
		var score := INF
		if o.is_worker():
			var mending: bool = o.order == "repair" and is_instance_valid(o.order_target) and _is_piece(o.order_target)
			if mending or piece.edge_distance(o.position) < 70.0:
				score = 0.0 if mending else 1.0
		elif float(o.d.get("range", 0.0)) >= 100.0 and o.has_attack():
			score = 3.0
		if score == INF:
			continue
		# (the most hurt first among the same kind; spread once a target has enough shooters on it)
		var n: int = int(aimed.get(o, 0))
		score += o.hp / maxf(1.0, o.max_hp) * 0.5 + (1.5 if n * 9.0 >= o.hp else 0.0) + o.position.distance_to(u.position) * 0.001
		if score < bs:
			bs = score
			best = o
	return best


## A Springer that has leapt up: once landed, it shoots the workers there first (then the shooters), from where it stands.
func _leapt_fight(u: Unit) -> void:
	u.siege_t = 0.0
	if not u.jump.is_empty() or u.phase != "":
		return
	var best: Unit = null
	var bs := INF
	for o in game.units_near(u.position, u._range() + 40.0):
		if o.dead or o.off_field or o.is_air() or not game.hostile(o.team, team) or not u.can_hit(o):
			continue
		var sc: float = o.position.distance_to(u.position) + (0.0 if o.is_worker() else (150.0 if float(o.d.get("range", 0.0)) >= 100.0 else 300.0))
		if sc < bs:
			bs = sc
			best = o
	if best != null and not (u.order == "attack" and u.order_target == best):
		u.cmd_attack(best)


## Waiting in a siege's reserve: walk to the spot, then hold there (a unit left idle would go
## for the wall by itself, into the defenders' fire).
## (They spread along the wall and back from it, never forward of the spot: into reach.)
func _to_spot(u: Unit, pt: Vector2, spread: float) -> void:
	# (an enemy that came out to it, close by on its own side of the wall: it fights, it does not stand and take it;
	# 0.14.73 Frostmere: a reserve held at its stage while the Crown's army shot it down, 24 lost for none)
	if u.has_attack():
		if u.order == "attack" and is_instance_valid(u.order_target) and u.order_target is Unit and not u.order_target.dead \
				and u.order_target.position.distance_to(u.position) < 220.0:
			return
		for o in game.units_near(u.position, 150.0):
			if o.dead or o.off_field or o.is_air() or not game.hostile(o.team, team) or not _armed(o) or not u.can_hit(o):
				continue
			if game.level_of(o.position) == game.level_of(u.position) and game.line_clear(u.position, o.center()):
				u.cmd_attack(o)
				return
	var out: Vector2 = _siege.get("out", Vector2.ZERO)
	var off := u.position - pt
	if off.length() < spread * 1.5 + 16.0 and off.dot(out) > -16.0:
		if u.order != "hold" and u.order != "move":
			u.cmd_hold()
		return
	if u.order != "move" or u.order_point.distance_to(pt) > spread * 1.5 + 10.0:
		var side := out.orthogonal()
		var p := pt + side * randf_range(-1.4, 1.4) * spread + out * randf_range(0.0, 1.0) * spread
		u.cmd_move(_flood_point(_siege["flood"], p, pt) if _siege.has("flood") else p)


## The piece's armour against this army (Spitter acid strips 2).
func _piece_armor(piece: Building, ground: Array) -> float:
	for u in ground:
		if u.kind == "spitter" and u.can_hit(piece):
			return maxf(0.0, piece.armor - 2.0)
	return piece.armor


## How good a wall-breaker a melee unit is: damage on the piece per second, for the room it
## takes at the face, for how long it lasts there (canister shreds light troops).
func _breaker_value(u: Unit, piece: Building, arm: float) -> float:
	var dmg := float(u.d["damage"]) * float(u.d.get("building_bonus", 1.0))
	var wd := maxf(1.0, dmg - arm) / _cycle(u)
	var side: float = u.radius * 2.0 + 4.0
	var lasts: float = u.hp / (float(Defs.CANISTER["vs_light"]) if u.has_tag("light") else 1.0)
	return wd * lasts / (side * side)


## A firing spot for a ranged unit: in its range of the piece, off the lane the melee walk up
## (straight out from the piece), apart from the others' spots, on ground it can reach.
func _ranged_spot(u: Unit, piece: Building, out: Vector2, flood: PackedByteArray, spots: Dictionary, gap: float) -> Vector2:
	var pc := piece.center()
	var rng: float = u._range()
	var lo: float = maxf(float(u.d.get("min_range", 0.0)) + 24.0, minf(70.0, rng * 0.6))
	var want: float = clampf(rng * 0.85, lo, rng - 10.0)
	var r := int(ceil(rng / Defs.TILE)) + 1
	var best := u.position
	var bs := INF
	var side := out.orthogonal()
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var c: Vector2i = piece.cell + Vector2i(dx, dy)
			if not game.in_map(c) or flood[game.idx(c)] == 0:
				continue
			var p: Vector2 = game.cell_center(c)
			var e: float = piece.edge_distance(p)
			if e > rng - 10.0 or e < lo:
				continue
			var v := p - pc
			var s := absf(e - want) * 0.5 + p.distance_to(u.position) * 0.15
			if v.dot(out) > 0.0 and absf(v.dot(side)) < 52.0:
				s += 200.0           # the melee lane
			for o in spots:
				if is_instance_valid(o) and o != u and (spots[o] as Vector2).distance_to(p) < gap:
					s += 150.0
			if s < bs:
				bs = s
				best = p
	return best + Vector2(randf_range(-6, 6), randf_range(-6, 6))


## Gear mode, Normal and up: Springers JUMP UP onto the high ground (HIGH LEAP: Springer.landing) when that wins: a few of the
## wave's ready Springers below a cliff or a walled ramp, enemy workers or shooters on the high ground just past it (seen by
## our side), a landing spot within the jump where the armed enemies close by are worth less than the Springers that land
## (Musketeers in numbers there: no jump, the Springers would only die). Once up they shoot the workers first (_leapt: the
## siege leaves them be for a while). A leap is visible (the crouch) and costs the spring 10 s (design_principles 1).
var _leapt := {}               # Springer -> clock when it leapt up (the siege's orders leave it be for LEAP_HOLD s)
const LEAP_HOLD := 14.0
var _leap_t := 0.0


func _springer_leaps(wave: Array) -> void:
	if difficulty < 1 or not game.has_tech(team, "high_leap") or game.clock < _leap_t:
		return
	_leap_t = game.clock + 1.5
	for u in _leapt.keys():
		if not is_instance_valid(u) or u.dead or game.clock - float(_leapt[u]) > LEAP_HOLD:
			_leapt.erase(u)
	var ready: Array = wave.filter(func(u) -> bool: return is_instance_valid(u) and not u.dead and u.kind == Defs.SPRINGER \
			and not _leapt.has(u) and Springer.ready_problem(u) == "" and not game.on_high(u.position) and u.hp > u.max_hp * 0.5)
	if ready.size() < 2:
		return
	# the prey: enemy workers and shooters on the high ground that our side sees, within a jump and a shot of a Springer
	var reach := float(Defs.SPRINGER_JUMP["range"]) + float(Defs.UNITS[Defs.SPRINGER]["range"]) * 0.7
	var best_p := Vector2.INF
	var best_s := 0.0
	var best_w := false
	var seen := {}
	for j in ready:
		for o in game.units_near(j.position, reach):
			if seen.has(o) or o.dead or o.off_field or o.is_air() or not game.hostile(o.team, team) or not game.on_high(o.position):
				continue
			seen[o] = true
			if not game.is_visible_to(team, o.position):
				continue
			var w := 0.0
			if o.is_worker():
				w = 2.0 if o.order == "repair" else 1.0
			elif float(o.d.get("range", 0.0)) >= 100.0:
				w = 1.0
			if w > best_s:
				best_s = w
				best_p = o.position
				best_w = o.is_worker()
	if best_p == Vector2.INF:
		return
	# the jumpers: the ready Springers within a jump of a landing spot by the prey
	var group: Array = ready.filter(func(j: Unit) -> bool: return j.position.distance_to(best_p) < reach)
	if group.size() < 2:
		return
	var c := Vector2.ZERO
	for j in group:
		c += j.position
	c /= group.size()
	var land := best_p + (c - best_p).normalized() * 60.0          # (just short of the prey, on its side of the cliff)
	var mine := 0.0
	for j in group:
		mine += _unit_value(j)
	var theirs := 0.0
	for o in game.units_near(land, 230.0):
		if not o.dead and game.hostile(o.team, team) and _armed(o) and not o.off_field:
			theirs += _unit_value(o)
	if theirs * 1.1 > mine:
		return              # (it would not win up there)
	var n := 0
	for j in group:
		var l: Dictionary = Springer.landing(j, land + Vector2(randf_range(-24, 24), randf_range(-24, 24)))
		if l.has("at") and game.on_high(l["at"]):
			Springer.start(j, l["at"])
			_leapt[j] = game.clock
			j.siege_t = 0.0
			n += 1
	if n > 0 and game.mlog:
		game.mlog.add("%s's Springers leap up onto the high ground (%d of them, %s there; %d value of armed enemies near)" % [game.mlog.who(team), n,
			"workers" if best_w else "shooters", int(theirs)])


## Clockwork: Winders walk behind the army and repair it (they repair whatever is hurt near them on their own when
## they stop). GEAR MODE (the owner, 2026-10-27: "it brings workers to the battlefield"): a Clock Soldier, a Pendulum,
## a Springer... runs down in ~80 s off its gear ground and stands still, and only a Winder winds it up again out there, so
## the Winders go WITH the army wherever it is (the rally, the attack): about one for every five constructs (at least
## two, at most a third of the workers and 10), and they WIND first (run-down ones, then the lowest), repair second.
## Run-down constructs left behind on the way are fetched too while no enemy stands near them. (The Crate drop instead of
## building is the Clockwork's side of this: its workers are the ones that die in the field.)
func _follow_with_escort(army: Array) -> void:
	if army.is_empty():
		return
	var c := Vector2.ZERO
	for u in army:
		c += u.position
	c /= army.size()
	var gear := Defs.gear_mode
	var tins := army.filter(func(o: Unit) -> bool: return o.runs_on_spring()).size()
	var want := 2 + mini(tins / 6, 3)
	if gear:
		want = _escort_want(army)
	_escort = _escort.filter(func(u) -> bool: return is_instance_valid(u) and not u.dead)
	while _escort.size() < want:
		var pick: Unit = null
		var pd := INF
		for u in game.workers(team):
			if _escort.has(u) or u.order == "build" or u.crate_site != null or (scout != null and scout.is_scout(u)) or _fled.has(u):
				continue
			# (the nearest free hand; one already idle first)
			var dd: float = u.position.distance_to(c) - (100000.0 if u.order == "idle" else 0.0)
			if dd < pd:
				pd = dd
				pick = u
		if pick == null:
			break
		_escort.append(pick)
	if gear:
		_ballista_crew(army)
		_great_winder_follow(c)
		_escort_wind(army, c)
		return
	# run-down Wind-up Soldiers first: the escort cranks them back up
	var down: Array = game.units.filter(func(o: Unit) -> bool: return o.team == team and not o.dead and o.runs_on_spring() and o.powered_down())
	for u in _escort:
		if u.order == "repair":
			continue
		var crank: Unit = null
		var cd := 700.0
		for o in down:
			var dd: float = o.position.distance_to(u.position)
			if dd < cd and not game.units.any(func(x: Unit) -> bool: return x != u and x.order == "repair" and x.order_target == o):
				cd = dd
				crank = o
		if crank:
			u.cmd_repair(crank)
			down.erase(crank)
			continue
		if u.position.distance_to(c) > 140.0:
			u.cmd_move(c + Vector2(randf_range(-40, 40), randf_range(-40, 40)))


## Gear mode: how many Winders go with this army: one for every five constructs that run down (not the flyers), at
## least two, at most a third of the workers (the economy keeps the rest) and ten.
func _escort_want(army: Array) -> int:
	var cons := 0
	for u in army:
		if not u.is_worker() and not u.is_air() and String(u.d["faction"]) == "clockwork" and u.kind != Defs.GREAT_WINDER_KIND:
			cons += 1
	if cons == 0:
		return 0
	var cap := mini(10, maxi(2, game.workers(team).size() / 3))
	var bal := army.filter(func(u: Unit) -> bool: return u.kind == Defs.BALLISTA_KIND).size()
	return _great_winder_escort(clampi(2 + cons / 5, 2, cap)) + mini(bal, 2) * BALLISTA_CREW      # (+ the Ballistas' crew: _ballista_crew)


## Gear mode: each free escort Winder winds (cmd_repair: wind first, then mends) the construct that needs it most
## within reach: a run-down one first (anywhere within ~14 tiles of the army, with no enemy beside it), then the
## lowest under half wind, then a badly hurt one; with nothing to do it keeps just behind the army (toward home).
func _escort_wind(army: Array, c: Vector2) -> void:
	var need: Array = []          # [score, unit]: lower is more urgent
	var taken := {}
	for x in _escort:
		if x.order == "repair" and is_instance_valid(x.order_target):
			taken[x.order_target] = true
	for o in game.units:
		if o.team != team or o.dead or o.off_field or o.is_worker() or o.is_air() or String(o.d["faction"]) != "clockwork" or taken.has(o):
			continue
		var dc: float = o.position.distance_to(c)
		var score := INF
		if o.powered_down() or (o.wind < 0.2 and not o._in_field):
			if dc < 900.0 and not _enemy_near(o.position, 260.0):
				score = (0.0 if o.powered_down() else 0.5) + dc * 0.0001
		elif dc < 420.0:
			if o.wind < 0.45 and not o._in_field:
				score = 1.0 + o.wind
			elif o.hp < o.max_hp * 0.5:
				score = 2.0 + o.hp / maxf(1.0, o.max_hp)
		if score < INF:
			need.append([score, o])
	need.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var home := c
	var hall: Array = _halls()
	if not hall.is_empty():
		home = (hall[0] as Building).center()
	var behind := c + (home - c).normalized() * 70.0 if home.distance_to(c) > 1.0 else c
	for u in _escort:
		if u.order == "repair" and is_instance_valid(u.order_target) and not u.order_target.dead:
			continue
		if u.crew_of != null or u.order == "board":
			continue          # (crewing a Spring Ballista, or on his way to: _ballista_crew)
		var best: Unit = null
		var bi := -1
		var bd := INF
		# (the most urgent first; among those as urgent, the nearest)
		for i in need.size():
			var o: Unit = need[i][1]
			var d: float = float(need[i][0]) * 10000.0 + o.position.distance_to(u.position)
			if d < bd:
				bd = d
				best = o
				bi = i
		if best and u.can_repair(best):
			u.cmd_repair(best)
			need.remove_at(bi)
			continue
		if u.position.distance_to(behind) > 120.0:
			u.cmd_move(behind + Vector2(randf_range(-40, 40), randf_range(-40, 40)))


## Gear mode, the SPRING BALLISTA (scripts/ballista.gd), kept small and in its own functions (the clockwork-ai rework
## edits the rest): once its Escapement works, a couple of Ballistas with the army (_produce), more when the enemy shows
## ARMOUR (armoured units seen now, remembered 120 s) or WALLS and GATES; they pick their own targets (armour, gates,
## lines: Ballista.pick; _micro leaves them to it); the escort Winders crew them, BALLISTA_CREW each (the first two).
const BALLISTA_CREW := 2
var _armour_seen := 0
var _armour_seen_t := -999.0


func _ballista_want() -> int:
	if not game.has_working(team, Defs.CW_TECH):
		return 0
	var n := 0
	var walls := false
	for u in game.units:
		if not u.dead and not u.off_field and not u.is_air() and u.has_tag("armored") and game.hostile(u.team, team) \
				and game.side_sees(team, u.position):
			n += 1
	if n > 0:
		_armour_seen = maxi(n, _armour_seen if game.clock - _armour_seen_t < 120.0 else 0)
		_armour_seen_t = game.clock
	elif game.clock - _armour_seen_t > 120.0:
		_armour_seen = 0
	for b in game.buildings:
		if (b.kind == "wall" or b.kind == "gate") and not b.dead and game.hostile(b.team, team) and game.side_sees(team, b.center()):
			walls = true
			break
	return 1 + (1 if _armour_seen >= 2 or walls else 0) + (1 if _armour_seen >= 6 else 0)


## The escort Winders crew the army's Ballistas (Ballista.ai_crew: the nearest free escort men, BALLISTA_CREW each).
func _ballista_crew(army: Array) -> void:
	var bs: Array = army.filter(func(u: Unit) -> bool: return u.kind == Defs.BALLISTA_KIND)
	if bs.is_empty():
		return
	var sent := Ballista.ai_crew(bs, _escort, BALLISTA_CREW)
	if not sent.is_empty() and game.mlog and not game._first_of.has("%d:ai_bal_crew" % team):
		game._first_of["%d:ai_bal_crew" % team] = true
		game.mlog.add("%s sends %d Winders to crew its Spring Ballista" % [game.mlog.who(team), sent.size()])


## Gear mode, the GREAT WINDER (scripts/great_winder.gd), kept small and in its own functions (the clockwork-ai rework
## edits the rest): once its Escapement works and the army has GREAT_WINDER_ARMY soldiers (after the Pendulums, Ballistas
## and Netters it wants: the escort Winders do the winding until then), ONE Great Winder (_produce:
## _great_winder_due); it walks just behind the army wherever the army goes (_great_winder_follow: the attack, the
## rally), where its area keeps the army wound and it mends and sweeps by itself (its autocasts). It TAKES THE ESCORT'S
## PLACE (the owner, 2026-10-27): while one is out, the escort of ordinary Winders is GREAT_WINDER_ESCORT smaller for
## each, down to one Winder (for the stragglers run down outside its area); the Ballistas' crew are extra, as before.
const GREAT_WINDER_ARMY := 4
const GREAT_WINDER_ESCORT := 3


## Make a Great Winder at this Works now? None yet (nor queued), its Escapement works, enough army, the Tension.
func _great_winder_due(w: Building, have: int, others: int, keep: float) -> bool:
	return have < 1 and others >= GREAT_WINDER_ARMY and game.has_working(team, Defs.CW_TECH) \
			and game.tension(team) - float(Defs.tension_cost(Defs.UNITS[Defs.GREAT_WINDER_KIND])) >= keep \
			and game.can_train(w, Defs.GREAT_WINDER_KIND) == ""


## Our Great Winders.
func _great_winders() -> Array:
	return game.units.filter(func(u: Unit) -> bool: return u.team == team and not u.dead and u.kind == Defs.GREAT_WINDER_KIND)


## The escort's base size (`base` Winders) less GREAT_WINDER_ESCORT for each Great Winder we have, at least one.
func _great_winder_escort(base: int) -> int:
	var n := _great_winders().size()
	if n == 0:
		return base
	return maxi(1, base - GREAT_WINDER_ESCORT * n)


## Each Great Winder walks to a spot just behind the army (toward home), unless it is mending or sweeping there.
func _great_winder_follow(c: Vector2) -> void:
	var gws := _great_winders()
	if gws.is_empty():
		return
	var home := c
	var hall: Array = _halls()
	if not hall.is_empty():
		home = (hall[0] as Building).center()
	var behind := c + (home - c).normalized() * 60.0 if home.distance_to(c) > 1.0 else c
	for u in gws:
		if u.order == "mend" or u.order == "sweep":
			if u.position.distance_to(c) < 420.0:
				continue          # (busy by the army: its autocast)
		if u.position.distance_to(behind) > 110.0 and not (u.order == "move" and u.order_point.distance_to(behind) < 90.0):
			u.cmd_move(behind)
			if game.mlog and not game._first_of.has("%d:ai_gw_out" % team):
				game._first_of["%d:ai_gw_out" % team] = true
				game.mlog.add("%s sends its Great Winder with the army" % game.mlog.who(team))


## An enemy (not a worker) within r of p.
func _enemy_near(p: Vector2, r: float) -> bool:
	for o in game.units_near(p, r):
		if not o.dead and game.hostile(o.team, team) and not o.is_worker():
			return true
	return false


func _release_escort() -> void:
	for u in _escort:
		if is_instance_valid(u) and not u.dead:
			u.cmd_stop()
	_escort.clear()


## Every place our buildings are under attack (one spot per raid, at least 300 px apart).
## Can this soldier hit a flyer at all (anti-air men, the cannon's canister)?
func _hits_air(u: Unit) -> bool:
	return bool(u.d.get("anti_air", false)) or u.kind == "cannon"


# ---- sized defence: commit only what beats the enemy at the spot, with a leash ----
## Margins and limits (design principles 1 and 2: a decoy must not cost the whole army, a lost
## fight is reinforced, a real attack gets a full answer in proportion to what is seen).
const DEF_MARGIN := 1.5         # real attack: send this much value per value seen
const DEF_MARGIN_GUNS := 1.2    # ... times this more when the enemy brought artillery
const DEF_UNSEEN := 300.0       # a threat we cannot see (guns shelling from the dark) counts as this much
const LONE_CAP := 4             # the most soldiers a lone fast raider ever draws
const LONE_CAP_SCOUT := 2       # ... and an unarmed scout
const LONE_MIN := 0.5           # the catchers must be worth this share of the raider, else it is ignored
const LONE_LEASH := 380.0       # a detachment gives up this far from our nearest building
const LONE_TIME := 25.0         # ... or after this many seconds
const LONE_COOL := 30.0         # then the same kind of raider is ignored for this long
const REAL_LEASH := 700.0
const HOME_AREA := 260.0        # within this of one of our buildings is "our own area"
const FAST_SPEED := 95.0        # an enemy this quick (horseman, scout, raptor) is a raider, not an army

var _det: Dictionary = {}       # Unit -> {"spot": Vector2, "t0": float, "lone": bool}: the detachments out
var _lone_cool := 0.0
var _known_foes: Dictionary = {}   # enemy unit id -> clock it was last seen (the hands that pulled back no longer watch it)
var _known_guns: Dictionary = {}   # enemy artillery seen (instance id -> {"u": Unit, "p": Vector2, "t": float})


func _unit_value(u: Unit) -> float:
	var v: float = float(u.d.get("cost", 50)) / maxf(1.0, float(u.d.get("spawn", 1))) + float(u.d.get("cost2", 0)) * 0.5
	return v * (0.4 + 0.6 * clampf(u.hp / maxf(1.0, u.max_hp), 0.0, 1.0))


func _armed(u: Unit) -> bool:
	return not u.is_worker() and (u.has_attack() or Defs.MUSKETS.has(u.kind))


func _is_gun(u: Unit) -> bool:
	return u.kind in ["cannon", "mortar", "spore_mother"] or (u.kind == "tesla_cart" and u.tesla_mode == "deployed")


## The visible enemies around a raid spot, as numbers.
func _assess(spot: Vector2) -> Dictionary:
	var foes: Array = game.units_near(spot, 300.0).filter(func(o: Unit) -> bool: return game.hostile(o.team, team) and not o.dead and not o.off_field)
	var seen: Array = foes.filter(func(o: Unit) -> bool: return _sighted(o))
	var armed: Array = seen.filter(func(o: Unit) -> bool: return _armed(o))
	var a := {"spot": spot, "value": 0.0, "count": armed.size(), "lone": false, "speed": 0.0, "guns": false,
		"air_only": not foes.is_empty() and foes.all(func(o: Unit) -> bool: return o.is_air()), "unarmed": false}
	if seen.is_empty():
		a["value"] = DEF_UNSEEN
		a["count"] = 3
		return a
	for o in armed:
		a["value"] += _unit_value(o)
		a["speed"] = maxf(a["speed"], float(o.d.get("speed", 60)))
		if _is_gun(o):
			a["guns"] = true
	for o in seen:
		if not _armed(o):
			a["speed"] = maxf(a["speed"], float(o.d.get("speed", 60)))
	a["unarmed"] = armed.is_empty()
	a["lone"] = armed.size() <= 2 and armed.all(func(o: Unit) -> bool: return float(o.d.get("speed", 60)) >= FAST_SPEED)
	return a


## Seen right now, or a moment ago (out of sight is not gone: the hands that ran from a raid
## no longer watch it, which must not make an army look like nothing, or a scout like an army).
func _sighted(o: Unit) -> bool:
	if game.is_visible_to(team, o.position):
		_known_foes[o.get_instance_id()] = game.clock
		return true
	return game.clock - float(_known_foes.get(o.get_instance_id(), -100.0)) < 20.0


func _home_dist(p: Vector2) -> float:
	var best := INF
	for b in game.buildings:
		if b.team == team and not b.dead and not b.ghost:
			best = minf(best, b.center().distance_to(p))
	return best


## Enemy artillery we have seen lately (a limbered gun on the move does not count).
func _note_guns() -> void:
	for id in _known_guns.keys():
		var e: Dictionary = _known_guns[id]
		if not is_instance_valid(e["u"]) or e["u"].dead or game.clock - float(e["t"]) > 90.0:
			_known_guns.erase(id)
	for o in game.units:
		if o.team != team and game.hostile(o.team, team) and not o.dead and _is_gun(o) and o.order == "idle" and game.is_visible_to(team, o.position):
			_known_guns[o.get_instance_id()] = {"u": o, "p": o.position, "t": game.clock}


## Is this ground, outside our own area, under a known enemy gun?
func _gun_danger(p: Vector2) -> bool:
	if _home_dist(p) <= HOME_AREA:
		return false
	for id in _known_guns:
		var e: Dictionary = _known_guns[id]
		if p.distance_to(e["p"]) < float(e["u"].d.get("range", 200)) + 40.0:
			return true
	return false


func _post_spot() -> Vector2:
	var hall: Array = _halls()
	if hall.is_empty():
		return Vector2.INF
	return _home_spot(_rally_front(hall[0]))


func _release(u: Unit, lone: bool) -> void:
	_det.erase(u)
	if lone:
		_lone_cool = game.clock + LONE_COOL
	if is_instance_valid(u) and not u.dead and not _attacking:
		var post := _post_spot()
		if post != Vector2.INF:
			u.cmd_move(post, true)


## The threat is over: the detachments walk home.
func _end_defence() -> void:
	for u in _det.keys():
		_release(u, false)
	_det.clear()


## Answer each raid in proportion: commit enough soldiers to beat what is visible there (more
## when the fight turns), keep the rest at the post. A lone fast raider draws a few catchers
## on a leash (or nobody); nothing is chased into known guns outside our own area.
func _defend(army: Array, threat: Vector2, spots: Array) -> void:
	_note_guns()
	if spots.is_empty():
		spots = [threat]
	# (round 5, Clockwork: riders at the Winders draw a group of Clock Soldiers to the Winders, not a chase)
	var by_r5: Array = r5.guard_workers(army, spots)
	if not by_r5.is_empty():
		spots = spots.filter(func(sp: Vector2) -> bool: return not by_r5.has(sp))
		army = army.filter(func(u: Unit) -> bool: return not r5.busy(u))
	var asses: Array = []
	for sp in spots:
		asses.append(_assess(sp))
	asses.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["value"] > b["value"])
	# detachments already out: follow the raid they were sent to, or give up
	for u in _det.keys():
		var e: Dictionary = _det[u]
		if not is_instance_valid(u) or u.dead:
			if e["lone"]:
				_lone_cool = game.clock + LONE_COOL    # the raider eats detachments: stop feeding it
			_det.erase(u)
			continue
		var a: Dictionary = {}
		for x in asses:
			if (x["spot"] as Vector2).distance_to(e["spot"]) < 350.0:
				a = x
				break
		var lone: bool = e["lone"]
		if a.is_empty():
			_release(u, false)
			continue
		var far: float = _home_dist(u.position)
		if lone and (far > LONE_LEASH or game.clock - float(e["t0"]) > LONE_TIME) or far > REAL_LEASH or _gun_danger(u.position) or _horse_leash(u, far):
			_release(u, lone)
			continue
		e["spot"] = a["spot"]
		if u.order == "idle" and u.target == null:
			u.cmd_move(a["spot"] + Vector2(randf_range(-30, 30), randf_range(-30, 30)), true)
	for a in asses:
		var spot: Vector2 = a["spot"]
		if _gun_danger(spot):
			continue
		var lone: bool = a["lone"]
		if lone and brood != null and brood.raid_party(spot):
			lone = false        # (Brood: two Horsemen hunting the grubs are a raid, not a lone rider: the Raptors answer as a pack)
		if lone and game.clock < _lone_cool:
			continue
		var committed := 0.0
		var committed_n := 0
		var mine: Dictionary = {}
		for u in army:
			if _det.has(u) and (_det[u]["spot"] as Vector2).distance_to(spot) < 350.0 or u.position.distance_to(spot) < 350.0 and u.order == "attack":
				mine[u] = true
				committed += _unit_value(u)
				committed_n += 1
		var need: float = float(a["value"]) * (1.0 if lone else DEF_MARGIN * (DEF_MARGIN_GUNS if a["guns"] else 1.0))
		var cap := 999
		if lone:
			cap = LONE_CAP_SCOUT if a["unarmed"] else LONE_CAP
			if a["unarmed"]:
				need = 1.0
		if committed >= need and committed_n > 0 or committed_n >= cap:
			continue
		var pool: Array = []
		for u in army:
			if mine.has(u) or _det.has(u) or u.order == "attack" or not (u.target == null or u.order == "idle"):
				continue
			if a["air_only"] and not _hits_air(u):
				continue
			if lone and float(u.d.get("speed", 60)) < float(a["speed"]) * 0.85 and not (a["air_only"] and float(u.d.get("range", 0)) >= 130.0):
				continue     # only men who can catch it (or shoot a flyer from where they stand)
			pool.append(u)
		pool.sort_custom(func(x: Unit, y: Unit) -> bool: return x.position.distance_to(spot) < y.position.distance_to(spot))
		var picks: Array = []
		var got := committed
		for u in pool:
			if got >= need and (committed_n + picks.size()) > 0 or committed_n + picks.size() >= cap:
				break
			picks.append(u)
			got += _unit_value(u)
		if lone and not a["unarmed"] and committed_n + picks.size() > 0 and got < float(a["value"]) * LONE_MIN:
			continue     # nobody fast enough that is worth sending: it is ignored
		for u in picks:
			_det[u] = {"spot": spot, "t0": game.clock, "lone": lone}
			u.cmd_move(spot + Vector2(randf_range(-30, 30), randf_range(-30, 30)), true)



func _threats() -> Array:
	var out: Array = []
	for b in game.buildings:
		if b.team != team or b.dead:
			continue
		for u in game.units_near(b.center(), 330.0):
			if game.hostile(u.team, team) and not u.dead and not u.off_field:
				if out.all(func(p: Vector2) -> bool: return p.distance_to(u.position) > 300.0):
					out.append(u.position)
				break
	return out


func _threat() -> Vector2:
	for b in game.buildings:
		if b.team != team or b.dead:
			continue
		for u in game.units_near(b.center(), 330.0):
			if game.hostile(u.team, team) and not u.dead and not u.off_field:
				return u.position
	return Vector2.INF


## Which enemy to go after: the nearest one; Brutal hunts the human player first.
func _foe() -> int:
	var foes := game.enemies_of(team)
	if foes.is_empty():
		return -1
	if difficulty >= 3 and not game.demo and foes.has(game.human):
		return game.human
	var me := game.center_of_team(team)
	var best: int = foes[0]
	var bd := INF
	for f in foes:
		var dd: float = game.center_of_team(f).distance_to(me)
		if dd < bd:
			bd = dd
			best = f
	return best


func _enemy_base() -> Vector2:
	var enemy := _foe()
	if enemy < 0:
		return game.center_of_team(team)
	if _clock() and Defs.gear_mode and difficulty >= 1 and open_targets_on:
		var open := _open_target(enemy)
		if open != Vector2.INF:
			return open
	var best := Vector2.INF
	var bd := INF
	var me := game.center_of_team(team)
	# go for the economy: the enemy's nearest hall (its workers and farms are around it);
	# the army fights whatever is in the way on the walk there. A hall walled too strongly
	# for the last wave is left be for a while, if there's another one.
	var open_hall := false
	for b in game.buildings:
		if b.team == enemy and not b.dead and not b.ghost and b.kind == game.faction_hall(enemy) and float(_walled_halls.get(b, 0.0)) <= game.clock:
			open_hall = true
	for b in game.buildings:
		if b.team == enemy and not b.dead and not b.ghost and b.kind == game.faction_hall(enemy):
			if open_hall and float(_walled_halls.get(b, 0.0)) > game.clock:
				continue
			var dd: float = b.center().distance_to(me)
			if dd < bd:
				bd = dd
				best = b.center()
	if best != Vector2.INF:
		return best
	for b in game.buildings:
		if b.team == enemy and not b.dead and not b.ghost:
			var dd: float = b.center().distance_to(me)
			if dd < bd:
				bd = dd
				best = b.center()
	if best == Vector2.INF:
		return Vector2(game.starts[enemy]) * Defs.TILE
	return best


## Gear mode's Clockwork (Normal and up): a target it can walk up to without breaking a wall: the enemy's expansion, its
## farms and outlying buildings outside the walls (a walled main with Musketeers on the high ground is the last thing to
## go for: the 0.14.72 games lost wave after wave at the ramp while the Crown's new Town Hall stood open). The nearest
## to our base, a hall or an economy building first; INF when everything is behind a wall (then the main and the
## siege). Worked out every 10 s.
var open_targets_on := true    # (experiments switch it off: tools/shot_ai_match.gd noopen:1, every wave goes for the main)
var _open_t := -99.0
var _open_at := Vector2.INF
var _open_b: Building = null


func _open_target(enemy: int) -> Vector2:
	if _open_b != null and is_instance_valid(_open_b) and not _open_b.dead and game.clock - _open_t < 10.0:
		return _open_at
	if game.clock - _open_t < 10.0 and _open_b == null:
		return _open_at
	_open_t = game.clock
	_open_b = null
	_open_at = Vector2.INF
	var hall: Array = _halls()
	if hall.is_empty():
		return _open_at
	var from: Vector2i = game.cell_of(_front())
	if not game.in_map(from) or not _walkable(from, team):
		from = game.nearest_free(from, 4)
	var flood := _flood_from([from], team)
	var pieces: Array = []
	for b in game.buildings:
		if not b.dead and b.built and _is_piece(b) and game.hostile(b.team, team):
			pieces.append(b.center())
	var me: Vector2 = (hall[0] as Building).center()
	var best: Building = null
	var bs := INF
	for b in game.buildings:
		if b.team != enemy or b.dead or b.ghost or _is_piece(b):
			continue
		var bc: Vector2 = b.center()
		if pieces.any(func(p: Vector2) -> bool: return p.distance_to(bc) < 170.0):
			continue          # (part of the wall: the ramp Cottage)
		if not _reach_b(b, flood):
			continue
		if _bad_spots.keys().any(func(p: Vector2) -> bool: return float(_bad_spots[p]) > game.clock and p.distance_to(bc) < 500.0):
			continue          # (a wave just lost far more than it killed there: _losing_trade)
		if _overlooked(bc, flood):
			continue          # (under a walled plateau's guns: the siege of the main is weighed up instead)
		var score: float = bc.distance_to(me)
		if b.kind == game.faction_hall(enemy):
			score -= 600.0
		elif Defs.is_econ(b.kind):
			score -= 250.0
		if score < bs:
			bs = score
			best = b
	if best != null:
		_open_b = best
		_open_at = best.center()
	return _open_at


## Spot p lies under high ground we cannot walk onto (a walled plateau: its Musketeers and guns shoot down on whoever
## fights there): a walkable high-ground cell outside `flood` within COVER_R. (A Crown expansion right under its main's
## cliff drew wave after wave into the fire from above, 0.14.73 Greenhold.)
const COVER_R := 300.0


func _overlooked(p: Vector2, flood: PackedByteArray) -> bool:
	if game.on_high(p):
		return false
	var c0: Vector2i = game.cell_of(p)
	var r := int(COVER_R / Defs.TILE)
	for dy in range(-r, r + 1, 2):
		for dx in range(-r, r + 1, 2):
			if dx * dx + dy * dy > r * r:
				continue
			var c := c0 + Vector2i(dx, dy)
			if game.in_map(c) and game.height[game.idx(c)] == 1 and flood[game.idx(c)] == 0 and _walkable(c, -1):
				return true
	return false


## Some cell right beside building b is in `flood` (we can walk up to it).
func _reach_b(b: Building, flood: PackedByteArray) -> bool:
	var r: Rect2 = b.rect()
	var c0: Vector2i = game.cell_of(r.position) - Vector2i(1, 1)
	var c1: Vector2i = game.cell_of(r.end) + Vector2i(1, 1)
	for y in range(c0.y, c1.y + 1):
		for x in range(c0.x, c1.x + 1):
			if (y == c0.y or y == c1.y or x == c0.x or x == c1.x) and game.in_map(Vector2i(x, y)) and flood[game.idx(Vector2i(x, y))] == 1:
				return true
	return false


# ------------------------------------------------------------------ abilities (Normal and up)

## Canister when a crowd closes on a cannon. (Musketeers pick musket or bayonet by themselves.)
func _abilities() -> void:
	_spells()
	if _brood():
		_skywings()
		if brood != null:
			brood.offer()           # (offerings for the next tech creature when no bodies are coming: scripts/ai_brood.gd)
		else:
			_offer()
	if _clock():
		_overloads()
		_braces()
		ShieldWall.think(game, team)       # (Clock Soldiers: shields up in ranged fire, down to chase or fall back)
	if not _crown():
		return
	for u in game.army(team):
		if u.kind == "cannon":
			var crowd := 0
			var flyers := 0
			for o in game.units_near(u.position, Defs.CANISTER["range"] + 20.0):
				if game.hostile(o.team, team) and not o.dead:
					crowd += 1
					if o.is_air():
						flyers += 1
			u.set_canister(crowd >= 3 or flyers >= 1)
	_shell_bodies()


# ------------------------------------------------------------------ Crown vs Brood: shelling the bodies (Defs.BODY_BLAST)

## The owner's design (2026-10-26): when the Crown faces the Brood and nothing threatens its base, an idle cannon or mortar
## fires a few shots (BOMBARD) at a spot it can see where several bodies the Brood could harvest lie together (ground the
## Brood's grubs can walk to), away from our own men. Never mid-battle: no armed enemy in sight near the gun or the spot,
## and it stands down at once when one shows up or the base is attacked (or after `shots`, or when the bodies are gone).
const SHELL := {"min_bodies": 3, "shots": 3, "scan": 5.0, "clear": 420.0, "own_near": 64.0, "walk": 96.0, "max_t": 40.0}
var shell_bodies_on := true      # (tests switch it off to measure the ordinary splash alone)
var _shell := {}                 # gun -> {"p": the spot, "t": clock it began, "pw": its powder then}
var _shell_t := 0.0
var shell_log: Array = []        # [clock, gun kind, bodies at the spot] (tests, the match log)


func _vs_brood() -> bool:
	for f in game.enemies_of(team):
		if game.faction_of(f) == "brood" and not game.eliminated[f]:
			return true
	return false


## The radius a gun's shot tears bodies in (a Mortar's splash; a cannon: round shot's small splash, canister's reach).
func _blast_r(g: Unit) -> float:
	if g.kind == "cannon":
		return 60.0 if g.mode == "canister" else float(Defs.ROUND_SHOT["splash"]) + 6.0
	return float(g.d.get("splash", 40.0))


## The bodies the Brood could still harvest within r of p.
func _bodies_at(p: Vector2, r: float) -> int:
	var n := 0
	for c in game.corpses:
		if is_instance_valid(c) and not c.torn and c.position.distance_to(p) <= r:
			n += 1
	return n


## The walkable region at p (a body or a unit can lie on the edge of a cell that is not walkable: the nearest one that is).
func _region_at(p: Vector2) -> int:
	var c: Vector2i = game.cell_of(p)
	var r: int = game.region_of(c)
	if r >= 0:
		return r
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
		r = game.region_of(c + d)
		if r >= 0:
			return r
	return -1


## An armed enemy in sight (or seen a moment ago) within SHELL.clear of p.
func _foes_near(p: Vector2) -> bool:
	for o in game.units_near(p, float(SHELL["clear"])):
		if game.hostile(o.team, team) and not o.dead and not o.off_field and _armed(o) and _sighted(o):
			return true
	return false


func _shell_bodies() -> void:
	var calm := _threat() == Vector2.INF
	for g in game.army(team):
		if g.order == "bombard" and not _shell.has(g):
			_shell[g] = {"p": g.order_point, "t": game.clock, "pw": g.powder}     # (a game loaded with one at it)
	# the guns at it: they stand down when it is done, when it gets dangerous, or when something else ordered them
	for g in _shell.keys():
		var job: Dictionary = _shell[g]
		var done: bool = not is_instance_valid(g) or g.dead or g.order != "bombard" or (g.order_point as Vector2).distance_to(job["p"]) > 1.0
		if not done and (not calm or float(job["pw"]) - g.powder >= float(SHELL["shots"]) or g.powder < 1.0 \
				or game.clock - float(job["t"]) > float(SHELL["max_t"]) or _bodies_at(job["p"], _blast_r(g)) == 0 \
				or _foes_near(g.position) or _foes_near(job["p"])):
			g.cmd_stop()
			done = true
		if done:
			_shell.erase(g)
	if not calm or not shell_bodies_on or game.clock < _shell_t or not _vs_brood():
		return
	_shell_t = game.clock + float(SHELL["scan"])
	if game.corpses.size() < int(SHELL["min_bodies"]):
		return
	# where the Brood's ground units can walk: the regions they stand in
	var reach := {}
	for o in game.units:
		if not o.dead and game.hostile(o.team, team) and game.faction_of(o.team) == "brood" and not o.is_air():
			reach[_region_at(o.position)] = true
	for g in game.army(team):
		if not g.can_bombard() or _shell.has(g) or g.order != "idle" or g.target != null or g.phase != "" or g.powder < 2.0 \
				or (_attacking and _wave_set.has(g)):
			continue        # (busy, nearly dry, or out with the wave)
		var r := _blast_r(g)
		var far: float = g._range() + (float(SHELL["walk"]) if g.can_roll() else 0.0)
		var best := Vector2.INF
		var best_n := int(SHELL["min_bodies"]) - 1
		for c in game.corpses:
			if not is_instance_valid(c) or c.torn or c.position.distance_to(g.position) > far:
				continue
			if not game.is_visible_to(team, c.position) or not reach.has(_region_at(c.position)):
				continue
			var n := _bodies_at(c.position, r * 0.85)
			if n <= best_n:
				continue
			if _shell.values().any(func(j: Dictionary) -> bool: return (j["p"] as Vector2).distance_to(c.position) < r * 1.5):
				continue        # (another gun is on it)
			if game.units_near(c.position, float(SHELL["own_near"]) + r).any(func(o: Unit) -> bool: return not o.dead and game.allied(o.team, team) and not o.is_air()):
				continue        # (our own men would be hit)
			if _foes_near(c.position) or _foes_near(g.position):
				continue
			best = c.position
			best_n = n
		if best == Vector2.INF:
			continue
		g.cmd_bombard(best)
		_shell[g] = {"p": best, "t": game.clock, "pw": g.powder}
		shell_log.append([game.clock, g.kind, best_n])
		if game.mlog:
			game.mlog.add("%s's %s shells %d bodies so the Brood can't harvest them" % [game.mlog.who(team), g.d["name"], best_n])


## Stormcallers drop storms on packed enemies (not on our own men); Spore Mothers heal a
## hurt swarm in the middle of a fight.
func _spells() -> void:
	for u in game.army(team):
		# half the Bloaters keep their gas for big bursts (on walls and clumps)
		if u.kind == "bloater" and u.mode == "" and u.serial % 2 == 0:
			u.set_hold_gas(true)
		if u.order == "cast" or u.order == "tongue" or u.tongue_stage != "":
			continue
		if u.kind == "mist_toad":
			_toad(u)
		elif u.kind == "stormcaller" and u.charge >= float(Defs.STORM["cost"]):
			var best := Vector2.INF
			var score := 3.5 if difficulty >= 2 else 4.5
			var r: float = Defs.STORM["radius"]
			for e in game.units_near(u.position, float(Defs.STORM["range"]) + 60.0):
				if not game.hostile(e.team, team) or e.dead or e.off_field:
					continue
				var s := 0.0
				for o in game.units_near(e.position, r):
					if o.dead or o.off_field:
						continue
					if game.hostile(o.team, team):
						s += 1.0 + float(o.d["supply"]) * 0.25
					else:
						s -= 2.0
				if s > score:
					score = s
					best = e.position
			# the storm only stuns: worth it when our own army is there to hit them meanwhile
			if best != Vector2.INF and game.units_near(best, r + 160.0).any(func(f: Unit) -> bool: return f.team == team and not f.dead and not f.is_worker() and f.kind != "stormcaller" and f.position.distance_to(best) > r):
				u.cmd_cast("storm", best)
		elif u.kind == "spore_mother" and u.spell_cd <= 0.0 and _res2() >= float(Defs.MIASMA["cost2"]) + 10.0:
			var hurt := 0
			var at := Vector2.ZERO
			for o in game.units_near(u.position, float(Defs.MIASMA["range"])):
				if o.team == team and not o.dead and o.hp < o.max_hp * 0.65:
					hurt += 1
					at += o.position
			if hurt >= 4:
				u.cmd_cast("miasma", at / hurt)


## Mist Toad: TONGUE drags a high-value target (guns, casters, a Missionary) into the swarm,
## once our army is close enough to eat it; FOG goes down on an enemy firing line while our
## army is engaging it. It keeps the energy for a TONGUE when there's a prize about.
const TONGUE_PRIZES := ["cannon", "mortar", "stormcaller", "tesla_cart", "arc_thrower", "missionary", "spore_mother"]


func _toad(u: Unit) -> void:
	# (Toads share the work: one prize per tongue, one fog bank at a time)
	var taken := {}
	var fogging := false
	for o in game.army(team):
		if o.kind == "mist_toad" and o != u:
			if o.tongue_victim:
				taken[o.tongue_victim] = true
			if o.order == "tongue" and o.order_target:
				taken[o.order_target] = true
			if o.order == "cast":
				fogging = true
	var near: Array = game.units_near(u.position, float(Defs.TONGUE["range"]) + 120.0)
	var friends := 0
	for f in game.units_near(u.position, 220.0):
		if f.team == team and not f.dead and not f.is_worker() and f != u:
			friends += 1
	# TONGUE: the best prize in reach (round to it if it's just out of range)
	var prize: Unit = null
	var pv := 0.0
	for e in near:
		if not TONGUE_PRIZES.has(e.kind) or taken.has(e) or not u.can_tongue(e) or not game.side_sees(team, e.position):
			continue
		var dd: float = e.position.distance_to(u.position)
		var v := float(e.d["cost"]) + float(e.d.get("cost2", 0)) * 2.0 - dd * 0.3
		if v > pv:
			pv = v
			prize = e
	if prize and u.charge >= float(Defs.TONGUE["cost"]) and friends >= 3:
		u.cmd_tongue(prize)
		return
	# FOG: on the enemy's shooters, while our army is in the fight
	var keep := float(Defs.TONGUE["cost"]) if prize else 0.0
	if fogging or u.charge < float(Defs.FOG["cost"]) + keep:
		return
	var best := Vector2.INF
	var score := 2.5
	var r := float(Defs.FOG["radius"])
	for e in game.units_near(u.position, float(Defs.FOG["range"]) + r):
		if not game.hostile(e.team, team) or e.dead or e.off_field or e.is_worker() or float(e.d["range"]) < 100.0:
			continue
		if game.in_fog(e.position):
			continue
		var s := 0.0
		for o in game.units_near(e.position, r):
			if o.dead or o.off_field or o.is_worker():
				continue
			if game.hostile(o.team, team):
				s += (1.0 + float(o.d["supply"]) * 0.25) if float(o.d["range"]) >= 100.0 else 0.2
			elif float(o.d["range"]) >= 100.0:
				s -= 0.6      # our own shooters in there would miss too
		if s > score:
			score = s
			best = e.position
	if best == Vector2.INF:
		return
	# only while our army engages them: someone of ours fighting close by
	var engaged := game.units_near(best, r + 200.0).any(func(f: Unit) -> bool: return f.team == team and not f.dead and not f.is_worker() and f.kind != "mist_toad" and (f.target != null or f.position.distance_to(best) < r + 60.0))
	if engaged:
		var at := best
		if at.distance_to(u.position) > float(Defs.FOG["range"]):
			at = u.position + (best - u.position).normalized() * float(Defs.FOG["range"])
		u.cmd_cast("fog", at)


## Brood: Skywings hunt flyers in the air; with no enemy flyers about they land on enemy
## ground forces and bite, and take off again when flyers show up.
func _skywings() -> void:
	for u in game.army(team):
		if u.kind != "skywing" or u.sky_cd > 0.0 or u.order in ["move", "cast"]:
			continue
		var flyers := 0
		var ground := 0
		for o in game.units_near(u.position, 380.0):
			if not game.hostile(o.team, team) or o.dead or o.off_field:
				continue
			if o.is_air():
				flyers += 1
			elif not o.is_worker() or o.position.distance_to(u.position) < 200.0:
				ground += 1
		if u.sky == "air" and flyers == 0 and ground >= 2 and (u.target == null or u.order == "idle"):
			u.cmd_land()
			u.sky_cd = 6.0
		elif u.sky == "ground" and (flyers > 0 or (ground == 0 and u.target == null)):
			u.cmd_take_off()
			u.sky_cd = 6.0


## Brood: when it can hatch essence-costing creatures (Skywings, Bloaters, Brutes, Spore
## Mothers; Spitters too) but lacks the essence and its biomass bank is high, spare Raptors
## at home are offered up at the Brood Pen (3 essence each). With almost none left, a few
## go whatever the bank (Spitters need 5 an egg).
var _offer_next := 0.0


func _offer() -> void:
	if game.clock < _offer_next or _hall_reserve:
		return
	var pen := game.nearest_of(game.center_of_team(team), team, "brood_pen")
	if pen == null:
		return
	var want := 0
	for k in ["skywing", "bloater", "brute", "spore_mother", "mist_toad", "spitter"]:
		var u: Dictionary = Defs.UNITS[k]
		var reqs: Array = u["requires"] if u.get("requires", "") is Array else [u["requires"]]
		if reqs.all(func(r: String) -> bool: return game._has_built(team, r)):
			want = maxi(want, int(u.get("cost2", 0)))
	if _mound_saving():
		want = maxi(want, int(Defs.HALL_LEVELS[2]["cost2"]) + 20)     # (for the Broodmound)
	if want == 0:
		return
	var target := want
	var pending := 0
	for u in game.army(team):
		if u.order == "sacrifice":
			pending += Game.sacrifice_value(u.kind)
	var have := _res2() + pending
	# a little essence always (Spitters, 5 an egg, are the swarm's answer to armour and
	# flyers): a few raptors whatever the bank; more only with biomass piling up
	var small := have < 10.0
	if have >= target or (not small and _gold() < _lv([700, 550, 450])):
		return
	if small and _gold() < 100:
		return
	var in_wave := {}
	for g in _swarm:
		for u in g[0]:
			in_wave[u] = true
	var raptors := game.army(team).filter(func(u: Unit) -> bool: return u.kind == "raptor" and not in_wave.has(u) \
		and u.order in ["idle", "move", "amove"] and u.target == null)
	if raptors.size() <= 6:
		return              # (keep a few at home)
	raptors.sort_custom(func(a: Unit, b: Unit) -> bool: return a.position.distance_squared_to(pen.center()) < b.position.distance_squared_to(pen.center()))
	var n := mini(mini(int(ceil((target - have) / 3.0)), 4 if small and _gold() < _lv([700, 550, 450]) else 9), raptors.size() - 6)
	for u in raptors.slice(0, n):
		u.cmd_sacrifice()
	_offer_next = game.clock + _lv([40.0, 25.0, 15.0])


## Clockwork: Bulwarks BRACE when the army faces a firing line (musketeers, spitters and
## the like shooting at it) with friends behind the shield to cover; they lift it again
## when the shooting stops, the others have moved on, or melee is all over them.
func _braces() -> void:
	for u in game.army(team):
		if u.kind != "bulwark" or u.powered_down() or u.brace_t > 0.0:
			continue
		var shooters := 0
		var melee := 0
		var at := Vector2.ZERO
		for o in game.units_near(u.position, 340.0):
			if not game.hostile(o.team, team) or o.dead or o.off_field or o.is_worker():
				continue
			if float(o.d["range"]) >= 100.0 and o.kind != "cannon" and o.kind != "spore_mother":
				shooters += 1
				at += o.position
			elif o.position.distance_to(u.position) < 70.0:
				melee += 1
		var friends := 0
		for f in game.units_near(u.position, float(Defs.BRACE["reach"])):
			if f != u and f.team == team and not f.dead and not f.is_air() and f.kind != "bulwark":
				friends += 1
		if not u.braced:
			if shooters >= 2 and friends >= 2 and melee < 3:
				u.set_brace(true)
				u.facing = (at / shooters - u.position).normalized()
		elif shooters == 0 or friends < 1 or melee >= 4:
			u.set_brace(false)


## Clockwork: an Ornithopter with a battery overloads a Thresher (or a Steam Walker)
## that's just getting into a fight.
func _overloads() -> void:
	var topters: Array = game.army(team).filter(func(u: Unit) -> bool: return u.kind == "ornithopter" and u.topter_bat != "" and u.order != "overload" and u.work != "winding")
	if topters.is_empty():
		return
	for k in ["thresher", "steam_walker"]:
		for c in game.army(team):
			if c.kind != k or c.overclock_t > 0.0 or c.powered_down() or c.target == null or not is_instance_valid(c.target):
				continue
			if c.target.edge_distance(c.position) > 140.0:
				continue
			var best: Unit = null
			var bd := 600.0
			for t in topters:
				var dd: float = t.position.distance_to(c.position)
				if dd < bd:
					bd = dd
					best = t
			if best:
				best.cmd_overload(c)
				topters.erase(best)
				if topters.is_empty():
					return


## Crown: now and then a balloon takes four Musketeers aboard and drops them on the
## enemy's workers, away from its army; then it floats home.
var _drop := {}                 # {"b": balloon, "men": [..], "phase": "load"/"fly", "at": spot, "t": seconds}
var _drop_next := 300.0         # (match clock) the earliest next drop


func _balloon_drop() -> void:
	# balloons low on powder (their store refills the Musketeers aboard) go and restock
	for u in game.army(team):
		if u.kind == "balloon" and u.passengers.is_empty() and u.powder < u._pmax * 0.5 and u.order in ["idle", "amove", "move"] \
				and (_drop.is_empty() or _drop.get("b") != u):
			u.cmd_restock()
	if _drop.is_empty():
		if game.clock < _drop_next or _threat() != Vector2.INF:
			return
		var balloon: Unit = null
		for u in game.army(team):
			if u.kind == "balloon" and u.passengers.is_empty() and u.hp > u.max_hp * 0.6 and u.order in ["idle", "amove", "move"]:
				balloon = u
				break
		if balloon == null or not game._clear_at(balloon.position, 8.0, team):
			return
		var men: Array = game.army(team).filter(func(u: Unit) -> bool: return u.kind == "musketeer" and u.order in ["idle", "amove"] \
			and u.target == null and u.position.distance_to(balloon.position) < 700.0 and not _raiders.has(u))
		if men.size() < 3:
			_drop_next = game.clock + 30.0
			return
		men.sort_custom(func(a: Unit, b: Unit) -> bool: return a.position.distance_squared_to(balloon.position) < b.position.distance_squared_to(balloon.position))
		men = men.slice(0, int(Defs.DROPSHIP["capacity"]))
		var at := _drop_spot()
		if at == Vector2.INF:
			_drop_next = game.clock + 60.0
			return
		balloon.cmd_stop()
		game.load_order(men, [balloon])
		_drop = {"b": balloon, "men": men, "phase": "load", "at": at, "t": 0.0}
		return
	var b = _drop["b"]
	_drop["t"] = float(_drop["t"]) + _think_dt
	_drop["men"] = (_drop["men"] as Array).filter(func(u) -> bool: return is_instance_valid(u) and not u.dead)
	if not is_instance_valid(b) or b.dead:
		_end_drop()
		return
	match _drop["phase"]:
		"load":
			var walking: bool = (_drop["men"] as Array).any(func(u: Unit) -> bool: return u.order == "board")
			if not walking or float(_drop["t"]) > 30.0:
				if b.passengers.is_empty():
					_end_drop()
					return
				b.cmd_unload(_drop["at"])
				_drop["phase"] = "fly"
				_drop["t"] = 0.0
		"fly":
			if b.passengers.is_empty():
				# they're down: at them, and the balloon goes home
				for u in _drop["men"]:
					u.cmd_move(_drop["at"] + Vector2(randf_range(-60, 60), randf_range(-60, 60)), true)
				if game.mlog:
					game.mlog.add("%s dropped %d Musketeers from a balloon" % [game.mlog.who(team), (_drop["men"] as Array).size()])
				var hall: Array = _halls()
				if not hall.is_empty():
					b.cmd_move(hall[0].center())
				_end_drop()
			elif b.hp < b.max_hp * 0.4 and b.work != "dropping":
				b.cmd_unload(b.position)        # being shot down: let them off now
			elif b.order != "unload":
				b.cmd_unload(_drop["at"])


func _end_drop() -> void:
	for u in _drop.get("men", []):
		if is_instance_valid(u) and not u.dead and u.order == "board":
			u.cmd_stop()
	_drop = {}
	_drop_next = game.clock + randf_range(150.0, 240.0)


## Where to drop: next to the enemy's workers or economy, the farther from its army the better.
func _drop_spot() -> Vector2:
	var foe := _foe()
	if foe < 0:
		return Vector2.INF
	var foes_army: Array = game.army(foe)
	var best := Vector2.INF
	var score := -INF
	for b in game.buildings:
		if b.team != foe or b.dead or b.ghost or not (Defs.is_econ(b.kind) or b.kind == game.faction_hall(foe)):
			continue
		var guard := 0
		for o in foes_army:
			if o.position.distance_to(b.center()) < 350.0:
				guard += int(o.d["supply"])
		var s: float = -float(guard) * 10.0 + (30.0 if Defs.is_econ(b.kind) else 0.0) - b.center().distance_to(game.center_of_team(team)) * 0.01
		if s > score:
			score = s
			best = b.center()
	if best == Vector2.INF:
		return Vector2.INF
	# beside it, on the side away from the enemy's base centre
	var away: Vector2 = (best - game.center_of_team(foe)).normalized()
	return best + (away if away != Vector2.ZERO else Vector2.RIGHT) * 70.0


# ------------------------------------------------------------------ micro (Hard and Brutal)

var _kite := {}       # unit -> seconds until it turns back to the fight
var _mending := {}    # hurt units sent home to heal


func _value(u: Unit) -> float:
	return float(u.d["cost"]) / maxf(1.0, float(u.d.get("spawn", 1))) * (u.hp / maxf(1.0, u.max_hp)) + 20.0


## Focus fire on the weakest enemy in reach; Brutal also kites with ranged units, sends
## badly hurt big units home to heal and backs off from a fight that's lost.
func _micro() -> void:
	var army := game.army(team)
	if army.is_empty():
		return
	var brutal := difficulty >= 3
	var halls := _halls()
	var home: Vector2 = halls[0].center() if not halls.is_empty() else game.center_of_team(team)
	if (brutal or (difficulty >= 2 and _clock() and Defs.gear_mode)) and _attacking and not siege_no_retreat and _siege.is_empty():
		var c := Vector2.ZERO
		var mine := 0.0
		for u in army:
			c += u.position
			mine += _value(u)
		c /= army.size()
		var theirs := 0.0
		for o in game.units_near(c, 380.0):
			if game.hostile(o.team, team) and not o.dead and not o.is_worker() and not o.off_field:
				theirs += _value(o)
		if theirs > mine * 1.5 and theirs > 300.0:
			_attacking = false
			_release_escort()
			for u in army:
				u.cmd_move(home.lerp(c, 0.25) + Vector2(randf_range(-50, 50), randf_range(-50, 50)))
			return
	for k in _kite.keys():
		if not is_instance_valid(k) or k.dead:
			_kite.erase(k)
	for k in _mending.keys():
		if not is_instance_valid(k) or k.dead or k.hp > k.max_hp * 0.85:
			_mending.erase(k)
	for k in _patch.keys():
		if not is_instance_valid(k) or k.dead:
			_patch.erase(k)
	for u in army:
		if u.deploys() or u.d.get("medic", false) or _mending.has(u) or _on_errand(u) or u.siege_t > 0.0:
			continue
		if brutal and u.hp < u.max_hp * 0.25 and int(u.d["supply"]) >= 2 and u.target:
			_mending[u] = true
			u.cmd_move(home + Vector2(randf_range(-40, 40), randf_range(-40, 40)))
			continue
		if _kite.has(u):
			_kite[u] = float(_kite[u]) - _think_dt
			if float(_kite[u]) <= 0.0:
				_kite.erase(u)
				u.cmd_move(_wave_target if _attacking else u.position, true)
			continue
		var reach: float = float(u.d["range"]) + u.radius + 30.0
		# (Musketeers stand and use the bayonet instead)
		if brutal and float(u.d["range"]) >= 100.0 and u.cooldown > 0.4 and not u.is_air() and u.kind != "musketeer":
			var close: Unit = null
			var cd := 70.0
			for o in game.units_near(u.position, 70.0):
				if game.hostile(o.team, team) and not o.dead and float(o.d["range"]) < 50.0 and o.can_hit(u):
					var dd: float = o.position.distance_to(u.position)
					if dd < cd:
						cd = dd
						close = o
			if close:
				u.cmd_move(u.position + (u.position - close.position).normalized() * 60.0)
				_kite[u] = 0.6
				continue
		if u.kind == Defs.NETTER:
			_netter_aim(u)       # (its own pick, Netter.pick, but never a worker while a fighter is in reach)
			continue
		if u.kind == Defs.BALLISTA_KIND:
			continue        # (its own pick: armour and gates, Ballista.pick)
		if u.kind == Defs.PENDULUM and _pendulum_aim(u):
			continue
		if u.kind == "clock_soldier" and _patch_up(u):
			continue
		if u.order in ["idle", "amove", "hold"] and u.target:
			var best: Entity = null
			var bh := INF
			for o in game.units_near(u.position, reach):
				if game.hostile(o.team, team) and not o.dead and not o.off_field and u.can_hit(o) and not o.untouchable():
					var h: float = o.hp - (200.0 if o.d.get("medic", false) else 0.0) - (40.0 if float(o.d["damage"]) > 20.0 else 0.0)
					if h < bh:
						bh = h
						best = o
			if best and best != u.target:
				u.target = best


## Gear mode (Hard): a Netter about to fire that has picked a worker (Netter.pick nets the most dangerous enemy in reach,
## and a Labourer in front is often all there is: 38 of 45 nets in one 0.14.72 game) nets the most dangerous fighter
## within its reach and a step instead: a gun, a rider, a Musketeer in a line. In a siege a worker mending the wall is
## the point (_siege_orders sends it).
func _netter_aim(u: Unit) -> void:
	if u.siege_t > 0.0 or u.cooldown > 0.6 or u.phase != "":
		return
	var t = u.target if u.target != null and is_instance_valid(u.target) else null
	if t == null or not (t is Unit) or not t.is_worker():
		return
	var best: Unit = null
	var bs := 0.0
	for o in game.units_near(u.position, u._range() + 60.0):
		if o.dead or o.off_field or o.is_worker() or not o.has_attack() or not game.hostile(o.team, team) or not u.can_hit(o) or Netter.caught(o):
			continue
		if not game.is_visible_to(team, o.position):
			continue
		var v: float = Netter.danger(o)
		if _is_gun(o) or Defs.RIDERS.values().has(o.kind) or o.kind == "cuirassier":
			v *= 1.5
		if v > bs:
			bs = v
			best = o
	if best != null:
		u.target = best


## Gear mode (Hard): a Pendulum's blades cut every enemy in the arc in front of it, the light ones hardest: one that is
## not at a blow already walks into the thickest knot of enemy foot soldiers close by (three or more together, on its
## own level), not at a lone one. True when it was sent.
func _pendulum_aim(u: Unit) -> bool:
	if u.siege_t > 0.0 or u.phase != "" or not u.order in ["idle", "amove"]:
		return false
	if u.target != null and is_instance_valid(u.target) and u.target is Unit and u.target.edge_distance(u.position) <= u._range() + 4.0:
		return false
	var lv := game.level_of(u.position)
	var best: Unit = null
	var bn := 2
	var near: Array = game.units_near(u.position, 240.0).filter(func(o: Unit) -> bool: return not o.dead and not o.off_field and not o.is_air() \
			and game.hostile(o.team, team) and not o.is_worker() and game.level_of(o.position) == lv)
	for o in near:
		var n := 0
		for q in near:
			if q.position.distance_to(o.position) < 64.0:
				n += 1
		if n > bn:
			bn = n
			best = o
	if best == null or best == u.target:
		return false
	u.target = best
	return true


## Gear mode (Hard): a badly hurt Clock Soldier in a fight steps back to the nearest escort Winder (they mend it: _escort_wind)
## and goes back in once it is mended (or after PATCH_MAX s).
var _patch := {}            # Clock Soldier -> clock it stepped back
const PATCH_MAX := 20.0


func _patch_up(u: Unit) -> bool:
	if _patch.has(u):
		if u.hp > u.max_hp * 0.8 or game.clock - float(_patch[u]) > PATCH_MAX:
			_patch.erase(u)
			if _attacking:
				u.cmd_move(_wave_target + Vector2(randf_range(-50, 50), randf_range(-50, 50)), true)
			return false
		return true
	if u.hp > u.max_hp * 0.35 or u.target == null or _escort.is_empty() or u.siege_t > 0.0:
		return false
	var best: Unit = null
	var bd := 520.0
	for w in _escort:
		if is_instance_valid(w) and not w.dead:
			var dd: float = w.position.distance_to(u.position)
			if dd < bd and not _enemy_near(w.position, 150.0):
				bd = dd
				best = w
	if best == null:
		return false
	_patch[u] = game.clock
	u.cmd_move(best.position + Vector2(randf_range(-16, 16), randf_range(-16, 16)))
	return true


# ------------------------------------------------------------------ horses (Crown)

## Crown horses: a Horseman, cannon, mortar or wagon in a queue gets its own horse by
## itself (Game.train: a free one at a breeder, else the breeder trains one), so the
## computer only keeps a spare or two bought at its breeder (_buy_horses); the Town Hall's
## haulers (_assign_haulers) bring them to the buildings; stray horses are sent home; guns and wagons at home get a second horse (_team_up); spare horses become
## Dragoons' mounts; dismounted cavalry gets back on a horse.
func _horses() -> void:
	var horses: Array = game.horses_of(team)
	var halls := _halls()
	if halls.is_empty():
		return
	# where horses are wanted, and how many short each place is
	var short := {}
	var need := 0
	var places: Array = _mine("foundry").filter(func(b: Building) -> bool: return b.built)
	for b in places:
		var want := 2 if _gold() > 600 else 1
		var fh: int = r5.foundry_horses(b)     # (round 5: against the Clockwork one, and only for a gun it wants)
		if fh >= 0:
			want = fh
		var have: int = game.horses_at(b)
		for h in horses:
			if h.order == "move" and b.edge_distance(h.order_point) < 40.0:
				have += 1       # (on its way there)
		if have < want:
			short[b] = want - have
			need += want - have
	# horses standing at those places stay there (and the ones kept for a recruit)
	var keep := {}
	for h in horses:
		if h.horse_rid != 0:
			keep[h] = true
			continue
		for b in places:
			if b.edge_distance(h.position) <= float(Defs.HORSES["at_building"]) * Defs.TILE + h.radius:
				keep[h] = true
	# strays (far from all our buildings, nobody with them): home to a breeder or the hall
	var homes: Array = _mine("horse_breeder").filter(func(b: Building) -> bool: return b.built)
	if homes.is_empty():
		homes = halls
	for h in horses:
		if h.leader != null or h.into != null or h.order != "idle" or keep.has(h):
			continue
		var near_home := false
		for b in game.buildings:
			if b.team == team and not b.dead and b.edge_distance(h.position) < 8.0 * Defs.TILE:
				near_home = true
				break
		if not near_home and not game.units_near(h.position, 80.0).any(func(o: Unit) -> bool: return o.team == team and o.kind != "horse"):
			var hb: Building = homes[0]
			for b in homes:
				if b.center().distance_to(h.position) < hb.center().distance_to(h.position):
					hb = b
			h.cmd_move(game.approach_point(hb, h.position) + Vector2(randf_range(-30, 30), randf_range(-30, 30)))
	_remount_riders(horses, keep)
	_spares_home(horses, keep)
	var teams := _team_up(horses, keep)
	_buy_horses(horses, keep, need + teams)
	_assign_haulers()
	if difficulty >= 1:
		_mount_men(horses, keep, need + teams)


## Crown: workers assigned to the Town Hall as haulers (Game.haul_dispatch: they lead the
## horses to the Barracks and Foundries and carry kegs to the wagons). One once there is a
## Horse Breeder, a gun or a wagon, two from 6 horse-using units, three from 12. The man comes
## from the idle ones first, else a farm hand (never the Mill, never a builder); the farm is
## refilled by the next hire, as haulers aren't counted among game.workers.
func _assign_haulers() -> void:
	var halls: Array = _halls().filter(func(h: Building) -> bool: return h.built and h.haul_cap() > 0)
	if halls.is_empty():
		return
	var users := game.army(team).filter(func(u: Unit) -> bool: return Defs.RIDERS.has(u.kind) or Defs.HARNESSED.has(u.kind)).size()
	var want := 0
	if users > 0 or not _mine("horse_breeder").is_empty():
		want = 1 + (1 if users >= 6 else 0) + (1 if users >= 12 else 0)
	if game.haulers_of(team).size() >= want:
		return
	var hall: Building = halls[0]
	var best: Unit = null
	var bd := INF
	for u in game.workers(team):
		if u.kind != "labourer" or u.order == "build" or u.keg or _escort.has(u):
			continue
		var farm: bool = u.order == "gather" and u.home_mine is Building and (u.home_mine as Building).kind == "farm"
		if u.order != "idle" and not farm:
			continue
		var dd: float = u.position.distance_to(hall.center()) + (0.0 if u.order == "idle" else 3000.0)
		if dd < bd:
			bd = dd
			best = u
	if best:
		best.cmd_gather(hall)


## A man of ours on foot who should be on a horse: a Dismounted Horseman or Cuirassier, or
## one of our Dragoons left on foot (auto_mount) once the fight is over.
func _wants_horse(u: Unit) -> bool:
	if u.kind == "dismounted":
		return true
	return u.kind == "musketeer" and (u.auto_mount or u.horse_rid != 0)    # (a Dragoon on foot, or one trained, his horse kept for him)


## Fighting, or enemy fighters close by: not the moment to walk off for a horse.
func _in_fight(u: Unit) -> bool:
	if u.target != null and is_instance_valid(u.target) and not u.target.dead and game.hostile(u.target.team, team):
		return true
	for o in game.units_near(u.position, 7.0 * Defs.TILE):
		if not o.dead and game.hostile(o.team, team) and not o.is_worker() and o.kind != "horse" and o.has_attack():
			return true
	return false


var _mount_t := {}               # rider -> when he set off for his horse (_remount_riders)
var _bad_horse := {}             # horse -> until when riders leave it be (they couldn't reach it)


## Every rider of ours left on foot gets on a horse: his own reserved one (Unit._wait_horse
## takes him there), or, when that isn't to be had (still at the breeder, killed, stolen,
## taken by another; or he has none: he dismounted, was raised, his horse bolted), the
## nearest free horse of ours (not kept for someone else, not led or hitched, not standing
## ready at a Foundry), wherever it stands, out of a fight. Taking another horse frees his
## reservation (Unit.do_mount): one still being bred comes out a spare.
func _remount_riders(horses: Array, keep: Dictionary) -> void:
	# (a man who has been walking to a horse for long without getting there can't reach it:
	# he lets it go, and that horse is left out for a while)
	for u in _mount_t.keys():
		if not is_instance_valid(u) or u.dead or u.order != "mount":
			_mount_t.erase(u)
	for h in _bad_horse.keys():
		if not is_instance_valid(h) or game.clock > float(_bad_horse[h]):
			_bad_horse.erase(h)
	for u in game.army(team):
		if u.order == "mount" and u.work != "mounting" and u.order_target is Unit:
			if not _mount_t.has(u):
				_mount_t[u] = game.clock
			elif game.clock - float(_mount_t[u]) > 35.0:
				_bad_horse[u.order_target] = game.clock + 40.0
				_mount_t.erase(u)
				u.cmd_stop()
	var free := horses.filter(func(h: Unit) -> bool: return not h.off_field and h.horse_rid == 0 and h.leader == null and h.into == null \
		and not Unit._claim_live(h) and not keep.has(h) and not _bad_horse.has(h))
	if free.is_empty():
		return
	for u in game.army(team):
		if free.is_empty():
			return
		if not _wants_horse(u) or u.order == "mount" or u.work != "" or u.aboard or u.off_field or u._heal_remount or _on_errand(u) or u.order == "hold":
			continue
		if u.kind == "musketeer" and u.order != "idle" and u.horse_rid == 0:
			continue                         # (a Dragoon on foot remounts by himself to move)
		if u.horse_rid != 0:
			var mine: Unit = game.reserved_horse(team, u.horse_rid)
			if (mine and Unit.horse_free_for(mine, u)) or game.hauler_serves_rid(team, u.horse_rid):
				continue                     # (his own is there for him, or a hauler brings it: Unit._wait_horse)
		if _in_fight(u):
			continue
		var reach := (40.0 if u.kind == "dismounted" or u.horse_rid != 0 else 12.0) * Defs.TILE
		var h: Unit = null
		var bd := reach
		for o in free:
			var dd: float = o.position.distance_to(u.position)
			if dd < bd and Unit.horse_free_for(o, u):
				bd = dd
				h = o
		if h == null:
			continue
		var aft := {}
		if u.order == "amove" or u.order == "move":
			aft = {"o": u.order, "p": u.order_point}
		if u.cmd_mount(h, aft):
			free.erase(h)


## Spare horses standing about away from home (where a rider left them, a loose one caught)
## with nobody of ours by them: home to a breeder, where a new recruit takes one instead of a
## new one being bought (Game.spare_horse). Horses at a Barracks stay: a recruit there takes
## one straight away (Game.free_horse_at).
func _spares_home(horses: Array, keep: Dictionary) -> void:
	var brs: Array = _mine("horse_breeder").filter(func(b: Building) -> bool: return b.built)
	if brs.is_empty():
		return
	var near := float(Defs.HORSES["near_breeder"]) * Defs.TILE
	var at := float(Defs.HORSES["at_building"]) * Defs.TILE
	var bars: Array = _mine("barracks").filter(func(b: Building) -> bool: return b.built)
	for h in horses:
		if h.off_field or h.order != "idle" or h.horse_rid != 0 or h.leader != null or h.into != null or keep.has(h) or Unit._claim_live(h):
			continue
		if brs.any(func(b: Building) -> bool: return b.edge_distance(h.position) <= near + h.radius):
			continue
		if bars.any(func(b: Building) -> bool: return b.edge_distance(h.position) <= at + h.radius):
			continue
		# (a Dragoon's horse while he fights on foot, a rider of ours close by who'll take it: it stays)
		if game.units_near(h.position, 6.0 * Defs.TILE).any(func(o: Unit) -> bool: return o.team == team and not o.dead and _wants_horse(o)):
			continue
		var hb: Building = brs[0]
		for b in brs:
			if b.center().distance_to(h.position) < hb.center().distance_to(h.position):
				hb = b
		h.cmd_move(game.approach_point(hb, h.position) + Vector2(randf_range(-24, 24), randf_range(-24, 24)))


var _loose_at := 0.0
var _catchers: Array = []        # men sent to catch a loose horse (they let it go once it's ours)


## Loose horses (nobody's: their riders fell, Unit._rider_falls). The Crown sends its
## nearest free man who can lead horses (an idle Labourer or soldier, a Labourer at work; not
## its groom) to catch one in its base or by its army, with no enemy close; a Clockwork
## Winder close by takes one; the Brood kills one near its creatures (cheap essence) with
## nobody to fight there, but doesn't chase them across the map.
func _loose_horses() -> void:
	# the ones caught: let go where they stand (strays are sent home: _horses)
	for u in _catchers.duplicate():
		if not is_instance_valid(u) or u.dead:
			_catchers.erase(u)
		elif u.order != "lead" and not u.queue.any(func(o: Dictionary) -> bool: return o["o"] == "lead"):
			if not u.led.is_empty():
				u.release_horses()
			_catchers.erase(u)
			if u.is_worker() and u.order == "idle":
				u.auto_work = true
	if game.clock < _loose_at:
		return
	_loose_at = game.clock + 2.0
	var fac := game.faction_of(team)
	if fac != "crown" and fac != "brood" and fac != "clockwork":
		return
	var T := Defs.TILE
	for h in game.units:
		if not Game.loose_horse(h) or h.off_field or h.bolt_t > 0.0:
			continue
		if h.claimed and is_instance_valid(h.claimed) and not h.claimed.dead and h.claimed.is_coming_for(h):
			continue                     # (someone's on his way to it)
		var near: Array = game.units_near(h.position, 9.0 * T)
		if near.any(func(o: Unit) -> bool: return not o.dead and game.hostile(o.team, team) and o.kind != "horse" \
				and o.position.distance_to(h.position) < 6.0 * T):
			continue                     # enemies there: not worth it
		if fac == "brood":
			var biter: Unit = null
			var bd := 8.0 * T
			for o in near:
				if o.team != team or o.dead or o.is_worker() or not o.has_attack() or not o.can_hit(h) or o.target != null \
						or not (o.order == "idle" or o.order == "hold") or _on_errand(o):
					continue
				var dd: float = o.position.distance_to(h.position)
				if dd < bd:
					bd = dd
					biter = o
			if biter:
				biter.cmd_attack(h)
			continue
		# the Crown: in its base, or by its army; the Clockwork: a Winder close by
		var reach := 6.0 * T
		if fac == "crown":
			reach = 16.0 * T
			var home := game.buildings.any(func(b: Building) -> bool: return b.team == team and not b.dead and b.edge_distance(h.position) < 12.0 * T)
			var by_army := near.any(func(o: Unit) -> bool: return o.team == team and not o.dead and not o.is_worker() and o.kind != "horse" \
				and o.position.distance_to(h.position) < 8.0 * T)
			if not home and not by_army:
				continue
		var best: Unit = null
		var bd2 := reach
		for o in game.units_near(h.position, reach):
			if o.team != team or o.dead or not o.can_lead() or o.is_hauler() or o.lead_count() > 0 or o.target != null \
					or o.keg or o.order == "keg" or _on_errand(o) or _catchers.has(o) or not Unit.horse_free_for(h, o):
				continue
			if fac == "clockwork" and o.kind != "winder":
				continue
			if not (o.order == "idle" or (o.is_worker() and o.order == "gather")):
				continue
			var dd: float = o.position.distance_to(h.position)
			if dd < bd2:
				bd2 = dd
				best = o
		if best and best.cmd_lead(h):
			_catchers.append(best)


## Guns and wagons at home with a single horse get a second one (from Normal up, with the
## gold for it): a free horse walks over and is hitched. Returns how many still want one.
func _team_up(horses: Array, keep: Dictionary) -> int:
	if difficulty < 1 or _gold() < 200:
		return 0
	var want := 0
	for g in game.army(team):
		if not Defs.HARNESSED.has(g.kind) or g.horse_count() != 1 or g.aboard:
			continue
		var hall: Building = game.nearest_hall(g.position, team)
		if hall == null or hall.edge_distance(g.position) > 16.0 * Defs.TILE:
			continue                       # (out in the field: not now)
		if horses.any(func(h: Unit) -> bool: return h.into == g):
			continue                       # one's on its way
		var h: Unit = null
		var bd := INF
		for o in horses:
			if keep.has(o) or o.leader != null or o.into != null or o.horse_rid != 0 or o.order == "move":
				continue
			var dd: float = o.position.distance_to(g.position)
			if dd < bd and dd < 30.0 * Defs.TILE:
				bd = dd
				h = o
		if h and game.hauler_serves(team):
			g.team_want = 2                  # (a hauler brings a spare: Game.haul_dispatch)
		elif h:
			h.walk_into(g)
			keep[h] = true
		else:
			want += 1
	return mini(want, 2)


## Horses are bought (Defs.UNITS.horse at a Horse Breeder): a spare (two during a Horseman
## rush) beyond the ones the Foundries and the guns' teams want, counting the free ones and
## the spares in the breeders' queues. (Recruits get theirs by themselves: Game.train.)
func _buy_horses(horses: Array, keep: Dictionary, need: int) -> void:
	var breeders := _mine("horse_breeder").filter(func(b: Building) -> bool: return b.built)
	if breeders.is_empty() or (_mine("barracks").is_empty() and _mine("foundry").is_empty() and not _rushing()):
		return
	# (unridden horses of ours standing about, or walking home to a breeder, are spares too:
	# none is bought while they're there; one a rider is on his way to isn't)
	var near := float(Defs.HORSES["near_breeder"]) * Defs.TILE
	var free := horses.filter(func(h: Unit) -> bool: return h.leader == null and h.into == null and not keep.has(h) and h.horse_rid == 0 \
		and not Unit._claim_live(h) and (h.order != "move" or breeders.any(func(b: Building) -> bool: return b.edge_distance(h.order_point) <= near))).size()
	var coming := 0
	for b in breeders:
		for i in b.queue.size():
			if b.queue[i] == "horse" and int(b.kit_at(i).get("rid", 0)) == 0:
				coming += 1
	var spare := 2 if _rushing() else 1
	if r5.spare_horses() >= 0:
		spare = r5.spare_horses()           # (round 5: no spare standing about against the Clockwork)
	if need + spare <= 0:
		return
	if free + coming >= need + spare:
		return
	breeders.sort_custom(func(a: Building, b: Building) -> bool: return a.queue.size() < b.queue.size())
	var b: Building = breeders[0]
	if b.queue.size() < 2:
		game.train(b, "horse")


## Spare horses at home (beyond what the buildings want): idle Musketeers there mount up as
## Dragoons (up to a quarter of the line), and dismounted cavalry rides again.
func _mount_men(horses: Array, keep: Dictionary, need: int) -> void:
	var spare := horses.filter(func(h: Unit) -> bool: return h.leader == null and h.into == null and h.claimed == null and h.horse_rid == 0 and not keep.has(h))
	if spare.is_empty():
		return
	spare = spare.filter(func(h: Unit) -> bool: return not Unit._claim_live(h))   # (riders took theirs: _remount_riders)
	var army := game.army(team)
	if spare.size() <= need + 1:
		return
	var muskets := army.filter(func(u: Unit) -> bool: return u.kind == "musketeer").size()
	var dragoons := army.filter(func(u: Unit) -> bool: return u.kind == "dragoon" or (u.kind == "musketeer" and u.auto_mount)).size()
	var want := int((muskets + dragoons) / 4.0)
	for u in army:
		if dragoons >= want or spare.size() <= need + 1:
			break
		if u.kind != "musketeer" or u.auto_mount or u.order != "idle" or u.target != null or _on_errand(u) or game.nearest_hall(u.position, team) == null or game.nearest_hall(u.position, team).edge_distance(u.position) > 14.0 * Defs.TILE:
			continue
		var h: Unit = u.nearest_free_horse(10.0)
		if h and spare.has(h) and u.cmd_mount(h):
			spare.erase(h)
			dragoons += 1
			u.auto_mount = true         # (the computer's Dragoons always get back on to move)


# ---- Brood against Horsemen: keep the Raptors home (36 hp, 6 damage do little against 140 hp and armour)
const HORSE_MEMORY := 150.0     # a Horseman seen this long ago still counts
const HORSE_PUSH := 1.2         # the army must be worth this much times what was seen before it pushes
const RAPTOR_VS_HORSE := 0.35   # (a Raptor's cost counts this much against mounted soldiers)
var bank_spend_on := true        # (tests switch the Crown's bank spending off for a "before" number)
var horse_hold_on := true      # (tests switch the Horsemen answer off for a "before" number)
var _hz_t := -99.0              # (cache) when the sightings were last counted
var _hz_horse_t := -999.0       # the last time an enemy Horseman / Cuirassier / Dragoon was in sight
var _hz_log: Array = []         # [clock, enemy army value in sight]
var _hz_logged := false


## Count what our eyes show of the enemy army, every 3 s: when it was last mounted, and how much it is worth.
func _horse_watch() -> void:
	if game.clock - _hz_t < 3.0:
		return
	_hz_t = game.clock
	var foe := _foe()
	if foe < 0:
		return
	var val := 0.0
	var horses := 0
	for u in game.army(foe):
		if not game.is_visible_to(team, u.position):
			continue
		val += float(u.d["cost"]) / maxf(1.0, float(u.d.get("spawn", 1)))
		if u.has_attack() and u.kind != "horse" and AIScout._is_horseman(u):
			horses += 1
	if horses > 0:
		_hz_horse_t = game.clock
	if val > 0.0:
		_hz_log.append([game.clock, val])
	while not _hz_log.is_empty() and game.clock - float(_hz_log[0][0]) > HORSE_MEMORY + 90.0:
		_hz_log.pop_front()


## Brood only (not the air plan): Horsemen were seen lately.
func _horse_alert() -> bool:
	if not horse_hold_on or not _brood() or strategy == "air" or difficulty < 1 or peaceful:
		return false
	_horse_watch()
	if scout != null and scout.rush_units_seen() > 0 and scout._foe_faction() == "crown":
		_hz_horse_t = maxf(_hz_horse_t, game.clock - 1.0)
	var on := game.clock - _hz_horse_t <= HORSE_MEMORY
	if on and not _hz_logged and game.mlog:
		_hz_logged = true
		game.mlog.add("%s saw Horsemen: Raptors do little against them, so it keeps its army at home and builds Spitters and Brutes" % game.mlog.who(team))
	return on


## The most the enemy army was worth in sight lately (what a push has to beat).
func _horse_seen_value() -> float:
	var v := 0.0
	for e in _hz_log:
		if game.clock - float(e[0]) <= HORSE_MEMORY + 90.0:
			v = maxf(v, float(e[1]))
	return v


## What our army is worth against Horsemen: Raptors count a third.
func _horse_value(army: Array) -> float:
	var v := 0.0
	for u in army:
		var c := float(u.d["cost"]) / maxf(1.0, float(u.d.get("spawn", 1))) + float(u.d.get("cost2", 0)) * 0.5
		v += c * (RAPTOR_VS_HORSE if u.kind == "raptor" else 1.0)
	return v


## True while the army stays home: Horsemen were seen and the army (Raptors at a third) is not yet
## worth HORSE_PUSH times what was seen.
func _horse_hold(army: Array) -> bool:
	if not _horse_alert():
		return false
	return _horse_value(army) < _horse_seen_value() * HORSE_PUSH


## The unit to hatch against Horsemen when it is asked for: Spitters (their acid strips the armour, from range), then Brutes.
func _horse_counter(h: Building, army: Array, k: String) -> String:
	if not _horse_alert():
		return k
	var brutes := army.filter(func(u: Unit) -> bool: return u.kind == "brute").size()
	if game.can_train(h, "brute") == "" and brutes * 5 < army.size() + 3:
		return "brute"
	if game.can_train(h, "spitter") == "":
		return "spitter"
	return k


## The Brood Pen and the Gorge Pit (Spitters, Brutes) come at once when Horsemen are about.
func _horse_tech() -> void:
	if not _horse_alert() or _mine("warren").is_empty():
		return
	for k in ["brood_pen", "gorge_pit"]:
		if _mine(k).is_empty() and not _busy_building(k) and game.requirement_met(team, k):
			if _gold() >= int(Defs.BUILDINGS[k]["cost"]) + 20:
				_construct(k)
			else:
				_reserve = maxi(_reserve, int(Defs.BUILDINGS[k]["cost"]))      # (the eggs wait: save up for it)
			return


# ---- Crown: gold piling up unspent
const BANK_RESERVE := 600       # gold kept for rebuilding after losses (cheap rebuilding is the loser's way back: docs/design_principles.md 2)
const BANK_STEP := 350          # ... and this much above it before anything is bought
const BANK_WAIT := 15.0         # ... for this long (a hall or a building being saved for is not a pile-up)
var _bank_t := 0.0
var _bank_since := -1.0         # since when the gold has been above reserve + step
var bank_log: Array = []        # [clock, what it bought] (tests read it)


## Measured (tools/measure_crown_bank.gd, Crown vs Hard Brood, Ashford Crossing, 200 supply cap): the Crown spends
## its gold well until it has won the middle game (under 100 on average up to 12:00); the pile (1,800 gold,
## 90 s over 1,000) came in one game once the soil had fallen under 45% on its two halls, with a third
## hall not taken until the soil was nearly spent (_hall_first waits while two halls still hold over a quarter),
## and with the supply stuck at the cap of its Cottages for 3 minutes. So the sinks, in order, once more than
## the reserve and a step has sat unspent for BANK_WAIT s (never at the expense of the rebuild reserve):
## a second Cottage when supply-blocked, every research still missing, a Town Hall on fresh soil while
## the best land is below 60% (the soil runs down, the expansion pays for the next stretch). More production
## buildings follow in _build_up (Barracks, Foundry) when the pile stays.
func _bank_spend() -> void:
	if not bank_spend_on or not _crown() or difficulty < 1 or _hall_reserve or peaceful:
		return
	if _gold() < BANK_RESERVE + BANK_STEP:
		_bank_since = -1.0
		return
	if _bank_since < 0.0:
		_bank_since = game.clock
	if game.clock - _bank_since < BANK_WAIT or game.clock - _bank_t < 10.0:
		return
	_bank_t = game.clock
	var sup: String = _sup()
	var cap: int = game.players[team]["cap"]
	if cap < game.max_supply(team) and game.supply_used(team) >= cap - 4 and _mine(sup).filter(func(b: Building) -> bool: return not b.built).size() < 2:
		_construct(sup)          # (supply-blocked with gold in hand: a second Cottage goes up beside the first)
		bank_log.append([game.clock, sup])
		return
	for key in Defs.RESEARCH:
		var info: Dictionary = Defs.RESEARCH[key]
		if info["faction"] != "crown" or game.has_tech(team, key) or game.researching(team, key):
			continue
		if _gold() < int(info["cost"]) + BANK_RESERVE or _res2() < float(info.get("cost2", 0)) + 20.0:
			continue
		for b in _mine(info["at"]):
			if game.research_problem(b, key) == "":
				game.start_research(b, key)
				bank_log.append([game.clock, key])
				return
	var hall: String = _f()["hall"]
	if _best_soil() < 0.6 and _halls().size() < 4 and not _busy_building(hall) and _gold() >= int(Defs.BUILDINGS[hall]["cost"]) + BANK_RESERVE:
		var sp := _safe_hall_spot()      # (past the plan's hall limit: the soil of the others is running out)
		if sp.x >= 0 and _lode_value(sp) > 0.0:
			_construct(hall, sp)
			bank_log.append([game.clock, hall])


## Horsemen seen: a Raptor is no match for one, and one can never catch a rider. The Raptors stay by the
## capital and the ramp: a detachment of them is called back at HORSE_LEASH, and a Raptor found far
## from home outside an attack wave walks back to the post.
const HORSE_LEASH := 300.0
func _horse_leash(u: Unit, far: float) -> bool:
	return u.kind == "raptor" and far > HORSE_LEASH and _horse_alert()


func _horse_posture(army: Array) -> void:
	if _attacking or _swarm_phase != "" or not _horse_alert():
		return
	var post := _post_spot()
	if post == Vector2.INF:
		return
	for u in army:
		if u.kind == "raptor" and u.order != "move" and _home_dist(u.position) > HORSE_LEASH + 120.0:
			u.cmd_move(post, true)
