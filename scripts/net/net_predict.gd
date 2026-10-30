class_name NetPredict
extends RefCounted
## Online: what an order shows on the click, before the host's answer (docs/online_lag_study.md, "Instant feedback").
## The host still decides everything. On a GUEST the click changes its own puppet copy at once: the queue gets the
## item (drawn pending), the resources and supply show it spent, the progress bar starts, the rally flag moves, a
## setting flips, a gun starts to deploy, a building site appears in a pending look (drawn here, it is not a building
## yet) and the units turn and start out (their side of it is NetSession's lead: walking to a spot, walking into range
## of what they were told to attack or work at, or standing still at a stop). Each of those is an ENTRY of small
## changes (ops) laid over the pictures: before a snapshot is applied every entry is taken off (undo_all), after it the
## entries the host has not answered yet are laid on again (redo_all), so the host's truth always comes through, and
## the moment its answer is in (the ack) the entry goes and the snapshot already shows the real thing: no jump. A
## refused order takes its entry off at once (refused, with the reason from the host).
## On the HOST, with "Same delay for both players", its own orders wait (NetSession.hold): the same entries are made, but
## nothing of the real game is touched: the HUD shows the resources, supply and queues through shown_player /
## shown_queue (the real values with the waiting entries on top), the site is drawn here, the units turn at once.

const MAX_MS := 4000              # an entry the host never answered is dropped after this (a lost link)
const LINGER := ["prop", "timer", "fade"]     # ops kept one picture past the host's answer (after_snapshot)
const FADE_MS := 1500             # ...and a fade until the building is gone, at most this long after the answer

var s: NetSession
var game: Game
var on := true                    # (tests: nopredict, to measure without it)
var list: Array = []              # entries, oldest first: {"key", "t0", "fn", "ops": [...], "patch": [...], "qi": [[b, i]]}
var _applied := false             # guest: the entries are laid on the puppets now
var _next := 1                    # host: ids of held orders
var _view: Node2D                 # the pending building sites
var shown_n := 0                  # (tests) entries made
var undone_n := 0                 # (tests) entries a refusal took back
var sites_seen := 0               # (tests) pending sites drawn


static func make(sess: NetSession) -> NetPredict:
	var p := NetPredict.new()
	p.s = sess
	p.game = sess.game
	return p


func _now() -> int:
	return Time.get_ticks_msec()


# ------------------------------------------------------------------ an order given here

## An order given on this machine (NetCommands.forward on a guest, NetCommands.hold on the host). `key`: the guest's
## command number (the host acks it); on the host -1, and the id it returns goes with the held order (dropped when it
## runs). The units' own reaction (turning, starting out) is made here too.
func order(who: Object, fn: String, args: Array, key: int) -> int:
	if not on:
		return 0
	if s.is_host:
		key = _next
		_next += 1
	_react(who, fn, args, key)
	var ops := _ops(who, fn, args)
	if ops.is_empty():
		return key
	var e := {"key": key, "t0": _now(), "fn": fn, "ops": ops, "patch": [], "qi": []}
	list.append(e)
	shown_n += 1
	if not s.is_host:
		_undo_all()
		_redo_all()
	_redraw_sites()
	return key


## The units of an order (the receiver for a unit's own command, or the list in the arguments), ours and alive.
func _units_of(who: Object, args: Array, i := 0) -> Array:
	var raw: Array = []
	if who is Unit:
		raw = [who]
	elif args.size() > i and args[i] is Array:
		raw = args[i]
	return raw.filter(func(u) -> bool: return u is Unit and is_instance_valid(u) and not u.dead and u.team == game.human and u.kind != "horse")


