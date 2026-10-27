class_name Chat
extends Node
## The in-game chat: what YOU, the computers and (online) the other players say. The HUD draws the log (hud.gd),
## the match log keeps every line ("[02:15] P1 Crown says: gg"), and a "gg" from the player while a computer
## has one pending ends the match (AI.gg_reply, ai_resign.gd). Online every line goes through NetSession.chat_out:
## a guest's own lines to the host, the host's (its own, the computers', the other guests') to the guests.

const SHOW_SECS := 10.0         # a line stays this long, then fades
const FADE_SECS := 1.5
const VISIBLE_LINES := 5        # the log shows at most this many lines at once
const KEEP := 40                # history kept (Enter shows the recent ones again)
const MAX_LEN := 80
const MIN_GAP_MS := 400         # the player's lines: no faster than this (no spam)
## The phone's quick-chat buttons: [label, text sent].
const QUICK := [["GG", "gg"], ["GL HF", "gl hf"], ["THANKS", "thanks"], ["OOPS", "oops"], ["WAIT", "wait"], ["ATTACK?", "attack?"]]

var game: Game
var lines: Array = []           # {team, name, text, born (msec)}
var reveal_until := 0           # msec: the history is shown whole until then (Enter, the phone's button)
var _last_player_ms := -10000


func name_of(t: int) -> String:
	if t == game.human and not game.demo:
		return "YOU"
	return "P%d %s" % [t + 1, game.faction_of(t).capitalize()]


## A line in the log (and the match log). Returns it. `from_net`: online, where it came from (-1: said here; the host:
## a guest's relay id; a guest: 0, the host), so it is passed on to the others but not back.
func post(team: int, text: String, from_net := -1) -> Dictionary:
	text = clean(text)
	if text == "":
		return {}
	var line := {"team": team, "name": name_of(team), "text": text, "born": Time.get_ticks_msec()}
	lines.append(line)
	while lines.size() > KEEP:
		lines.pop_front()
	if game.mlog:
		game.mlog.add("%s says: %s" % [line["name"], text])
	Sfx.play_any(["ui/chat"], Vector2.INF, -6.0)
	if game.net != null:
		game.net.chat_out(team, text, from_net)
	return line


## The player says something. A gg while a computer's gg is pending ends the match.
## Returns false if it was ignored (empty, or too soon after the last).
func player_say(text: String) -> bool:
	text = clean(text)
	var now := Time.get_ticks_msec()
	if text == "" or game.over or game.demo or now - _last_player_ms < MIN_GAP_MS:
		return false
	_last_player_ms = now
	post(game.human, text)
	if is_gg(text):
		for ai in game.ais.duplicate():
			if is_instance_valid(ai) and ai.gg_pending():
				ai.gg_reply()
	return true


## Lines to draw now: [[line, alpha]], oldest first, at most VISIBLE_LINES.
func visible(now_ms: int, all := false) -> Array:
	var out: Array = []
	var show_all := all or now_ms < reveal_until
	for i in range(lines.size() - 1, -1, -1):
		var l: Dictionary = lines[i]
		var age := (now_ms - int(l["born"])) / 1000.0
		var a := 1.0
		if not show_all:
			if age >= SHOW_SECS + FADE_SECS:
				continue
			a = clampf((SHOW_SECS + FADE_SECS - age) / FADE_SECS, 0.0, 1.0)
		out.push_front([l, a])
		if out.size() >= VISIBLE_LINES:
			break
	return out


## Show the recent history again for a while.
func reveal(secs := SHOW_SECS) -> void:
	reveal_until = Time.get_ticks_msec() + int(secs * 1000.0)


static func clean(text: String) -> String:
	var t := text.strip_edges().replace("\n", " ").replace("\t", " ")
	while t.contains("  "):
		t = t.replace("  ", " ")
	return t.substr(0, MAX_LEN)


const GG_WORDS := ["gg", "ggs", "ggwp", "gge", "ggg", "gggg"]
const NOT_GG := ["not", "no", "nope", "never", "dont", "don't", "nogg", "ngg"]


## Does this text mean "good game"? gg, GG!, gg wp, ggwp, good game, good game well played...
static func is_gg(text: String) -> bool:
	var norm := ""
	for ch in text.to_lower():
		norm += ch if (ch >= "a" and ch <= "z") or ch == " " or ch == "'" else " "
	var words := norm.split(" ", false)
	if words.is_empty() or words.size() > 5:
		return false
	for w in words:
		if NOT_GG.has(w):
			return false
	for w in words:
		if GG_WORDS.has(w):
			return true
	return " ".join(words).begins_with("good game")
