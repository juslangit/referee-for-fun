extends Node
func _ready() -> void:
	for path in ["res://assets/characters/spectator.glb"]:
		var m: Node3D = load(path).instantiate()
		add_child(m)
		var p := Models.animator(m)
		print("%s: %s" % [path.get_file(), p.get_animation_list() if p else "no animator"])
		var sk := Models.skeleton_of(m)
		print("  bones: %d" % (sk.get_bone_count() if sk else -1))
	get_tree().quit()
