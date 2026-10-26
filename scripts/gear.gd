class_name GearNet
extends Node2D
## THE GEAR FIELD (the Clockwork's base, docs/clockwork_gear_prototype.md; every number in Defs.GEAR).
##
## Every Clockwork building has a ring of real gears set into the ground round it (a toothed ring, drawn in code):
## radius = half its footprint + a pad (a SMALL or a BIG connecting gear; the Clocktower's is the biggest), rounded to a
## whole number of teeth. Rings that touch MESH: neighbours counter-rotate, a small gear spins faster than a big one and
## the teeth interlock (each gear's angle is worked out from its parent's in the connection tree, so the mesh is exact).
##
## CONNECTED: a finished building is connected if its ring touches a ring that is connected, down to a finished Clocktower
## (a Clocktower is a root: its own field). The graph is recomputed at once when anything changes and every 0.5 s.
## An unconnected building: gears stopped, `speed_mult` 0 (production, repairs, income), "UNLINKED" over it. A building
## that dies leaves its ring stopped; whatever hung on it alone is unlinked. Constructs stay wound on connected gear
## ground (Game.in_field asks here). The placement rule (placement_problem): a new building's ring must touch the
## connected field and may not cut deeper than Defs.GEAR.overlap into another ring (a Clocktower is the exception).

const T := Defs.TILE
const FY := Game.FIELD_Y

var game: Game
var enforce := true              # false: unconnected buildings work anyway (old tests, sandbox)
var linked := {}                 # Building -> true: connected
var parent_of := {}              # Building -> the building it hangs on in the connection tree
var order: Array = []            # connected buildings, roots first (parents before children)
var ang := {}                    # Building -> its gear's angle now
var version := 0                 # bumped when the connected set changes
var _nodes := {}                 # Building -> GearDisc
var _field := {}                 # team -> [[centre in gear space, radius px]] of the connected rings
var _sig := -1
var _solved_at := -10.0
var _clock := 0.0
var _top: Node2D
var _top_t := 0.0


func _ready() -> void:
	_top = Node2D.new()
	_top.z_index = 31
	_top.draw.connect(_draw_top)
	add_child(_top)


# ------------------------------------------------------------------ geometry (gear space: y is divided by FIELD_Y, so a
# ring lying flat on the ground is a circle there and an ellipse on the screen, like the old fields)

static func gpos(p: Vector2) -> Vector2:
	return Vector2(p.x, p.y / FY)


## Teeth of a ring of this radius (px).
static func tooth_count(r: float) -> int:
	return maxi(10, int(round(TAU * r / float(Defs.GEAR["pitch"]))))


static func radius_of_teeth(n: int) -> float:
	return float(n) * float(Defs.GEAR["pitch"]) / TAU


## The tooth count of a building kind's ring: footprint half-extent + pad, to whole teeth.
static func ring_n(kind: String, size: Vector2i, big: bool) -> int:
	var half := maxf(float(size.x) * T * 0.5, float(size.y) * T * 0.5 / FY)
	var pads: Dictionary = Defs.GEAR["pad"]
	var pad: float = pads["tower"] if kind == "clocktower" else (pads["big"] if big else pads["small"])
	return tooth_count(half + pad * T)


static func ring_r(kind: String, size: Vector2i, big: bool) -> float:
	return radius_of_teeth(ring_n(kind, size, big))


static func b_n(b: Building) -> int:
	return ring_n(b.kind, b.size, b.gear_big)


static func b_r(b: Building) -> float:
	return radius_of_teeth(b_n(b))


static func has_gear(b: Building) -> bool:
	return Defs.gear_mode and b.d["faction"] == "clockwork"


## The ring's centre in gear space.
static func b_c(b: Building) -> Vector2:
	return gpos(b.center())


# ------------------------------------------------------------------ the graph

func is_linked(b: Building) -> bool:
	if not enforce or not has_gear(b):
		return true
	return linked.has(b)