## The units turn, start out and answer at once. Guest: NetSession leads (walk / chase / stop); host: they turn.
func _react(who: Object, fn: String, args: Array, key: int) -> void:
	var g := game
	match fn:
		"smart_command":
			var us := _units_of(who, args)
			if us.is_empty():
				return
			var ch: Array = g._smart_choice(us, g.on_map(args[1]), bool(args[2]))
			if ch[1] != "other":
				_face(us, g.on_map(args[1]))         # (the walk itself: smart_feedback leads it)
				return
			var e := g.entity_at(g.on_map(args[1]))
			if e == null:
				return
			var atk: bool = g.prey(us[0].team, e)
			_chase(us, e, atk, key)
		"group_move":
			_face(_units_of(who, args), g.on_map(args[1]))
		"line_move":
			var pts: PackedVector2Array = args[1]
			var us := _units_of(who, args)
			if pts.size() >= 2 and not us.is_empty():
				# (spread along the line, as the host will: each to its share of it)
				for i in us.size():
					var at := _along(pts, (i + 0.5) / us.size())
					s.lead([us[i]], at, bool(args[2]), key)
					_face([us[i]], at)
				g.command_sound(us, "attack" if bool(args[2]) else "move", "amove" if bool(args[2]) else "move")
		"command_all":
			var us := _units_of(who, args)
			if String(args[1]) == "stop" or String(args[1]) == "hold":
				s.lead_stop(us, key)        # (its bugle came with NetCommands.feedback)
		"cmd_stop":
			var us := _units_of(who, args)
			s.lead_stop(us, key)
			g.command_sound(us, "move", "move")
		"cmd_gather":
			var us := _units_of(who, args)
			if args.size() > 0 and args[0] is Entity and is_instance_valid(args[0]):
				_chase(us, args[0], false, key)
				g._ping((args[0] as Entity).center(), Color(1, 0.85, 0.3))
		"cmd_harvest", "cmd_land", "cmd_take_off", "cmd_dismount", "cmd_restock", "cmd_sacrifice", "set_brace", "set_supply", "set_hold_fire":
			g.command_sound(_units_of(who, args), "move", "move")
		"cmd_deploy", "cmd_pack":
			var us := _units_of(who, args)
			s.lead_stop(us, key)
			g.command_sound(us, "move", "move")
		"give":
			var us := _units_of(who, args)
			var o: Dictionary = args[0] if args.size() > 0 and args[0] is Dictionary else {}
			var tgt = o.get("e")
			if tgt is Entity and is_instance_valid(tgt):
				_chase(us, tgt, g.prey(game.human, tgt), key)
			elif o.get("p") is Vector2:
				s.lead(us, o["p"], String(o.get("o", "")) == "amove", key)
				_face(us, o["p"])
				g._ping(o["p"], Color(0.4, 1, 0.4))
			g.command_sound(us, "move", "move")
		"place_building":
			var k := String(args[1])
			var c: Vector2i = args[2]
			var size: Vector2i = Defs.BUILDINGS[k]["size"]
			var mid := (Vector2(c) + Vector2(size) * 0.5) * Defs.TILE
			var us := _units_of(who, args, 3).filter(func(u: Unit) -> bool: return u.is_worker())
			var fac := String(Defs.BUILDINGS[k]["faction"])
			if fac != "crown" and not us.is_empty():
				# (one Winder or grub takes a site: the nearest; a Winder goes for the crate at a Clocktower first)
				us.sort_custom(func(a: Unit, b: Unit) -> bool: return a.position.distance_squared_to(mid) < b.position.distance_squared_to(mid))
				us = [us[0]]
				if fac == "clockwork":
					var tw: Building = g.nearest_of(mid, game.human, "clocktower")
					if tw and tw.built and not tw.dead:
						_chase(us, tw, false, key)
						us = []
			if not us.is_empty():
				_chase_point(us, mid, Vector2(size) * Defs.TILE * 0.5, key)
			g._ping(mid, Color(1, 0.85, 0.3))
			g.command_sound(us if not us.is_empty() else _units_of(who, args, 3), "move", "move")
		"lay_line":
			var cells: Array = args[1]
			var us := _units_of(who, args, 2)
			if not cells.is_empty():
				var at := g.cell_center(cells[0])
				s.lead(us, at, false, key)
				_face(us, at)
				g._ping(g.cell_center(cells[cells.size() - 1]), Color(1, 0.85, 0.3))
				g.command_sound(us, "move", "move")
		"ground_order", "bombard_order":
			var us := _units_of(who, args)
			var at: Vector2 = args[1] if args[1] is Vector2 else ((args[1] as PackedVector2Array)[0] if not (args[1] as PackedVector2Array).is_empty() else Vector2.INF)
			if at != Vector2.INF:
				# (no turn: a gun turns only once it is set up there, which the host decides)
				if fn == "ground_order":
					g._ping(at, Color(1.0, 0.55, 0.2))
					g.command_sound(us, "attack", "attack")
		"cast_order":
			var spell := String(args[1])
			var at: Vector2 = args[2]
			var us := _units_of(who, args).filter(func(u: Unit) -> bool: return u.kind == String(Game.CASTERS.get(spell, "")) and u.order != "cast" and g.spell_problem(u, spell) == "")
			if not us.is_empty():
				# (cast_order sends the nearest able caster: it heads into range of the spot, turned to it)
				us.sort_custom(func(a: Unit, b: Unit) -> bool: return a.position.distance_squared_to(at) < b.position.distance_squared_to(at))
				var c: Unit = us[0]
				var rng := float(Game.spell_info(spell).get("range", 0.0))
				_face([c], at)
				if not s.is_host and c.position.distance_to(at) > rng:
					s.lead_to(c, null, rng, key, Rect2(at, Vector2.ZERO))
				g.command_sound([c], "attack", "attack")
			g._ping(at, Color(0.6, 1.0, 0.35))
		"tongue_order", "overload_order":
			var us := _units_of(who, args)
			if args[1] is Entity and is_instance_valid(args[1]):
				_face(us, (args[1] as Entity).center())
			g.command_sound(us, "attack", "attack")
		"refit_order":
			var us := _units_of(who, args)
			for u in us:
				var pl: Entity = g.refit_place(u.team, u.position)
				if pl:
					_chase([u], pl, false, key)
			g.command_sound(us, "move", "move")
		"load_order":
			var us := _units_of(who, args)
			var bs: Array = args[1] if args.size() > 1 and args[1] is Array else []
			if not bs.is_empty() and bs[0] is Entity and is_instance_valid(bs[0]):
				_chase(us, bs[0], false, key)
			g.command_sound(us, "move", "move")
		"unload_order", "ride_order":
			var us := _units_of(who, args)
			var at = args[1]
			if at is Vector2:
				g._ping(g.on_map(at), Color(0.4, 1, 0.4))
				_face(us, at)
			g.command_sound(us, "move", "move")
		"morph_order", "cancel_morph", "mount_order", "lead_order", "harness_order", "mature_order":
			var us := _units_of(who, args)
			if fn == "morph_order" or fn == "mature_order":
				s.lead_stop(us, key)
			g.command_sound(us, "move", "move")


