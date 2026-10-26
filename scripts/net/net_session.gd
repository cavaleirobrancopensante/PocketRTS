class_name NetSession
extends Node
## An online match in progress, attached to the Game (game.net).
## HOST: the real game and the computer players run here. Every 0.1 s the whole picture goes to the
## guests (NetSnapshot.build); their orders come back as commands (NetCommands.apply).
## GUEST: the game is a puppet (game.puppet): it applies snapshots and sends its orders as commands.
## The players are the game's teams: `peer_team` maps a guest's relay id to the team it plays (a
## second guest on the same side is a 2v1 co-op, a team vs a computer side, nothing more to build).

signal lost(why: String)

const SNAP_EVERY := 0.1

var game: Game
var link: NetLink
var is_host := true
var my_team := 0                  # the team this machine plays
var peer_team := {}               # host: relay id -> team
var by_id := {}                   # net id -> Entity (as of the last snapshot)
var known := {}                   # host: the ids the last snapshot listed
var next_id := 1
var snap_n := 0                   # host: snapshots sent / guest: the last one applied
var interval := SNAP_EVERY        # guest: seconds between snapshots, smoothed
var motion := {}                  # guest: id -> [from, to, seconds since]
var rowhash := {}                 # guest: id -> hash of the last row applied
var acks := {}                    # host: relay id -> the last command number run for it
var cmd_seq := 0                  # guest: commands sent
var last_ack := 0                 # guest: the host has run commands up to this one
var sent_at := {}                 # guest: command number -> msec it was sent
var cmd_rtt_ms := 0.0             # guest: sent -> seen in a snapshot
var cmds_applied := 0
var cmds_rejected := 0
var snaps_got := 0
var last_reject := ""
var trace := false
var _t := 0.0
var over_sent := 0
var fx: Array = []                # host: effects and shots since the last snapshot
var lost_peers := {}              # host: relay ids of guests who left
var count_diff_max := 0           # guest (tests): the most entities a snapshot left different from the host's list
var count_diff_snaps := 0
var line_fp := -1                 # host: fingerprint of the Line in the last snapshot that carried it
var _last_snap_ms := 0


## Create the session on a Game (after it is in the tree).
static func attach(g: Game, lnk: NetLink, host: bool, team: int, peers: Dictionary) -> NetSession:
	var s := NetSession.new()
	s.game = g
	s.link = lnk
	s.is_host = host
	s.my_team = team
	s.peer_team = peers
	s.process_mode = Node.PROCESS_MODE_ALWAYS
	g.net = s
	g.add_child(s)
	lnk.message.connect(s._on_message)
	lnk.notice.connect(s._on_notice)
	lnk.closed.connect(s._on_closed)
	return s


func assign(e: Entity) -> void:
	if e.net_id == 0:
		e.net_id = next_id
		next_id += 1


func _process(delta: float) -> void:
	if not is_host:
		return
	_t += delta
	if _t < SNAP_EVERY:
		return
	_t = 0.0
	if game.over:
		over_sent += 1
		if over_sent > 20:
			return                  # (the end has been told; stop)
	snap_n += 1
	link.send(NetSnapshot.build(self), 0)


## All the players of this machine's side are out (a friend still playing keeps the match going).
func humans_out() -> bool:
	if not game.eliminated[game.human]:
		return false
	for pr in peer_team:
		if not game.eliminated[int(peer_team[pr])] and not lost_peers.has(pr):
			return false
	return true


# ------------------------------------------------------------------ host: sights and shots for the guests

const FX_SENT := ["hit", "smoke", "smoke_big", "dust", "explosion", "burst", "flame", "blast", "blaze", "acid_splash",
	"zap_strike", "zap_spark_y", "zap_burst", "zap_burst_y", "arc_impact", "bloat_cloud"]
const FX_MAX := 60


func note_effect(name: String, p: Vector2, speed: float, looping: bool) -> void:
	if looping or fx.size() >= FX_MAX or not FX_SENT.has(name):
		return
	fx.append(["e", name, p, speed])


func note_shot(s: Shot, kind: String, a: Vector2, b: Vector2, spd: float) -> void:
	if fx.size() < FX_MAX:
		fx.append(["s", kind, a, b, spd, s.face_offset, s.scale.x, s.impact, s.impact_scale, s.arc])


## A Ticking Owl let its weight go (CwAir.drop_bomb): the guest sees it fall and burst (the host's bomb does the damage).
func note_bomb(b: OwlBomb) -> void:
	if fx.size() < FX_MAX:
		fx.append(["b", "", b.from, b.to, b.ground_from, b.duration])


