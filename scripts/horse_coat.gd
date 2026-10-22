class_name HorseCoat
## Horses come in different coats: every horse-drawn or ridden unit (Cuirassier, Field Cannon,
## Mortar, Powder Wagon) gets one at random when it is made. The sprites keep their one painted
## horse; shaders/team.gdshader repaints it through a mask per sprite strip, written by
## tools/import_horse_coats.py into assets/units/horse_masks/<unit>/.

const COATS := ["dark", "bay", "grey", "white", "spotted"]
## How often each coat turns up (out of 100).
const WEIGHTS := {"dark": 30, "bay": 30, "grey": 20, "white": 10, "spotted": 10}
## The coat each unit's sprites are painted in: that one is shown as painted. The Mortar has
## none (its walk's horse is dark, its other strips' chestnut): every coat is repainted.
const NATIVE := {"cuirassier": "dark", "cannon": "dark", "powder_wagon": "dark", "mortar": ""}
const MASKS := "res://assets/units/horse_masks/"
const RAMPS := preload("res://assets/units/horse_masks/coat_ramps.png")

static var _masks := {}       # sprite strip path -> its mask (or null: no horse in it)


static func has_horse(kind: String) -> bool:
	return NATIVE.has(kind)


## A coat by the odds above.
static func pick() -> String:
	var total := 0
	for c in COATS:
		total += int(WEIGHTS[c])
	var r := randi() % total
	for c in COATS:
		r -= int(WEIGHTS[c])
		if r < 0:
			return c
	return COATS[0]


## Shows the unit's coat (after its coat changes, e.g. on loading a game).
static func apply(u: Unit) -> void:
	if u.sprite == null or not has_horse(u.kind):
		return
	var m := u.sprite.material as ShaderMaterial
	if m == null:
		return
	var i := COATS.find(u.coat)
	if u.coat == NATIVE[u.kind]:
		i = -1
	m.set_shader_parameter("coat", i)
	m.set_shader_parameter("coat_ramps", RAMPS)
	update_mask(u)


## The mask for the strip the unit's sprite shows now (on every change of strip).
static func update_mask(u: Unit) -> void:
	var m := u.sprite.material as ShaderMaterial
	if m == null:
		return
	m.set_shader_parameter("horse_mask", mask_for(u.sprite.texture))


static func mask_for(t: Texture2D) -> Texture2D:
	if t == null:
		return null
	var p := t.resource_path
	if not _masks.has(p):
		var mp := MASKS + p.trim_prefix("res://assets/units/")
		_masks[p] = load(mp) if p.begins_with("res://assets/units/") and ResourceLoader.exists(mp) else null
	return _masks[p]