## Turn these units toward p at once (guest: until the host's picture shows them; host: the order turns them the same
## a moment later). Units busy firing keep their aim.
func _face(us: Array, p: Vector2) -> void:
	for u in us:
		if not (u is Unit) or not is_instance_valid(u) or u.dead or u.phase != "":
			continue
		var d: Vector2 = p - u.position
		if d.length() > 2.0:
			if s.is_host:
				if u.velocity.length() < 1.0:
					u.facing = d.normalized()
			else:
				s.face(u, d.normalized())


func _chase(us: Array, e: Entity, attack: bool, key: int) -> void:
	if us.is_empty() or e == null:
		return
	if s.is_host:
		_face(us, e.center())
		return
	for u in us:
		var reach: float = (u._range() if u.has_method("_range") else 30.0) if attack else 10.0
		s.lead_to(u, e, maxf(reach, 6.0), key)


func _chase_point(us: Array, p: Vector2, half: Vector2, key: int) -> void:
	if s.is_host:
		_face(us, p)
		return
	for u in us:
		s.lead_to(u, null, 10.0, key, Rect2(p - half, half * 2.0))


## The point at share f (0..1) along a polyline.
static func _along(pts: PackedVector2Array, f: float) -> Vector2:
	var total := 0.0
	for i in range(1, pts.size()):
		total += pts[i - 1].distance_to(pts[i])
	var want := total * clampf(f, 0.0, 1.0)
	for i in range(1, pts.size()):
		var seg := pts[i - 1].distance_to(pts[i])
		if want <= seg:
			return pts[i - 1].lerp(pts[i], want / maxf(seg, 0.001))
		want -= seg
	return pts[pts.size() - 1]


