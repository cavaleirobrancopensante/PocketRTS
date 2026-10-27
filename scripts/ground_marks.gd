class_name GroundMarks
extends Node2D
## AREA MARKS ON THE GROUND (docs/aoe_show.md; the owner: "most area of effect should show, it's just fair"). Where an area
## attack strikes, a short, see-through mark of its real shape (the same geometry the damage uses) is laid on the ground
## under the units and fades in about 0.3-0.5 s: a WEDGE (the Pendulum's arc, a canister's cone), a RING (a Mortar shell's
## burst, a keg or Powder Wagon going up, an Owl's bomb), an OVAL (the squashed ellipses the Brood's spit and clouds use:
## Game.in_ellipse) or a BAND (a round shot's line). Slow things that land later (a Mortar shell, a Spore Mother's spit, the
## Owl's bomb) first lay a WARNING where they will land while they are in the air: an outline whose fill grows as the
## shot comes down. Clouds and storms that stay a while keep a faint edge for as long as they last.
##
## Who sees a mark: the side that made it, and anyone whose side sees that ground now (Game.mark_seen: the fog is
## respected). Online, the host sends each mark with the snapshot's effects (NetSession.note_mark) and the guest lays it by
## its own fog. Settings.area_marks turns them off (on by default).
##
## Two of these nodes: Game.ground_marks (on the ground, under the units and buildings) and Game.swipe_marks (over them:
## the Pendulum's crescent SMEAR, the trail of its blade along the low sweep, which lingers ~0.35 s after the blow).
## Nothing is processed or drawn while there are no marks (set_process off): no cost when nothing is happening.
## Code-drawn (docs/art_style_inconsistency.md).

## The marks' colours by what made them.
const COLS := {
	"steel": Color(0.62, 0.86, 1.0),         # the Pendulum's blades (steel, a cold blue-white)
	"powder": Color(1.0, 0.62, 0.25),        # Crown shells, kegs, round shot, canister
	"brass": Color(1.0, 0.8, 0.38),          # the Ticking Owl's bomb, Clockwork guns
	"acid": Color(0.72, 1.0, 0.3),           # Spore Mother's spit, a Bloater's burst and gas
	"miasma": Color(0.75, 0.55, 1.0),        # Miasma (it heals the Brood inside)
	"fog": Color(0.75, 0.82, 0.78),          # a Mist Toad's fog bank
	"storm": Color(0.55, 0.8, 1.0),          # storms (they stun / burn)
	"steam": Color(0.92, 0.95, 0.95),        # a Steam Walker's jet
}
const STRIKE := 0.45            # seconds a strike's mark lasts (fading all the way)
const SMEAR := 0.38             # seconds the Pendulum's smear lingers
const ZONE_FADE := 0.5
const SMEAR_Y := 0.55           # the smear's crescent squashed flat: it runs along the ground at the blade's height          # a lasting zone's edge fades over its last half second

var game: Game
var top := false                # this node draws the smears (over the units), not the ground marks
## Each mark: {s: shape ("ring" "oval" "wedge" "band" "smear"), c: colour, p: where, a: a direction (wedge / smear) or the
## band's far end, r: radius / reach / half width, h: half angle (wedge, smear) / 0, life, t: left, warn, zone, arm}
var marks: Array = []
var shown_total := 0            # (tests) marks laid so far


func _ready() -> void:
	set_process(not marks.is_empty())


func add(m: Dictionary) -> void:
	m["t"] = float(m["life"])
	marks.append(m)
	shown_total += 1
	if not is_processing():
		set_process(true)
	queue_redraw()


func clear() -> void:
	marks.clear()
	set_process(false)
	queue_redraw()


func _process(delta: float) -> void:
	for m in marks:
		m["t"] = float(m["t"]) - delta
	marks = marks.filter(func(m: Dictionary) -> bool: return float(m["t"]) > 0.0)
	if marks.is_empty():
		set_process(false)
	queue_redraw()


## 0..1: how strongly mark m shows now.
static func fade(m: Dictionary) -> float:
	var t := float(m["t"])
	if bool(m.get("zone", false)):
		return clampf(t / ZONE_FADE, 0.0, 1.0)
	if bool(m.get("warn", false)):
		return 1.0
	return clampf(t / float(m["life"]), 0.0, 1.0)


func _draw() -> void:
	for m in marks:
		if String(m["s"]) == "smear":
			_smear(m)
		else:
			_mark(m)


