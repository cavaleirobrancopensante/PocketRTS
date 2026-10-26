class_name ChainNet
extends Node2D
## The Netter's net in flight (Netter.fire; Defs.NET): a bundle of chain with its weights ahead
## (assets/effects/netter_net.png, pointing right), flying from the spring cannon's muzzle along a low arc at Defs.NET
## "speed" px/s, following its target's body; it opens a little as it flies. Where it reaches the target, the target is
## caught (Netter.catch). If the target is gone (dead, removed, aboard) the net drops where it was going, harmless.
## On an online guest the same node flies as a picture only (`view`: NetSession.play_fx), following the guest's copy.

var game: Game
var from := Vector2.ZERO
var to := Vector2.ZERO          # where it is going now (the target's body, followed)
var target: Unit = null
var shooter: Entity = null
var team := 0
var speed := 380.0
var damage := 4.0
var view := false               # (an online guest) only the picture: no catch
var t := 0.0
var duration := 0.3
var landed := false
var sprite: Sprite2D
var _counted := true            # (on the target's `nets_in` until it lands or is gone)


func _ready() -> void:
	sprite = Sprite2D.new()
	sprite.texture = Game.tex("res://assets/effects/netter_net.png")
	add_child(sprite)
	z_index = 6
	_counted = not view
	if target != null and is_instance_valid(target):
		to = target.center()
	duration = maxf(from.distance_to(to) / maxf(speed, 1.0), 0.08)
	visible = game == null or not game.fx_hidden(from, to)     # (over ground the watching side has never looked at: unseen)
	_place(0.0)


func _physics_process(delta: float) -> void:
	if landed:
		return
	t += delta
	if target != null and is_instance_valid(target) and not target.dead:
		to = target.center()
	var f := clampf(t / duration, 0.0, 1.0)
	_place(f)
	if f >= 1.0:
		landed = true
		_release()
		if not view and target != null and is_instance_valid(target) and not target.dead:
			Netter.catch(target, shooter, damage)
		elif game and is_instance_valid(game) and visible:
			var fx := game.spawn_effect("dust", to + Vector2(0, 10), 1.6)     # (nobody left to catch: it drops)
			fx.scale = Vector2(0.4, 0.3)
		queue_free()


func _exit_tree() -> void:
	_release()


## Off the target's count of nets flying at it.
func _release() -> void:
	if _counted:
		_counted = false
		if target != null and is_instance_valid(target):
			target.nets_in = maxi(0, target.nets_in - 1)


func _place(f: float) -> void:
	var dist := from.distance_to(to)
	var arc := float(Defs.NET["arc"])
	position = from.lerp(to, f) - Vector2(0.0, sin(f * PI) * dist * arc)
	var vel := (to - from) - Vector2(0.0, cos(f * PI) * PI * dist * arc)
	if vel.length() > 0.01:
		sprite.rotation = vel.angle()
	sprite.flip_v = vel.x < 0.0          # (flying left: still the right way up)
	var s := lerpf(0.8, 1.15, f)          # (it opens as it flies)
	sprite.scale = Vector2(s, s)