# ------------------------------------------------------------------ what an order changes (ops)

## The changes an order shows at once, as ops (see _apply_op). [] when nothing to show beyond the units' reaction.
func _ops(who: Object, fn: String, args: Array) -> Array:
	var g := game
	var t := game.human
	var ops: Array = []
	match fn:
		"train_any":
			var key := String(args[1])
			var best: Building = null
			for b in args[0]:
				if not (b is Building) or not is_instance_valid(b) or b.dead or b.team != t:
					continue
				if _can_train(b, key) != "":
					continue
				if best == null or b.queue.size() < best.queue.size():
					best = b
			if best == null:
				return []
			var price: Array = g.unit_price(t, key)
			var k := Defs.train_kind(key)
			ops.append(["res", "gold", -int(price[0])])
			if Defs.tension_cost(Defs.UNITS[k]) > 0:
				ops.append(["res", "tension", -float(price[1])])
			elif g.faction_of(t) != "clockwork" and int(price[1]) != 0:
				ops.append(["res", "res2", -float(price[1])])
			ops.append(["qadd", best, k])
		"start_research":
			var b: Building = args[0]
			var key := String(args[1])
			if not _ok(b) or g.research_problem(b, key) != "":
				return []
			var info: Dictionary = Defs.RESEARCH[key]
			ops.append(["res", "gold", -int(info["cost"])])
			if float(info.get("cost2", 0)) != 0.0:
				ops.append(["res", "res2", -float(info.get("cost2", 0))])
			if Defs.tension_cost(info) > 0:
				ops.append(["res", "tension", -float(Defs.tension_cost(info))])
			ops.append(["qadd", b, "@" + key])
		"cancel_train", "cancel_train_at":
			var b: Building = args[0]
			if not _ok(b):
				return []
			var q := _queue_now(b)
			if q.is_empty():
				return []
			var i := q.size() - 1 if fn == "cancel_train" else int(args[1])
			if i < 0 or i >= q.size():
				return []
			_refund_ops(ops, String(q[i]))
			ops.append(["qpop", b, -1 if fn == "cancel_train" else i])
		"place_building":
			var k := String(args[1])
			var c: Vector2i = args[2]
			if args.size() >= 6:
				g.set_gear_pick(t, k, int(args[5]) == 1)      # (GEAR PICK: the ring it goes on, its price)
			if g.placement_problem(t, k, c) != "" or int(_player(t)["gold"]) < g.build_price(t, k) or not g.requirement_met(t, k):
				return []
			ops.append(["res", "gold", -g.build_price(t, k)])
			if Defs.tension_cost(Defs.BUILDINGS[k]) > 0:
				ops.append(["res", "tension", -float(Defs.tension_cost(Defs.BUILDINGS[k]))])
			ops.append(["site", k, c])
		"abandon":
			var b: Building = args[0]
			if not _ok(b) or b.built:
				return []
			ops.append(["res", "gold", b.price() if b.ghost else int(b.price() * 0.75)])
			ops.append(["fade", b, Color(1, 1, 1, 0.2)])
		"demolish":
			var b: Building = args[0]
			if not _ok(b):
				return []
			ops.append(["fade", b, Color(1.0, 0.55, 0.45, 0.45)])
		"set_rally":
			var b: Building = args[0]
			if not _ok(b):
				return []
			var p: Vector2 = g.on_map(args[1])
			var which := String(args[2]) if args.size() > 2 else "auto"
			var e := g.entity_at(p)
			if b.dual_rally():
				var site: bool = e is Building and e.team == b.team and Defs.crew_cap(e.d) > 0
				if which == "auto":
					which = "worker" if site else "army"
				if which == "worker":
					ops.append(["prop", b, "worker_rally", p])
					ops.append(["prop", b, "worker_rally_target", e if site else null])
					return ops
				ops.append(["prop", b, "rally", p])
				ops.append(["prop", b, "rally_target", e if e is Unit and e.team == b.team and not e.dead and e.kind != "horse" else null])
				return ops
			ops.append(["prop", b, "rally", p])
			var rt = e if e is Building and e.team == b.team and Defs.crew_cap(e.d) > 0 else null
			if e is Unit and e.team == b.team and not e.dead and e.kind != "horse":
				rt = e
			ops.append(["prop", b, "rally_target", rt])
		"set_gate_locked":
			if _ok(args[0]):
				ops.append(["prop", args[0], "locked", bool(args[1])])
		"set_hold_fire":
			if who is Unit and (who as Unit).has_gun():
				ops.append(["prop", who, "hold_fire", bool(args[0])])
		"set_supply":
			if who is Unit:
				ops.append(["prop", who, "supplying", bool(args[0])])
		"cmd_deploy":
			var u: Unit = who
			if u.deploys() and u.tesla_mode == "packed" and u.aboard == null:
				ops.append(["prop", u, "tesla_mode", "deploying"])
				ops.append(["timer", u, "tesla_t", u.switch_time(), -1.0])
		"cmd_pack":
			var u: Unit = who
			if u.deploys() and u.tesla_mode == "deployed" and (u.harnessed or not Defs.HARNESSED.has(u.kind)):
				ops.append(["prop", u, "tesla_mode", "packing"])
				ops.append(["timer", u, "tesla_t", u.switch_time(), -1.0])
		"morph_order":
			var m: Dictionary = Defs.OWL_MORPH
			var gold := int(_player(t)["gold"])
			for u in _units_of(who, args):
				if u.kind != Defs.CUCKOO or CwAir.morph_problem(u) != "" or gold < int(m["cost"]):
					continue
				gold -= int(m["cost"])
				ops.append(["res", "gold", -int(m["cost"])])
				if float(m.get("tension", 0.0)) > 0.0:
					ops.append(["res", "tension", -float(m["tension"])])
				ops.append(["timer", u, "owl_t", 0.0, 1.0])
		_:
			if fn.begins_with("@") and who is Entity and NetCommands.PROPS.has(fn.substr(1)) and args.size() == 1:
				ops.append(["prop", who, fn.substr(1), args[0]])
	return ops


