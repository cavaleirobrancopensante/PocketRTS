class_name OwlBomb
extends Node2D
## The Ticking Owl's pendulum weight, let go over a building (CwAir.drop_bomb; Defs.OWL_BOMB): it falls from where it hung
## (`from`, in the air) onto the impact point (`to`, on the ground), tumbling with its red light pulsing
## (assets/effects/owl_bomb.png, 4 frames), faster as it comes down; its shadow slides along the ground under it and darkens.
## Where it lands it bursts (Game.owl_bomb_land: the damage, the explosion assets/effects/owl_blast.png).

var game: Game
var from := Vector2.ZERO         # where it was let go (world px, as drawn in the air)
var to := Vector2.ZERO           # the impact point (on the ground)
var ground_from := Vector2.ZERO  # the ground point under `from`
var t := 0.0
var duration := 0.4
var damage := 45.0
var team := 0
var shooter: Entity
var landed := false
var sprite: Sprite2D


func _ready() -> void:
	sprite = Sprite2D.new()
	sprite.texture = Game.tex("res://assets/effects/owl_bomb.png")
	sprite.hframes = int(ArtData.EFFECTS["owl_bomb"]["frames"])
	sprite.scale = Vector2.ONE * float(Defs.OWL_BOMB["scale"])
	add_child(sprite)
	z_index = 6
	_place(0.0)


## The height over the ground track at share f of the fall: it drops from the weight's height, accelerating (h0 (1 - f^2)).
func height(f: float) -> float:
	return (ground_from.y - from.y) * (1.0 - f * f)


func ground(f: float) -> Vector2:
	return ground_from.lerp(to, f)


func _place(f: float) -> void:
	position = ground(f) - Vector2(0.0, height(f))


func _physics_process(delta: float) -> void:
	t += delta
	var f := clampf(t / maxf(duration, 0.05), 0.0, 1.0)
	_place(f)
	sprite.frame = int(t * 12.0) % maxi(sprite.hframes, 1)
	queue_redraw()
	if f >= 1.0 and not landed:
		landed = true
		if not is_instance_valid(shooter):
			shooter = null       # (the Owl is gone from the game: removed, not just dead)
		game.owl_bomb_land(to, damage, team, shooter)
		queue_free()


func _draw() -> void:
	# its shadow on the ground under it, darker as it comes down
	var f := clampf(t / maxf(duration, 0.05), 0.0, 1.0)
	var g := ground(f) - position
	draw_set_transform(g, 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, 5.0, Color(0, 0, 0, 0.15 + 0.3 * f))
	draw_set_transform(Vector2.ZERO)
