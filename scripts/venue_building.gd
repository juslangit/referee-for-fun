class_name VenueBuilding
extends Node3D

## The modelled building round an indoor court, which changes as the career climbs.
##
## Luqman asked on 2026-10-20 for every indoor sport to be played in its own real building,
## and for the bottom of the ladder to be somewhere humbler: a community hall at the school
## and club rungs, and the sport's arena from the state rung up. Each building is a model
## made in Blender by `tools/stadium/build_stadium.py` and a JSON of the same name that
## `Bowl` seats the crowd from, so swapping one is swapping both.
##
## `halls` maps each `Venue.Tier` to a venue id in `assets/stadium/`. The court asks
## `use(tier)` before it dresses the stands; it returns true when the building changed,
## because then the crowd has to be reseated.

var halls: Dictionary = {}

## The venue standing now, its model and its seating plan.
var current := ""
var model: Node3D
var bowl: Bowl


func use(tier: Venue.Tier) -> bool:
	var id: String = halls.get(tier, "")
	if id == current:
		return false
	if model != null:
		remove_child(model)
		model.queue_free()
		model = null
	current = id
	bowl = null
	if id.is_empty():
		return true
	model = load("res://assets/stadium/%s.glb" % id).instantiate()
	model.name = id.to_pascal_case()
	add_child(model)
	bowl = Bowl.open("res://assets/stadium/%s.json" % id)
	_no_shadows(model)
	return true


## Seats the crowd in this building: its plan, how much of each spectator to keep, and the
## colour of its seats, all from the venue's JSON. With no building, the stands go back to
## the two straight banks they were before.
func seat(stands: Stands) -> void:
	stands.bowl = bowl
	if bowl == null:
		stands.crowd_detail = 1.0
		stands.seat_colour = Color.WHITE
		return
	stands.crowd_detail = float(bowl.data.get("crowd_detail", 0.5))
	var colour: Array = bowl.data.get("seat_colour", [1.0, 1.0, 1.0])
	stands.seat_colour = Color(colour[0], colour[1], colour[2])


## The building is lit by the hall rig's spotlights, which are aimed at the court; nothing in
## it should be drawn again into their shadow maps. The roof alone would black out the court
## under the sun the rig uses for its one shadow direction.
func _no_shadows(root: Node) -> void:
	for piece in root.find_children("*", "GeometryInstance3D", true, false):
		(piece as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Repaints every part of the building whose mesh is named `part` (a material key in the
## venue's builder, capitalised: "Apron", "Accent"), or puts nothing back if there is none.
func paint(part: String, material: Material) -> void:
	if model == null:
		return
	for piece in model.find_children("*", "MeshInstance3D", true, false):
		if String(piece.name).begins_with(part):
			(piece as MeshInstance3D).material_override = material
