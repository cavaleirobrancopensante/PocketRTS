class_name HotkeyBar
extends RefCounted
## The bottom hotkey bar (above the selection card, as wide as the card is): IDLE (F1), ARMY (F2),
## MAKE (F3) and the ten control groups 1 2 3 4 5 6 7 8 9 0, and under it, peeking out above
## the bar, nine camera tabs F4-F12.
##
## Groups (computer): number = select (twice: jump to it), Shift+number = ADD the selection to
## the group, Ctrl+number = SET it (replace), Ctrl+Shift+number = ADD the selection to it, Shift+number = add the group to the selection (as in StarCraft 2; to drop a unit: select the group, Shift+click the unit off, Ctrl+number again).
## The same with the mouse on the buttons (Shift/Ctrl+click), and on a phone: tap selects,
## hold sets. Camera tabs: F4-F12 jump, Shift+F4-F12 (or Ctrl+) save the view; a tap on a tab
## jumps (an empty one saves), a long press saves.
## (Browsers: Ctrl+1-8 switches tabs, F5/F11/F12 reload, full-screen and dev tools; use the buttons then.)
## The groups and views live in the Game (game.groups, game.cam_slots) and are in the autosave.

const IDLE := 0
const ARMY := 1
const MAKE := 2
const GROUP0 := 3                 # button 3 is group 1 ... button 12 is group 0 (index 9)
const N_BTN := 13
const N_CAM := 9
const CAM0 := 100                 # hit ids 100-108 are the camera tabs
const TAB_H := 16.0               # the visible edge of a camera tab
const BTN_H := 40.0
const FLASH_S := 0.14             # how long a pressed button stays pushed in
const HOLD_S := 0.45              # a long press saves (group / view)
const FKEYS := [KEY_F4, KEY_F5, KEY_F6, KEY_F7, KEY_F8, KEY_F9, KEY_F10, KEY_F11, KEY_F12]
const NAMES := ["IDLE", "ARMY", "MAKE"]

var hud: Control                  # the Hud (its game, toast, drawing)
var _flash := {}                  # hit id -> when it was pressed (msec)
var _down := {}                   # hit id -> when a press began (touch / mouse)
var _last_g := -1
var _last_t := 0


func _init(h: Control) -> void:
	hud = h


static func min_width() -> float:
	return N_BTN * (24.0 if not Settings.pc() else 44.0)


static func size_hint() -> Vector2:
	return Vector2(min_width(), TAB_H + BTN_H)


# ------------------------------------------------------------------ geometry

func rect() -> Rect2:
	return hud._layout()["hotbar"]


func bar_rect() -> Rect2:
	var r := rect()
	return Rect2(r.position + Vector2(0, TAB_H), Vector2(r.size.x, r.size.y - TAB_H))


func button_rect(i: int) -> Rect2:
	var b := bar_rect()
	var w := b.size.x / N_BTN
	return Rect2(b.position.x + i * w + 1, b.position.y, w - 2, b.size.y)


## The visible edge of camera tab j (it goes on under the bar): the tabs sit over buttons 4-12.
func tab_rect(j: int) -> Rect2:
	var b := button_rect(GROUP0 + j)
	return Rect2(b.position.x + 2, rect().position.y, b.size.x - 4, TAB_H + 8.0)


## The id of what is at p (HUD coordinates): a button 0-12, a tab 100-108, or -1.
func hit(p: Vector2) -> int:
	if not rect().has_point(p):
		return -1
	for i in N_BTN:
		if button_rect(i).has_point(p):
			return i
	for j in N_CAM:
		var t := tab_rect(j)
		if Rect2(t.position, Vector2(t.size.x, TAB_H)).has_point(p):
			return CAM0 + j
	return -1


func rect_of(id: int) -> Rect2:
	return tab_rect(id - CAM0) if id >= CAM0 else button_rect(id)


static func group_of(id: int) -> int:
	return id - GROUP0 if id >= GROUP0 and id < CAM0 else -1