func _ok(b) -> bool:
	return b is Building and is_instance_valid(b) and not b.dead and b.team == game.human


## (train_any's own check, against the queue as shown: earlier pending entries count)
func _can_train(b: Building, key: String) -> String:
	var why := game.can_train(b, key)
	if why != "":
		return why
	var price: Array = game.unit_price(b.team, key)
	if int(_player(b.team)["gold"]) < int(price[0]):
		return "gold"
	return ""


## What a cancelled entry gives back (as Game.refund, without a kit's fee: the guest doesn't hold the kits).
func _refund_ops(ops: Array, k: String) -> void:
	if Building.is_research(k):
		var info: Dictionary = Defs.RESEARCH[k.substr(1)]
		ops.append(["res", "gold", int(info["cost"])])
		if float(info.get("cost2", 0)) != 0.0:
			ops.append(["res", "res2", float(info.get("cost2", 0))])
		if Defs.tension_cost(info) > 0:
			ops.append(["res", "tension", float(Defs.tension_cost(info))])
		return
	if not Defs.UNITS.has(k):
		return
	ops.append(["res", "gold", int(Defs.UNITS[k]["cost"])])
	if Defs.tension_cost(Defs.UNITS[k]) > 0:
		ops.append(["res", "tension", float(Defs.tension_cost(Defs.UNITS[k]))])
	elif game.faction_of(game.human) != "clockwork" and int(Defs.UNITS[k].get("cost2", 0)) != 0:
		ops.append(["res", "res2", float(Defs.UNITS[k].get("cost2", 0))])


