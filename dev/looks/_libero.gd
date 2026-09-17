extends Node

## The libero's shirt: a repainted kit instead of a box strapped to the chest.
##
## Left, what the game does today — `Models.wear_bib()` puts a 0.34 x 0.40 x 0.26 m
## BoxMesh on the chest bone. Right, the same character wearing a shirt repainted in
## texture space by `tools/meshy/recolour_kit.py`.

const MODEL := "res://assets/meshy/player_red/player_red_animated.glb"
const LIBERO_TEX := "res://assets/meshy/player_red_libero/player_red_libero_texture.png"


func _ready() -> void:
	var world := Node3D.new()
	add_child(world)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.10, 0.12, 0.15)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.48, 0.51, 0.58)
	env.ambient_light_energy = 0.8
	var holder := WorldEnvironment.new()
	holder.environment = env
	world.add_child(holder)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-40.0, -35.0, 0.0)
	key.light_energy = 1.6
	world.add_child(key)

	var boxed: Node3D = load(MODEL).instantiate()
	boxed.position = Vector3(-0.55, 0.0, 0.0)
	world.add_child(boxed)
	Models.wear_bib(boxed, Color(0.95, 0.82, 0.20))
	_pose(boxed)

	var painted: Node3D = load(MODEL).instantiate()
	painted.position = Vector3(0.55, 0.0, 0.0)
	world.add_child(painted)
	_wear_kit(painted, load(LIBERO_TEX))
	_pose(painted)

	var eye := Camera3D.new()
	world.add_child(eye)
	eye.look_at_from_position(Vector3(0.0, 1.15, 3.1), Vector3(0.0, 0.95, 0.0), Vector3.UP)
	eye.fov = 42.0
	eye.current = true

	for f in 10:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://dev/shots/_shot_libero.png")
	get_tree().quit()


func _pose(figure: Node3D) -> void:
	var player := Models.animator(figure)
	if player == null:
		return
	player.play("vb_ready")
	player.seek(0.5, true)
	player.advance(0.0)


## The repainted sheet onto every surface the character has, keeping the rest of the
## material as Meshy set it.
func _wear_kit(figure: Node3D, sheet: Texture2D) -> void:
	for node in figure.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		var mesh := mesh_instance.mesh
		if mesh == null:
			continue
		for s in mesh.get_surface_count():
			var was := mesh_instance.get_active_material(s)
			var now := (was.duplicate() if was != null else StandardMaterial3D.new()) as StandardMaterial3D
			now.albedo_texture = sheet
			mesh_instance.set_surface_override_material(s, now)
