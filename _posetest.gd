extends Node3D

## What does the animated model actually do once it is playing? Measured over several
## frames, because a clip with root motion in it moves the character as it plays.

func _ready() -> void:
	var holder: Node3D = Models.player(Color.RED)
	add_child(holder)
	var animator := Models.animator(holder)
	var idle := Models.clip_named(animator, ["idle"])
	Models.make_looping(animator, idle)
	animator.play(idle)
	print("playing: ", idle)

	for frame in range(5):
		await get_tree().process_frame
		var box := _measure(holder)
		print("frame %d  box %.2f x %.2f x %.2f  at (%.2f, %.2f, %.2f)" % [
			frame, box.size.x, box.size.y, box.size.z,
			box.get_center().x, box.position.y, box.get_center().z])
	get_tree().quit()


func _measure(from: Node3D) -> AABB:
	var into := from.global_transform.affine_inverse()
	var box := AABB()
	var started := false
	for child in _every(from):
		if child is MeshInstance3D and child.mesh != null:
			var placed: Node3D = child
			var driver: Node = child.get_node_or_null(child.skeleton)
			if driver is Skeleton3D:
				placed = driver
			var here: AABB = (into * placed.global_transform) * child.mesh.get_aabb()
			box = here if not started else box.merge(here)
			started = true
	return box


func _every(node: Node) -> Array:
	var found := [node]
	for child in node.get_children():
		found.append_array(_every(child))
	return found
