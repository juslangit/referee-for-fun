extends Node

## The Meshy character Luqman downloaded, stood on the court beside a player the game
## already uses, so the two can be compared at the same scale under the same light.

const NEW := "res://assets/meshy/official/official_animated.glb"
const OLD := "res://assets/meshy/official_new/official_new_rigged.glb"


func _ready() -> void:
	var hall: Node = load("res://scenes/match.tscn").instantiate()
	hall.print_truth_while_testing = false
	add_child(hall)
	await get_tree().physics_frame
	hall.career = Career.new()
	hall.ui.hide_menus()
	hall.ui.show_hud(false)
	for player in hall.players:
		player.visible = false

	var newcomer: Node3D = load(NEW).instantiate()
	newcomer.name = "Newcomer"
	# Its origin is at the model's centre, not between its feet — the glTF bounds run
	# from -0.951 to +0.947 on Y — so dropped in at floor level it stands waist-deep in
	# the court. Lifted by half its height to compare like with like.
	newcomer.position = Vector3(-1.2, 0.0, 2.6)
	add_child(newcomer)
	_report("the official in game now", newcomer)

	var known: Node3D = load(OLD).instantiate()
	known.name = "Known"
	known.position = Vector3(1.2, 0.0, 2.6)
	add_child(known)
	_report("the new Meshy character", known)

	# From the umpire's chair, which is the only place a player is ever seen from.
	var eye := hall.camera as Camera3D
	eye.current = true
	for f in 8:
		await get_tree().process_frame
	await _shot("res://dev/shots/_shot_newathlete_chair.png")

	# And close, from the front, so the surface can be judged rather than guessed at.
	var near := Camera3D.new()
	near.position = Vector3(0.0, 1.1, 6.2)
	near.look_at(Vector3(0.0, 0.95, 2.6))
	near.fov = 42.0
	add_child(near)
	near.current = true
	for f in 8:
		await get_tree().process_frame
	await _shot("res://dev/shots/_shot_newathlete_close.png")
	get_tree().quit()


func _report(what: String, root: Node3D) -> void:
	var tris := 0
	var meshes := 0
	var skinned := 0
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		meshes += 1
		if mi.skeleton != NodePath("") and mi.skin != null:
			skinned += 1
		var mesh := mi.mesh
		if mesh != null:
			for s in mesh.get_surface_count():
				var arrays := mesh.surface_get_arrays(s)
				var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
				tris += (idx.size() / 3) if idx.size() > 0 else 0
	var bones := root.find_children("*", "Skeleton3D", true, false).size()
	var players := root.find_children("*", "AnimationPlayer", true, false)
	var clips := 0
	for node in players:
		clips += (node as AnimationPlayer).get_animation_list().size()
	var box := root.get_node_or_null(".") as Node3D
	print("%-26s  %6d tris  %d mesh  %d skinned  %d skeleton  %d clip(s)" % [
		what, tris, meshes, skinned, bones, clips])


func _shot(path: String) -> void:
	for f in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
