class_name NetLobby
extends Node
## The waiting room of an online game, with no screen of its own (the MULTIPLAYER page, ui/multiplayer_menu.gd,
## shows it; tests drive it directly). The host opens a room (a short code), friends join with the
## code, the host picks map and mode and starts. The slots are the same as the skirmish's: the host
## is slot 0 ("you"), a friend takes a "remote" slot, the rest are computers; slots with the same
## `side` are allies. 1v1 = [you side 0, remote side 1]; 2v1 co-op = [you 0, remote 0, computer 1].

signal changed                           # slots, status or people changed: redraw
signal start_now(cfg: Dictionary)        # guest: the host started: hand cfg to Main.start
signal failed(why: String)               # could not connect / refused / the host left
signal pinged                            # a new round trip to the other player(s) was measured (ping_ms)

const MODES := ["1v1", "coop"]
const MODE_LABEL := {"1v1": "1 VS 1", "coop": "2 VS COMPUTER (CO-OP)", "custom": "CUSTOM TEAMS"}
const FACTIONS := ["random", "crown", "brood", "clockwork"]
const LEVELS := ["easy", "normal", "hard", "brutal"]     # the computer's difficulty (the host picks it)

var link: NetLink
var is_host := false
var code := ""
var map := "random_1v1"
var mode := "1v1"
var slots: Array = []                    # host: with "peer" (relay id, -1 waiting); guest: as the host sent
var my_slot := 0                         # guest: the slot the host gave us
var status := "Connecting..."
var online := false                       # connected and (guest) seated
var refused := ""
var version: String = ProjectSettings.get_setting("application/config/version", "dev")
var strategy_ai := "hard"
var denied := 0                          # host: how many colour / team picks were refused
## The same delay for both players (the host's choice, on unless turned off): the host's own orders wait as long as a
## guest's take to reach it (NetSession.hold_ms), so neither side reacts faster.
var same_delay := true
## Joining: the guest says "hi" every HI_EVERY s until the room arrives (a first word lost on the way, or said before
## the host's page was ready, left the room empty); after NO_ANSWER s with nothing it says so (and keeps trying).
## The host sends the room again to a guest who says hi twice, and every RESEND s anyway. Both measure the round
## trip to the other side (ping_ms) every PING_EVERY s.
const HI_EVERY := 2.0
const NO_ANSWER := 8.0
const RESEND := 3.0
const PING_EVERY := 2.0
var ping_ms := -1                        # the last round trip to the host (host: to the slowest friend); -1: none yet
var ping_of := {}                        # host: relay id -> its last round trip
var started := false                     # the match began: the session has the link now
var _got_lobby := false                  # guest: the host's room has come
var _lobby_hash := 0
var _hi_t := 0.0
var _wait_t := 0.0
var _resend_t := 0.0
var _ping_t := 0.0
var _ping_k := 0
var _ping_out := {}
var _no_answer := false


## Host a game: `relay` is the relay's address, `room` a code (NetLink.new_code()).
func host(relay: String, room: String) -> void:
	is_host = true
	code = room
	_link(relay)
	_preset(mode)
	link.open(relay, code, true)


func join(relay: String, room: String) -> void:
	is_host = false
	code = room.strip_edges().to_upper()
	_link(relay)
	link.open(relay, code, false)


func _link(_relay: String) -> void:
	link = NetLink.new()
	add_child(link)
	link.opened.connect(_on_opened)
	link.notice.connect(_on_notice)
	link.message.connect(_on_message)
	link.closed.connect(func(why: String) -> void:
		online = false
		status = why
		failed.emit(why))


func dispose() -> void:
	if link:
		link.close("bye")
	queue_free()


# ------------------------------------------------------------------ host

func _slot(who: String, side: int, peer := -1) -> Dictionary:
	var s := {"who": who, "faction": "random", "colour": Defs.COLOUR_FITS_MAP, "side": side, "peer": peer}
	if who != "you" and who != "remote":
		s["strategy"] = "balanced"
	return s


