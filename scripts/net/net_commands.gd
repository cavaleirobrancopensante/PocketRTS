class_name NetCommands
extends RefCounted
## The command funnel. Everything a player can order goes through one of the functions below.
## On the host (and in single-player) they run as always. On a guest the first line of each calls
## `Game.net_forward`, which sends the call to the host instead; the host checks that the units and
## buildings in it belong to that guest (never anyone else's) and runs the same function.
##
## GAME: functions of Game. "own": the arguments (indexes) that are entities / lists of entities
## which must belong to the guest (others are dropped). "team": the argument that is a team number
## (the host puts the guest's own in).
const GAME := {
	"smart_command": {"own": [0]}, "group_move": {"own": [0]}, "command_all": {"own": [0]},
	"set_rally": {"own": [0]}, "place_building": {"team": 0, "own": [3]}, "place_line": {"team": 0, "own": [4]},
	"train_any": {"own": [0]}, "cancel_train": {"own": [0]}, "cancel_train_at": {"own": [0]},
	"start_research": {"own": [0]}, "demolish": {"own": [0]}, "swap_gear": {"own": [0]},
	"abandon": {"own": [0]}, "set_gate_locked": {"own": [0]}, "refit_order": {"own": [0]},
	"mount_order": {"own": [0]}, "lead_order": {"own": [0]}, "harness_order": {"own": [0]},
	"unload_order": {"own": [0]}, "load_order": {"own": [0, 1]}, "overload_order": {"own": [0]},
	"cast_order": {"own": [0]}, "tongue_order": {"own": [0]}, "line_move": {"own": [0]},
	"morph_order": {"own": [0]}, "cancel_morph": {"own": [0]}, "mature_order": {"own": [0]},
	"bombard_order": {"own": [0]}, "ground_order": {"own": [0]},
	"lay_line": {"team": 0, "own": [2]}, "buy_train": {"team": 0}, "ride_order": {"own": [0]}, "set_split": {"team": 0},
	"player_surrender": {"team": 0},
}

## UNIT / BUILDING: methods of an entity the guest owns (the receiver must be theirs).
const ENTITY := ["cmd_gather", "cmd_harvest", "cmd_sacrifice", "cmd_deploy", "cmd_pack", "cmd_stop",
	"cmd_land", "cmd_take_off", "cmd_dismount", "cmd_restock", "give", "set_hold_fire", "set_brace", "set_supply", "set_shield",
	"cmd_lay", "cmd_uproot", "cmd_grow", "cmd_grow_stop", "cmd_nb_research", "cmd_nb_research_stop", "band_hire", "band_solo"]      # (the Brood: the Mother lays an egg; UPROOT / HAUL; GROW and STOP GROWING; a creature's RESEARCH and STOP RESEARCH)

## Settings flipped by the command card (a property of an entity the guest owns).
const PROPS := ["auto_repair", "auto_train", "auto_refit", "supplying", "courier", "team_want", "auto_sweep", "auto_harvest"]      # (auto_sweep: a Great Winder's SWEEP; auto_harvest: a grub's HARVEST autocast)


## Guest side: send this call to the host. True: it was taken (the caller returns).
static func forward(s: NetSession, who: Object, fn: String, args: Array) -> bool:
	var ok := [true]
	var wire: Array = []
	var game := s.game
	if fn == "place_building":
		# (the reason a spot is refused comes at once, from the guest's own copy of the map)
		var why := game.placement_problem(game.human, String(args[1]), args[2])
		if why != "":
			game.notify(why)
			return true
	for a in args:
		wire.append(NetCodec.enc(a, ok))
	var oid := 0
	if who is Entity:
		oid = (who as Entity).net_id
		if oid == 0:
			ok[0] = false
	if not ok[0]:
		game.notify("That order can't be sent online.", true)
		return true
	feedback(game, who, fn, args)
	if s.predict:
		s.predict.order(who, fn, args, s.cmd_seq + 1)      # (what the click shows at once: NetPredict)
	s.send_cmd({"o": oid, "f": fn, "a": wire})
	return true


## Host, with the same delay for both players: its own order (given at the screen now) waits as long as a guest's takes
## to reach it (NetSession.hold_ms), then runs (NetSession._run_held); the click answers at once, as on a guest
## (feedback). The caller returns as on a guest. True: taken.
static func hold(s: NetSession, who: Object, fn: String, args: Array) -> bool:
	var game := s.game
	if fn == "place_building":
		var why := game.placement_problem(game.human, String(args[1]), args[2])
		if why != "":
			game.notify(why)
			return true
	feedback(game, who, fn, args)
	var pid: int = s.predict.order(who, fn, args, -1) if s.predict else 0
	s.hold(who, fn, args.duplicate(true), pid)
	return true


