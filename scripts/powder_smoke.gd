class_name PowderSmoke
extends Node2D
## Black powder smoke (docs/powder_smoke.md): every Crown powder shot leaves puffs of grey-white
## smoke that drift on a light wind, grow, thin and fade over 8 to 22 seconds, so a long
## firefight builds a haze over the firing line that clears slowly afterwards.
##
## Looks only. It never touches the simulation: its own random numbers (rng), nothing it does
## is read by the game, and it runs (or not, Settings.powder_smoke) the same on the host, the
## online guest and in replays. Puffs live in packed arrays (a ring: the newest overwrite the
## oldest) and are drawn in one MultiMesh, the haze under the units (z -15), and one puff in
## three again, half as solid, in a second one: a thin veil over them (z 1), under the effects,
## the overlay with the orders, the fog and the UI. A puff shows only where the watching side sees now: it is
## not made on ground out of sight, and one that drifts out of sight fades out.
##
## THICK (level 3, the owner's experiment, the default for now): a third more puffs, living a
## quarter longer and a little more solid, all drawn in ONE MultiMesh over everything in the
## world (z 60: over the units, their bars, the rings, the overlay with the orders, the fog)
## and still under the HUD, the minimap and the menus (CanvasLayers). No veil and no haze under.

const Z_UNDER := -15            # over the ground marks (-16), under every building and unit
const Z_VEIL := 1               # the thin veil over the units (body bars are z 1 too, effects 3)
const Z_TOP := 60               # THICK: over the whole world (the fog is z 40, the overlay with rings and orders 50)
const THICK := 3                # the level of the THICK experiment
const THICK_N := 1.34           # THICK: puffs per shot, as a share of FULL's (a musket 3 -> 4, a cannon 7 -> 9)
const THICK_A := 1.15           # THICK: a little more solid
const VEIL := 0.5               # how solid the veil's puffs are, as a share of the haze's
const VEIL_EVERY := 3           # the veil draws one puff in three (its own MultiMesh: a third of the fill)
const FRAMES := 3               # assets/effects/smoke.png frames 1..3 (frame 0 has the muzzle flash)

## Each kind of shot: [puffs on full, puffs on light, life min, life max, size at birth,
## size grown (both as a scale of the 27 px smoke frame), push (px/s, along the shot),
## spread (px around the muzzle), peak alpha].
const KINDS := {
	"musket": [3, 1, 10.0, 16.0, 0.6, 2.9, 30.0, 5.0, 0.42],
	"cannon": [7, 3, 16.0, 24.0, 1.0, 4.4, 46.0, 10.0, 0.48],
	"canister": [8, 3, 15.0, 22.0, 1.0, 4.2, 60.0, 14.0, 0.48],
	"mortar": [5, 2, 14.0, 20.0, 0.9, 3.6, 18.0, 8.0, 0.45],
	"keg": [8, 3, 15.0, 21.0, 1.2, 4.6, 30.0, 26.0, 0.48],
	"wagon": [16, 6, 17.0, 24.0, 1.5, 5.4, 40.0, 50.0, 0.5],
	"shell": [3, 1, 10.0, 15.0, 0.9, 3.2, 22.0, 14.0, 0.36],
}
const CAP := {3: 960, 2: 720, 1: 260}          # puffs alive at most (thick, full, light)
const LIFE_K := {3: 1.25, 2: 1.0, 1: 0.65}     # light: shorter lives; thick: longer
const HZ := {3: 20.0, 2: 20.0, 1: 12.0}         # how often the puffs move and the MultiMesh is refilled (they move a few px a second)
const SOFT := 0.8                      # past this share of the cap the oldest puffs age 12x faster (gone in a second or two)

static var force := -1                 # tests and tools: this level in every new match (-1: the setting)

var game: Game
var level := 2                         # 0 off, 1 light, 2 full, 3 thick (Settings.powder_smoke_level at the start)
var rng := RandomNumberGenerator.new()  # (its own: the game's random numbers are never touched)
var cap := 720
var made := 0                          # puffs made so far (tests)
var refused := 0                       # puffs not made: ground the watching side does not see (tests)

