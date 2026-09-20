class_name NetCord
extends RefCounted

## The net, as cord rather than as a slab.
##
## Every net in this game was two solid boxes: a 2 cm slab for the mesh at 55% alpha and
## another for the white tape. From the chair it read as a white bar with a smear under
## it — and the umpire looks through the net for the whole match, which makes it one of
## the few objects in the game that is always on screen.
##
## A net is a square grid of cord, and every sport's is the same thing at a different
## size, so there is **one texture** — a single cell of mesh, in `assets/ui/net_cord.png`
## — tiled to each sport's own gauge. Luqman, 2026-09-20: "if two sports can use one same
## net, just do one."
##
## The gauges are the sports' own, and two pairs genuinely coincide:
##
##   badminton      15-20 mm squares (BWF)
##   sepak takraw   60-80 mm (ISTAF)
##   volleyball     100 mm (FIVB) — **indoor and beach are the same net**
##   tennis         not more than 40 mm (ITF)
##   table tennis   a fine mesh (ITTF gives no figure; 12.5 mm reads correctly)
##
## Nothing else changes. The quads, the collision box and `shake_net()` are untouched,
## which matters: the game watches the exact moment a shuttle crosses the plane of the
## net to judge an under-the-net fault, and the net-cord shake is what a net touch looks
## like from the chair. A net is one of the few things here that has to stay a flat plane
## in a known place.

const SHEET := "res://assets/ui/net_cord.png"

## How much of a BoxMesh's UV space one face gets, across and down. See `dress()`.
const FACE_U := 3.0
const FACE_V := 2.0

## How wide one square of mesh is, in metres.
const BADMINTON := 0.018
const TAKRAW := 0.070
const VOLLEYBALL := 0.100
const TENNIS := 0.040
const TABLE_TENNIS := 0.0125


## Turns a plain net material into corded mesh, tiled so the squares come out at their
## real size on a net this big.
##
## `across` and `down` are the net's own dimensions in metres, so the tiling is worked
## out from the court rather than guessed: a 6.1 m badminton net at an 18 mm gauge is 339
## squares across, and saying so in metres keeps it right if a court is ever resized.
static func dress(material: StandardMaterial3D, across: float, down: float,
		gauge: float) -> void:
	if material == null:
		return
	material.albedo_texture = load(SHEET)
	# White, so the cord keeps the colour it was drawn in rather than being tinted by
	# whatever the slab used to be.
	material.albedo_color = Color.WHITE
	# Scissor rather than blended alpha. A net is hundreds of tiny holes, and sorting
	# that many transparent surfaces against each other is both slow and wrong — players
	# seen through a blended net come out in the wrong order.
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.alpha_scissor_threshold = 0.35
	# Seen from both sides: the umpire is on one side of the net and half the players are
	# on the other.
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	# The net quads are BoxMeshes, and Godot lays a box's six faces out in an atlas
	# rather than giving each one the whole 0..1 of UV space — a face spans a third
	# across and a half down. Asking for 339 squares on a 6.1 m badminton net therefore
	# drew 113 of them, at 54 mm instead of 18. The two factors put that back.
	#
	# Measured rather than assumed: the first render came out with squares about three
	# times too big, which is what a third of the U range does to them.
	material.uv1_scale = Vector3(
		maxf(1.0, across / gauge) * FACE_U, maxf(1.0, down / gauge) * FACE_V, 1.0)
	# The cord is thread, not plastic. Left shiny it catches the spotlights and the whole
	# net flares white from the chair.
	material.roughness = 0.9
	material.metallic = 0.0
