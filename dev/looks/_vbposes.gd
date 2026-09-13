extends Node3D

## The six volleyball clips, one character each, held at the moment that matters.
##
## Authored blind — the poses are written as numbers in a Python file and nobody sees
## them until they are on a character in the game. This is the only way to find out
## whether "both arms straight and locked in front" actually produced that.

const AT := {
	"vb_ready": 0.5,
	"vb_dig": 0.22,
	"vb_set": 0.45,
	"vb_spike": 0.38,
	"vb_block": 0.30,
	"vb_serve": 0.30,
}


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
	env.ambient_light_energy = 1.0
	world.environment = env
	add_child(world)

	var names := AT.keys()
	var missing: Array[String] = []
	for i in names.size():
		var clip: String = names[i]
		var model := Models.player(Sides.Team.BLUE)
		if model == null:
			print("no character to pose")
			get_tree().quit()
			return
		var holder := Node3D.new()
		holder.position = Vector3((i - (names.size() - 1) * 0.5) * 1.25, 0.0, 0.0)
		# The Meshy characters look down their own +Z, so a camera on +Z is already
		# looking them in the face. Turning them by PI photographs their backs.
		holder.rotation.y = 0.0
		add_child(holder)
		holder.add_child(model)

		var animator := Models.animator(model)
		if animator == null or not animator.has_animation(clip):
			missing.append(clip)
			continue
		animator.play(clip)
		animator.seek(animator.get_animation(clip).length * float(AT[clip]), true)
		animator.pause()

	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 1.15, 5.4)
	camera.fov = 52.0
	add_child(camera)

	print("clips on the character: %d" % _clip_count())
	print("volleyball clips missing: %s" % ("none" if missing.is_empty() else str(missing)))
	for f in 12:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://dev/shots/vb_poses.png")
	print("saved, left to right: %s" % ", ".join(names))
	get_tree().quit()


func _clip_count() -> int:
	var model := Models.player(Sides.Team.BLUE)
	var animator := Models.animator(model)
	return 0 if animator == null else animator.get_animation_list().size()