# the ring of puffs (struct of arrays, sized once)
var _pos := PackedVector2Array()
var _vel := PackedVector2Array()
var _age := PackedFloat32Array()
var _life := PackedFloat32Array()      # 0: a free slot
var _s0 := PackedFloat32Array()
var _s1 := PackedFloat32Array()
var _a := PackedFloat32Array()         # peak alpha
var _rot := PackedFloat32Array()
var _spin := PackedFloat32Array()
var _frame := PackedFloat32Array()
var _grey := PackedFloat32Array()
var _seen := PackedFloat32Array()      # 0..1: fades out where the watching side stops seeing
var _seen_to := PackedByteArray()
var _w := 0                            # where the next puff goes (the oldest slot)
var alive := 0

var _mm: MultiMesh
var _under: MultiMeshInstance2D
var _veil: MultiMeshInstance2D
var _buf := PackedFloat32Array()
var _mmv: MultiMesh                    # the veil's puffs
var _bufv := PackedFloat32Array()
var _capv := 0
var tick_us := 0                       # time spent moving the puffs and filling the buffers (the bench)
var ticks := 0
var _acc := 0.0
var _vis_t := 0.0
var wind := Vector2(7, 2)              # px/s: a light wind shared by every puff, slowly turning
var _wind_a := 0.0
var _wind_k := 0.0


func setup(g: Game, lv: int) -> void:
	game = g
	level = clampi(lv, 0, THICK)
	rng.seed = 0x5A0E ^ int(hash(g.map_name))       # (the same wind for the same map; never randomize())
	_wind_a = rng.randf() * TAU
	_wind_k = rng.randf_range(0.6, 1.4)
	cap = int(CAP.get(level, 0))
	_pos.resize(cap)
	_vel.resize(cap)
	# (packed arrays are values: each resized by name)
	_age.resize(cap)
	_life.resize(cap)
	_s0.resize(cap)
	_s1.resize(cap)
	_a.resize(cap)
	_rot.resize(cap)
	_spin.resize(cap)
	_frame.resize(cap)
	_grey.resize(cap)
	_seen.resize(cap)
	_life.fill(0.0)
	_seen_to.resize(cap)
	_buf.resize(cap * 16)
	_buf.fill(0.0)
	_capv = cap / VEIL_EVERY + 1
	_bufv.resize(_capv * 16)
	_bufv.fill(0.0)
	if level == 0:
		return
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_2D
	_mm.use_colors = true
	_mm.use_custom_data = true
	_mm.mesh = _quad()
	# (the puffs move every tick: one box over any map, or the MultiMesh is culled by its first puffs' box)
	_mm.custom_aabb = AABB(Vector3(-1.0e6, -1.0e6, -1.0), Vector3(2.0e6, 2.0e6, 2.0))
	_mm.instance_count = cap
	_mm.visible_instance_count = 0
	var tex := _atlas()
	var mat := ShaderMaterial.new()
	mat.shader = _shader()
	_under = MultiMeshInstance2D.new()
	_under.multimesh = _mm
	_under.texture = tex
	_under.material = mat
	_under.z_index = Z_TOP if level == THICK else Z_UNDER
	_under.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(_under)
	if level == THICK:
		_capv = 0                                    # (THICK: the one layer is already over everything)
		return
	_mmv = MultiMesh.new()
	_mmv.transform_format = MultiMesh.TRANSFORM_2D
	_mmv.use_colors = true
	_mmv.use_custom_data = true
	_mmv.mesh = _mm.mesh
	_mmv.custom_aabb = _mm.custom_aabb
	_mmv.instance_count = _capv
	_mmv.visible_instance_count = 0
	_veil = MultiMeshInstance2D.new()
	_veil.multimesh = _mmv
	_veil.texture = tex
	_veil.material = mat
	_veil.z_index = Z_VEIL
	_veil.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(_veil)


