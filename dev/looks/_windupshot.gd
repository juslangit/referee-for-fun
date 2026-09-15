extends Node3D

## The crouch before a smash and the smash it runs into, one character per moment, from
## the front and from the side. Left of the gap is `smash_windup`, right is `smash`.
##
##     godot --path . res://dev/looks/_windupshot.tscn
##
## Meshy made the motion from a description and nobody chose its poses, so this is how
## anyone finds out what it does on our characters and with our racket in the hand. The
## game starts the clip on the frame the shuttle is struck; `CONTACT` is where the racket
## should be at full stretch overhead, and the racket head's height there is printed.

## 6.4 frames at 24 fps: frame 24 of Meshy's clip, which is trimmed to start at 17.6.
const CONTACT := 6.4 / 24.0
## [clip, seconds into it]. The wind-up is 7.6 frames, 0.317 s.
const AT := [
	["smash_windup", 0.0], ["smash_windup", 0.1], ["smash_windup", 0.2], ["smash_windup", 0.3],
	["smash", 0.0], ["smash", 0.12], ["smash", CONTACT], ["smash", 0.5],
]


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
			if animator == null or not animator.has_animation(String(AT[i][0])):
				print("no %s on the character" % AT[i][0])
				get_tree().quit()
				return
			length = animator.get_animation(String(AT[i][0])).length
			animator.play(String(AT[i][0]))
			animator.seek(minf(float(AT[i][1]), length), true)
			animator.pause()
			if row == 0 and is_equal_approx(float(AT[i][1]), CONTACT):
				await get_tree().process_frame
				var racket = model.get_meta("racket") if model.has_meta("racket") else null
				if racket != null:
					print("racket at contact: %.2f m up" % racket.global_position.y)

	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 1.9, 9.6)
	camera.fov = 42.0
	add_child(camera)

	for f in 12:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://dev/shots/windup.png")
	print("saved dev/shots/windup.png")
	get_tree().quit()