## Work speed of a Clockwork building: 0 while unconnected (or while its gear is being swapped), else 1.
func speed_mult(b: Building) -> float:
	if not enforce or not Defs.gear_mode or b.d["faction"] != "clockwork" or not b.built or b.dead:
		return 1.0
	return 1.0 if linked.has(b) and b.gear_swap_t < 0.0 else 0.0


func _signature() -> int:
	var s := 0
	for b in game.buildings:
		if is_instance_valid(b) and b.d["faction"] == "clockwork":
			s += b.get_instance_id() % 9973 + (3 if b.built else 0) + (5 if b.dead else 0) + (7 if b.gear_big else 0) + (11 if b.ghost else 0)
	return s


## Recompute which buildings are connected (rings touching rings, from the Clocktowers).
func solve() -> void:
	_solved_at = _clock
	var was := linked.size()
	var old_set := linked
	linked = {}
	parent_of = {}
	order = []
	_field = {}
	if not Defs.gear_mode or game == null:
		return
	var list: Array = []
	var gp: Array = []
	var rr: Array = []
	for b in game.buildings:
		if is_instance_valid(b) and not b.dead and not b.ghost and b.built and b.d["faction"] == "clockwork":
			list.append(b)
			gp.append(b_c(b))
			rr.append(b_r(b))
	var slack := float(Defs.GEAR["slack"]) * T
	var q: Array = []
	for i in list.size():
		if list[i].kind == "clocktower":
			linked[list[i]] = true
			q.append(i)
	var qi := 0
	while qi < q.size():
		var a: int = q[qi]
		qi += 1
		var ta: int = list[a].team
		for j in list.size():
			var bj: Building = list[j]
			if bj.team != ta or linked.has(bj):
				continue
			if (gp[a] as Vector2).distance_to(gp[j]) <= float(rr[a]) + float(rr[j]) + slack:
				linked[bj] = true
				parent_of[bj] = list[a]
				q.append(j)
	for i in q:
		var b: Building = list[i]
		order.append(b)
		if not _field.has(b.team):
			_field[b.team] = []
		_field[b.team].append([gp[i], rr[i]])
	if old_set.size() != was or linked.size() != old_set.size() or not _same(old_set):
		version += 1
	_dirty_view()


func _same(a: Dictionary) -> bool:
	for k in linked:
		if not a.has(k):
			return false
	return true


func _dirty_view() -> void:
	if _top:
		_top.queue_redraw()


## Is p (world px) on connected gear ground of team t: inside a connected building's ring?
func in_field(t: int, p: Vector2) -> bool:
	var g := gpos(p)
	for r in _field.get(t, []):
		var rad: float = r[1]
		if g.distance_squared_to(r[0]) <= rad * rad:
			return true
	return false


## "" if a building of kind k may go at cell c for team t, else why not: its ring must touch the connected field and
## not cut into another ring (a Clocktower starts a field of its own).
func placement_problem(t: int, k: String, c: Vector2i, big := false) -> String:
	var st := candidate(t, k, c, big)
	match st["state"]:
		"clash":
			return "Its gear ring would clash with a %s's ring: leave room for the gears to mesh." % String(Defs.BUILDINGS[st["with"].kind]["name"])
		"far":
			return "Its gear ring must touch your gear field: mesh it with a linked building's ring."
	return ""


## {"state": "ok" | "clash" | "far" | "tower", "with": the building it clashes with}
func candidate(t: int, k: String, c: Vector2i, big := false) -> Dictionary:
	if not enforce or not Defs.gear_mode or Defs.BUILDINGS[k]["faction"] != "clockwork" or k == "clocktower":
		return {"state": "ok" if k != "clocktower" else "tower"}
	if _signature() != _sig:
		_sig = _signature()
		solve()
	var size: Vector2i = Defs.BUILDINGS[k]["size"]
	var g := gpos(Vector2(c) * T + Vector2(size) * T * 0.5)
	var r := ring_r(k, size, big)
	var touch := false
	var slack := float(Defs.GEAR["slack"]) * T
	var over := float(Defs.GEAR["overlap"]) * T
	for b in game.buildings:
		if not is_instance_valid(b) or b.dead or b.team != t or b.d["faction"] != "clockwork":
			continue
		var gap := g.distance_to(b_c(b)) - (r + b_r(b))
		if gap < -over:
			return {"state": "clash", "with": b}
		if gap <= slack and linked.has(b):
			touch = true
	return {"state": "ok" if touch else "far"}


