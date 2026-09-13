extends Node

## The smash in a real badminton rally, with the racket in the hand and the shuttle
## leaving it.
##
##     godot --path . res://dev/looks/_smashrally.tscn --fixed-fps 120
##
## Plays rallies until somebody smashes, then photographs them from beside the court at
## the moment of the strike, a quarter of a second on (the clip's contact), and at the
## landing of the jump.

const AT := [0.0, 0.27, 0.6]


func _ready() -> void:
	var arena: Node = load("res://scenes/match.tscn").instantiate()
	arena.print_truth_while_testing = false
	add_child(arena)
	await get_tree().physics_frame
	arena._set_up_the_match(false)
	arena.begin_match()

	var camera := Camera3D.new()
	camera.fov = 40.0
	arena.add_child(camera)

	for r in 12:
		arena.start_rally()
		var waited := 0
		var smasher: Player = null
		while arena._phase != arena.Phase.AWAITING_CALL and waited < 4000:
			await get_tree().process_frame
			waited += 1
			for p in arena.players:
				if p._clip == "smash":
					smasher = p
			if smasher != null:
				break
		if smasher == null:
			if arena._phase == arena.Phase.AWAITING_CALL:
				arena.make_call(&"in" if arena.rally.was_in else &"out")
			continue

		print("rally %d: %s smashes from %s" % [r, Sides.label(smasher.team), smasher.global_position])
		var started := 0.0
		for i in AT.size():
			while started < float(AT[i]):
				await get_tree().process_frame
				started += get_process_delta_time()
			var at := smasher.global_position
			camera.global_position = at + Vector3(4.2, 1.5, 0.0)
			camera.look_at(at + Vector3(0.0, 1.5, 0.0))
			camera.make_current()
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(
				"res://dev/shots/smash_rally_%d.png" % i)
			print("   %.2f s  clip %s  shuttle %s" % [started, smasher._clip,
				arena._shuttle.global_position if is_instance_valid(arena._shuttle) else "gone"])
		get_tree().quit()
		return
	print("nobody smashed in 12 rallies")
	get_tree().quit()
