extends Node

## What animations a model actually carries, by name.
##
##   MODEL="res://assets/characters/spectator.glb" \
##     godot --headless --path . res://dev/looks/_clips.tscn --quit-after 400
##
## Every model in this game names its clips differently — one calls it "Run" and the next
## "Armature|walk2", which is why `Models.clip_named` guesses from a list of words. This
## answers the question directly, and it is the first thing to run when a new model arrives
## and the thing that should be playing is not.
##
## It found the three clips the crowd is built from on 2026-09-21: the forge's spectator
## carries `sit`, `clap` and `cheer`, which is what made a seated audience possible at all.

func _ready() -> void:
	var wanted := OS.get_environment("MODEL")
	for path in ([wanted] if not wanted.is_empty() else ["res://assets/characters/spectator.glb"]):
		var m: Node3D = load(path).instantiate()
		add_child(m)
		var p := Models.animator(m)
		print("%s: %s" % [path.get_file(), p.get_animation_list() if p else "no animator"])
		var sk := Models.skeleton_of(m)
		print("  bones: %d" % (sk.get_bone_count() if sk else -1))
	get_tree().quit()
