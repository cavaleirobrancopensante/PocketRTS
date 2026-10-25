class_name LocTranslation
extends Translation
## Registered with the TranslationServer for pt_BR and es_ES: every Label, Button and tooltip
## then gets its text from Loc.t (exact entries and %s/%d patterns alike).


func _get_message(src_message: StringName, _context: StringName) -> StringName:
	var s := String(src_message)
	var r := Loc.t(s)
	return StringName(r) if r != s else StringName()
