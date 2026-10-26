class_name Projectile
extends Node2D
## A cannonball: flies in an arc to a spot and explodes with splash damage. (A Spore Mother's
## blob and a Mortar's shell are lobbed much higher.)

var game: Game
var from := Vector2.ZERO
var to := Vector2.ZERO
var t := 0.0
var duration := 0.6
var damage := 30.0
var splash := 40.0
var team := 0
var shooter: Entity
var round_shot := false
var blob := false               # Spore Mother: a big glob of spit lobbed high
var shell := false              # Mortar: a shell lobbed high over men and walls
var aimed := false              # fired at a spot (BOMBARD): it tears up the bodies in its whole blast (Defs.BODY_BLAST)
var sprite: Sprite2D
var _frames := 1


func _ready() -> void:
	sprite = Sprite2D.new()
	if blob:
		sprite.texture = Game.tex("res://assets/effects/acid_ball.png")
		sprite.hframes = int(ArtData.EFFECTS.get("acid_ball", {"frames": 1})["frames"])
		sprite.scale = Vector2(3.0, 3.0)
	elif shell and ArtData.EFFECTS.has("mortar_shell"):
		sprite.texture = Game.tex("res://assets/effects/mortar_shell.png")
		_frames = int(ArtData.EFFECTS["mortar_shell"]["frames"])
		sprite.hframes = _frames
	else:
		sprite.texture = Game.tex("res://assets/effects/ball_big.png")
		sprite.scale = Vector2(0.9, 0.9)
	add_child(sprite)
	z_index = 5
	visible = game == null or not game.fx_hidden(from, to)     # (fired and landing where the watching side has never looked: unseen)


func _arc() -> float:
	if shell:
		return float(Defs.MORTAR["arc"])
	return 0.45 if blob else 0.18


func _physics_process(delta: float) -> void:
	var _p0 := Time.get_ticks_usec()
	_tick_projectile(delta)
	Prof.add("projectiles", _p0)


func _tick_projectile(delta: float) -> void:
	t += delta
	var f := clampf(t / duration, 0.0, 1.0)
	var arc := _arc()
	var h := sin(f * PI) * from.distance_to(to) * arc
	position = from.lerp(to, f) - Vector2(0, h)
	var dh := cos(f * PI) * PI * from.distance_to(to) * arc
	if shell:
		# a round bomb, its fuse fizzing (the frames)
		sprite.frame = int(t * 12.0) % maxi(_frames, 1)
		queue_redraw()       # its shadow on the ground
	else:
		sprite.rotation = ((to - from) - Vector2(0, dh)).angle() + PI
	if f >= 1.0:
		if not is_instance_valid(shooter):
			shooter = null       # (whoever fired it is gone from the game: removed, not just dead)
		if blob:
			game.blob_land(to, damage, splash, team, shooter)
		elif shell:
			game.mortar_land(to, damage, splash, team, shooter, aimed)
		elif round_shot:
			game.round_shot_land(from, to, damage, team, shooter, aimed)
		else:
			game.explode(to, damage, splash, team, shooter)
		queue_free()


func _draw() -> void:
	if not shell:
		return
	# the shell's shadow on the ground, darker as it comes down
	var f := clampf(t / duration, 0.0, 1.0)
	var ground := from.lerp(to, f) - position
	draw_set_transform(ground, 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, 5.0, Color(0, 0, 0, 0.15 + 0.25 * f))
	draw_set_transform(Vector2.ZERO)