## Guest: what the player sees and hears at the click, as the host would show it (the ring on the ground, the unit
## answering, the bugle), while the order itself goes to the host. (On the host these are only made for its own
## orders: Game._ping and command_sound stay quiet while a guest's order runs.)
static func feedback(game: Game, who: Object, fn: String, args: Array) -> void:
	match fn:
		"smart_command":
			game.smart_feedback(args[0], args[1], bool(args[2]))
		"group_move":
			var us: Array = (args[0] as Array).filter(func(u) -> bool: return u is Unit and is_instance_valid(u) and not u.dead and u.kind != "horse")
			if not us.is_empty() and us[0].team == game.human:
				var atk := bool(args[2])
				game.command_sound(us, "attack" if atk else "move", "amove" if atk else "move")
				game._ping(game.on_map(args[1]), Color(1, 0.3, 0.3) if atk else Color(0.4, 1, 0.4))
				game.net.lead(us, args[1], atk)
		"line_move":
			var pts: PackedVector2Array = args[1]
			if pts.size() >= 2:
				game._ping(pts[pts.size() - 1], Color(1, 0.4, 0.3) if bool(args[2]) else Color(0.4, 1, 0.4))
		"bombard_order":
			var us: Array = (args[0] as Array).filter(func(u) -> bool: return u is Unit and is_instance_valid(u) and not u.dead and u.can_bombard())
			if not us.is_empty() and us[0].team == game.human:
				game.command_sound(us, "attack", "attack")
				game._ping(game.on_map(args[1]), Color(1.0, 0.55, 0.2))
		"command_all":
			for u in args[0]:
				if u is Unit and is_instance_valid(u) and not u.dead and u.kind != "horse" and u.team == game.human:
					Sfx.bugle(game.faction_of(game.human), String(args[1]))
					break
		"set_rally":
			game._ping(game.on_map(args[1]), Color(1, 0.85, 0.3))
		"tongue_order", "overload_order":
			var e = args[1]
			if e is Entity and is_instance_valid(e):
				game._ping(e.position, Color(1.0, 0.45, 0.6) if fn == "tongue_order" else Color(1, 0.85, 0.3))


## Host side: run a guest's command (after checking it). While it runs, the game knows whose it is
## (Game.net_cmd_team / net_cmd_peer: its marker and voice stay quiet here, its messages go to the guest).
static func apply(s: NetSession, peer: int, c: Dictionary) -> String:
	var team: int = s.peer_team.get(peer, -1)
	if team < 0:
		return "no team"
	var game := s.game
	game.net_cmd_team = team
	game.net_cmd_peer = peer
	var why := _apply(s, team, c)
	game.net_cmd_team = -1
	game.net_cmd_peer = -1
	return why


static func _apply(s: NetSession, team: int, c: Dictionary) -> String:
	var fn := String(c.get("f", ""))
	var args = NetCodec.dec(c.get("a", []), s.by_id)
	if not (args is Array):
		return "bad args"
	var wire: Array = c.get("a", [])
	for i in wire.size():
		if wire[i] is Dictionary and wire[i].size() == 1 and wire[i].has("e") and args[i] == null:
			return "target is gone"
	var oid := int(c.get("o", 0))
	var game := s.game
	if oid != 0:
		var e = s.by_id.get(oid)
		if not is_instance_valid(e) or e.team != team or e.dead:
			return "not yours"
		if fn.begins_with("@"):
			var prop := fn.substr(1)
			if not PROPS.has(prop) or args.size() != 1:
				return "bad property"
			e.set(prop, args[0])
			return ""
		if not ENTITY.has(fn) or not e.has_method(fn):
			return "unknown " + fn
		if fn == "give" and args.size() > 0 and args[0] is Dictionary and args[0].has("fn"):
			return "no callables"
		_clean_refs(args)
		e.callv(fn, args)
		return ""
	if not GAME.has(fn):
		return "unknown " + fn
	var spec: Dictionary = GAME[fn]
	if spec.has("team"):
		if args.size() <= int(spec["team"]):
			return "bad args"
		args[int(spec["team"])] = team
	for i in spec.get("own", []):
		if i >= args.size():
			return "bad args"
		var a = args[i]
		if a is Array:
			args[i] = a.filter(func(x) -> bool: return is_instance_valid(x) and x is Entity and x.team == team and not x.dead)
		elif not (is_instance_valid(a) and a is Entity and a.team == team and not a.dead):
			return "not yours"
	_clean_refs(args)
	if fn == "place_building" and args.size() >= 5:
		var why := game.placement_problem(team, String(args[1]), args[2])
		if why != "":
			return why
		why = _build_cost_problem(game, team, String(args[1]))
		if why != "":
			return why        # (place_building would just not build: the guest's site must go, with the reason)
	var r = game.callv(fn, args)
	if r is String and r != "":
		return r
	return ""


## Why player `team` can't pay for (or may not have) building `k` ("" if it can): place_building's own checks, in words.
static func _build_cost_problem(game: Game, team: int, k: String) -> String:
	if not Defs.BUILDINGS.has(k):
		return "bad args"
	var res: Array = Defs.FACTIONS[game.faction_of(team)]["res"]
	if int(game.players[team]["gold"]) < int(Defs.BUILDINGS[k]["cost"]):
		return "Not enough %s." % String(res[0]).to_lower()
	if game.tension(team) < float(Defs.tension_cost(Defs.BUILDINGS[k])):
		return "Not enough %s." % "tension"
	if not game.requirement_met(team, k):
		var rt := game.requirement_text(team, k)
		return rt if rt != "" and rt[0] == rt[0].to_upper() else "Can't build that yet."
	return ""


## A reference that no longer exists (null in a list) is dropped from lists.
static func _clean_refs(args: Array) -> void:
	for i in args.size():
		if args[i] is Array:
			args[i] = args[i].filter(func(x) -> bool: return x != null)
