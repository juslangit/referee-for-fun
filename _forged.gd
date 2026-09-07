extends Node3D

const MADE := ["athlete_tall", "athlete_average", "athlete_stocky", "athlete_wiry", "spectator"]

func _ready() -> void:
	for name in MADE:
		var path := "res://assets/characters/%s.glb" % name
		if not ResourceLoader.exists(path):
			print("%-18s MISSING" % name); continue
		var model: Node3D = load(path).instantiate()
		add_child(model)
		await get_tree().process_frame

		var box := _measure(model)
		var animator: AnimationPlayer = null
		var bones := 0
		for node in _every(model):
			if node is AnimationPlayer: animator = node
			if node is Skeleton3D: bones = node.get_bone_count()
		var clips: Array = animator.get_animation_list() if animator else []
		print("%-18s %.2f m tall, feet y %+.3f, %d bones, %d clips" % [
			name, box.size.y, box.position.y, bones, clips.size()])
		print("    %s" % ", ".join(clips))
	get_tree().quit()

func _measure(from: Node3D) -> AABB:
	var into := from.global_transform.affine_inverse()
	var box := AABB(); var started := false
	for child in _every(from):
		if child is MeshInstance3D and child.mesh != null:
			var placed: Node3D = child
			var driver: Node = child.get_node_or_null(child.skeleton)
			if driver is Skeleton3D: placed = driver
			var here: AABB = (into * placed.global_transform) * child.mesh.get_aabb()
			box = here if not started else box.merge(here); started = true
	return box

func _every(node: Node) -> Array:
	var found := [node]
	for c in node.get_children(): found.append_array(_every(c))
	return found
