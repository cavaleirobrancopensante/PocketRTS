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

const MODES := ["1v1", "coop"]
const MODE_LABEL := {"1v1": "1 VS 1", "coop": "2 VS COMPUTER (CO-OP)"}

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
	# keep what was chosen and who sits where
	for i in mini(old.size(), slots.size()):
		if old[i]["who"] == slots[i]["who"]:
			slots[i]["faction"] = old[i]["faction"]
			slots[i]["peer"] = old[i].get("peer", -1)
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


func set_faction(i: int, f: String) -> void:
	if i >= 0 and i < slots.size():
		slots[i]["faction"] = f
		changed.emit()
		_send_lobby()


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
			link.send({"t": "lobby", "map": map, "mode": mode, "slots": _public_slots(), "you": i}, int(slots[i]["peer"]))


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
	if is_host:
		var peers := {}
		for i in cfg["slots"].size():
			var pr := int(cfg["slots"][i].get("peer", -1))
			if cfg["slots"][i]["who"] == "remote" and pr >= 0:
				peers[pr] = i
		for pr in peers:
			var gc := _guest_cfg(cfg, int(peers[pr]))
			link.send({"t": "start", "cfg": gc, "team": int(peers[pr])}, int(pr))
		NetSession.attach(game, link, true, 0, peers)
	else:
		NetSession.attach(game, link, false, my_slot, {})


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
	online = true
	changed.emit()


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
			for s in slots:
				if s["who"] == "remote" and int(s.get("peer", -1)) == from and ["crown", "brood", "clockwork", "random"].has(String(m.get("faction", ""))):
					s["faction"] = String(m["faction"])
			changed.emit()
			_send_lobby()
		"lobby":
			if is_host:
				return
			map = String(m.get("map", map))
			mode = String(m.get("mode", mode))
			slots = m.get("slots", [])
			my_slot = int(m.get("you", 0))
			status = "In the room. The host starts the game."
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
			c["net"] = {"role": "guest", "lobby": self}
			start_now.emit(c)


## Guest: choose my faction.
func choose_faction(f: String) -> void:
	if not is_host:
		link.send({"t": "set", "faction": f})