## A Netter's net left the muzzle (Netter.fire): the guest sees it fly at its copy of the target (the host's net catches).
func note_net(cn: ChainNet) -> void:
	if fx.size() < FX_MAX and cn.target != null and is_instance_valid(cn.target):
		assign(cn.target)
		fx.append(["n", "", cn.from, cn.target.net_id, cn.speed])


## Guest: play what the host saw happen since the last snapshot.
func play_fx(list: Array) -> void:
	for f in list:
		var p: Vector2 = f[2]
		if not game.view_rect.has_point(p):
			continue
		if f[0] == "e":
			game.spawn_effect(String(f[1]), p, float(f[3]))
		elif f[0] == "b":
			var ob := OwlBomb.new()       # (the falling weight, as a picture: it bursts where it lands)
			ob.game = game
			ob.view = true
			ob.from = p
			ob.to = f[3]
			ob.ground_from = f[4]
			ob.duration = float(f[5])
			game.add_child(ob)
		elif f[0] == "n":
			var tg = by_id.get(int(f[3]))
			if not is_instance_valid(tg) or not (tg is Unit):
				continue
			var cn := ChainNet.new()      # (the net in flight, as a picture: the host's catches)
			cn.game = game
			cn.view = true
			cn.from = p
			cn.target = tg
			cn.speed = float(f[4])
			game.add_child(cn)
		else:
			var s := Shot.new()
			s.face_offset = float(f[5])
			s.scale = Vector2(float(f[6]), float(f[6]))
			s.impact = String(f[7])
			s.impact_scale = float(f[8])
			s.arc = float(f[9])
			s.launch(game, String(f[1]), p, f[3], float(f[4]))


# ------------------------------------------------------------------ guest: orders out

func send_cmd(c: Dictionary) -> void:
	cmd_seq += 1
	c["t"] = "cmd"
	c["s"] = cmd_seq
	sent_at[cmd_seq] = Time.get_ticks_msec()
	link.send(c)
	if trace:
		print("[net] guest sent #%d %s" % [cmd_seq, c.get("f")])


# ------------------------------------------------------------------ messages in

func _on_message(from: int, m: Dictionary) -> void:
	match String(m.get("t", "")):
		"cmd":
			if not is_host:
				return
			var why := NetCommands.apply(self, from, m)
			acks[from] = int(m.get("s", 0))
			if why == "":
				cmds_applied += 1
				if trace:
					print("[net] host ran #%d %s from %d" % [int(m.get("s", 0)), m.get("f"), from])
			else:
				cmds_rejected += 1
				last_reject = why
				if trace:
					print("[net] host refused #%d %s: %s" % [int(m.get("s", 0)), m.get("f"), why])
				if why.length() > 8 and why[0] == why[0].to_upper() and not why.begins_with("not ") and not why.begins_with("unknown"):
					link.send({"t": "msg", "m": why}, from)       # (a game reason: "Not enough gold." ...)
		"snap":
			if is_host:
				return
			var now := Time.get_ticks_msec()
			if _last_snap_ms > 0:
				interval = clampf(lerpf(interval, float(now - _last_snap_ms) / 1000.0, 0.2), 0.05, 0.4)
			_last_snap_ms = now
			snaps_got += 1
			snap_n = int(m.get("n", snap_n))
			var ack := int(m.get("ack", {}).get(link.my_id, 0)) if m.get("ack") is Dictionary else 0
			if ack > last_ack:
				if sent_at.has(ack):
					cmd_rtt_ms = float(now - int(sent_at[ack]))
				last_ack = ack
				for k in sent_at.keys():
					if int(k) <= ack:
						sent_at.erase(k)
			NetSnapshot.apply(self, m)
		"msg":
			game.notify(String(m.get("m", "")))


func _on_notice(d: Dictionary) -> void:
	if String(d.get("t", "")) == "leave" and is_host:
		var team: int = peer_team.get(int(d.get("id", -1)), -1)
		var who := game.team_name(team).capitalize() if team >= 0 else "A friend"
		game.notify("%s left the game. A computer plays on." % who)
		if game.mlog and team >= 0:
			game.mlog.add("(online) %s's player disconnected: a computer takes over" % game.mlog.who(team))
		if team >= 0 and not game.over and not lost_peers.has(int(d.get("id", -1))):
			lost_peers[int(d.get("id", -1))] = true
			if not game.eliminated[team]:
				var ai := AI.new()                  # (their side is not left standing still)
				ai.game = game
				ai.team = team
				ai.difficulty = 1
				ai.strategy = "balanced"
				game.add_child(ai)
				game.ais.append(ai)


func _on_closed(why: String) -> void:
	if game and is_instance_valid(game) and not game.over:
		game.notify(why)
	lost.emit(why)
