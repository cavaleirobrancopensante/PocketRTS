extends "res://tools/study/bo_ai.gd"
## Balance study v2 (docs/study_v2.md): the scripted player of tools/study/bo_ai.gd with a fuller record. A TOOL ONLY:
## like bo_ai.gd it changes nothing in the game's computer; it only adds bookkeeping and two time limits so a step the
## rules no longer allow cannot hold the whole game in the script:
##   * a step that has waited STEP_TIMEOUT seconds (default 180) is given up ("timeout") and the next step goes on;
##     "wait:T" steps and "attack@S|T" (which carries its own deadline) are never timed out;
##   * the script hands over to the ordinary computer at SCRIPT_TIMEOUT seconds at the latest (default 720), whatever is left.
## Per step it records when it was first tried, when it was done (placed / queued / started), when a building it placed
## stood, and what happened: "done", "skipped" (bo_ai.gd's own skips: over the limit, no spot), "timeout", "lost" (the
## site was lost before it stood, and placed again) or "pending" (still waiting when the game ended).

var step_timeout := 180.0
var script_timeout := 720.0
var steps_rec: Array = []           # per step index: {"step", "first", "issued", "built", "status", "note"}
var script_end_t := -1.0
var script_end_why := ""
var _cur_si := -1


func _ready() -> void:
	super()
	for s in steps:
		steps_rec.append({"step": String(s), "first": -1.0, "issued": -1.0, "built": -1.0, "status": "pending", "note": "", "_li": -1})


func _end_script(why: String) -> void:
	if scripted:
		script_end_t = snappedf(game.clock, 0.1)
		script_end_why = why
	super._end_script(why)


func _bo_tick() -> void:
	if scripted and game.clock >= script_timeout:
		_end_script("script time limit (%d s)" % int(script_timeout))
		return
	super._bo_tick()


func _do(s: String) -> String:
	var i := si
	if i < 0 or i >= steps_rec.size():
		return super._do(s)
	var rec: Dictionary = steps_rec[i]
	if float(rec["first"]) < 0.0:
		rec["first"] = snappedf(game.clock, 0.1)
	var n0 := step_log.size()
	var r := super._do(s)
	if r == "done":
		rec["issued"] = snappedf(game.clock, 0.1)
		rec["status"] = "done"
		if step_log.size() > n0:
			var li := step_log.size() - 1
			rec["_li"] = li
			var txt := String(step_log[li]["step"])
			if txt.contains("skipped"):
				rec["status"] = "skipped"
				rec["note"] = txt
			elif txt.contains("already") or txt.contains("top level"):
				rec["note"] = txt
		return r
	# still waiting
	var timed: bool = not s.begins_with("wait:") and not (s.begins_with("attack@") and s.contains("|"))
	if timed and game.clock - float(rec["first"]) >= step_timeout:
		rec["status"] = "timeout"
		rec["issued"] = snappedf(game.clock, 0.1)
		rec["note"] = "waited %d s" % int(step_timeout)
		_log("%s (timed out)" % s, -4.0)
		if game.mlog:
			game.mlog.add("%s's scripted step %s timed out" % [game.mlog.who(team), s])
		return "done"
	return r


## The fuller record: bo_ai.gd's report plus the per-step table and the hand-over.
func report_v2() -> Dictionary:
	var rep := report()
	var out: Array = []
	for rec in steps_rec:
		var d: Dictionary = (rec as Dictionary).duplicate()
		var li := int(d["_li"])
		d.erase("_li")
		if li >= 0 and li < step_log.size():
			var dn := float(step_log[li]["done"])
			if dn > float(d["issued"]) + 0.05:
				d["built"] = dn        # (a building's site that stood, or a gear swap that finished)
			if dn == -2.0 and String(d["status"]) == "done":
				d["status"] = "lost"
		out.append(d)
	rep["steps_v2"] = out
	rep["script_end_t"] = script_end_t
	rep["script_end_why"] = script_end_why if script_end_t >= 0.0 else "still scripted at the end"
	rep["then"] = String(bo.get("then", "balanced"))
	rep["steps_list"] = steps.duplicate()
	var n_done := 0
	for d in out:
		if String(d["status"]) == "done":
			n_done += 1
	rep["steps_done"] = n_done
	return rep
