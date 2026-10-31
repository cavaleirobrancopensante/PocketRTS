class_name OccludedLook
extends Node2D
## UNITS HIDDEN BEHIND BIG SPRITES (the owner's playtest, 2026-10-30 19:13: a grub behind the Brood Mother can't be
## seen): as StarCraft 2 and Warcraft 3 do, a unit standing BEHIND a bigger picture that covers it (a building of any
## side, a rooted Brood creature, a big creature: the Mother, a father, a Pendulum...) is drawn again ON TOP as a
## SILHOUETTE: a flat translucent fill in its side's colour with a bright rim (SHADER), over the picture hiding it.
## Cheap for big battles: only YOUR units and the selected ones are looked at, only those whose picture overlaps a
## coverer's picture drawn in front of them (sorted lower on the screen), only on screen; the list is redone
## SCAN times a second (Game.occluded_layer, z 2: over the buildings and walkers, under the flyers and fog).
##
## ONLY WHEN REALLY HIDDEN (the owner's playtest, 2026-10-31: "any contact the unit has with a building triggers a
## shadow... the gears supposedly count, so mostly all of the Clockwork workers are showing the shadow"; 0.25.2,
## docs/bars_ghost_sil.md): a unit counts as hidden only where the coverer's picture is really drawn over it: it sorts
## behind it (its feet above the coverer's base line) and the coverer's OPAQUE pixels lie over at least COVER of the
## unit's own opaque pixels (both looked up in a 1-bit alpha mask of each texture, _mask, sampled on a SAMPLES grid).
## The ground (gear rings, floor plates, brass plates, decals) is never a coverer: only building and creature sprites
## are. And only the COVERED PART of the unit is drawn as a silhouette: each silhouette is a pooled Sprite2D whose
## shader keeps a pixel only where the coverer's own picture is opaque there (the mask_* uniforms). A coverer with no
## plain sprite (a rooted Brood creature: BroodRoot.body_rect) is a rect as before, and the whole unit shows.

const SCAN := 0.1                # s between two looks for hidden units (the silhouettes themselves follow every frame)
const BIG_R := 22.0              # a walking creature this big (radius) covers the units behind it
const FILL := 0.42               # the fill's opacity; the rim is drawn at RIM
const RIM := 0.95
const COVER := 0.3               # share of the unit's opaque pixels the coverer's opaque pixels must lie over
const SAMPLES := Vector2i(6, 8)  # the grid over the unit's frame where both masks are looked up
const MAX_SIL := 64              # silhouettes drawn at most (the pool)
const SHADER := """
shader_type canvas_item;
uniform sampler2D mask_tex : filter_nearest;
uniform vec2 mask_x = vec2(0.0);
uniform vec2 mask_y = vec2(0.0);
uniform vec2 mask_o = vec2(0.0);
uniform vec4 mask_rect = vec4(0.0, 0.0, 1.0, 1.0);
uniform float use_mask = 0.0;
varying vec4 tint;
varying vec2 wpos;
void vertex() {
	tint = COLOR;
	wpos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}
void fragment() {
	float a = texture(TEXTURE, UV).a;
	vec2 px = TEXTURE_PIXEL_SIZE;
	float n = min(min(texture(TEXTURE, UV + vec2(px.x, 0.0)).a, texture(TEXTURE, UV - vec2(px.x, 0.0)).a),
		min(texture(TEXTURE, UV + vec2(0.0, px.y)).a, texture(TEXTURE, UV - vec2(0.0, px.y)).a));
	float rim = step(0.5, a) * (1.0 - step(0.5, n));
	float m = 1.0;
	if (use_mask > 0.5) {
		vec2 muv = mask_x * wpos.x + mask_y * wpos.y + mask_o;
		bool inside = muv.x >= mask_rect.x && muv.y >= mask_rect.y && muv.x <= mask_rect.z && muv.y <= mask_rect.w;
		m = inside ? step(0.5, texture(mask_tex, muv).a) : 0.0;
	}
	COLOR = vec4(mix(tint.rgb, vec3(1.0), rim * 0.35), step(0.5, a) * mix(tint.a, %s, rim) * m);
}
"""

static var on := true          # (off: no silhouettes; the tests' before/after pictures)
static var _masks := {}        # Texture2D -> BitMap of its alpha (null: none to read: counted as opaque)
var game: Node = null
var hidden_units: Array = []     # the units drawn as silhouettes now (the tests read it)
var cover_of := {}               # Unit -> the Sprite2D covering it (null: a rect coverer, the whole unit shows)
var _t := 0.0
var _shader: Shader
var _pool: Array = []            # Sprite2D silhouettes (each with its own ShaderMaterial)


func _ready() -> void:
	z_index = 2
	_shader = Shader.new()
	_shader.code = SHADER % str(RIM)


