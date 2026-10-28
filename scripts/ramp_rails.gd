class_name RampRails
extends Node2D
## The ramp rails drawn (docs/ramp_funnel.md): a low stone kerb down both sides of every ramp, from
## the cliff to the row above its bottom one (Game.rails, MapGen.ramp_rails). Seen from above and a
## little to the south, as the game is: a lit top, a dark outline, the south face of a kerb that
## runs east-west, and a small shadow to the south-east. Drawn on the ground (under every unit and
## building); no unit stands on it (Game.rail_fix). Code drawing: docs/art_style_inconsistency.md.

var game: Game

const TOP := Color(0.80, 0.76, 0.67)
const TOP_LIT := Color(0.93, 0.90, 0.82)
const FACE := Color(0.47, 0.43, 0.37)
const LINE := Color(0.13, 0.11, 0.09)
const SHADOW := Color(0.0, 0.0, 0.0, 0.32)
const HALF := 3.0         # (px: half the kerb's width, each side of the cells' shared edge)
const FACE_H := 4.0       # (px: the south face's height)
const JOINT := 10.0       # (px between the stones' joints)


func _draw() -> void:
	if game == null:
		return
	for rl in game.rails:
		var r: Rect2 = rl["rect"]
		if rl["vertical"]:
			_north_south(r.position.x, r.position.y, r.end.y)
		else:
			_east_west(r.position.y, r.position.x, r.end.x)


## A kerb along x = x, from y0 (north) to y1 (south).
func _north_south(x: float, y0: float, y1: float) -> void:
	# shadow to the east and past the south end
	draw_rect(Rect2(x + HALF + 1.0, y0 + 2.0, 3.0, y1 - y0), SHADOW)
	draw_rect(Rect2(x - HALF + 1.0, y1 + FACE_H, HALF * 2.0 + 2.0, 2.0), SHADOW)
	# outline, top, and the south end's face
	draw_rect(Rect2(x - HALF - 1.0, y0 - 1.0, HALF * 2.0 + 2.0, y1 - y0 + FACE_H + 2.0), LINE)
	draw_rect(Rect2(x - HALF, y0, HALF * 2.0, y1 - y0), TOP)
	draw_rect(Rect2(x - HALF, y0, 1.5, y1 - y0), TOP_LIT)
	draw_rect(Rect2(x - HALF, y1, HALF * 2.0, FACE_H), FACE)
	var y := y0 + JOINT
	while y < y1 - 2.0:
		draw_line(Vector2(x - HALF, y), Vector2(x + HALF, y), LINE, 1.0)
		y += JOINT


## A kerb along y = y, from x0 (west) to x1 (east): its top just north of the line, its south face
## just south of it.
func _east_west(y: float, x0: float, x1: float) -> void:
	var top := y - HALF
	draw_rect(Rect2(x0 + 1.0, y + FACE_H, x1 - x0 + 2.0, 3.0), SHADOW)
	draw_rect(Rect2(x0 - 1.0, top - 1.0, x1 - x0 + 2.0, HALF + FACE_H + 2.0), LINE)
	draw_rect(Rect2(x0, top, x1 - x0, HALF), TOP)
	draw_rect(Rect2(x0, top, x1 - x0, 1.0), TOP_LIT)
	draw_rect(Rect2(x0, y, x1 - x0, FACE_H), FACE)
	var x := x0 + JOINT
	while x < x1 - 2.0:
		draw_line(Vector2(x, top), Vector2(x, y + FACE_H), LINE, 1.0)
		x += JOINT
