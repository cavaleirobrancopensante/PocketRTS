class_name Cursors
extends Node
## The mouse cursor (computer only: phones have no cursor). The brass pointer everywhere
## (menus and game); in a match it follows the game state: ATTACK's crosshair (the blade ring
## over something the selected units can attack, in ATTACK or with soldiers selected, where a
## right click attacks), MOVE's arrow on a ring, PATROL's dotted pointer, the hammer for
## building and REPAIR (the barred circle where the building can't go), the pennant for rally
## points, the pointer with a green ring over your own units and buildings.
## Art: assets/ui/cursors/<name>.png (the Crown's, also used in the menus) and the Brood's and
## Clockwork's own sets in its brood/ and clockwork/ sub-folders, shown in a match of that
## faction; cut by tools/import_cursors.py, which also writes the hotspots
## (scripts/cursor_hotspots.gd).

const HOT := preload("res://scripts/cursor_hotspots.gd")
const HOTS := {
	"crown": {"32": HOT.HOTSPOT_32, "48": HOT.HOTSPOT_48},
	"brood": {"32": HOT.HOTSPOT_BROOD_32, "48": HOT.HOTSPOT_BROOD_48},
	"clockwork": {"32": HOT.HOTSPOT_CLOCKWORK_32, "48": HOT.HOTSPOT_CLOCKWORK_48},
}
const NAMES := ["pointer", "attack", "attack_enemy", "move", "select", "build", "rally", "forbidden", "patrol"]
const HOVER_EVERY := 0.1        # seconds between looks at what's under the mouse (entity_at loops all units)

var main: Node                  # its `game` is the match being played (null in the menus)
var current := ""               # the cursor shown ("" = the system's)
var _tex := {}                  # faction -> {name -> texture}
var _hot := {}                  # faction -> {name -> hotspot}
var _set := "crown"             # whose cursors are shown
var _hover: Entity = null
var _hover_t := 0.0
var _hover_at := Vector2.INF
var _place_key := ""
var _place_bad := false
var _place_t := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# 48 px on high-DPI desktop screens; the web always 32 (a browser draws a cursor in CSS
	# pixels, already scaled for the screen)
	var big := not OS.has_feature("web") and DisplayServer.screen_get_scale() >= 1.5
	var sz := "48" if big else "32"
	for fac in ["crown", "brood", "clockwork"]:
		var dir: String = "res://assets/ui/cursors/" + ("" if fac == "crown" else fac + "/")
		_tex[fac] = {}
		_hot[fac] = HOTS[fac][sz]
		for n in NAMES:
			_tex[fac][n] = load("%s%s%s.png" % [dir, n, "_48" if big else ""])


## Custom cursors only with a mouse: not on phones (or a computer set up as a phone, where
## the mouse pretends to be a finger).
static func wanted() -> bool:
	if OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios"):
		return false
	return Settings.device != "mobile"


func _process(delta: float) -> void:
	if not wanted():
		_show("")
		return
	var game: Game = main.get("game") if main else null
	if game == null or not is_instance_valid(game) or game.controls == null or game.over:
		if game != null and is_instance_valid(game):
			game.hover_target = null
		_use("crown")
		_show("pointer")
		return
	_use(game.faction_of(game.human) if _tex.has(game.faction_of(game.human)) else "crown")
	var hov := _hovered(game, delta)
	game.hover_target = hov
	_show(choose(game.controls, game, hov))


## Switch to a faction's set (the cursor on show is redrawn from it).
func _use(fac: String) -> void:
	if fac != _set:
		_set = fac
		if current != "":
			var n := current
			current = ""
			_show(n)


func _show(n: String) -> void:
	if n == current:
		return
	current = n
	if n == "":
		Input.set_custom_mouse_cursor(null)
	else:
		Input.set_custom_mouse_cursor(_tex[_set][n], Input.CURSOR_ARROW, _hot[_set][n])


## What's under the mouse in the world (null over the interface), looked at every
## HOVER_EVERY seconds or when the mouse moves.
func _hovered(game: Game, delta: float) -> Entity:
	_hover_t -= delta
	var vp := game.get_viewport()
	var mp := vp.get_mouse_position()
	if _hover_t <= 0.0 or mp.distance_squared_to(_hover_at) > 64.0:
		_hover_t = HOVER_EVERY
		_hover_at = mp
		var gui := vp.gui_get_hovered_control()
		_hover = null if gui != null else game.entity_at(game.controls.to_world(mp))
	if _hover != null and (not is_instance_valid(_hover) or _hover.dead):
		_hover = null
	return _hover


## The cursor for this game state with `hover` under the mouse (no side effects: tested by
## a script).
func choose(c: Controls, game: Game, hover: Entity) -> String:
	match c.mode:
		"attack":
			return "attack_enemy" if _can_attack(game, hover) else "attack"
		"move":
			return "move"
		"patrol":
			return "patrol"
		"place":
			return "forbidden" if _bad_spot(c, game) else "build"
		"repair":
			return "build"
		"rally", "rally_army", "rally_worker":
			return "rally"
		"cast", "load", "unload", "overload":
			return "attack"
	if hover == null:
		return "pointer"
	if hover.team == game.controlled_team() and hover.team >= 0:
		return "select"
	if _can_attack(game, hover) and game.selected_units().any(func(u: Unit) -> bool: return not u.is_worker()):
		return "attack_enemy"      # soldiers selected: a right click attacks it
	return "pointer"


func _can_attack(game: Game, e: Entity) -> bool:
	if e == null or game.controlled_team() < 0 or not game.prey(game.controlled_team(), e):
		return false
	return game.selected_units().any(func(u: Unit) -> bool: return u.can_hit(e))


## The building's ghost is red (the same check the ghost makes), re-checked when it moves
## and a few times a second (gold, men in the way).
func _bad_spot(c: Controls, game: Game) -> bool:
	if c.ghost_cell.x < 0 or c.place_kind == "":
		return false
	var key := "%s@%s" % [c.place_kind, c.ghost_cell]
	var now := Time.get_ticks_msec() / 1000.0
	if key != _place_key or now - _place_t > 0.25:
		_place_key = key
		_place_t = now
		_place_bad = game.placement_problem(game.human, c.place_kind, c.ghost_cell) != ""
	return _place_bad
