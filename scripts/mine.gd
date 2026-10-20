class_name GoldMine
extends Entity
## A gold mine. Labourers take gold from it until it runs dry.

var cell := Vector2i.ZERO
var size := Vector2i(3, 2)
var gold := Defs.MINE_GOLD
var feeders: Array = []          # Brood grubs burrowed here
var rig: Node = null             # Clockwork Drill Rig on this mine
var sprite: Sprite2D


func is_mine() -> bool:
	return true


func setup(g: Game, c: Vector2i) -> void:
	game = g
	kind = "mine"
	cell = c
	var r := rect()
	position = Vector2(r.get_center().x, r.end.y)


func _ready() -> void:
	sprite = Sprite2D.new()
	sprite.centered = false
	add_child(sprite)
	_update()


func rect() -> Rect2:
	return Rect2(Vector2(cell) * Defs.TILE, Vector2(size) * Defs.TILE)


func take(n: int) -> int:
	var got := mini(n, gold)
	gold -= got
	_update()
	return got


func _update() -> void:
	var state := "full" if gold > Defs.MINE_GOLD * 0.5 else ("half" if gold > 0 else "empty")
	var t := Game.tex("res://assets/world/mine_%s.png" % state)
	sprite.texture = t
	sprite.offset = Vector2(-t.get_width() * 0.5, -t.get_height() + 8)


func _draw() -> void:
	if selected:
		var r := rect()
		draw_rect(Rect2(r.position - global_position, r.size).grow(3), Color(1, 0.9, 0.4, 0.8), false, 2.0)
