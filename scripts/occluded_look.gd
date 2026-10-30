class_name OccludedLook
extends Node2D
## UNITS HIDDEN BEHIND BIG SPRITES (the owner's playtest, 2026-10-30 19:13: a grub behind the Brood Mother can't be
## seen): as StarCraft 2 and Warcraft 3 do, a unit standing BEHIND a bigger picture that covers it (a building of any
## side, a rooted Brood creature, a big creature: the Mother, a father, a Pendulum...) is drawn again ON TOP as a
## SILHOUETTE: a flat translucent fill in its side's colour with a bright rim (SHADER), over the picture hiding it.
## Cheap for big battles: only YOUR units and the selected ones are looked at, only those whose picture overlaps a
## coverer's picture drawn in front of them (sorted lower on the screen), only on screen; the list is redone
## SCAN times a second (Game.occluded_layer, z 2: over the buildings and walkers, under the flyers and fog).

const SCAN := 0.1                # s between two looks for hidden units (the silhouettes themselves follow every frame)
const BIG_R := 22.0              # a walking creature this big (radius) covers the units behind it
const FILL := 0.42               # the fill's opacity; the rim is drawn at RIM
const RIM := 0.95
const SHADER := """
shader_type canvas_item;
varying vec4 tint;
void vertex() { tint = COLOR; }
void fragment() {
	float a = texture(TEXTURE, UV).a;
	vec2 px = TEXTURE_PIXEL_SIZE;
	float n = min(min(texture(TEXTURE, UV + vec2(px.x, 0.0)).a, texture(TEXTURE, UV - vec2(px.x, 0.0)).a),
		min(texture(TEXTURE, UV + vec2(0.0, px.y)).a, texture(TEXTURE, UV - vec2(0.0, px.y)).a));
	float rim = step(0.5, a) * (1.0 - step(0.5, n));
	COLOR = vec4(mix(tint.rgb, vec3(1.0), rim * 0.35), step(0.5, a) * mix(tint.a, %s, rim));
}
"""

static var on := true          # (off: no silhouettes; the tests' before/after pictures)
var game: Node = null
var hidden_units: Array = []     # the units drawn as silhouettes now (the tests read it)
var _t := 0.0


func _ready() -> void:
	z_index = 2
	var sh := Shader.new()
	sh.code = SHADER % str(RIM)
	material = ShaderMaterial.new()
	(material as ShaderMaterial).shader = sh


func _process(delta: float) -> void:
	_t -= delta
	if _t <= 0.0:
		_t = SCAN
		scan()
	if not hidden_units.is_empty() or _t == SCAN:
		queue_redraw()


## What covers a unit: [its picture's rect, the y it is sorted at] for each building and big creature in view.
func _coverers(vr: Rect2) -> Array:
	var out: Array = []
	for b in game.buildings:
		if b.dead or not b.visible:
			continue
		var r: Rect2 = b.sprite_rect()
		if r.size.x > 1.0 and vr.intersects(r):
			out.append([r, b.global_position.y, b])
	for u in game.units:
		if u.dead or not u.visible or u.is_air() or u.sprite == null:
			continue
		var rooted: bool = u._k_nb and BroodRoot.has_fp(u)
		if not rooted and u.radius < BIG_R and u.kind != BroodNew.QUEEN:
			continue
		var r: Rect2 = BroodRoot.body_rect(u) if u._k_nb else _sprite_rect(u.sprite)
		if r.size.x > 1.0 and vr.intersects(r):
			out.append([r, BroodRoot.sort_y(u) if u._k_nb else u.position.y, u])
	return out


## Looks again for the units hidden behind a bigger picture.
func scan() -> void:
	hidden_units.clear()
	if game == null or not on:
		return
	var vr: Rect2 = game.view_rect.grow(64.0)
	var me: int = game.human
	var cov := _coverers(vr)
	if cov.is_empty():
		return
	var seen := {}
	for c in cov:
		var cr: Rect2 = c[0]
		for u in game.units_near(cr.get_center(), cr.size.length() * 0.5 + 40.0):
			if seen.has(u) or u == c[2] or u.dead or not u.visible or u.is_air() or u.sprite == null or not u.sprite.visible:
				continue
			if not (u.team == me or game.selection.has(u)):
				continue
			if u._k_nb and BroodRoot.has_fp(u):
				continue          # (rooted itself: a structure)
			if u.position.y >= float(c[1]):
				continue          # (in front of it: drawn over it already)
			var ur := _sprite_rect(u.sprite)
			var hit := ur.intersection(cr)
			if hit.get_area() < ur.get_area() * 0.25:
				continue          # (barely touched: still seen)
			seen[u] = true
			hidden_units.append(u)


func _draw() -> void:
	if hidden_units.is_empty():
		return
	var inv := get_global_transform().affine_inverse()
	for u in hidden_units:
		if not is_instance_valid(u) or u.dead:
			continue
		var s: Sprite2D = u.sprite
		if s == null or s.texture == null or not s.visible:
			continue
		var col: Color = u.cloth_colour()
		col.a = FILL
		draw_set_transform_matrix(inv * s.get_global_transform())
		var src := _src_rect(s)
		var dst := s.get_rect()
		if s.flip_h:
			dst.size.x = -dst.size.x          # (as Sprite2D draws a flipped frame)
		if s.flip_v:
			dst.size.y = -dst.size.y
		draw_texture_rect_region(s.texture, dst, src, col)
	draw_set_transform_matrix(Transform2D.IDENTITY)


## The frame of the sprite's texture it shows now (as Sprite2D picks it).
static func _src_rect(s: Sprite2D) -> Rect2:
	var base := s.region_rect if s.region_enabled else Rect2(Vector2.ZERO, s.texture.get_size())
	var fs := base.size / Vector2(maxi(1, s.hframes), maxi(1, s.vframes))
	return Rect2(base.position + Vector2(s.frame % maxi(1, s.hframes), s.frame / maxi(1, s.hframes)) * fs, fs)


## Where a sprite is drawn in the world.
static func _sprite_rect(s: Sprite2D) -> Rect2:
	var r := s.get_rect()
	var xf := s.get_global_transform()
	var a: Vector2 = xf * r.position
	var b: Vector2 = xf * r.end
	return Rect2(Vector2(minf(a.x, b.x), minf(a.y, b.y)), (b - a).abs())
