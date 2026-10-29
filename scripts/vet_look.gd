class_name VetLook
## Veterancy shows on the sprite itself (no overhead pips). A Crown soldier's trim (the lace
## of his tricorne, the band of his felt hat, the comb and brim of his helmet) is black under
## Defs.VET["silver"] kills, silver from there and gold from Defs.VET["gold"]; a Brood
## creature's skin is as painted, then amber-ochre, then obsidian. shaders/team.gdshader
## recolours through a mask per sprite strip: assets/units/trim_masks/<art>/ (written by
## tools/import_vet_trim.py) and assets/units/skin_masks/<art>/ (tools/import_vet_skin.py).
## A strip without a mask (workers, guns, Clockwork) shows nothing.
## THE VENOM LINE (Defs.VENOM_SWAP: the belly and a flank stripe in the team colour) has a second mask per strip,
## assets/units/venom_masks/<art>/ (tools/import_venom_colours.py), set here too.

const STYLES := {"crown": 1, "brood": 2}
const VENOM := 3          # (the venom line's own masks: not a veterancy style, only a mask folder)
const DIRS := {1: "res://assets/units/trim_masks/", 2: "res://assets/units/skin_masks/", VENOM: "res://assets/units/venom_masks/"}


## Does this unit wear the venom line's colours (its art: a Venom Challenger drawn as the Venom Sire too)?
static func venom(u: Unit) -> bool:
	return Defs.VENOM_SWAP.has(u.art) or Defs.VENOM_SWAP.has(u.kind)

static var _masks := {}       # "style:strip path" -> its mask (or null)


## 0 under the silver threshold, 1 silver (amber), 2 gold (obsidian).
static func level(kills: int) -> int:
	if kills >= int(Defs.VET["gold"]):
		return 2
	if kills >= int(Defs.VET["silver"]):
		return 1
	return 0


static func style_of(u: Unit) -> int:
	return int(STYLES.get(String(u.d.get("faction", "")), 0))


## Shows the unit's veterancy (after its kills change, or it is made, loaded or raised).
static func apply(u: Unit) -> void:
	if u.sprite == null:
		return
	var m := u.sprite.material as ShaderMaterial
	if m == null:
		return
	var st := style_of(u)
	m.set_shader_parameter("vet_style", st)
	m.set_shader_parameter("vet_level", level(u.kills))
	m.set_shader_parameter("venom_swap", venom(u))
	if st > 0:
		update_mask(u)


## The mask for the strip the unit's sprite shows now (on every change of strip).
static func update_mask(u: Unit) -> void:
	var m := u.sprite.material as ShaderMaterial
	if m == null:
		return
	m.set_shader_parameter("vet_mask", mask_for(u.sprite.texture, style_of(u)))
	if venom(u):
		m.set_shader_parameter("venom_mask", mask_for(u.sprite.texture, VENOM))


static func mask_for(t: Texture2D, st: int) -> Texture2D:
	if t == null or not DIRS.has(st):
		return null
	# (asked on every change of strip, of every unit on screen: by the texture's id first, no text built)
	var ik := t.get_instance_id() * 4 + st
	var hit = _by_id.get(ik, false)
	if hit is bool:
		hit = _mask_slow(t, st)
		_by_id[ik] = hit
	return hit


static var _by_id := {}


static func _mask_slow(t: Texture2D, st: int) -> Texture2D:
	var p := t.resource_path
	var k := "%d:%s" % [st, p]
	if not _masks.has(k):
		var mp: String = String(DIRS[st]) + p.trim_prefix("res://assets/units/")
		_masks[k] = load(mp) if p.begins_with("res://assets/units/") and ResourceLoader.exists(mp) else null
	return _masks[k]