# ------------------------------------------------------------------ guest: laid on and taken off

func _elapsed(e: Dictionary) -> float:
	return (_now() - int(e["t0"])) / 1000.0


func _patch(e: Dictionary, obj, name: String) -> void:
	if obj is Dictionary:
		(e["patch"] as Array).append([obj, name, (obj as Dictionary).get(name), true])
	else:
		(e["patch"] as Array).append([obj, name, (obj as Object).get(name), false])


func _apply(e: Dictionary) -> void:
	e["patch"] = []
	e["qi"] = []
	var el := _elapsed(e)
	for op in e["ops"]:
		match String(op[0]):
			"res":
				var pl: Dictionary = game.players[game.human]
				_patch(e, pl, op[1])
				if String(op[1]) == "gold":
					pl["gold"] = int(pl.get("gold", 0)) + int(op[2])
				else:
					pl[op[1]] = maxf(0.0, float(pl.get(op[1], 0.0)) + float(op[2])) if String(op[1]) == "tension" else float(pl.get(op[1], 0.0)) + float(op[2])
			"qadd":
				var b = op[1]
				if not is_instance_valid(b) or b.dead:
					continue
				_patch(e, b, "queue")
				var q: Array = (b.queue as Array).duplicate()
				q.append(op[2])
				if b.queue.is_empty():
					_patch(e, b, "prod_t")
					b.prod_t = el
				b.queue = q
				(e["qi"] as Array).append([b, q.size() - 1])
			"qpop":
				var b = op[1]
				if not is_instance_valid(b) or b.dead or b.queue.is_empty():
					continue
				var i := int(op[2])
				if i < 0 or i >= b.queue.size():
					i = b.queue.size() - 1
				_patch(e, b, "queue")
				var q: Array = (b.queue as Array).duplicate()
				q.remove_at(i)
				if i == 0:
					_patch(e, b, "prod_t")
					b.prod_t = 0.0
				b.queue = q
			"prop":
				var o = op[1]
				if is_instance_valid(o):
					_patch(e, o, op[2])
					o.set(op[2], op[3])
					if o is CanvasItem:
						(o as CanvasItem).queue_redraw()
			"timer":
				var o = op[1]
				if is_instance_valid(o):
					_patch(e, o, op[2])
					o.set(op[2], maxf(0.0, float(op[3]) + float(op[4]) * el))
			"fade":
				var b = op[1]
				if is_instance_valid(b):
					_patch(e, b, "modulate")     # (the node's own: its sprite's is set by the building itself every so often)
					b.modulate = op[2]


func _undo(e: Dictionary) -> void:
	var p: Array = e["patch"]
	for i in range(p.size() - 1, -1, -1):
		var pt: Array = p[i]
		if bool(pt[3]):
			(pt[0] as Dictionary)[pt[1]] = pt[2]
		elif is_instance_valid(pt[0]):
			(pt[0] as Object).set(pt[1], pt[2])
	e["patch"] = []
	e["qi"] = []


func _undo_all() -> void:
	for i in range(list.size() - 1, -1, -1):
		_undo(list[i])
	_applied = false


func _redo_all() -> void:
	for e in list:
		_apply(e)
	_applied = true


## Guest: before a snapshot is applied (its rows only bring what changed: what they don't name must be the host's).
func before_snapshot() -> void:
	if not list.is_empty():
		_undo_all()