func _preset(m: String) -> void:
	var old: Array = slots
	mode = m
	slots = [_slot("you", 0), _slot("remote", 0 if m == "coop" else 1)]
	if m == "coop":
		slots.append(_slot(strategy_ai, 1))
	# keep what was chosen (faction, colour, the computer's level) and who sits where
	for i in mini(old.size(), slots.size()):
		var same: bool = old[i]["who"] == slots[i]["who"] or (_is_computer(old[i]) and _is_computer(slots[i]))
		if same:
			slots[i]["faction"] = old[i]["faction"]
			slots[i]["colour"] = int(old[i].get("colour", Defs.COLOUR_FITS_MAP))
			slots[i]["peer"] = old[i].get("peer", -1)
			if _is_computer(old[i]):
				slots[i]["who"] = old[i]["who"]
	changed.emit()
	_send_lobby()


func set_mode(m: String) -> void:
	if not is_host or not MODES.has(m):
		return
	_preset(m)
	if MapGen.is_pool(map) or not map_fits(map):
		map = "random_1v1" if m == "1v1" else "random_2v2"      # (the 2v2 maps have four start spots)
	changed.emit()
	_send_lobby()


## Does this map (or random pool) hold everyone in the room?
func map_fits(id: String) -> bool:
	if MapGen.is_pool(id):
		return not MapGen.pool_maps(id, slots.size()).is_empty()
	if id.begins_with("custom:"):
		return false
	return MapGen.max_players(id) >= slots.size()


func set_map(id: String) -> void:
	if map_fits(id):
		map = id
		changed.emit()
		_send_lobby()


static func _is_computer(s: Dictionary) -> bool:
	return s["who"] != "you" and s["who"] != "remote"


func set_faction(i: int, f: String) -> void:
	if i >= 0 and i < slots.size() and FACTIONS.has(f):
		slots[i]["faction"] = f
		changed.emit()
		_send_lobby()


## Is this palette colour already worn by another slot? (RANDOM and FITS MAP may repeat: they are
## made different when the match starts.)
func colour_taken(c: int, except: int) -> bool:
	if c < 0:
		return false
	for j in slots.size():
		if j != except and int(slots[j].get("colour", Defs.COLOUR_FITS_MAP)) == c:
			return true
	return false


## Give slot `i` a colour. Refused (false) when another player already has it or it is no colour.
func set_colour(i: int, c: int) -> bool:
	if i < 0 or i >= slots.size() or c < Defs.COLOUR_FITS_MAP or c >= Defs.PALETTE.size() or colour_taken(c, i):
		denied += 1
		return false
	slots[i]["colour"] = c
	changed.emit()
	_send_lobby()
	return true


## The host puts slot `i` on team `side` (0-based). At least two teams are needed to start.
func set_side(i: int, side: int) -> void:
	if not is_host or i < 0 or i >= slots.size() or side < 0 or side >= slots.size():
		return
	slots[i]["side"] = side
	mode = _mode_of_sides()
	changed.emit()
	_send_lobby()


func _mode_of_sides() -> String:
	var sides: Array = slots.map(func(s: Dictionary) -> int: return int(s["side"]))
	if sides == [0, 1]:
		return "1v1"
	if sides == [0, 0, 1]:
		return "coop"
	return "custom"


## The host turns the same delay for both players on or off.
func set_same_delay(on: bool) -> void:
	if is_host:
		same_delay = on
		changed.emit()
		_send_lobby()


## The host sets the difficulty of the computer in slot `i`.
func set_level(i: int, lvl: String) -> void:
	if is_host and i >= 0 and i < slots.size() and _is_computer(slots[i]) and LEVELS.has(lvl):
		slots[i]["who"] = lvl
		strategy_ai = lvl
		changed.emit()
		_send_lobby()


## The host sets the plan (strategy) of the computer in slot `i`; it travels in the slots to the guest and in make_cfg to the match.
func set_strategy(i: int, st: String) -> void:
	if is_host and i >= 0 and i < slots.size() and _is_computer(slots[i]) and (st == "random" or AI.STRATEGIES.has(st)):
		slots[i]["strategy"] = st
		changed.emit()
		_send_lobby()


## What stops the host from starting ("" = nothing).
func problem() -> String:
	var sides := {}
	for s in slots:
		sides[int(s["side"])] = true
	if sides.size() < 2:
		return "Everyone is on one team."
	if not all_seated():
		return "Waiting for your friend to join."
	return ""


