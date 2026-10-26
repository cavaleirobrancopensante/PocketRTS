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
	"start_research": {"own": [0]}, "start_hall_upgrade": {"own": [0]}, "demolish": {"own": [0]}, "swap_gear": {"own": [0]},
	"abandon": {"own": [0]}, "set_gate_locked": {"own": [0]}, "refit_order": {"own": [0]},
	"mount_order": {"own": [0]}, "lead_order": {"own": [0]}, "harness_order": {"own": [0]},
	"unload_order": {"own": [0]}, "load_order": {"own": [0, 1]}, "overload_order": {"own": [0]},
	"cast_order": {"own": [0]}, "tongue_order": {"own": [0]}, "line_move": {"own": [0]},
	"morph_order": {"own": [0]}, "cancel_morph": {"own": [0]},
	"lay_line": {"team": 0, "own": [2]}, "buy_train": {"team": 0}, "ride_order": {"own": [0]}, "set_split": {"team": 0}, "player_surrender": {},
}

## UNIT / BUILDING: methods of an entity the guest owns (the receiver must be theirs).
const ENTITY := ["cmd_gather", "cmd_harvest", "cmd_sacrifice", "cmd_deploy", "cmd_pack", "cmd_stop",
	"cmd_land", "cmd_take_off", "cmd_dismount", "cmd_restock", "give", "set_hold_fire", "set_brace", "set_supply"]

## Settings flipped by the command card (a property of an entity the guest owns).
const PROPS := ["auto_repair", "auto_train", "auto_refit", "supplying", "courier", "team_want"]


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
	s.send_cmd({"o": oid, "f": fn, "a": wire})
	return true


## Host side: run a guest's command (after checking it).
static func apply(s: NetSession, peer: int, c: Dictionary) -> String:
	var team: int = s.peer_team.get(peer, -1)
	if team < 0:
		return "no team"
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
	if fn == "player_surrender":
		var was := game.human
		game.human = team
		game.player_surrender()
		game.human = was
		return ""
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
	var r = game.callv(fn, args)
	if r is String and r != "":
		return r
	return ""


## A reference that no longer exists (null in a list) is dropped from lists.
static func _clean_refs(args: Array) -> void:
	for i in args.size():
		if args[i] is Array:
			args[i] = args[i].filter(func(x) -> bool: return x != null)
