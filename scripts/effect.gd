class_name Effect
extends Sprite2D
## A one-shot (or looping) animated effect from assets/effects.

var fps := 10.0
var loop := false
var t := 0.0
var n := 1
static var live := 0         # effects on the field now (the match log's Performance line)


func _enter_tree() -> void:
	live += 1


func _exit_tree() -> void:
	live -= 1


func setup(name: String, speed := 1.0, looping := false) -> void:
	var info: Dictionary = ArtData.EFFECTS[name]
	texture = Game.tex("res://assets/effects/%s.png" % name)
	hframes = info["frames"]
	n = hframes
	fps = 10.0 * speed
	loop = looping
	centered = true
	if name in ["fire", "dust", "blast", "blaze"]:
		offset = Vector2(0, -float(info["size"].y) * 0.4)


func _process(delta: float) -> void:
	t += delta * fps
	var f := int(t)
	if f >= n:
		if loop:
			t = fmod(t, float(n))
			f = int(t)
		else:
			queue_free()
			return
	frame = f
	if not loop and n >= 4 and f >= n - 2:
		modulate.a = minf(modulate.a, clampf(float(n) - t, 0.0, 1.0) * 0.5 + 0.2)
