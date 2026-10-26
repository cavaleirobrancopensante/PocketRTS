class_name RatchetTurret
extends RefCounted
## The RATCHET TURRET's head and gun (gear mode's Clockwork static defence; numbers in Defs.TURRET). The base is the
## building's own sprite (assets/buildings/ratchet_turret_*.png); the head is a second sprite on its turntable, one of
## five painted facings (S, SE, E, NE, N; W, SW and NW are the E, SE and NE mirrored, like the units), shown while the
## turret stands (under construction the scaffold has no head; the ruin has the head lying in its rubble).
## It turns one 45-degree step at a time toward the nearest enemy in range, ground or air, and fires a screw
## (Game.screw_shot) once it faces it; idle, it keeps its last facing. Unlinked from the gear field it does nothing.
## Art: tools/gear_art/import_ratchet_turret.py.

## Facing index 0..7 clockwise on screen from east -> [painted facing, mirrored]
const DIRS := [["e", false], ["se", false], ["s", false], ["se", true], ["e", true], ["ne", true], ["n", false], ["ne", false]]

var b: Building
var head: Sprite2D
var facing := 2          # (built facing south, toward the viewer)
var want := 2
var target: Unit = null
var cd := 0.0
var _scan := 0.0
var _turn := 0.0
var shots := 0           # screws fired (tests)


func _init(bld: Building) -> void:
	b = bld
	head = Sprite2D.new()
	head.centered = true
	head.position = Defs.TURRET["head_at"]
	head.visible = false
	b.add_child(head)
	_show()


## The head's picture for the current facing.
func _show() -> void:
	var dd: Array = DIRS[facing]
	var t := Game.tex("res://assets/buildings/ratchet_turret_head_%s.png" % String(dd[0]))
	if head.texture != t:
		head.texture = t
	head.flip_h = bool(dd[1])


## The barrel tip in world px for the current facing (Defs.TURRET "tips", from the collar centre).
func tip() -> Vector2:
	var dd: Array = DIRS[facing]
	var o: Vector2 = Defs.TURRET["tips"][String(dd[0])]
	if bool(dd[1]):
		o.x = -o.x
	return b.global_position + head.position + o


## The facing index (0..7) nearest the direction from the head to p.
func dir_to(p: Vector2) -> int:
	var a := (p - (b.global_position + head.position)).angle()
	return posmod(int(round(a / (PI / 4.0))), 8)


## Can it fire right now: built, standing, linked to the gear field.
func armed() -> bool:
	return b.built and not b.dead and b.game.gear_net.speed_mult(b) > 0.0


func tick(delta: float) -> void:
	head.visible = b.built and not b.dead
	if not head.visible:
		return
	cd = maxf(cd - delta, 0.0)
	if not armed():
		target = null
		return
	var r := float(Defs.TURRET["range"])
	_scan -= delta
	if _scan <= 0.0 or not _good(target, r):
		_scan = float(Defs.TURRET["scan"])
		target = _pick(r)
	if target == null:
		return          # (idle: it keeps its last facing)
	want = dir_to(target.center())
	if facing != want:
		_turn -= delta
		if _turn <= 0.0:
			_turn = float(Defs.TURRET["turn"])
			# one step the short way round
			var diff := posmod(want - facing, 8)
			facing = posmod(facing + (1 if diff <= 4 else -1), 8)
			_show()
		return
	if cd <= 0.0:
		cd = float(Defs.TURRET["cooldown"])
		shots += 1
		b.game.screw_shot(b, target, float(Defs.TURRET["damage"]), tip(), DIRS[facing])


func _good(u: Unit, r: float) -> bool:
	if u == null or not is_instance_valid(u) or u.dead or u.off_field or u.untouchable():
		return false
	if not b.game.hostile(u.team, b.team):
		return false
	return u.position.distance_to(b.center()) <= r + float(u.radius)


## The nearest enemy unit in range, on the ground or in the air.
func _pick(r: float) -> Unit:
	var best: Unit = null
	var bd := INF
	for u in b.game.units_near(b.center(), r + 30.0):
		if not _good(u, r):
			continue
		var dd: float = u.position.distance_to(b.center())
		if dd < bd:
			bd = dd
			best = u
	return best
