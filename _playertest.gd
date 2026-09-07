extends Node3D

func _ready() -> void:
	var p := Player.new()
	add_child(p)
	p.setup(Sides.Team.RED, Vector3.ZERO)
	for frame in range(4):
		await get_tree().process_frame
	var bibs := 0
	var rackets := 0
	for node in _every(p):
		if node.name == "Bib": bibs += 1
		if node.name == "Obj_Racket": rackets += 1
	print("bibs %d  rackets %d" % [bibs, rackets])
	print("figure pos %v  rot %v" % [p.get_child(0).position, p.get_child(0).rotation])
	var box := _measure(p)
	print("player box %.2f x %.2f x %.2f  bottom y %+.3f" % [box.size.x, box.size.y, box.size.z, box.position.y])
	get_tree().quit()

func _measure(from: Node3D) -> AABB:
	var into := from.global_transform.affine_inverse()
	var box := AABB(); var started := false
	for child in _every(from):
		if child is MeshInstance3D and child.mesh != null:
			var here: AABB = (into * child.global_transform) * child.mesh.get_aabb()
			box = here if not started else box.merge(here); started = true
	return box

func _every(node: Node) -> Array:
	var found := [node]
	for c in node.get_children(): found.append_array(_every(c))
	return found
