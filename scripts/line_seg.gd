class_name PipeSeg
extends Entity
## One segment of the Clockwork's Line (docs/clockwork_rework_plan.md): a pipe on one map cell.
## An Entity so that enemies can shoot it and Winders repair it with the existing code; it is not
## a Building (is_building() is false) and blocks nothing: units walk over it. Owned and drawn by
## LineNetwork (scripts/line.gd), which keeps them on a grid.

var cell := Vector2i.ZERO
var built := false
var progress := 0.0             # 0..1 while a Winder lays it
var d: Dictionary = Defs.LINE["pipe"]    # (repair reads d["time"] and d["cost"] like a building's)
var pressure := 0.0             # effective pressure at this cell (set by the solver)
var net: LineNetwork = null
var _shown_hp := -1.0


func setup(n: LineNetwork, t: int, c: Vector2i, complete: bool) -> void:
	net = n
	game = n.game
	team = t
	kind = "pipe"
	cell = c
	built = complete
	progress = 1.0 if complete else 0.0
	max_hp = float(d["hp"])
	armor = float(d["armor"])
	hp = max_hp if complete else max_hp * 0.2
	sight = 0
	position = game.cell_center(c)
	set_process(false)
	set_physics_process(false)


func rect() -> Rect2:
	return Rect2(Vector2(cell) * Defs.TILE, Vector2(Defs.TILE, Defs.TILE))


func center() -> Vector2:
	return rect().get_center()


## Laying work: a Winder adds `delta` seconds. True once it is finished.
func add_progress(delta: float) -> bool:
	if built:
		return true
	progress = minf(1.0, progress + delta / float(d["time"]))
	hp = lerpf(max_hp * 0.2, max_hp, progress)
	if progress >= 1.0:
		built = true
		hp = max_hp
		net.changed()
	return built


func die() -> void:
	if dead:
		return
	dead = true
	var fx := game.spawn_effect("dust", global_position, 1.0)
	if fx:
		fx.scale = Vector2(0.5, 0.5)
	Sfx.play_any(["combat/gear_hit", "gear_hit"], global_position)
	net.remove_seg(self, true)
