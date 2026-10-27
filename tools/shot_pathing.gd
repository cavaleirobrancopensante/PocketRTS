extends "res://tools/test_pathing.gd"
## Pictures of the pathfinding test bed's cases (start and end of each) for docs/shots/pathing/:
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1600x900 --fixed-fps 30 --script res://tools/shot_pathing.gd -- shots=docs/shots/pathing/after [only=up_cliff maps=greenhold]


func _initialize() -> void:
	super._initialize()
	if shots == "":
		shots = "user://pathing_shots"
		DirAccess.make_dir_recursive_absolute(shots)
