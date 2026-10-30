class_name Shot
extends Sprite2D
## A visible missile (musket ball, bolt, acid glob). Purely visual: the damage was dealt
## when it was fired. Spawns an impact effect on arrival.

var from := Vector2.ZERO
var to := Vector2.ZERO
var speed := 800.0
var arc := 0.0               # height of the arc as a share of the distance
var face_offset := 0.0       # the art's own facing (PI if drawn facing left)
var impact := ""
var impact_scale := 1.0
var impact_sound := ""      # played where it lands (a venom glob's wet splat: combat/<kind>_hit)
var game: Game
var _t := 0.0
var _dur := 0.1


func launch(g: Game, kind: String, a: Vector2, b: Vector2, spd: float) -> Shot:
	game = g
	if g.net != null and not g.puppet:
		g.net.note_shot(self, kind, a, b, spd)          # (online host: the guest sees it too)
	if g.rec != null and not g.puppet:
		g.rec.note_shot(self, kind, a, b, spd)          # (and the replay)
	texture = Game.tex("res://assets/effects/%s.png" % kind)
	# an animated missile (the Arc Thrower's ball): its frames cycle in flight
	if ArtData.EFFECTS.has(kind) and int(ArtData.EFFECTS[kind]["frames"]) > 1:
		hframes = int(ArtData.EFFECTS[kind]["frames"])
	from = a
	to = b
	speed = spd
	_dur = maxf(a.distance_to(b) / speed, 0.04)
	position = a
	z_index = 6
	visible = not g.fx_hidden(a, b)       # (from and to ground the watching side has never looked at: unseen)
	g.add_child(self)
	_place(0.0)
	return self


func _place(f: float) -> void:
	var h := sin(f * PI) * from.distance_to(to) * arc
	var p := from.lerp(to, f) - Vector2(0, h)
	var dh := cos(f * PI) * PI * from.distance_to(to) * arc
	var vel := (to - from) - Vector2(0, dh)
	rotation = vel.angle() + face_offset
	position = p


func _process(delta: float) -> void:
	_t += delta
	if hframes > 1:
		frame = int(_t * 12.0) % hframes
	var f := clampf(_t / _dur, 0.0, 1.0)
	_place(f)
	if f >= 1.0:
		if impact != "" and game and is_instance_valid(game):
			var fx := game.spawn_effect(impact, to, 1.4)
			fx.scale = Vector2(impact_scale, impact_scale)
			fx.rotation = (to - from).angle() if impact == "acid_splash" else 0.0
		if impact_sound != "":
			Sfx.play_any([impact_sound, "combat/spitter_hit"], to)     # (a glob landing: heard only where your side sees)
		queue_free()