## One shot's smoke: `kind` from KINDS at p, pushed along `dir` (zero: no push, it just rises
## and spreads, as a blast's). Nothing on ground the watching side doesn't see now.
func puff(kind: String, p: Vector2, dir := Vector2.ZERO) -> void:
	if level == 0 or cap == 0 or not KINDS.has(kind):
		return
	if not sees(p):
		refused += 1
		return
	var k: Array = KINDS[kind]
	var n := int(k[0] if level >= 2 else k[1])
	if level == THICK:
		n = roundi(float(k[0]) * THICK_N)
	var ak := THICK_A if level == THICK else 1.0
	var lk := float(LIFE_K[level])
	var d := dir.normalized() if dir != Vector2.ZERO else Vector2.ZERO
	for i in n:
		var j := _w
		_w = (_w + 1) % cap
		if _life[j] <= 0.0:
			alive += 1
		var f := float(i) / maxf(float(n - 1), 1.0)
		var off := Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * float(k[7])
		_pos[j] = p + off + d * float(k[7]) * 1.5 * f          # (a gun's puffs roll out along the shot)
		var push := float(k[6]) * rng.randf_range(0.6, 1.2)
		var v := d * push * (1.0 - 0.5 * f)
		if d == Vector2.ZERO:
			v = off.normalized() * push * 0.5 if off != Vector2.ZERO else Vector2.ZERO
		_vel[j] = v
		_age[j] = 0.0
		_life[j] = rng.randf_range(float(k[2]), float(k[3])) * lk
		_s0[j] = float(k[4]) * rng.randf_range(0.8, 1.15)
		_s1[j] = float(k[5]) * rng.randf_range(0.8, 1.2)
		_a[j] = float(k[8]) * ak * rng.randf_range(0.8, 1.1)
		_rot[j] = rng.randf() * TAU
		_spin[j] = rng.randf_range(-0.08, 0.08)
		_frame[j] = float(rng.randi() % FRAMES)
		_grey[j] = rng.randf_range(0.80, 0.95)
		_seen[j] = 1.0
		_seen_to[j] = 1
		made += 1


## Does the watching side see the ground at p now (watching computers: through whose eyes; no
## fog: everywhere)?
func sees(p: Vector2) -> bool:
	if game == null:
		return false
	if game.sees_all():
		return true
	var ft := game.fog_team()
	if ft < 0:
		return true
	var sv = game._side_vis.get(game.sides[ft])
	if sv == null or (sv as PackedByteArray).size() != game.W * game.H:
		return game.ground_seen(p)
	var c := game.cell_of(p)
	if c.x < 0 or c.y < 0 or c.x >= game.W or c.y >= game.H:
		return false
	return (sv as PackedByteArray)[c.y * game.W + c.x] == 1


## Every puff gone (a replay's jump, tests).
func clear() -> void:
	_life.fill(0.0)
	alive = 0
	if _mm:
		_mm.visible_instance_count = 0
		if _mmv:
			_mmv.visible_instance_count = 0


func _process(delta: float) -> void:
	if level == 0 or game == null:
		return
	var _p0 := Time.get_ticks_usec()
	_acc += delta
	var step := 1.0 / float(HZ[level])
	if _acc >= step:
		tick(_acc)
		_acc = 0.0
		tick_us += Time.get_ticks_usec() - _p0
		ticks += 1
	Prof.add("powder smoke", _p0)


