class_name LineTool
extends RefCounted
## The Line tool (a Winder's LINE button): pick a start cell and an end cell, the game routes the Line over
## free ground, shows the ghost path with its cost and the pressure it would carry at the end, and the
## selected Winders lay it. Computer: click the start, move the mouse (the ghost follows), click the end;
## or press on the start, drag and let go on the end. Phone: tap the start, tap the end (a preview), tap the
## end again or press LAY. Esc / right click / CANCEL leaves the tool. Called from Controls and the HUD.

var controls: Controls
var game: Game
var start := Vector2i(-1, -1)
var end := Vector2i(-1, -1)
var plan := {}
var _press_cell := Vector2i(-1, -1)


func _init(c: Controls) -> void:
	controls = c
	game = c.game
	game.line_net.tool_on = true
	reset()


func reset() -> void:
	start = Vector2i(-1, -1)
	end = Vector2i(-1, -1)
	plan = {}
	_press_cell = Vector2i(-1, -1)
	game.line_net.tool_from = start
	game.line_net.tool_path = []
	game.line_net.tool_info = {}
	game._redraw_line()


func stop() -> void:
	game.line_net.tool_on = false
	reset()


func cell_at(screen: Vector2) -> Vector2i:
	return game.cell_of(controls.to_world(screen))


func builders() -> Array:
	var sel: Array = game.selected_units()
	if Defs.cw_roster:
		sel = CwUnits.expand_layers(sel)         # a Work Car sends its crew out to lay
	return sel.filter(func(u: Unit) -> bool: return u.kind == "winder")


func _team() -> int:
	return game.controlled_team()


func _set_start(c: Vector2i) -> void:
	if not game.line_net.pipeable(_team(), c):
		game.notify("Pipes need free ground there.")
		return
	start = c
	end = Vector2i(-1, -1)
	plan = {}
	game.line_net.tool_from = c
	game.line_net.tool_path = [c]
	game.line_net.tool_info = {"ok": false, "why": "Pick the end."}
	game._redraw_line()


func _preview(c: Vector2i) -> void:
	if start.x < 0 or c == end:
		return
	end = c
	if c == start:
		game.line_net.tool_path = [c]
		game.line_net.tool_info = {"ok": false, "why": "Pick the end."}
		plan = {}
	else:
		plan = game.line_net.plan(_team(), start, c)
		game.line_net.tool_path = plan.get("cells", [c])
		game.line_net.tool_info = plan
		if plan.get("ok", false):
			var cost: int = plan["cost"]
			if int(game.players[_team()]["gold"]) < cost:
				game.line_net.tool_info = plan.duplicate()
				game.line_net.tool_info["ok"] = false
				game.line_net.tool_info["why"] = "Not enough ore."
	game._redraw_line()


func can_confirm() -> bool:
	return start.x >= 0 and plan.get("ok", false) and int(plan.get("cost", 0)) <= int(game.players[_team()]["gold"])


func why_not() -> String:
	if start.x < 0:
		return "Pick the start."
	if plan.is_empty():
		return "Pick the end."
	if not plan.get("ok", false):
		return String(plan.get("why", ""))
	if int(plan["cost"]) > int(game.players[_team()]["gold"]):
		return "Not enough ore."
	return ""


func cost_text() -> String:
	return str(int(plan.get("cost", 0))) if plan.get("ok", false) else ""


## Lay it. keep: Shift (stay in the tool for the next run).
func confirm(keep := false) -> void:
	if not can_confirm():
		var why := why_not()
		if why != "":
			game.notify(why)
		return
	var cells: Array = plan["cells"]
	game.lay_line(_team(), cells, builders(), keep)
	Sfx.play_any(["ui/click", "click"])
	if keep:
		var last: Vector2i = cells[cells.size() - 1]
		_set_start(last)
	else:
		controls.cancel_mode()


# ---- computer

func hover(screen: Vector2) -> void:
	if start.x >= 0:
		_preview(cell_at(screen))


func press(screen: Vector2, shift := false) -> void:
	var c := cell_at(screen)
	if start.x < 0:
		_set_start(c)
		_press_cell = c
		return
	_preview(c)
	_press_cell = Vector2i(-1, -1)
	confirm(shift)


func release(screen: Vector2, shift := false) -> void:
	var c := cell_at(screen)
	if _press_cell.x >= 0 and c != _press_cell and start.x >= 0:
		_preview(c)
		_press_cell = Vector2i(-1, -1)
		confirm(shift)
	_press_cell = Vector2i(-1, -1)


# ---- phone

func tap(screen: Vector2) -> void:
	var c := cell_at(screen)
	if start.x < 0:
		_set_start(c)
		return
	if c == end and plan.get("ok", false):
		confirm()
		return
	_preview(c)
