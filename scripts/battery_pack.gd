extends Sprite2D
## A Clockwork construct's battery, strapped to its back: a child of the unit's body
## sprite, so it flips, bobs, hovers and goes cold with it (it shares the body's team
## shader). Every frame it follows the body's animation frame to the spot ArtData.PACKS
## gives for it (tools/make_packs.py), turns to the matching view of the cell, hangs in
## front of or behind the body, and shows the charge: the glowing fluid and the sight
## slot fill with `wind`, greyed out when it's flat.

var unit: Unit
var _packs: Dictionary


func _ready() -> void:
	var p: Dictionary = ArtData.PACKS[unit.kind]
	_packs = p["keys"]
	texture = Game.tex("res://assets/effects/pack_%s.png" % p["type"])
	hframes = 14
	vframes = 5
	centered = true
	use_parent_material = true


func _process(_delta: float) -> void:
	if unit.dead:
		visible = false      # the construct falls apart; the cell goes with it
		set_process(false)
		return
	var frames: Array = _packs.get(unit.anim + "_" + unit.anim_dir, [])
	if frames.is_empty():
		visible = false
		return
	var body := get_parent() as Sprite2D
	var e: Array = frames[mini(body.frame, frames.size() - 1)]
	var level := clampi(int(round(unit.wind * 13.0)), 0, 13)
	visible = true
	frame = int(e[0]) * 14 + level
	show_behind_parent = not e[1]
	position = Vector2(e[2], e[3])
	rotation_degrees = e[4]
	self_modulate = Color(1, 1, 1) if unit.wind > 0.0 else Color(0.6, 0.6, 0.6)
