extends Node3D

## The umpire's high chair seen from straight above, set exactly as court.gd sets it,
## with a red bar laid towards the court (-X). For squaring the chair to the court.
##
##     godot --path . res://dev/looks/_chairtop.tscn

func _ready() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-60, 20, 0)
	add_child(sun)
	var chair := Props.node(Props.HIGH_CHAIR, 2.75, Props.turned(Props.HIGH_CHAIR_SQUARE))
	chair.position = Vector3(0.28, 0, 0)
	chair.rotation.y = float(OS.get_environment("SPIN")) if OS.has_environment("SPIN") else PI * 0.5
	add_child(chair)
	var bar := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.5, 0.02, 0.05)
	bar.mesh = box
	bar.position = Vector3(-0.75, 0, 0)
	var red := StandardMaterial3D.new()
	red.albedo_color = Color.RED
	bar.material_override = red
	add_child(bar)
	var cam := Camera3D.new()
	add_child(cam)
	cam.position = Vector3(0, 7, 0)
	cam.look_at(Vector3.ZERO, Vector3.FORWARD)
	cam.fov = 35
	cam.current = true
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://dev/shots/_chairtop.png")
	get_tree().quit()