## Everyone who is going to play has arrived.
func all_seated() -> bool:
	for s in slots:
		if s["who"] == "remote" and int(s.get("peer", -1)) < 0:
			return false
	return online


func _public_slots() -> Array:
	var out: Array = []
	for s in slots:
		var c: Dictionary = s.duplicate()
		c["here"] = s["who"] != "remote" or int(s.get("peer", -1)) >= 0
		c.erase("peer")
		out.append(c)
	return out


func _send_lobby() -> void:
	if not is_host or not link or not link.connected:
		return
	for i in slots.size():
		if slots[i]["who"] == "remote" and int(slots[i].get("peer", -1)) >= 0:
			link.send({"t": "lobby", "map": map, "mode": mode, "slots": _public_slots(), "you": i, "same": same_delay}, int(slots[i]["peer"]))


## Start the match (host). Main.start(cfg) builds the game and calls begin() with the resolved cfg.
func make_cfg() -> Dictionary:
	var sl: Array = []
	for s in slots:
		var c: Dictionary = s.duplicate()
		c.erase("here")
		sl.append(c)
	return {"map": map, "slots": sl, "seed": randi(), "net": {"role": "host", "lobby": self}}


# ------------------------------------------------------------------ both

## Main.start made the game: tell the guests and open the session. `cfg` is the resolved setup
## (factions, colours, map) that both sides build the same match from.
func begin(game: Game, cfg: Dictionary) -> void:
	started = true
	if is_host:
		var peers := {}
		for i in cfg["slots"].size():
			var pr := int(cfg["slots"][i].get("peer", -1))
			if cfg["slots"][i]["who"] == "remote" and pr >= 0:
				peers[pr] = i
		for pr in peers:
			var gc := _guest_cfg(cfg, int(peers[pr]))
			link.send({"t": "start", "cfg": gc, "team": int(peers[pr]), "same": same_delay}, int(pr))
		NetSession.attach(game, link, true, 0, peers, same_delay)
	else:
		NetSession.attach(game, link, false, my_slot, {}, same_delay)


func _guest_cfg(cfg: Dictionary, team: int) -> Dictionary:
	var c := {"map": cfg["map"], "seed": cfg["seed"], "slots": []}
	for i in cfg["slots"].size():
		var s: Dictionary = cfg["slots"][i].duplicate()
		s.erase("peer")
		s["who"] = "you" if i == team else ("remote" if cfg["slots"][i]["who"] in ["you", "remote"] else "easy")
		c["slots"].append(s)
	return c


# ------------------------------------------------------------------ relay

func _on_opened(_id: int) -> void:
	if is_host:
		status = "Room %s is open. Tell your friend the code." % code
	else:
		status = "Joined room %s. Waiting for the host..." % code
		link.send({"t": "hi", "ver": version})
		_hi_t = HI_EVERY
		_wait_t = 0.0
	online = true
	changed.emit()


func _process(delta: float) -> void:
	if not online or started or link == null or not link.is_open():
		return
	if not is_host and not _got_lobby:
		_hi_t -= delta
		_wait_t += delta
		if _hi_t <= 0.0:
			_hi_t = HI_EVERY
			link.send({"t": "hi", "ver": version})
		if _wait_t >= NO_ANSWER and not _no_answer:
			_no_answer = true
			status = "No answer from the host yet. Check the room code, and that the host's room is still open. Still trying..."
			changed.emit()
	if is_host:
		_resend_t -= delta
		if _resend_t <= 0.0:
			_resend_t = RESEND
			_send_lobby()            # (a room lost on the way is put right within a few seconds)
	_ping_t -= delta
	if _ping_t <= 0.0 and (is_host or _got_lobby):
		_ping_t = PING_EVERY
		_ping_k += 1
		_ping_out[_ping_k] = Time.get_ticks_msec()
		link.send({"t": "lping", "k": _ping_k}, 0)
		if _ping_out.size() > 30:
			_ping_out.erase(_ping_out.keys().min())


## The round trip shown in the room: "Ping to the host: 85 ms" ("" before the first).
func ping_text() -> String:
	if ping_ms < 0:
		return ""
	return (Loc.t("Ping to your friend: %d ms") if is_host else Loc.t("Ping to the host: %d ms")) % ping_ms