func _process(delta: float) -> void:
	_t -= delta
	if _t <= 0.0:
		_t = SCAN
		scan()
	_follow()


## What covers a unit: [its picture's rect, the y it is sorted at, the coverer, its Sprite2D or null] for each building and
## big creature in view.
func _coverers(vr: Rect2) -> Array:
	var out: Array = []
	for b in game.buildings:
		if b.dead or not b.visible:
			continue
		var r: Rect2 = b.sprite_rect()
		if r.size.x > 1.0 and vr.intersects(r):
			var bs: Sprite2D = b.sprite if b.sprite != null and b.sprite.visible and b.sprite.texture != null else null
			out.append([_sprite_rect(bs) if bs != null else r, b.global_position.y, b, bs])
	for u in game.units:
		if u.dead or not u.visible or u.is_air() or u.sprite == null:
			continue
		var rooted: bool = u._k_nb and BroodRoot.has_fp(u)
		if not rooted and u.radius < BIG_R and u.kind != BroodNew.QUEEN:
			continue
		if u._k_nb:
			var r: Rect2 = BroodRoot.body_rect(u)
			if r.size.x > 1.0 and vr.intersects(r):
				out.append([r, BroodRoot.sort_y(u), u, null])
		else:
			var r2 := _sprite_rect(u.sprite)
			if r2.size.x > 1.0 and vr.intersects(r2):
				out.append([r2, u.position.y, u, u.sprite])
	return out


## Looks again for the units hidden behind a bigger picture.
func scan() -> void:
	hidden_units.clear()
	cover_of.clear()
	if game == null or not on:
		return
	var vr: Rect2 = game.view_rect.grow(64.0)
	var me: int = game.human
	var cov := _coverers(vr)
	if cov.is_empty():
		return
	var best := {}               # Unit -> [share covered, coverer sprite]
	for c in cov:
		var cr: Rect2 = c[0]
		var cs: Sprite2D = c[3]
		for u in game.units_near(cr.get_center(), cr.size.length() * 0.5 + 40.0):
			if u == c[2] or u.dead or not u.visible or u.is_air() or u.sprite == null or not u.sprite.visible:
				continue
			if not (u.team == me or game.selection.has(u)):
				continue
			if u._k_nb and BroodRoot.has_fp(u):
				continue          # (rooted itself: a structure)
			if u.position.y >= float(c[1]):
				continue          # (in front of it: drawn over it already)
			var ur := _sprite_rect(u.sprite)
			if not ur.intersects(cr):
				continue
			var share := 0.0
			if cs == null:
				share = ur.intersection(cr).get_area() / maxf(ur.get_area(), 1.0)
				if share < 0.25:
					continue      # (barely touched: still seen)
			else:
				share = covered_share(u.sprite, cs)
				if share < COVER:
					continue      # (the coverer's picture doesn't really lie over it: its empty corners, its edges)
			if not best.has(u) or share > float(best[u][0]):
				best[u] = [share, cs]
	for u in best:
		hidden_units.append(u)
		cover_of[u] = best[u][1]
		if hidden_units.size() >= MAX_SIL:
			break


## The share of sprite s's opaque pixels (on a SAMPLES grid over its frame) that sprite c's opaque pixels lie over.
static func covered_share(s: Sprite2D, c: Sprite2D) -> float:
	var r := _sprite_rect(s)
	var cr := _sprite_rect(c)
	var mine := 0
	var hit := 0
	for j in SAMPLES.y:
		for i in SAMPLES.x:
			var p := r.position + Vector2((float(i) + 0.5) / float(SAMPLES.x) * r.size.x, (float(j) + 0.5) / float(SAMPLES.y) * r.size.y)
			if not opaque_at(s, p):
				continue
			mine += 1
			if cr.has_point(p) and opaque_at(c, p):
				hit += 1
	return float(hit) / float(mine) if mine > 0 else 0.0


## Is sprite s drawn opaque at world point p (its current frame, through its 1-bit alpha mask)?
static func opaque_at(s: Sprite2D, p: Vector2) -> bool:
	var dst := s.get_rect()
	if dst.size.x <= 0.0 or dst.size.y <= 0.0:
		return false
	var lp := s.get_global_transform().affine_inverse() * p
	var u := (lp.x - dst.position.x) / dst.size.x
	var v := (lp.y - dst.position.y) / dst.size.y
	if u < 0.0 or v < 0.0 or u >= 1.0 or v >= 1.0:
		return false
	if s.flip_h:
		u = 1.0 - u
	if s.flip_v:
		v = 1.0 - v
	var bm: BitMap = _mask(s.texture)
	if bm == null:
		return true
	var src := _src_rect(s)
	var x := clampi(int(src.position.x + u * src.size.x), 0, bm.get_size().x - 1)
	var y := clampi(int(src.position.y + v * src.size.y), 0, bm.get_size().y - 1)
	return bm.get_bit(x, y)


