class_name HeavyWorks
extends Node2D
## THE HEAVY WORKS' BAY (owner, 2026-10-27: "I want the actual vehicles to be shown being assembled there"; docs/gear_rules.md).
## The yard's painted bay is EMPTY (art/redraws/heavy_works_empty_chatgpt.png, tools/press_anim/heavy_works_key.py); while
## the Heavy Works trains a machine (a Pendulum, a Spring Ballista, later the Great Winder), this node draws THAT UNIT'S OWN
## SPRITE (the first frame of its idle strip, facing out of the bay) standing on the bay floor under the crane, BUILT UP
## FROM THE GROUND as the training goes on: shown from the bottom up in STEPS steps (each part is bolted on whole), dark
## at first and brightening toward its true colours, a thin hot seam glowing along the top of what is built so far; the
## crane's chain and hook (cut off the painted frame, drawn here) hang down to the top of the work. Idle: an empty bay, the
## hook back up where it was painted. Under construction and as a ruin: nothing (their frames keep their own hook).
## Drawn every frame from the building's queue and prod_t, so an online guest (whose buildings are not ticked) and a
## replay show it too. Code-drawn parts (the seam, the chain's length, the darkening): docs/art_style_inconsistency.md.

## The bay, in px from the building's anchor (its footprint's bottom-centre): where the machine's feet stand, where the
## chain hangs from the gantry beam (its top) and where the painted hook rests when idle (its top). Measured on the art
## (sheet px -> game px: (x - 10) / 3 - 60, (y - 70) / 3 - 129; tools/press_anim/heavy_works_key.py).
const FEET := Vector2(14, -37)
const CHAIN_TOP := Vector2(14, -105)
const HOOK_REST := -82.0           # (the hook's top, y, when idle)
## The room in the bay (px): the machine is scaled down to fit (never up).
const ROOM := Vector2(64, 58)
## The view the machine is drawn in (out of the bay, toward the viewer).
const DIR := "se"
const STEPS := 6                    # its parts come in this many steps, bottom up
const DARK := 0.32                  # its brightness when the first part is in (1 when done)

var b: Building
var _tex: Texture2D = null
var _kind := ""
var _cell := Rect2()
var _anchor := Vector2.ZERO
var _scale := 1.0
var shown := ""                     # the kind in the bay now ("" empty; tests)
var built_share := 0.0              # what share of it is shown (0..1, in steps; tests)


func _init(bld: Building) -> void:
	b = bld
	z_index = 1
	z_as_relative = true


## The machine b is making now ("" when it trains nothing, or researches).
static func machine_of(bld: Building) -> String:
	if bld.queue.is_empty() or bld.dead or not bld.built:
		return ""
	var k := String(bld.queue[0])
	if k.begins_with("@") or not Defs.UNITS.has(k):
		return ""
	return k


func _process(_delta: float) -> void:
	if b == null or not is_instance_valid(b):
		return
	var k := machine_of(b)
	var f := 0.0
	if k != "":
		f = clampf(b.prod_t / maxf(Building.entry_time(k), 0.01), 0.0, 1.0)
	var share := 0.0
	if k != "":
		share = clampf(ceil(f * STEPS + 0.001) / float(STEPS), 1.0 / float(STEPS), 1.0)
	if k != shown or not is_equal_approx(share, built_share) or k != "":
		shown = k
		built_share = share
		queue_redraw()


## The unit's idle frame and how it fits the bay.
func _load(k: String) -> void:
	_kind = k
	_tex = null
	if not CwArt.SHEETS.has(k):
		return
	var path := "res://assets/units/%s/idle_%s.png" % [k, DIR]
	if not ResourceLoader.exists(path):
		return
	_tex = Game.tex(path)
	var sh: Array = CwArt.SHEETS[k]
	_cell = Rect2(0, 0, float(sh[0]), float(sh[1]))
	_anchor = Vector2(float(sh[2]), float(sh[3]))
	# fit by its drawn box (the opaque pixels of the frame), not the cell
	var box := _opaque_box(_tex, _cell)
	_scale = minf(1.0, minf(ROOM.x / maxf(box.size.x, 1.0), ROOM.y / maxf(_anchor.y - box.position.y, 1.0)))


static var _boxes := {}


static func _opaque_box(t: Texture2D, cell: Rect2) -> Rect2:
	var key := "%s:%s" % [t.resource_path, cell]
	if _boxes.has(key):
		return _boxes[key]
	var r := cell
	var img := t.get_image()
	if img != null:
		if img.is_compressed():
			img.decompress()
		var sub := img.get_region(Rect2i(cell))
		var used := sub.get_used_rect()
		if used.size.x > 0:
			r = Rect2(used)
	_boxes[key] = r
	return r


func _draw() -> void:
	if b == null or b.dead or not b.built:
		return
	var damaged := b.hp < b.max_hp * 0.5
	var top_y := HOOK_REST
	if shown != "":
		if shown != _kind:
			_load(shown)
		if _tex != null:
			var cut := clampf(built_share, 0.0, 1.0)
			# the frame from its feet up: the bottom `cut` of its drawn height
			var box := _opaque_box(_tex, _cell)
			var h_full := _anchor.y - box.position.y
			var h := h_full * cut
			var src := Rect2(_cell.position.x, _anchor.y - h, _cell.size.x, h + (_cell.size.y - _anchor.y))
			var dst := Rect2(FEET + Vector2(-_anchor.x, -h) * _scale, src.size * _scale)
			var lite := lerpf(DARK, 1.0, cut * cut)
			draw_texture_rect_region(_tex, dst, src, Color(lite, lite * 0.97, lite * 0.94, 1.0))
			if cut < 1.0:
				# the hot seam where the next part goes on
				var y := FEET.y - h * _scale
				var w := box.size.x * _scale * 0.5
				var cx := FEET.x + (box.position.x + box.size.x * 0.5 - _anchor.x) * _scale
				var glow := 0.55 + 0.45 * sin(float(Time.get_ticks_msec()) * 0.012)
				draw_line(Vector2(cx - w, y), Vector2(cx + w, y), Color(1.0, 0.72, 0.3, 0.55 * glow), 3.0)
				draw_line(Vector2(cx - w * 0.8, y), Vector2(cx + w * 0.8, y), Color(1.0, 0.95, 0.75, 0.8 * glow), 1.0)
			top_y = maxf(FEET.y - h * _scale - 12.0, CHAIN_TOP.y + 4.0)       # (lowered onto the work)
	if damaged:
		return          # (the damaged frame keeps its own painted hook)
	_draw_crane(top_y)


## The chain from the beam down to the hook, whose top is at y (the painted links, tiled), and the hook.
func _draw_crane(hook_top: float) -> void:
	var chain := Game.tex("res://assets/buildings/heavy_works_chain.png")
	var hook := Game.tex("res://assets/buildings/heavy_works_hook.png")
	if chain == null or hook == null:
		return
	var cw := float(chain.get_width())
	var ch := float(chain.get_height())
	var y := CHAIN_TOP.y
	while y < hook_top - 0.5:
		var hh := minf(ch, hook_top - y)
		draw_texture_rect_region(chain, Rect2(CHAIN_TOP.x - cw * 0.5, y, cw, hh), Rect2(0, 0, cw, hh))
		y += ch
	draw_texture(hook, Vector2(CHAIN_TOP.x - float(hook.get_width()) * 0.5 - 1.0, hook_top - 1.0))
