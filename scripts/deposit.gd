class_name Deposit
extends Entity
## A rock outcrop at the back of a base site: saltpetre (the Crown's Powder Mills grind it into
## powder) or ore (the Clockwork's Ore Crushers turn battery charge into ore from it). 2x2
## tiles; it blocks the way, shows how much is left (four pictures, full to exhausted), stays
## on the map when spent and is seen through the fog once explored. Nobody owns it.

var cell := Vector2i.ZERO
var size := Vector2i(2, 2)
var amount := 0.0
var full := 1.0
var sprite: Sprite2D
var _state := -1
var _sparkle_t := 0.0


func is_deposit() -> bool:
	return true


## kind: "saltpetre" or "ore"; amt < 0: full.
func setup(g: Game, k: String, c: Vector2i, amt := -1.0) -> void:
	game = g
	kind = k
	cell = c
	full = float(Defs.DEPOSIT[k])
	amount = full if amt < 0.0 else clampf(amt, 0.0, full)
	max_hp = full
	hp = amount
	var r := rect()
	position = Vector2(r.get_center().x, r.end.y)
	# each outcrop sparkles on its own rhythm (no rng: the map stays the same for a seed)
	_sparkle_t = 2.0 + fmod(float(c.x) * 0.73 + float(c.y) * 1.37, 6.0)


func _ready() -> void:
	sprite = Sprite2D.new()
	sprite.centered = false
	sprite.offset = Vector2(-36, -60)
	add_child(sprite)
	_update()


func rect() -> Rect2:
	return Rect2(Vector2(cell) * Defs.TILE, Vector2(size) * Defs.TILE)


func name_text() -> String:
	return "Saltpetre" if kind == "saltpetre" else "Ore"


## Share left (0..1).
func left() -> float:
	return clampf(amount / full, 0.0, 1.0) if full > 0.0 else 0.0


## Draw up to n from it; returns what it gave.
func take(n: float) -> float:
	var got := clampf(n, 0.0, amount)
	if got <= 0.0:
		return 0.0
	amount -= got
	if amount < 0.001:
		amount = 0.0
	hp = amount
	_update()
	return got


## 0 full, 1 half mined, 2 nearly spent, 3 exhausted (the four pictures).
func state() -> int:
	var f := left()
	if amount <= 0.0:
		return 3
	return 0 if f > 0.66 else (1 if f > 0.33 else 2)


func _update() -> void:
	var st := state()
	if st == _state or sprite == null:
		return
	_state = st
	sprite.texture = Game.tex("res://assets/deposits/%s_%d.png" % [kind, st])
	queue_redraw()


func _process(delta: float) -> void:
	# a full outcrop glints now and then (only where somebody could see it)
	if _state != 0 or not visible or game == null or game.edit_mode:
		return
	_sparkle_t -= delta
	if _sparkle_t > 0.0:
		return
	_sparkle_t = 5.0 + fmod(_sparkle_t * -97.0 + float(cell.x * 7 + cell.y * 13), 5.0)
	if not game.view_rect.has_point(global_position) or not ArtData.EFFECTS.has("deposit_sparkle"):
		return
	var fx := game.spawn_effect("deposit_sparkle", global_position + Vector2(float((cell.x * 11 + cell.y * 5) % 30) - 15.0, -46.0 + float((cell.y * 7) % 20)), 0.8)
	fx.z_index = 3


func _draw() -> void:
	if selected:
		var r := rect()
		draw_rect(Rect2(r.position - global_position, r.size).grow(3), Color(1, 0.9, 0.4, 0.8), false, 2.0)