# ------------------------------------------------------------------ pressing (mouse and touch)

func press(id: int) -> void:
	_down[id] = Time.get_ticks_msec()


## The finger / button is let go at p: runs what was pressed if it is still there.
func release(p: Vector2) -> void:
	for id in _down.keys():
		var held := (Time.get_ticks_msec() - int(_down[id])) / 1000.0
		_down.erase(id)
		if hit(p) != id:
			continue
		var mode := ""
		if held > HOLD_S:
			mode = "set"
		elif Settings.pc():
			var ctrl := Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_META)
			var shift := Input.is_key_pressed(KEY_SHIFT)
			if ctrl and shift:
				mode = "add"
			elif ctrl:
				mode = "set"
			elif shift:
				mode = "join"
		activate(id, mode, held)


func pressing() -> Array:
	return _down.keys()


## Do what button / tab `id` stands for. mode: "" (the plain press), "add" (selection into the group), "join" (group into the selection), "set".
func activate(id: int, mode := "", held := 0.0) -> void:
	_flash[id] = Time.get_ticks_msec()
	if id >= CAM0:
		var j := id - CAM0
		if mode == "set" or (game().cam_slots[j] == null and mode == ""):    # (a key never saves by itself: mode "go")
			cam_save(j)
		else:
			cam_go(j)
		return
	match id:
		IDLE:
			select_idle()
		ARMY:
			select_army()
		MAKE:
			select_production()
		_:
			var g := group_of(id)
			if mode == "" and game().groups[g].is_empty() and not game().selection.is_empty():
				mode = "set"          # (an empty group: the first press keeps the selection there)
			group_do(g, mode, held < 0.3)


func game() -> Game:
	return hud.game


# ------------------------------------------------------------------ keyboard

## A key pressed: true if the bar took it. Numbers 1-9, 0 and F1-F12.
func key(e: InputEventKey) -> bool:
	if hud.paused or game().over or game().spectating():
		return false
	var kc := e.keycode
	var g := -1
	if kc >= KEY_1 and kc <= KEY_9:
		g = int(kc - KEY_1)
	elif kc == KEY_0:
		g = 9
	if g >= 0:
		var mode := ""
		var ctrl: bool = e.ctrl_pressed or e.meta_pressed
		if ctrl and e.shift_pressed:
			mode = "add"
		elif ctrl:
			mode = "set"
		elif e.shift_pressed:
			mode = "join"
		_flash[GROUP0 + g] = Time.get_ticks_msec()
		group_do(g, mode, true)
		return true
	match kc:
		KEY_F1:
			activate(IDLE)
			return true
		KEY_F2:
			activate(ARMY)
			return true
		KEY_F3:
			activate(MAKE)
			return true
	var j := FKEYS.find(kc)
	if j >= 0:
		activate(CAM0 + j, "set" if (e.shift_pressed or e.ctrl_pressed or e.meta_pressed) else "go")
		return true
	return false


# ------------------------------------------------------------------ what they do

func _alive(list: Array) -> Array:
	return list.filter(func(x) -> bool: return is_instance_valid(x) and not x.dead)