# ------------------------------------------------------------------ ticking and drawing

func tick(delta: float) -> void:
	_clock += delta
	if game == null:
		return
	if not game.puppet:
		for b in game.buildings:
			if is_instance_valid(b) and b.gear_swap_t >= 0.0 and not b.dead:
				b.gear_swap_t -= delta
				if b.gear_swap_t <= 0.0:
					b.gear_swap_t = -1.0
					b.gear_big = b.gear_swap_to
					if game.hud != null and b.team == game.human and not game.demo:
						game.float_text(b.center() + Vector2(0, -40), "big gear" if b.gear_big else "small gear", Color(0.95, 0.85, 0.5))
	var s := _signature()
	if s != _sig or _clock - _solved_at >= float(Defs.GEAR["solve"]):
		_sig = s
		solve()
	_spin(delta)
	_sync_nodes()
	_top_t -= delta
	if _top_t <= 0.0:
		_top_t = 0.25
		_top.queue_redraw()


## Turn the gears: a root turns by itself, every other connected gear is placed from its parent so the teeth mesh.
func _spin(delta: float) -> void:
	var rate := float(Defs.GEAR["teeth_rate"])
	for b in order:
		if b.gear_swap_t >= 0.0:
			continue
		var p: Building = parent_of.get(b)
		var nb := b_n(b)
		if p == null:
			ang[b] = float(ang.get(b, 0.0)) + TAU * rate / float(nb) * delta
		else:
			var theta: float = (b_c(b) - b_c(p)).angle()
			var rp := b_r(p)
			var rb := b_r(b)
			ang[b] = theta + PI - rp * (float(ang.get(p, 0.0)) - theta) / rb - TAU / float(nb) * 0.5


func _sync_nodes() -> void:
	var me := game.controlled_team()
	for b in game.buildings:
		if not is_instance_valid(b) or not has_gear(b):
			continue
		var d: GearDisc = _nodes.get(b)
		var n := b_n(b)
		if d == null:
			d = GearDisc.new()
			d.b = b
			add_child(d)
			_nodes[b] = d
		d.sync(self, n, me)
	for b in _nodes.keys():
		if not is_instance_valid(b) or b.is_queued_for_deletion():
			(_nodes[b] as Node).queue_free()
			_nodes.erase(b)
			ang.erase(b)


func _draw_top() -> void:
	if game == null or not Defs.gear_mode:
		return
	var font := ThemeDB.fallback_font
	var me := game.controlled_team()
	for b in game.buildings:
		if not is_instance_valid(b) or b.dead or not b.built or not has_gear(b) or not game.view_rect.intersects(b.rect()):
			continue
		if me >= 0 and not game.allied(me, b.team):
			continue
		var txt := ""
		var col := Color(0.95, 0.35, 0.28)
		if enforce and not linked.has(b):
			txt = "UNLINKED"
		elif b.gear_swap_t >= 0.0:
			txt = "SWAPPING"
			col = Color(0.95, 0.8, 0.4)
		if txt == "":
			continue
		_badge(font, b.rect().get_center() + Vector2(0, -b.rect().size.y * 0.5 - 14.0), txt, col)