## A texture's alpha as a BitMap (made once, kept).
static func _mask(t: Texture2D) -> BitMap:
	if t == null:
		return null
	if _masks.has(t):
		return _masks[t]
	if _masks.size() > 400:
		_masks.clear()
	var bm: BitMap = null
	var img := t.get_image()
	if img != null and not img.is_empty():
		if img.is_compressed():
			img.decompress()
		bm = BitMap.new()
		bm.create_from_image_alpha(img, 0.5)
	_masks[t] = bm
	return bm


## Each frame: the pooled silhouettes follow their units' sprites (frame, flip, place) and their coverers' pictures.
func _follow() -> void:
	var n := 0
	for u in hidden_units:
		if not is_instance_valid(u) or u.dead:
			continue
		var s: Sprite2D = u.sprite
		if s == null or s.texture == null or not s.visible:
			continue
		var sil := _sil(n)
		n += 1
		sil.visible = true
		sil.texture = s.texture
		sil.centered = s.centered
		sil.offset = s.offset
		sil.flip_h = s.flip_h
		sil.flip_v = s.flip_v
		sil.region_enabled = s.region_enabled
		sil.region_rect = s.region_rect
		sil.hframes = maxi(1, s.hframes)
		sil.vframes = maxi(1, s.vframes)
		sil.frame = clampi(s.frame, 0, sil.hframes * sil.vframes - 1)
		sil.global_transform = s.get_global_transform()
		var col: Color = u.cloth_colour()
		col.a = FILL
		sil.self_modulate = col
		var m: ShaderMaterial = sil.material
		var c = cover_of.get(u)
		if c != null and is_instance_valid(c) and (c as Sprite2D).texture != null:
			_set_mask(m, c)
		else:
			m.set_shader_parameter("use_mask", 0.0)
	for i in range(n, _pool.size()):
		(_pool[i] as Sprite2D).visible = false


func _sil(i: int) -> Sprite2D:
	while _pool.size() <= i:
		var sp := Sprite2D.new()
		var m := ShaderMaterial.new()
		m.shader = _shader
		sp.material = m
		add_child(sp)
		_pool.append(sp)
	return _pool[i]


## The mask uniforms: world point -> the coverer's texture UV (its frame, flip and place now), and its frame's UV rect.
static func _set_mask(m: ShaderMaterial, c: Sprite2D) -> void:
	var ts := c.texture.get_size()
	var dst := c.get_rect()
	var src := _src_rect(c)
	if dst.size.x <= 0.0 or dst.size.y <= 0.0 or ts.x <= 0.0 or ts.y <= 0.0:
		m.set_shader_parameter("use_mask", 0.0)
		return
	var ax := src.size.x / (dst.size.x * ts.x)
	var bx := (src.position.x - dst.position.x * src.size.x / dst.size.x) / ts.x
	if c.flip_h:
		ax = -ax
		bx = (src.position.x + src.size.x + dst.position.x * src.size.x / dst.size.x) / ts.x
	var ay := src.size.y / (dst.size.y * ts.y)
	var by := (src.position.y - dst.position.y * src.size.y / dst.size.y) / ts.y
	if c.flip_v:
		ay = -ay
		by = (src.position.y + src.size.y + dst.position.y * src.size.y / dst.size.y) / ts.y
	var xf := Transform2D(Vector2(ax, 0.0), Vector2(0.0, ay), Vector2(bx, by)) * c.get_global_transform().affine_inverse()
	m.set_shader_parameter("mask_tex", c.texture)
	m.set_shader_parameter("mask_x", xf.x)
	m.set_shader_parameter("mask_y", xf.y)
	m.set_shader_parameter("mask_o", xf.origin)
	m.set_shader_parameter("mask_rect", Vector4(src.position.x / ts.x, src.position.y / ts.y, src.end.x / ts.x, src.end.y / ts.y))
	m.set_shader_parameter("use_mask", 1.0)


## The frame of the sprite's texture it shows now (as Sprite2D picks it).
static func _src_rect(s: Sprite2D) -> Rect2:
	var base := s.region_rect if s.region_enabled else Rect2(Vector2.ZERO, s.texture.get_size())
	var fs := base.size / Vector2(maxi(1, s.hframes), maxi(1, s.vframes))
	return Rect2(base.position + Vector2(s.frame % maxi(1, s.hframes), s.frame / maxi(1, s.hframes)) * fs, fs)


## Where a sprite is drawn in the world.
static func _sprite_rect(s: Sprite2D) -> Rect2:
	if s == null:
		return Rect2()
	var r := s.get_rect()
	var xf := s.get_global_transform()
	var a: Vector2 = xf * r.position
	var b: Vector2 = xf * r.end
	return Rect2(Vector2(minf(a.x, b.x), minf(a.y, b.y)), (b - a).abs())