## Group g (0-based): mode "" select (twice: jump), "add" (selection into the group), "join" (group into the selection), "set".
func group_do(g: int, mode: String, can_jump := true) -> void:
	var gm := game()
	var n := g + 1 if g < 9 else 0
	var sel: Array = _alive(gm.selection)
	match mode:
		"set":
			gm.groups[g] = sel.duplicate()
			hud.toast("Group %d set (%d)." % [n, sel.size()] if not sel.is_empty() else "Group %d cleared." % n, false)
		"add":
			if sel.is_empty():
				hud.toast("Select something to add to group %d." % n)
				return
			var cur: Array = _alive(gm.groups[g])
			var added := 0
			for x in sel:
				if not cur.has(x):
					cur.append(x)
					added += 1
			gm.groups[g] = cur
			hud.toast("Added %d to group %d (now %d)." % [added, n, cur.size()], false)
		"join":
			var al: Array = _alive(gm.groups[g])
			if al.is_empty():
				hud.toast("Group %d is empty." % n)
				return
			var both: Array = sel.duplicate()
			for x in al:
				if not both.has(x):
					both.append(x)
			gm.set_selection(both)
		_:
			var alive: Array = _alive(gm.groups[g])
			gm.groups[g] = alive
			if alive.is_empty():
				hud.toast("Group %d is empty: Ctrl+%d sets it from the selection." % [n, n] if Settings.pc() else "Group %d is empty: select something and hold the button." % n)
				return
			var again: bool = can_jump and _last_g == g and Time.get_ticks_msec() - _last_t < 400 and gm.selection == alive
			gm.set_selection(alive)
			if again:
				hud._jump(_centre(alive))
			_last_g = g
			_last_t = Time.get_ticks_msec()


func _centre(list: Array) -> Vector2:
	var c := Vector2.ZERO
	for x in list:
		c += x.global_position
	return c / list.size()


func select_idle() -> void:
	var gm := game()
	var idle := gm.labourers(gm.human).filter(func(u: Unit) -> bool: return u.order == "idle")
	if idle.is_empty():
		hud.toast("No idle workers.")
		return
	gm.set_selection(idle)
	hud._jump(idle[0].position)


func select_army() -> void:
	var gm := game()
	var a := gm.army(gm.human)
	if a.is_empty():
		hud.toast("No army yet.")
		return
	gm.set_selection(a)


## Every finished building that makes something (the Town Hall too).
func production_buildings() -> Array:
	var gm := game()
	return gm.buildings.filter(func(b: Building) -> bool:
		return b.team == gm.human and not b.dead and b.built and not (b.d["trains"] as Array).is_empty())


func select_production() -> void:
	var pb := production_buildings()
	if pb.is_empty():
		hud.toast("No buildings that make anything yet.")
		return
	game().set_selection(pb)


func cam_save(j: int) -> void:
	var cam := game().camera
	game().cam_slots[j] = [cam.position, cam.zoom.x]
	hud.toast("View F%d saved." % (j + 4), false)


func cam_go(j: int) -> void:
	var c = game().cam_slots[j]
	if c == null:
		hud.toast("View F%d is empty: %s saves this view." % [j + 4, ("Shift+F%d" % (j + 4)) if Settings.pc() else "hold the tab"])
		return
	var cam := game().camera
	var z := clampf(float(c[1]), 0.55, 2.6)
	cam.zoom = Vector2(z, z)
	hud._jump(c[0])
	cam.force_update_scroll()


# ------------------------------------------------------------------ look

## 0..1: how far a pressed button is pushed in (1 just pressed, 0 at rest).
func pushed(id: int) -> float:
	var t = _flash.get(id)
	if t == null:
		var d = _down.get(id)
		return 1.0 if d != null else 0.0
	var age := (Time.get_ticks_msec() - int(t)) / 1000.0
	if age >= FLASH_S:
		_flash.erase(id)
		return 1.0 if _down.has(id) else 0.0
	return 1.0 - age / FLASH_S * 0.5


## What the layer's redraw hangs on: where the pushes are, and their phase.
func sig() -> Array:
	var out: Array = []
	for id in _flash.keys():
		out.append([id, int((Time.get_ticks_msec() - int(_flash[id])) / 45.0)])
	var d: Array = _down.keys()
	d.sort()
	return [out, d, game().groups.map(func(g: Array) -> int: return g.size()), game().cam_slots.map(func(c) -> bool: return c != null)]


