extends Node

## The nod, four frames across, beside an argue for comparison.
##
## Authored rather than reused: `celebrate` was the obvious existing clip and it is the
## wrong one, because a celebration is about winning the rally and this is about the
## person in the chair. The two have to read as different things from several metres
## away, which is the only reason this render exists.

const WIDTH := 1400
const HEIGHT := 460

## Frames of `nod` worth looking at: the stance, the deepest of the two dips, the lift
## between them, and the second dip.
const MOMENTS := [0.0, 6.0 / 24.0, 13.0 / 24.0, 20.0 / 24.0]


func _ready() -> void:
	var world := Node3D.new()
	add_child(world)

	var light := DirectionalLight3D.new()
	light.rotation = Vector3(deg_to_rad(-40.0), deg_to_rad(28.0), 0.0)
	light.light_energy = 1.5
	light.shadow_enabled = true
	world.add_child(light)

	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color(0.16, 0.18, 0.22)
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color(0.7, 0.72, 0.78)
	settings.ambient_light_energy = 0.8
	var env := WorldEnvironment.new()
	env.environment = settings
	world.add_child(env)

	var spacing := 1.05
	var shown := []
	for i in MOMENTS.size():
		shown.append(_pose(world, "nod", MOMENTS[i], (float(i) - 1.5) * spacing))
	# The counterpart, for contrast: this is what turning on the chair looks like.
	shown.append(_pose(world, "argue", 16.0 / 24.0, 2.5 * spacing))

	await get_tree().process_frame
	await get_tree().process_frame

	var frame := SubViewport.new()
	frame.size = Vector2i(WIDTH, HEIGHT)
	frame.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	frame.world_3d = get_viewport().find_world_3d()
	add_child(frame)

	var shot := Camera3D.new()
	shot.fov = 34.0
	# Added to the tree before it is aimed. look_at needs a global transform and there
	# is none until the node is in a tree, which the first run found out loudly.
	frame.add_child(shot)
	shot.position = Vector3(0.55, 1.40, 4.6)
	shot.look_at(Vector3(0.55, 1.22, 0.0), Vector3.UP)
	shot.current = true

	for f in 12:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	frame.get_texture().get_image().save_png("res://dev/shots/nod.png")
	print("saved dev/shots/nod.png — %d figures" % shown.size())
	get_tree().quit()


## One figure, frozen at one moment of one clip.
func _pose(world: Node3D, clip: String, at: float, x: float) -> Node3D:
	var figure := Models.player(Sides.Team.RED)
	if figure == null:
		print("   no character to pose")
		return null
	figure.position = Vector3(x, 0.0, 0.0)
	# Facing the camera, three-quarters on. The first attempt used 196 degrees on the
	# reasoning that a nod is aimed at the chair rather than at us, and photographed
	# five backs — a head dip is invisible from behind.
	figure.rotation.y = deg_to_rad(16.0)
	world.add_child(figure)

	var animator := Models.animator(figure)
	if animator == null or not animator.has_animation(clip):
		print("   %s has no clip called %s" % [figure.name, clip])
		return figure
	animator.play(clip)
	animator.seek(at, true)
	animator.pause()
	return figure