## Guest: after it: the entries the host has answered go (the snapshot shows the real thing), the rest go back on.
func after_snapshot() -> void:
	if list.is_empty():
		return
	var now := _now()
	for e in list:
		if int(e["key"]) <= s.last_ack:
			# (answered: a site cancelled that the snapshot has just taken away stays faded for the frame it still
			# stands, instead of flashing back; a building that fell shows its ruin as the host's game made it)
			for op in e["ops"]:
				if String(op[0]) == "fade" and is_instance_valid(op[1]) and op[1].is_queued_for_deletion():
					op[1].modulate = op[2]
	var keep: Array = []
	for e in list:
		if now - int(e["t0"]) >= MAX_MS:
			continue
		if int(e["key"]) > s.last_ack:
			keep.append(e)
			continue
		# Answered. What it spent, queued or placed is in this snapshot now; a setting, a timer or a fade stays one picture
		# more: a unit's slower values come in every other picture (NetSnapshot.build "halves"), and the one with the
		# answer may not carry them yet (without this a hold fire or a deploy flickered back for a picture).
		if not e.has("acked"):
			e["acked"] = now
			e["ops"] = (e["ops"] as Array).filter(func(op: Array) -> bool: return LINGER.has(String(op[0])))
			if not (e["ops"] as Array).is_empty():
				keep.append(e)
		elif now - int(e["acked"]) < FADE_MS:
			# (a building told to go stays faded until the host's pictures take it away: its death can come a tick later)
			e["ops"] = (e["ops"] as Array).filter(func(op: Array) -> bool: return String(op[0]) == "fade" and is_instance_valid(op[1]) and not op[1].dead)
			if not (e["ops"] as Array).is_empty():
				keep.append(e)
	list = keep
	_redo_all()
	_redraw_sites()


## Guest, each game tick: the timers move on (a progress bar, a deploy).
func tick() -> void:
	if list.is_empty():
		return
	if s.is_host:
		if _view and is_instance_valid(_view):
			_view.queue_redraw()
		return
	var now := _now()
	_undo_all()
	list = list.filter(func(e: Dictionary) -> bool: return now - int(e["t0"]) < MAX_MS)
	_redo_all()
	if _view and is_instance_valid(_view):
		_view.queue_redraw()


## Guest: the host refused order `key` (with the reason, shown by NetSession): it is taken back now.
func refused(key: int) -> void:
	var hit := list.filter(func(e: Dictionary) -> bool: return int(e["key"]) == key)
	s.lead_cancel(key)
	if hit.is_empty():
		return
	_undo_all()
	list = list.filter(func(e: Dictionary) -> bool: return int(e["key"]) != key)
	undone_n += hit.size()
	_redo_all()
	_redraw_sites()


## Host: its held order `key` has run (the real game shows it now).
func ran(key: int) -> void:
	if list.is_empty():
		return
	list = list.filter(func(e: Dictionary) -> bool: return int(e["key"]) != key and _now() - int(e["t0"]) < MAX_MS)
	_redraw_sites()


# ------------------------------------------------------------------ what the HUD shows

## Player t's resources as shown: on the host its waiting orders' spending on top of the real values (a copy); on a
## guest the puppet's own (the entries are laid on it already).
static func shown_player(g: Game, t: int) -> Dictionary:
	if g.net == null or g.net.predict == null or not g.net.is_host or t != g.human or g.net.predict.list.is_empty():
		return g.players[t]
	var pl: Dictionary = (g.players[t] as Dictionary).duplicate()
	for e in g.net.predict.list:
		for op in e["ops"]:
			if String(op[0]) == "res":
				if String(op[1]) == "gold":
					pl["gold"] = int(pl.get("gold", 0)) + int(op[2])
				else:
					pl[op[1]] = float(pl.get(op[1], 0.0)) + float(op[2])
	return pl


## Supply the host's waiting orders add (a guest's are in its queues already).
static func shown_supply(g: Game, t: int) -> int:
	var n := g.supply_used(t)
	if g.net == null or g.net.predict == null or not g.net.is_host or t != g.human:
		return n
	for e in g.net.predict.list:
		for op in e["ops"]:
			if String(op[0]) == "qadd" and not Building.is_research(String(op[2])) and Defs.UNITS.has(String(op[2])):
				n += int(Defs.UNITS[op[2]]["supply"]) * int(Defs.UNITS[op[2]].get("spawn", 1))
			elif String(op[0]) == "qpop" and is_instance_valid(op[1]):
				var q: Array = op[1].queue
				var i := int(op[2])
				var k := String(q[q.size() - 1 if i < 0 or i >= q.size() else i]) if not q.is_empty() else ""
				if k != "" and not Building.is_research(k) and Defs.UNITS.has(k):
					n -= int(Defs.UNITS[k]["supply"]) * int(Defs.UNITS[k].get("spawn", 1))
	return n