func tip(id: int) -> Dictionary:
	var pc := Settings.pc()
	if id >= CAM0:
		var j := id - CAM0
		return {"title": "View F%d" % (j + 4), "body": ("F%d: jump to the saved view. Shift+F%d: save this view here." % [j + 4, j + 4]) if pc
			else "Tap: jump to the saved view (an empty one saves this view). Hold: save this view here."}
	match id:
		IDLE:
			return {"title": "Idle workers" + (" (F1)" if pc else ""), "body": "Select every idle worker and jump to the first."}
		ARMY:
			return {"title": "Army" + (" (F2)" if pc else ""), "body": "Select every soldier you have."}
		MAKE:
			return {"title": "Make" + (" (F3)" if pc else ""), "body": "Select every building that makes something (the Town Hall too), to train from all of them at once."}
	var g := group_of(id)
	var n := g + 1 if g < 9 else 0
	return {"title": "Group %d" % n, "body": ("%d: select it (twice: jump to it). Shift+%d: add it to your selection. Ctrl+%d: set it to the selection. Ctrl+Shift+%d: add the selection to it. To drop a unit: select the group, Shift+click the unit off, Ctrl+%d." % [n, n, n, n, n]) if pc
		else "Tap: select it (twice: jump to it). Hold: keep the selection here."}


func draw(font: Font, counts: Array) -> void:
	var ci: CanvasItem = hud._ci
	var pc := Settings.pc()
	var mouse: Vector2 = hud._mouse() if pc else Vector2(-1, -1)
	var gm := game()
	# the camera tabs first: the bar covers their lower part
	for j in N_CAM:
		var tr := tab_rect(j)
		var id := CAM0 + j
		var set_ := gm.cam_slots[j] != null
		var push := pushed(id)
		var vr := Rect2(tr.position + Vector2(0, push * 2.0), tr.size)
		UiStyle.draw_button(ci, vr, pc and tr.has_point(mouse) and hit(mouse) == id, push > 0.0 or set_)
		if push > 0.0:
			ci.draw_rect(vr, Color(0, 0, 0, 0.25 * push))
		hud._text(UiStyle.bold_font(), vr.position + Vector2(vr.size.x * 0.5, TAB_H - 4), "F%d" % (j + 4), 11, Color(1, 0.9, 0.55) if set_ else Color(1, 1, 1, 0.5), 1)
	for i in N_BTN:
		var r := button_rect(i)
		var g := group_of(i)
		var count := 0
		match i:
			IDLE:
				count = int(counts[1]) if counts.size() > 1 else 0
			ARMY:
				count = int(counts[0]) if counts.size() > 0 else 0
			MAKE:
				count = int(counts[2]) if counts.size() > 2 else 0
			_:
				count = int(counts[3 + g]) if counts.size() > 3 + g else 0
		var push := pushed(i)
		var vr := Rect2(r.position + Vector2(0, push * 2.0), r.size)
		UiStyle.draw_button(ci, vr, pc and hit(mouse) == i, push > 0.0)
		if push > 0.0:
			ci.draw_rect(vr, Color(0, 0, 0, 0.25 * push))
		var label: String = NAMES[i] if i < GROUP0 else ("%d" % (g + 1 if g < 9 else 0))
		var lit := i < GROUP0 or count > 0
		var col := UiStyle.TEXT if lit else Color(1, 1, 1, 0.5)
		var lsz := 15 if i < GROUP0 else 20
		while lsz > 9 and UiStyle.bold_font().get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, lsz).x > vr.size.x - 3:
			lsz -= 1
		hud._text(UiStyle.bold_font(), vr.position + Vector2(vr.size.x * 0.5, 19), label, lsz, col, 1)
		var sub := ""
		if i == MAKE:
			sub = str(count) if count > 0 else ""
		elif i < GROUP0 or count > 0:
			sub = str(count)
		if sub != "":
			hud._text(font, vr.position + Vector2(vr.size.x * 0.5, 36), sub, 13, Color(1, 1, 1, 0.65), 1)
		if pc and i < GROUP0:
			hud._text(UiStyle.bold_font(), vr.position + Vector2(3, 10), "F%d" % (i + 1), 9, Color(1, 0.9, 0.55, 0.7))
