extends Node
## The web build comes in two packs (see docs/web_load.md): index.pck holds the code and data,
## assets.pck the art, sounds and voices. The page downloads both (and keeps them in the browser's
## cache, so an update that only changes code downloads just the small one) and puts the art pack
## at ASSETS before the engine starts. This first autoload mounts it before anything loads a picture.
## On Android and the desktop everything is in the one pack and this does nothing.

const ASSETS := "/assets.pck"


func _init() -> void:
	if not OS.has_feature("web") or not FileAccess.file_exists(ASSETS):
		return
	# false: the code pack's own files (project settings, class list) always win
	if not ProjectSettings.load_resource_pack(ASSETS, false):
		push_error("WebBoot: could not mount " + ASSETS)
