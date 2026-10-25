class_name OreDrill
extends RefCounted
## The Clockwork's Ore Drill (phase 2 of the Line): it digs its Clocktower's ore into `stock` at the Line's
## pressure and waits for an Ore Train (scripts/train.gd) to carry it off. Spent ore: a quarter (Defs.LODE_SPENT),
## like every mill. Nothing here needs Winders.

static var _frames: Array = []
static var _frames_ok := true


## (Building._econ, every frame) dig.
static func tick(b: Building, delta: float) -> void:
	var cap := float(Defs.RAIL["drill"]["stock"])
	var speed := b.game.line_net.speed_mult(b)
	var working := false
	if speed > 0.0 and b.stock < cap and not b.barren():
		var want := minf(float(Defs.RAIL["drill"]["rate"]) * speed * delta, cap - b.stock)
		b.stock += b.game.draw_lode(b, want)
		working = true
	b.drill_on = working
	_animate(b, working)


static func working(b: Building) -> bool:
	return b.drill_on


## The working loop (assets/buildings/ore_drill_working.png, 4 frames side by side) while it digs.
static func _animate(b: Building, working: bool) -> void:
	if b.sprite == null or b.hp < b.max_hp * 0.5:
		return
	if not working:
		if b.drill_anim:
			b.drill_anim = false
			b._update_sprite()
		return
	if _frames.is_empty() and _frames_ok:
		var strip: Texture2D = LineArt.tex("buildings/ore_drill_working.png")
		if strip == null:
			_frames_ok = false
		else:
			var fw := strip.get_width() / 4
			for i in 4:
				var at := AtlasTexture.new()
				at.atlas = strip
				at.region = Rect2(i * fw, 0, fw, strip.get_height())
				_frames.append(at)
	if _frames.is_empty():
		return
	b.drill_anim = true
	var i := int(b.game.clock * 6.0) % 4
	var t: Texture2D = _frames[i]
	if b.sprite.texture != t:
		b.sprite.texture = t
		b.sprite.offset = Building.body_offset(b.kind, t)


static func reset() -> void:
	_frames.clear()
	_frames_ok = true