## Move, grow and fade every puff by dt, and refill the MultiMesh (only the puffs in view).
func tick(dt: float) -> void:
	if alive == 0:
		if _mm and _mm.visible_instance_count != 0:
			_mm.visible_instance_count = 0
			if _mmv:
				_mmv.visible_instance_count = 0
		return
	# the wind: light, turning slowly over the match (minutes for a half turn), a little gusty
	var clk := game.clock
	var ang := _wind_a + sin(clk * 0.004 * _wind_k) * 2.2 + sin(clk * 0.031) * 0.25
	wind = Vector2.from_angle(ang) * (6.0 + 2.5 * sin(clk * 0.05 * _wind_k + 1.3))
	_vis_t -= dt
	var check := _vis_t <= 0.0
	if check:
		_vis_t = 0.25
	var over := alive - int(float(cap) * SOFT)      # (near the cap: the oldest fade early)
	var vr: Rect2 = game.view_rect
	var all_view := vr.size == Vector2.ZERO
	var damp := pow(0.35, dt)                        # (the shot's push dies away in about a second)
	var n := 0
	var nv := 0
	var j := _w                                      # (oldest first)
	for _i in cap:
		var life := _life[j]
		if life > 0.0:
			var age := _age[j] + dt * (12.0 if over > 0 else 1.0)
			if over > 0:
				over -= 1
			if age >= life:
				_life[j] = 0.0
				alive -= 1
			else:
				_age[j] = age
				var v := _vel[j] * damp
				_vel[j] = v
				var p := _pos[j] + (v + wind) * dt
				_pos[j] = p
				_rot[j] += _spin[j] * dt
				if check:
					_seen_to[j] = 1 if sees(p) else 0
				var sn := _seen[j]
				if _seen_to[j] == 1:
					sn = minf(sn + dt * 2.0, 1.0)
				else:
					sn = maxf(sn - dt * 1.5, 0.0)
				_seen[j] = sn
				if sn > 0.0 and (all_view or vr.has_point(p)):
					var x := age / life
					var g := 1.0 - (1.0 - x) * (1.0 - x)
					var s := (_s0[j] + (_s1[j] - _s0[j]) * g) * 27.0
					var al := _a[j] * minf(age * 6.0, 1.0) * (1.0 - pow(x, 1.6)) * sn      # (thick for a while, then vanishing slowly)
					var c := cos(_rot[j]) * s
					var si := sin(_rot[j]) * s
					var o := n * 16
					# Transform2D rows for the MultiMesh: [x.x, y.x, pad, origin.x, x.y, y.y, pad, origin.y]
					_buf[o] = c
					_buf[o + 1] = -si * 0.8
					_buf[o + 2] = 0.0
					_buf[o + 3] = p.x
					_buf[o + 4] = si
					_buf[o + 5] = c * 0.8
					_buf[o + 6] = 0.0
					_buf[o + 7] = p.y
					var gr := _grey[j] - 0.12 * x          # (older smoke a little greyer)
					_buf[o + 8] = gr
					_buf[o + 9] = gr
					_buf[o + 10] = gr * 0.97
					_buf[o + 11] = al
					_buf[o + 12] = _frame[j]
					n += 1
					if j % VEIL_EVERY == 0 and nv < _capv:
						var ov := nv * 16
						for q in 13:
							_bufv[ov + q] = _buf[o + q]
						_bufv[ov + 11] = al * VEIL
						nv += 1
		j += 1
		if j >= cap:
			j = 0
	if _mm == null:
		return
	# (per instance: transform 8 floats, colour 4, custom 4: the frame, then three unused)
	if n > 0:
		_mm.buffer = _buf
	_mm.visible_instance_count = n
	if _mmv == null:
		return
	if nv > 0:
		_mmv.buffer = _bufv
	_mmv.visible_instance_count = nv


## A 1x1 quad centred on 0 (the transform scales it to the puff), UVs the right way up in 2D.
static func _quad() -> ArrayMesh:
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = PackedVector2Array([Vector2(-0.5, -0.5), Vector2(0.5, -0.5), Vector2(0.5, 0.5), Vector2(-0.5, 0.5)])
	arr[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	arr[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m


## The painted smoke (assets/effects/smoke.png) without its first frame (the muzzle flash): three
## puffs side by side, made once.
static var _atlas_tex: Texture2D = null
static func _atlas() -> Texture2D:
	if _atlas_tex != null:
		return _atlas_tex
	var src: Texture2D = Game.tex("res://assets/effects/smoke.png")
	if src == null:
		return null
	var img := src.get_image()
	if img == null:
		return src
	if img.is_compressed():
		img.decompress()
	var fw := int(ArtData.EFFECTS["smoke"]["size"].x)
	var fh := img.get_height()
	var out := Image.create(fw * FRAMES, fh, false, Image.FORMAT_RGBA8)
	img.convert(Image.FORMAT_RGBA8)
	for f in FRAMES:
		out.blit_rect(img, Rect2i(fw * (f + 1), 0, fw, fh), Vector2i(fw * f, 0))
	_atlas_tex = ImageTexture.create_from_image(out)
	return _atlas_tex


static var _shader_res: Shader = null
static func _shader() -> Shader:
	if _shader_res == null:
		_shader_res = Shader.new()
		_shader_res.code = """
shader_type canvas_item;
// Powder smoke (scripts/powder_smoke.gd): each instance picks its frame of the smoke atlas
// (INSTANCE_CUSTOM.x) and is tinted grey-white by its colour (taken in vertex(): in fragment()
// COLOR already holds the texture at the whole atlas's UV).
varying float frame;
varying vec4 tint;
void vertex() {
	frame = INSTANCE_CUSTOM.x;
	tint = COLOR;
}
void fragment() {
	vec4 t = texture(TEXTURE, vec2((UV.x + frame) / %d.0, UV.y));
	// (the art's own shading kept a little, pulled toward a soft light grey so the haze reads as
	// one; its darkest edge pixels thinner, so the grown puffs have soft edges)
	float l = dot(t.rgb, vec3(0.3, 0.59, 0.11));
	COLOR = vec4(vec3(mix(l, 0.93, 0.6)) * tint.rgb, t.a * tint.a * smoothstep(0.15, 0.6, l));
}
""" % FRAMES
	return _shader_res
