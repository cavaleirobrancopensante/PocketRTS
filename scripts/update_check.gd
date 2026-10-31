class_name UpdateCheck
extends Node
## THE NEW-VERSION NOTICE (the owner, 2026-10-31): the Windows program and the Android app look, once a run, at the
## version the site serves (version.json, written by the site's build, .github/workflows/web.yml); if it is newer than
## this copy, the main menu shows a box: a new version is out, with DOWNLOAD (the site's file for this system) and
## LATER. The web build never asks (the page is always the newest).

const SITE := "https://holdfastrts.github.io/Holdfast/"
const FILES := {"Windows": "Holdfast_windows.zip", "Android": "Holdfast.apk"}

static var latest := ""            # what the site said ("" = not known yet / no answer)
static var asked := false          # (once a run)
static var dismissed := false      # LATER pressed this run
static var _req: HTTPRequest


## Is this a build that can be told to update (the Windows program or the Android app)?
static func wanted() -> bool:
	return not OS.has_feature("web") and not OS.has_feature("editor") and FILES.has(OS.get_name())


## Ask the site once a run; `done` is called when the answer is in (it may never come: no network).
static func ask(parent: Node, done: Callable) -> void:
	if asked or not wanted():
		return
	asked = true
	_req = HTTPRequest.new()
	_req.timeout = 8.0
	parent.add_child(_req)
	_req.request_completed.connect(func(result: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
		if result == HTTPRequest.RESULT_SUCCESS and code == 200:
			var j = JSON.parse_string(body.get_string_from_utf8())
			if j is Dictionary and j.has("version"):
				latest = String(j["version"])
				done.call()
		if is_instance_valid(_req):
			_req.queue_free())
	if _req.request(SITE + "version.json?t=%d" % Time.get_unix_time_from_system()) != OK:
		_req.queue_free()


## The site's version is newer than `mine` (numbers compared part by part: 0.24.31 < 0.25.0).
static func newer(site: String, mine: String) -> bool:
	var a := site.split(".")
	var b := mine.split(".")
	for i in maxi(a.size(), b.size()):
		var x := int(a[i]) if i < a.size() else 0
		var y := int(b[i]) if i < b.size() else 0
		if x != y:
			return x > y
	return false


## Should the main menu show the box now?
static func show_box(mine: String) -> bool:
	return not dismissed and latest != "" and newer(latest, mine)


static func download_url() -> String:
	return SITE + String(FILES.get(OS.get_name(), ""))
