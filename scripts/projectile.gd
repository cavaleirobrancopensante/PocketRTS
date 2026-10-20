class_name Projectile
extends Node2D
## A cannonball: flies in an arc to a spot and explodes with splash damage.

var game: Game
var from := Vector2.ZERO
var to := Vector2.ZERO
var t := 0.0
var duration := 0.6
var damage := 30.0
var splash := 40.0
var team := 0
var shooter: Entity
var sprite: Sprite2D


func _ready() -> void:
	sprite = Sprite2D.new()
	sprite.texture = Game.tex("res://assets/effects/ball_big.png")
	sprite.scale = Vector2(0.9, 0.9)
	add_child(sprite)
	z_index = 5


func _physics_process(delta: float) -> void:
	t += delta
	var f := clampf(t / duration, 0.0, 1.0)
	var h := sin(f * PI) * from.distance_to(to) * 0.18
	position = from.lerp(to, f) - Vector2(0, h)
	var dh := cos(f * PI) * PI * from.distance_to(to) * 0.18
	sprite.rotation = ((to - from) - Vector2(0, dh)).angle() + PI
	if f >= 1.0:
		game.explode(to, damage, splash, team, shooter)
		queue_free()
