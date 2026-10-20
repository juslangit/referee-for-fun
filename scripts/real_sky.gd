class_name RealSky
extends RefCounted

## A photographed sky for the outdoor courts, in place of a two-colour gradient.
##
## Luqman played tennis on 2026-10-20 and found the club courts empty: a flat blue
## gradient over a flat green plane, when the game is meant to look near real. The fix is
## a Poly Haven HDRI — a full 360° photograph with the light in it — as the background,
## the ambient light and the reflections all at once.
##
## A photographed sky has its own sun, so the game's `DirectionalLight3D` has to agree
## with it or the shadows point away from the sun you can see. Each sky below records
## where its sun is in the picture, found once by taking the brightest pixel:
##
## * `u` — across the panorama, 0 to 1. Godot puts u at azimuth `u × 360°`, measured with
##   direction `(sin a, ·, −cos a)`; measured by sweeping a narrow camera round the sky
##   on 2026-10-20 (u 0.600 peaked at 215°).
## * `elevation` — degrees above the horizon.
##
## `turn` spins the photograph about the vertical, which moves its sun to `u × 360° − turn`
## (also measured: +30° took that sun from 216° to 186°). It is how a sky is set so its
## sun lands where the court was lit from before, and so the interesting side of the
## picture is the side the umpire looks at.
##
## Every sky is CC0 from polyhaven.com.
## Tried on 2026-10-20 against je_gray_park (a low morning sun and long dark shadows) and
## netball_court (a real sports centre, but shot at dusk and washed out to white); Luqman
## kept this one.
##
## The beach got its own on 2026-10-20, when the other sports were given real surroundings:
## *Spiaggia di Mondello*, a white-sand beach in bright afternoon sun with the sea along one
## side and trees and headlands along the other — the nearest thing on Poly Haven to Pantai
## Cenang. Sun measured the same way (brightest pixel of the 4k file).
const SKIES := {
	&"rural_asphalt_road": {"file": "res://assets/sky/rural_asphalt_road_4k.hdr",
		"u": 0.600, "elevation": 45.7, "author": "Alexander Scholten"},
	&"spiaggia_di_mondello": {"file": "res://assets/sky/spiaggia_di_mondello_4k.hdr",
		"u": 0.6006, "elevation": 25.3, "author": "Andreas Mischok"},
}


## Where the sun is, in degrees round from -Z towards +X, once the sky is turned.
static func sun_azimuth_deg(id: StringName, turn_deg: float) -> float:
	return float(SKIES[id]["u"]) * 360.0 - turn_deg


## The rotation for a `DirectionalLight3D` shining from this sky's sun. The light points
## down its own -Z, so its +Z is set to the direction of the sun.
static func sun_rotation(id: StringName, turn_deg: float) -> Vector3:
	var a := deg_to_rad(sun_azimuth_deg(id, turn_deg))
	var e := deg_to_rad(float(SKIES[id]["elevation"]))
	return Vector3(-e, PI - a, 0.0)


## A `Sky` showing the photograph. Built fresh each time, because the environment that
## holds it is freed and rebuilt when a career goes indoors and comes back out.
static func sky(id: StringName) -> Sky:
	var material := PanoramaSkyMaterial.new()
	material.panorama = load(SKIES[id]["file"])
	var result := Sky.new()
	result.sky_material = material
	return result


static func turn_radians(turn_deg: float) -> Vector3:
	return Vector3(0.0, deg_to_rad(turn_deg), 0.0)