## The outline points of a mark's shape (closed), in world px.
static func outline(m: Dictionary, grow := 1.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var p: Vector2 = m["p"]
	var r := float(m["r"]) * grow
	match String(m["s"]):
		"ring", "oval":
			var sy := Game.FIELD_Y if String(m["s"]) == "oval" else 1.0
			var n := clampi(int(r * 0.6), 16, 48)
			for i in n:
				var a := TAU * float(i) / float(n)
				pts.append(p + Vector2(cos(a), sin(a) * sy) * r)
		"wedge":
			var dir: Vector2 = m["a"]
			var h := float(m["h"])
			pts.append(p)
			for i in 13:
				pts.append(p + dir.rotated(lerpf(-h, h, i / 12.0)) * r)
		"band":
			var b: Vector2 = m["a"]
			var n2 := (b - p).normalized().orthogonal() * float(m["r"])
			pts.append_array([p + n2, b + n2, b - n2, p - n2])
	return pts


func _mark(m: Dictionary) -> void:
	var c: Color = m["c"]
	var k := fade(m)
	if k <= 0.0:
		return
	var pts := outline(m)
	if pts.size() < 3:
		return
	var closed := pts.duplicate()
	closed.append(pts[0])
	if bool(m.get("warn", false)):
		# while the shot is in the air: the outline (blinking a little) and a fill that grows as it comes down
		var f := clampf(1.0 - float(m["t"]) / float(m["life"]), 0.0, 1.0)
		var blink := 0.75 + 0.25 * sin(float(m["t"]) * 18.0)
		draw_colored_polygon(pts, Color(c, 0.07))
		var inner := outline(m, maxf(f, 0.05))
		if inner.size() >= 3 and String(m["s"]) != "wedge":
			draw_colored_polygon(inner, Color(c, 0.12 + 0.16 * f))
		_edge(closed, c, 0.85 * blink)
		return
	if bool(m.get("zone", false)):
		# a cloud or storm that stays: its edge, faint, for as long as it lasts
		_edge(closed, c, 0.45 * k)
		var flash := clampf(1.0 - (float(m["life"]) - float(m["t"])) / STRIKE, 0.0, 1.0)
		if flash > 0.0:
			draw_colored_polygon(pts, Color(c, 0.2 * flash))
		return
	draw_colored_polygon(pts, Color(c, 0.3 * k))
	_edge(closed, c, 0.85 * k)


## A mark's edge: its colour over a thin dark line, so it reads on bright grass and on dark ground alike.
func _edge(closed: PackedVector2Array, c: Color, a: float) -> void:
	draw_polyline(closed, Color(0, 0, 0, 0.35 * a), 3.5, true)
	draw_polyline(closed, Color(c, a), 1.75, true)


## The Pendulum's smear: a crescent along the blade's low path round its feet (the ground squashed by FIELD_Y), from the
## side it swung from, across the front, to past the middle; the head runs on a little through the follow-through while
## the tail fades from its far end.
func _smear(m: Dictionary) -> void:
	var c: Color = m["c"]
	var life := float(m["life"])
	var age := life - float(m["t"])
	var k := pow(clampf(float(m["t"]) / life, 0.0, 1.0), 0.6)      # (bright for most of its life, then gone)
	var p: Vector2 = m["p"]
	var dir: Vector2 = m["a"]
	var r := float(m["r"])
	var h := float(m["h"])
	var side := 1.0 if int(m.get("arm", 0)) == 0 else -1.0      # the right arm sweeps from its right side to its left
	var a0 := side * h * 1.25                                    # where the sweep came from
	var a1 := lerpf(-side * h * 0.15, -side * h * 0.85, clampf(age / 0.14, 0.0, 1.0))     # the head: on through the follow-through
	var tail := lerpf(a0, a1, smoothstep(0.35, 1.0, age / life) * 0.7)     # the tail draws in a little as it fades
	var n := 18
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	var cols := PackedColorArray()
	for i in n + 1:
		var f := float(i) / float(n)                 # 0 at the tail, 1 at the head
		var a := lerpf(tail, a1, f)
		var d := dir.rotated(a)
		var w := lerpf(4.0, 16.0, f)                  # thin tail, thick head
		var o := Vector2(d.x, d.y * SMEAR_Y)
		outer.append(p + o * (r + w * 0.5))
		inner.append(p + o * (r - w * 0.5))
		cols.append(Color(c, k * lerpf(0.2, 0.95, sqrt(f))))
	# (one quad a step: a crescent is concave and a single polygon of it does not always triangulate)
	for i in n:
		var ci := Color(cols[i], cols[i].a * 0.55)
		var cj := Color(cols[i + 1], cols[i + 1].a * 0.55)
		draw_polygon(PackedVector2Array([outer[i], outer[i + 1], inner[i + 1], inner[i]]), PackedColorArray([cols[i], cols[i + 1], cj, ci]))
	# a dark line under it and a bright edge on the outside where the blade's edge ran: it reads on grass and over a
	# target flashing white alike
	var edge := PackedVector2Array()
	var back := PackedVector2Array()
	for i in range(n / 4, n + 1):
		edge.append(outer[i])
		back.append(inner[i])
	draw_polyline(back, Color(0.05, 0.08, 0.12, 0.45 * k), 2.0, true)
	draw_polyline(edge, Color(0.05, 0.08, 0.12, 0.45 * k), 3.5, true)
	draw_polyline(edge, Color(1, 1, 1, 0.85 * k), 1.5, true)
