extends Node3D

## The smash, one character per moment, from the side and from the front.
##
##     godot --path . res://dev/looks/_smashshot.tscn
##
## Meshy made the motion from a description and nobody chose its poses, so this is how
## anyone finds out what it does on our characters and with our racket in the hand. The
## game starts the clip on the frame the shuttle is struck; `CONTACT` is where the racket
## should be at full stretch overhead, and the racket head's height there is printed.

## 6.4 frames at 24 fps: frame 24 of Meshy's clip, which is trimmed to start at 17.6.
const CONTACT := 6.4 / 24.0
const AT := [0.0, 0.12, CONTACT, 0.4, 0.55, 0.7, 0.95]


func _ready() -> void:
	var light := DirectionalLight3D.new()
	light.rotation = Vector3(deg_to_rad(-46.0), deg_to_rad(28.0), 0.0)
	light.light_energy = 1.3
	add_child(light)
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.14, 0.16, 0.20)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.58, 0.64)
	world.environment = env
	add_child(world)

	var length := 0.0
	for row in 2:
		for i in AT.size():
			var model := Models.player(Sides.Team.BLUE)
			var holder := Node3D.new()
			holder.position = Vector3((i - (AT.size() - 1) * 0.5) * 1.3, 2.7 - row * 2.7, 0.0)
			# Top row faces the camera; bottom row is turned to show the swing side-on.
			holder.rotation.y = 0.0 if row == 0 else -PI * 0.5
			add_child(holder)
			holder.add_child(model)
			var animator := Models.animator(model)
			if animator == null or not animator.has_animation("smash"):
				print("no smash on the character")
				get_tree().quit()
				return
			length = animator.get_animation("smash").length
			animator.play("smash")
			animator.seek(minf(float(AT[i]), length), true)
			animator.pause()
			if row == 0 and is_equal_approx(float(AT[i]), CONTACT):
				await get_tree().process_frame
				var racket = model.get_meta("racket") if model.has_meta("racket") else null
				if racket != null:
					print("racket at contact: %.2f m up" % racket.global_position.y)

	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 1.9, 9.6)
	camera.fov = 42.0
	add_child(camera)

	print("smash is %.2f s long; frames at %s s" % [length, ", ".join(AT.map(func(t): return "%.2f" % t))])
	for f in 12:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://dev/shots/smash.png")
	print("saved dev/shots/smash.png")
	get_tree().quit()
