class_name Bowl
extends RefCounted

## A stadium bowl: rows of seats running all the way round a court, at the corners as well
## as down the sides.
##
## The steps themselves are modelled in Blender by `tools/stadium/build_stadium.py`, and
## this reads the same `assets/stadium/*_bowl.json` that script reads, so the people sit
## on the steps and not in the air beside them. Change the bowl in the JSON, re-run the
## script, and both follow.
##
## Every row runs round the inside face of the podium wall, offset outwards. That face is
## a rounded rectangle, and a point at offset `d` is `base + d * normal` where `base` is
## the matching point on the face — which is what keeps the rows parallel round the
## corners. `_frame` and `_seats_round` are the same functions as `frame` and
## `perimeter_points` in the Blender script; keep them the same.

const ARC := 10

var data: Dictionary
var _frame: Array = []


static func open(path: String) -> Bowl:
	var bowl := Bowl.new()
	var json: JSON = load(path)
	bowl.data = json.data
	bowl._build_frame()
	return bowl


func _build_frame() -> void:
	var hx: float = data["inner_half"][0]
	var hz: float = data["inner_half"][1]
	var r: float = data["corner_radius"]
	_frame.clear()
	for corner in [[hx - r, hz - r, 0.0], [-(hx - r), hz - r, 90.0],
			[-(hx - r), -(hz - r), 180.0], [hx - r, -(hz - r), 270.0]]:
		for i in ARC + 1:
			var a := deg_to_rad(float(corner[2]) + 90.0 * i / ARC)
			var n := Vector2(cos(a), sin(a))
			_frame.append([Vector2(corner[0], corner[1]) + n * r, n])


## Seats as transforms in the stadium's space: each at the middle of its row's tread, at
## the height of the tread, turned to face the court the way `Stands` turns the people
## down the two sides of a hall.
func seats() -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	var spacing: float = data["seat_spacing"]
	var gap: float = float(data["aisles"]["width"]) * 0.5 + spacing * 0.45
	for tier: Dictionary in data["tiers"]:
		for row in int(tier["rows"]):
			var d: float = tier["first_offset"] + tier["depth"] * (row + 0.5)
			var y: float = tier["base"] + tier["rise"] * (row + 1)
			var aisles: Array[Vector2] = []
			for spot in aisle_spots():
				aisles.append(spot[0] + spot[1] * d)
			for seat in _seats_round(d, spacing):
				var at: Vector2 = seat[0]
				if aisles.any(func(a: Vector2) -> bool: return a.distance_to(at) < gap):
					continue
				var n: Vector2 = seat[1]
				var t := Transform3D.IDENTITY
				t.basis = Basis(Vector3.UP, atan2(n.x, n.y))
				t.origin = Vector3(at.x, y, at.y)
				out.append(t)
	return out


## Evenly spaced [point, outward normal] round the row at offset `d`.
func _seats_round(d: float, spacing: float) -> Array:
	var loop: Array = []
	for f in _frame:
		loop.append([f[0] + f[1] * d, f[1]])
	var out: Array = []
	var carry := 0.0
	for i in loop.size():
		var a: Array = loop[i]
		var b: Array = loop[(i + 1) % loop.size()]
		var seg: float = (a[0] as Vector2).distance_to(b[0])
		var t := carry
		while t < seg:
			var f := t / seg if seg > 0.0 else 0.0
			var p: Vector2 = (a[0] as Vector2).lerp(b[0], f)
			var n: Vector2 = (a[1] as Vector2).lerp(b[1], f).normalized()
			out.append([p, n])
			t += spacing
		carry = t - seg
	return out


## [point on the podium face, outward normal] at the middle of every aisle.
func aisle_spots() -> Array:
	var hx: float = data["inner_half"][0]
	var hz: float = data["inner_half"][1]
	var r: float = data["corner_radius"]
	var spots: Array = []
	for side: float in [1.0, -1.0]:
		for z: float in data["aisles"]["side_z"]:
			spots.append([Vector2(side * hx, z), Vector2(side, 0.0)])
		for x: float in data["aisles"]["end_x"]:
			spots.append([Vector2(x, side * hz), Vector2(0.0, side)])
	for sx: float in [1.0, -1.0]:
		for sz: float in [1.0, -1.0]:
			for deg: float in data["aisles"]["corner_deg"]:
				var a := deg_to_rad(deg)
				var n := Vector2(sx * cos(a), sz * sin(a))
				spots.append([Vector2((hx - r) * sx, (hz - r) * sz) + n * r, n])
	return spots


## Where the stadium's video screens hang, for the game to put the score on them: the
## centre of each, just in front of the modelled screen, turned so its +Z faces the court.
func screen_spots() -> Array[Dictionary]:
	var hx: float = data["inner_half"][0]
	var hz: float = data["inner_half"][1]
	var r: float = data["corner_radius"]
	var out: Array[Dictionary] = []
	for screen: Dictionary in data.get("screens", []):
		var n := Vector2(float(screen["corner"][0]), float(screen["corner"][1])).normalized()
		var base := Vector2((hx - r) * screen["corner"][0], (hz - r) * screen["corner"][1]) + n * r
		var at := base + n * (float(screen["offset"]) - 0.45)
		var size := Vector2(screen["size"][0], screen["size"][1])
		out.append({"at": Vector3(at.x, float(screen["bottom"]) + size.y * 0.5, at.y),
			"turn": atan2(-n.x, -n.y), "size": size})
	return out