## A building's queue as shown: [entries, pending (one bool each: not confirmed by the host yet), the first one's
## progress time (prod_t)].
static func shown_queue(g: Game, b: Building) -> Array:
	var q: Array = b.queue
	if g.net == null or g.net.predict == null or g.net.predict.list.is_empty():
		return [q, [], b.prod_t]
	var p: NetPredict = g.net.predict
	var flags: Array = []
	if not g.net.is_host:
		flags.resize(q.size())
		flags.fill(false)
		for e in p.list:
			for qi in e["qi"]:
				if qi[0] == b and int(qi[1]) < flags.size():
					flags[int(qi[1])] = true
		return [q, flags, b.prod_t]
	# host: the real queue with the waiting entries on top
	var out: Array = q.duplicate()
	flags.resize(out.size())
	flags.fill(false)
	var prod := b.prod_t
	for e in p.list:
		for op in e["ops"]:
			if (String(op[0]) != "qadd" and String(op[0]) != "qpop") or op[1] != b:
				continue
			if String(op[0]) == "qadd":
				if out.is_empty():
					prod = p._elapsed(e)
				out.append(op[2])
				flags.append(true)
			elif String(op[0]) == "qpop" and not out.is_empty():
				var i := int(op[2])
				if i < 0 or i >= out.size():
					i = out.size() - 1
				out.remove_at(i)
				flags.remove_at(i)
				if i == 0:
					prod = 0.0
	return [out, flags, prod]


func _player(t: int) -> Dictionary:
	return NetPredict.shown_player(game, t)


func _queue_now(b: Building) -> Array:
	return NetPredict.shown_queue(game, b)[0]


## Pending entries anywhere (tests).
func pending() -> int:
	return list.size()


# ------------------------------------------------------------------ the pending building sites

func sites() -> Array:
	var out: Array = []
	for e in list:
		for op in e["ops"]:
			if String(op[0]) == "site":
				out.append([op[1], op[2], e])
	return out


func _redraw_sites() -> void:
	var any := not sites().is_empty()
	if any and (_view == null or not is_instance_valid(_view)):
		_view = Node2D.new()
		_view.z_index = -1
		_view.draw.connect(_draw_sites)
		game.add_child(_view)
	if _view and is_instance_valid(_view):
		_view.queue_redraw()


## A site that waits for the host: the building's picture faint and breathing, its footprint outlined in dashes.
func _draw_sites() -> void:
	var list_s := sites()
	if not list_s.is_empty():
		sites_seen += 1
	var pulse := 0.5 + 0.5 * sin(_now() / 160.0)
	var col := game.team_colour(game.human)
	for st in list_s:
		var k := String(st[0])
		var c: Vector2i = st[1]
		var size: Vector2i = Defs.BUILDINGS[k]["size"]
		var r := Rect2(Vector2(c) * Defs.TILE, Vector2(size) * Defs.TILE)
		_view.draw_rect(r, Color(col.r, col.g, col.b, 0.10 + 0.08 * pulse))
		var tx: Texture2D = null
		for state in ["construction", "built"]:
			var path := "res://assets/buildings/%s_%s.png" % [k, state]
			if tx == null and ResourceLoader.exists(path):
				tx = Game.tex(path)
		if tx:
			var at := Building.anchor(k, r) + Building.body_offset(k, tx)
			_view.draw_texture(tx, at, Color(1, 1, 1, 0.25 + 0.2 * pulse))
		var dash := 6.0
		var pts := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.position]
		for i in 4:
			_view.draw_dashed_line(pts[i], pts[i + 1], Color(1, 0.88, 0.4, 0.55 + 0.35 * pulse), 1.5, dash)
