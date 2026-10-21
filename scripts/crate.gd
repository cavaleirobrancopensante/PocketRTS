class_name Crate
extends Entity
## The Winder's crate (Clockwork) lying on the ground: dropped by the Winder carrying it to a
## new building's site when he died or was given another job on the way. Any Winder of its
## side can carry it on (sent onto it, or an idle one close by by himself: Unit._build).
## It can be shot to pieces (Defs.CRATE.hp); then the building it was going to be is
## cancelled, with the usual refund (Game.abandon).

var site: Building
var claimed: Unit = null       # the Winder on his way to pick it up
var sprite: Sprite2D
var _shown_hp := -1.0


func setup(g: Game, t: int, p: Vector2, s: Building) -> void:
	game = g
	team = t
	kind = "crate"
	site = s
	position = p
	max_hp = float(Defs.CRATE["hp"])
	hp = max_hp
	armor = 0.0
	sight = 2


func _ready() -> void:
	sprite = Sprite2D.new()
	sprite.centered = false
	sprite.texture = Game.tex("res://assets/effects/crate_ground.png")
	sprite.offset = Vector2(-sprite.texture.get_width() * 0.5, -sprite.texture.get_height() + 3)
	sprite.material = team_material()
	add_child(sprite)


## The crate itself (a small box standing on its spot), for shots, clicks and reach.
func rect() -> Rect2:
	return Rect2(global_position - Vector2(9, 16), Vector2(18, 18))


## Still wanted: its site stands, unfinished, waiting for this very crate.
func wanted() -> bool:
	return site != null and is_instance_valid(site) and not site.dead and not site.built and site.crate_obj == self


func _physics_process(delta: float) -> void:
	_process_flash(delta)
	if dead:
		return
	if not wanted():
		remove()
		return
	if claimed and (not is_instance_valid(claimed) or claimed.dead or claimed.order != "build" or claimed.order_target != site):
		claimed = null
	if hp != _shown_hp:
		_shown_hp = hp
		queue_redraw()


func _draw() -> void:
	if dead:
		return
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, 10.0, Color(0, 0, 0, 0.25))
	draw_set_transform(Vector2.ZERO)
	draw_health(-24.0, 20.0)


## Shot to pieces: the building it was going to be is cancelled (the usual refund).
func die() -> void:
	if dead:
		return
	dead = true
	var fx := game.spawn_effect("dust", global_position + Vector2(0, -6), 1.6)
	fx.scale = Vector2(0.6, 0.6)
	Sfx.play_any(["combat/gear_hit", "gear_hit"], global_position)
	if wanted():
		site.crate_obj = null
		site.crate = ""
		if team == game.human:
			game.float_text(global_position + Vector2(0, -26), "crate lost", Color(1, 0.6, 0.4))
		if game.mlog:
			game.mlog.add("%s lost the crate for a %s: cancelled" % [game.mlog.who(team), site.d["name"]])
		game.abandon(site)
	remove()


func remove() -> void:
	game.crates.erase(self)
	queue_free()