func _on_notice(d: Dictionary) -> void:
	match String(d.get("t", "")):
		"error":
			refused = String(d.get("m", "Refused."))
			status = refused
			failed.emit(refused)
		"closed":
			status = "The host left the game."
			online = false
			failed.emit(status)
		"leave":
			if is_host:
				for s in slots:
					if int(s.get("peer", -1)) == int(d.get("id", -2)):
						s["peer"] = -1
				ping_of.erase(int(d.get("id", -2)))
				status = "Your friend left. Waiting for someone to join."
				changed.emit()
				_send_lobby()


func _on_message(from: int, m: Dictionary) -> void:
	match String(m.get("t", "")):
		"hi":
			if not is_host:
				return
			if String(m.get("ver", "")) != version:
				link.send({"t": "refuse", "m": "The host plays version %s, you play %s. Both need the same version." % [version, m.get("ver", "?")]}, from)
				return
			for s in slots:
				if s["who"] == "remote" and int(s.get("peer", -1)) == from:
					_send_lobby()            # (seated, but its room never came: again)
					return
			for s in slots:
				if s["who"] == "remote" and int(s.get("peer", -1)) < 0:
					s["peer"] = from
					status = "A friend joined."
					changed.emit()
					_send_lobby()
					return
			link.send({"t": "refuse", "m": "The room is full."}, from)
		"set":
			if not is_host:
				return
			var seat := -1
			for i in slots.size():
				if slots[i]["who"] == "remote" and int(slots[i].get("peer", -1)) == from:
					seat = i
			if seat < 0:
				return
			if m.has("faction") and FACTIONS.has(String(m["faction"])):
				slots[seat]["faction"] = String(m["faction"])
			var bad := false
			if m.has("colour"):
				var c := int(m["colour"])
				if c < Defs.COLOUR_FITS_MAP or c >= Defs.PALETTE.size() or colour_taken(c, seat):
					denied += 1
					bad = true
				else:
					slots[seat]["colour"] = c
			changed.emit()
			_send_lobby()
			if bad:
				link.send({"t": "deny", "m": "That colour is already taken."}, from)
		"lping":
			link.send({"t": "lpong", "k": int(m.get("k", 0))}, from)
		"lpong":
			var k := int(m.get("k", 0))
			if _ping_out.has(k):
				var rtt := Time.get_ticks_msec() - int(_ping_out[k])
				_ping_out.erase(k)
				if is_host:
					ping_of[from] = rtt
					ping_ms = 0
					for pr in ping_of:
						ping_ms = maxi(ping_ms, int(ping_of[pr]))
				else:
					ping_ms = rtt
				pinged.emit()
		"deny":
			if not is_host:
				status = String(m.get("m", "Refused."))
				changed.emit()
		"lobby":
			if is_host:
				return
			map = String(m.get("map", map))
			mode = String(m.get("mode", mode))
			same_delay = bool(m.get("same", same_delay))
			var hs := hash([m.get("map"), m.get("mode"), m.get("same"), m.get("slots"), m.get("you")])
			if _got_lobby and hs == _lobby_hash:
				return                  # (the host's regular resend: nothing new, the page is left as it is)
			_lobby_hash = hs
			slots = m.get("slots", [])
			my_slot = int(m.get("you", 0))
			if not _got_lobby or _no_answer:
				status = "In the room. The host starts the game."
			_got_lobby = true
			_no_answer = false
			changed.emit()
		"refuse":
			refused = String(m.get("m", "Refused."))
			status = refused
			online = false
			failed.emit(refused)
		"start":
			if is_host:
				return
			var c: Dictionary = m["cfg"]
			my_slot = int(m.get("team", my_slot))
			same_delay = bool(m.get("same", same_delay))
			started = true
			c["net"] = {"role": "guest", "lobby": self}
			start_now.emit(c)


## Guest: choose my faction.
func choose_faction(f: String) -> void:
	if not is_host:
		link.send({"t": "set", "faction": f})


## Guest: choose my colour (the host refuses one somebody else has).
func choose_colour(c: int) -> void:
	if not is_host:
		link.send({"t": "set", "colour": c})
