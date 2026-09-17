extends Node3D

## The seven sepak takraw clips, each held at a few of its frames, from the front and then
## from the side.
##
## Authored blind, like the volleyball clips — numbers in tools/meshy/takraw_clips.py that
## nobody sees until they are on a character. A takraw clip has more ways to be wrong than
## a volleyball one, because it is the legs doing the work: a knee can bend the wrong way,
## a kick can go out behind, and a foot meant to be planted can hover a few centimetres
## over the floor, which is the one thing the serve is judged on. So each row stands on a
## strip of floor, and the side view is the one that shows it.
##
##     godot --path . res://dev/looks/_stposes.tscn --resolution 1600x900
##
## Saves dev/shots/st_poses_front.png and dev/shots/st_poses_side.png.

## Frames at 24 fps, chosen for the moments that matter: contact, the top of a jump, and a
## frame halfway through the block's turn, where a curve that goes the long way round
## would show up as a body facing sideways.
const AT := {
	"st_serve": [6, 13, 18],
	"st_throw": [0, 13, 20],
	"st_receive": [5, 9],
	"st_header": [4, 11],
	"st_set": [6, 12],
	"st_spike": [10, 14, 19],
	"st_block": [6, 11, 23],
}

const COLUMN := 1.45
const ROW := 3.1


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
	var bodies: Array[Node3D] = []
	var missing: Array[String] = []
	for column in names.size():
		var clip: String = names[column]
		var frames: Array = AT[clip]
		for row in frames.size():
			var at := Vector3((column - (names.size() - 1) * 0.5) * COLUMN, -row * ROW, 0.0)
			_floor(at)
			_label(at + Vector3(0.0, -0.25, 0.4), "%s  %d" % [clip.trim_prefix("st_"), frames[row]])
			var model := Models.player(Sides.Team.BLUE)
			if model == null:
				print("no character to pose")
				get_tree().quit()
				return
			var holder := Node3D.new()
			holder.position = at
			add_child(holder)
			holder.add_child(model)
			bodies.append(holder)
			var animator := Models.animator(model)
			if animator == null or not animator.has_animation(clip):
				if not missing.has(clip):
					missing.append(clip)
				continue
			animator.play(clip)
			animator.seek(float(frames[row]) / 24.0, true)
			animator.pause()

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = ROW * 3.0 + 0.2
	camera.position = Vector3(0.0, -ROW + 1.2, 12.0)
	add_child(camera)

	print("takraw clips missing: %s" % ("none" if missing.is_empty() else str(missing)))

	# The Meshy characters look down their own +Z, so a camera on +Z is already looking
	# them in the face; a quarter turn puts them facing screen right.
	await _save("res://dev/shots/st_poses_front.png")
	for body in bodies:
		body.rotation.y = PI * 0.5
	await _save("res://dev/shots/st_poses_side.png")
	print("columns, left to right: %s" % ", ".join(names))
	get_tree().quit()


func _save(path: String) -> void:
	for f in 12:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("saved ", path)


## A strip of floor under each figure, so a foot that is meant to be on it can be seen to be.
func _floor(at: Vector3) -> void:
	var strip := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(COLUMN * 0.9, 0.02, 0.9)
	strip.mesh = box
	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color(0.36, 0.40, 0.46)
	strip.material_override = paint
	strip.position = at + Vector3(0.0, -0.01, 0.0)
	add_child(strip)


func _label(at: Vector3, text: String) -> void:
	var label := Label3D.new()
	label.text = text
	label.pixel_size = 0.004
	label.font_size = 40
	label.position = at
	add_child(label)
