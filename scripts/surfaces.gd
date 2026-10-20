class_name Surfaces
extends RefCounted

## Photographed ground for the outdoor venues, in place of a flat colour.
##
## A Poly Haven 1k set (CC0), scaled so a tile is the same size wherever it
## lands — the sand under the court, the free zone and the beach out to the horizon are one
## surface, not three boxes of slightly different beige.

## The beach: Poly Haven's *Dense Sand*, trodden sand with footprints in it, lightened to the
## white of the beach in the sky photograph (`RealSky`, Spiaggia di Mondello).
const SAND := "res://assets/surfaces/beach_sand_%s_1k.jpg"

## How many metres one repeat of the sand covers.
const SAND_METRES := 2.2


## Sand, multiplied by `tint` — white for the open beach, a shade darker for the raked court —
## for a flat surface `size` metres across (see `lay_sand`).
##
## Mapped by the surface's own UVs rather than in world space: world-space (triplanar) mapping
## reads every texture three times over, and on a beach the sand fills most of the screen —
## it cost 17 frames a second on 2026-10-20 (85 against 68 at the club court).
static func sand(size: Vector2, tint := Color.WHITE) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_texture = load(SAND % "diff")
	material.albedo_color = tint
	material.normal_enabled = true
	material.normal_texture = load(SAND % "nor_gl")
	material.normal_scale = 0.8
	# Sand is matt everywhere; a roughness map would be a third texture read over most of
	# the screen for a difference nobody can see.
	material.roughness = 0.95
	material.uv1_scale = Vector3(size.x / SAND_METRES, size.y / SAND_METRES, 1.0)
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return material


## Turns a slab of ground (a `BoxMesh`) into a sheet of sand at its top face: a plane, whose
## UVs run once across it, so the sand can be scaled to metres without a box's folded UVs.
static func lay_sand(slab: MeshInstance3D, tint := Color.WHITE) -> void:
	var box := slab.mesh as BoxMesh
	var plane := PlaneMesh.new()
	plane.size = Vector2(box.size.x, box.size.z)
	slab.position.y += box.size.y * 0.5
	slab.mesh = plane
	slab.material_override = sand(plane.size, tint)
