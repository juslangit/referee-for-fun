class_name Figure
extends RefCounted

## A person, built out of boxes.
##
## Everybody on court was a capsule until now, which was fine for working out whether
## the game played well and hopeless for anything else — you could not tell which way
## somebody was facing, whether they were holding a racket, or whether the shape in
## the corner was an official or a bin.
##
## These are still primitives. They are not a substitute for modelled and animated
## characters, and the drop-in point for real ones is documented in `player.gd`. What
## they do is give every figure a front, a pair of legs, a head and, where it matters,
## something in their hand — which is enough for the court to read as a court.

const HEIGHT := 1.78

## Everybody is drawn on the people layer so the line camera can leave them out.
const PEOPLE_LAYER := 2

## Skin, and the darker shade used for shorts and shoes.
const SKIN := Color(0.78, 0.62, 0.50)
const DARK := Color(0.16, 0.17, 0.20)


## Builds a standing person facing -Z, holding a racket if asked.
static func standing(parent: Node3D, shirt: Color, with_racket := false) -> void:
	_leg(parent, -0.11)
	_leg(parent, 0.11)

	# Shorts, then the shirt above them.
	_box(parent, "Shorts", Vector3(0.40, 0.26, 0.24), Vector3(0.0, 0.96, 0.0), DARK)
	_box(parent, "Torso", Vector3(0.42, 0.50, 0.25), Vector3(0.0, 1.33, 0.0), shirt)
	_box(parent, "Shoulders", Vector3(0.50, 0.14, 0.26), Vector3(0.0, 1.52, 0.0), shirt)

	_arm(parent, -0.30, shirt)
	_arm(parent, 0.30, shirt)

	_box(parent, "Neck", Vector3(0.11, 0.07, 0.11), Vector3(0.0, 1.62, 0.0), SKIN)
	_head(parent, Vector3(0.0, 1.75, 0.0))

	if with_racket:
		_racket(parent)


## Builds a person sitting on a chair, facing -Z. Used for the line judges, who spend
## the entire match sitting down.
static func seated(parent: Node3D, shirt: Color) -> void:
	# Thighs forward, shins down.
	for side in [-0.11, 0.11]:
		_box(parent, "Thigh", Vector3(0.16, 0.16, 0.44), Vector3(side, 0.53, -0.16), DARK)
		_box(parent, "Shin", Vector3(0.15, 0.46, 0.16), Vector3(side, 0.23, -0.34), SKIN)
		_box(parent, "Shoe", Vector3(0.16, 0.08, 0.26), Vector3(side, 0.04, -0.42), DARK)

	_box(parent, "Torso", Vector3(0.42, 0.50, 0.25), Vector3(0.0, 0.86, 0.0), shirt)
	_box(parent, "Shoulders", Vector3(0.50, 0.14, 0.26), Vector3(0.0, 1.05, 0.0), shirt)

	for side in [-0.30, 0.30]:
		_box(parent, "Arm", Vector3(0.12, 0.40, 0.13), Vector3(side, 0.90, 0.0), shirt)

	_box(parent, "Neck", Vector3(0.11, 0.07, 0.11), Vector3(0.0, 1.15, 0.0), SKIN)
	_head(parent, Vector3(0.0, 1.28, 0.0))


# --- parts ---------------------------------------------------------------------

static func _leg(parent: Node3D, x: float) -> void:
	_box(parent, "Leg", Vector3(0.16, 0.84, 0.18), Vector3(x, 0.44, 0.0), SKIN)
	_box(parent, "Shoe", Vector3(0.17, 0.08, 0.26), Vector3(x, 0.04, -0.04), DARK)


static func _arm(parent: Node3D, x: float, shirt: Color) -> void:
	_box(parent, "Sleeve", Vector3(0.13, 0.18, 0.14), Vector3(x, 1.45, 0.0), shirt)
	_box(parent, "Arm", Vector3(0.11, 0.40, 0.12), Vector3(x, 1.16, 0.0), SKIN)


static func _head(parent: Node3D, at: Vector3) -> void:
	var head := MeshInstance3D.new()
	head.name = "Head"
	var sphere := SphereMesh.new()
	sphere.radius = 0.115
	sphere.height = 0.25
	head.mesh = sphere
	head.position = at
	head.material_override = _material(SKIN)
	head.layers = PEOPLE_LAYER
	parent.add_child(head)


## A racket, held out to the side in the right hand. It never swings — the shuttle is
## struck by the rally logic, not by an animation — but a badminton player without a
## racket looks wrong in a way that is hard to ignore.
static func _racket(parent: Node3D) -> void:
	var arm := Node3D.new()
	arm.name = "Racket"
	arm.position = Vector3(0.42, 1.24, -0.10)
	arm.rotation = Vector3(0.0, 0.0, deg_to_rad(-28.0))
	parent.add_child(arm)

	_box(arm, "Handle", Vector3(0.028, 0.26, 0.028), Vector3(0.0, 0.13, 0.0), Color(0.12, 0.12, 0.14))

	var head := MeshInstance3D.new()
	head.name = "Head"
	var ring := TorusMesh.new()
	ring.inner_radius = 0.10
	ring.outer_radius = 0.125
	ring.rings = 10
	ring.ring_segments = 8
	head.mesh = ring
	head.position = Vector3(0.0, 0.37, 0.0)
	head.rotation = Vector3(deg_to_rad(90.0), 0.0, 0.0)
	head.material_override = _material(Color(0.90, 0.90, 0.92))
	head.layers = PEOPLE_LAYER
	arm.add_child(head)


static func _box(parent: Node3D, part: String, size: Vector3, at: Vector3, colour: Color) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.name = part
	instance.mesh = mesh
	instance.position = at
	instance.material_override = _material(colour)
	instance.layers = PEOPLE_LAYER
	parent.add_child(instance)


static func _material(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 0.85
	return material