func _badge(font: Font, p: Vector2, txt: String, col: Color) -> void:
	txt = Loc.t(txt)
	var sz := 12
	var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
	var r := Rect2(p + Vector2(-w * 0.5 - 14.0, -9.0), Vector2(w + 22.0, 17.0))
	_top.draw_rect(r, Color(0.05, 0.05, 0.07, 0.82))
	_top.draw_rect(r, col, false, 1.5)
	var dc := r.position + Vector2(9.0, 8.5)
	_top.draw_arc(dc, 4.5, 0.0, TAU, 12, col, 1.5)
	_top.draw_circle(dc, 1.6, col)
	_top.draw_string(font, r.position + Vector2(18.0, 13.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, col)


## The placement ghost's ring (Game._draw_fields): drawn on `ci` in world space, green when it links, orange when it is
## too far from the field, red when it clashes with another ring.
func draw_ghost(ci: CanvasItem, t: int, k: String, c: Vector2i, big := false) -> void:
	if not Defs.gear_mode or Defs.BUILDINGS[k]["faction"] != "clockwork":
		return
	var size: Vector2i = Defs.BUILDINGS[k]["size"]
	var centre := Vector2(c) * T + Vector2(size) * T * 0.5
	var col: Color = ghost_colour(candidate(t, k, c, big)["state"])
	var n := ring_n(k, size, big)
	ci.draw_set_transform(centre, 0.0, Vector2(1.0, FY))
	draw_gear(ci, n, radius_of_teeth(n), col, Color(0.05, 0.1, 0.05), col, 0.22, float(_clock) * 0.4)
	ci.draw_set_transform(Vector2.ZERO)


func ghost_colour(state: String) -> Color:
	var cols: Dictionary = Defs.GEAR["col"]
	return cols["clash"] if state == "clash" else (cols["far"] if state == "far" else cols["ok"])


## The ghost's verdict over it (LINKS / NO LINK / CLASH / NEW FIELD), drawn on the overlay above the buildings.
func draw_ghost_label(ci: CanvasItem, t: int, k: String, c: Vector2i, big := false) -> void:
	if not Defs.gear_mode or Defs.BUILDINGS[k]["faction"] != "clockwork":
		return
	var size: Vector2i = Defs.BUILDINGS[k]["size"]
	var centre := Vector2(c) * T + Vector2(size) * T * 0.5
	var state: String = candidate(t, k, c, big)["state"]
	var label: String = {"far": "NO LINK", "clash": "CLASH", "tower": "NEW FIELD"}.get(state, "LINKS")
	var col := ghost_colour(state)
	var font := ThemeDB.fallback_font
	label = Loc.t(label)
	var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	var at := centre + Vector2(-w * 0.5, -float(size.y) * T * 0.5 - 34.0)
	ci.draw_rect(Rect2(at + Vector2(-6, -14), Vector2(w + 12, 20)), Color(0.05, 0.05, 0.07, 0.85))
	ci.draw_rect(Rect2(at + Vector2(-6, -14), Vector2(w + 12, 20)), col, false, 1.5)
	ci.draw_string(font, at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, col)


## One toothed ring in gear space about the origin: n teeth, pitch radius r. `rot`: its angle (the caller of a node
## turns the node instead and passes 0). Light: a translucent disc, a band, thin spokes, dark-edged brass teeth.
static func draw_gear(ci: CanvasItem, n: int, r: float, tone: Color, edge: Color, team_col: Color, fill := 0.14, rot := 0.0) -> void:
	var step := TAU / float(n)
	var pitch := TAU * r / float(n)
	var h := pitch * 0.55
	var pts := PackedVector2Array()
	for k in n:
		var a := step * float(k) + rot
		pts.append(Vector2.from_angle(a - step * 0.30) * (r - h * 0.5))
		pts.append(Vector2.from_angle(a - step * 0.16) * (r + h * 0.5))
		pts.append(Vector2.from_angle(a + step * 0.16) * (r + h * 0.5))
		pts.append(Vector2.from_angle(a + step * 0.30) * (r - h * 0.5))
	var ri := r - h * 0.5 - pitch * 0.8
	ci.draw_colored_polygon(pts, Color(tone.r, tone.g, tone.b, fill))
	ci.draw_arc(Vector2.ZERO, (ri + r - h * 0.5) * 0.5, 0.0, TAU, 64, Color(team_col.r, team_col.g, team_col.b, 0.30), pitch * 0.8)
	# spokes and a hub: thin, so units and ground still read through them
	var spokes := 6 if r < 120.0 else 10
	var hub := minf(r * 0.16, 26.0)
	for i in spokes:
		var a := TAU * float(i) / float(spokes) + rot
		ci.draw_line(Vector2.from_angle(a) * hub, Vector2.from_angle(a) * ri, Color(tone.r, tone.g, tone.b, 0.34), 2.0)
	ci.draw_arc(Vector2.ZERO, hub, 0.0, TAU, 20, Color(edge.r, edge.g, edge.b, 0.55), 3.0)
	ci.draw_arc(Vector2.ZERO, hub, 0.0, TAU, 20, tone, 1.4)
	ci.draw_arc(Vector2.ZERO, ri, 0.0, TAU, 64, Color(edge.r, edge.g, edge.b, 0.55), 3.0)
	ci.draw_arc(Vector2.ZERO, ri, 0.0, TAU, 64, tone, 1.4)
	var loop := pts.duplicate()
	loop.append(pts[0])
	ci.draw_polyline(loop, Color(edge.r, edge.g, edge.b, 0.75), 3.6, true)
	ci.draw_polyline(loop, tone, 1.8, true)


## One building's ring on the ground: a holder squashed like the old field rings, with a spinning child that draws once.
class GearDisc extends Node2D:
	var b: Building
	var spin: Node2D
	var n := 0
	var drawn_n := -1
	var drawn_team := -1
	var swap_from := 1.0

	func _init() -> void:
		spin = Node2D.new()
		add_child(spin)
		spin.draw.connect(_draw_spin)

	func _draw_spin() -> void:
		if b == null or n <= 0:
			return
		var cols: Dictionary = Defs.GEAR["col"]
		var tc: Color = Defs.TEAM_COLOURS[clampi(b.team, 0, Defs.TEAM_COLOURS.size() - 1)]
		GearNet.draw_gear(spin, n, GearNet.radius_of_teeth(n), cols["brass"], cols["edge"], tc)

	func sync(net: GearNet, tooth_n: int, me: int) -> void:
		if b.dead and b.rubble_t > 24.0:
			visible = false
			return
		var c := b.center()
		position = c
		scale = Vector2(1.0, GearNet.FY)
		if tooth_n != n or b.team != drawn_team:
			n = tooth_n
			drawn_team = b.team
			spin.queue_redraw()
		var s := 1.0
		if b.gear_swap_t >= 0.0:
			# the ring visibly changes size while the gear is swapped: from the old radius to the new one
			var total := float(Defs.GEAR["swap_time"])
			var k := clampf(1.0 - b.gear_swap_t / total, 0.0, 1.0)
			var r_old := GearNet.b_r(b)
			var r_new := GearNet.ring_r(b.kind, b.size, b.gear_swap_to)
			var cur := lerpf(r_old, r_new, k * k * (3.0 - 2.0 * k))
			s = cur / r_old
		spin.scale = Vector2(s, s)
		spin.rotation = float(net.ang.get(b, 0.0))
		# state colours: connected (full), unlinked (dull red-grey), a site or a swap (faint), dead (dark)
		var cols: Dictionary = Defs.GEAR["col"]
		var m := Color(1, 1, 1, 1)
		if b.dead:
			m = Color(cols["dead"].r * 1.4, cols["dead"].g * 1.4, cols["dead"].b * 1.4, 0.55)
		elif not b.built or b.ghost:
			m = Color(1, 1, 1, 0.4)
		elif net.enforce and not net.linked.has(b):
			m = Color(1.0, 0.62, 0.55, 0.78)
		modulate = m
		var shown := true
		if me >= 0 and not net.game.allied(me, b.team) and not net.game.demo:
			shown = b.visible
		visible = shown and net.game.view_rect.grow(GearNet.radius_of_teeth(n) + 40.0).has_point(c)
