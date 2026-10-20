class_name Surfaces
extends RefCounted

## Photographed ground for the outdoor venues, in place of a flat colour.
##
## A Poly Haven 1k set (CC0), mapped in world space so a tile is the same size wherever it
## lands — the sand under the court, the free zone and the beach out to the horizon are one
## surface, not three boxes of slightly different beige.

## The beach: Poly Haven's *Dense Sand*, trodden sand with footprints in it, lightened to the
## white of the beach in the sky photograph (`RealSky`, Spiaggia di Mondello).
const SAND := "res://assets/surfaces/beach_sand_%s_1k.jpg"

## How many metres one repeat of the sand covers.
const SAND_METRES := 2.2


## Sand, multiplied by `tint` — white for the open beach, a shade darker for the raked court.
static func sand(tint := Color.WHITE) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_texture = load(SAND % "diff")
	material.albedo_color = tint
	material.normal_enabled = true
	material.normal_texture = load(SAND % "nor_gl")
	material.normal_scale = 0.8
	material.roughness_texture = load(SAND % "rough")
	material.roughness = 1.0
	material.uv1_triplanar = true
	material.uv1_world_triplanar = true
	material.uv1_scale = Vector3.ONE / SAND_METRES
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return material
