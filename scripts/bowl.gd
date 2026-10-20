class_name Bowl
extends RefCounted

## A venue's seating: rows of seats round a court, or banks of them down some of its sides.
##
## The steps themselves are modelled in Blender by `tools/stadium/build_stadium.py`, and
## this reads the same `assets/stadium/<venue>.json` that script reads, so the people sit
## on the steps and not in the air beside them. Change the venue in the JSON, re-run the
## script, and both follow.
##
## A tier runs one of two ways:
##
## * **Round the bowl**, the default. Every row runs round the inside face of the podium
##   wall, offset outwards. That face is a rounded rectangle, and a point at offset `d` is
##   `base + d * normal` where `base` is the matching point on the face — which is what
##   keeps the rows parallel round the corners. A corner radius of half the width makes it
##   a circle.
## * **In straight runs**, when the tier has `runs`: a bank of seating down one side of the
##   floor only, like a scaffold grandstand on a beach or a hall's bleachers. Each run names
##   its side (`+x`, `-x`, `+z`, `-z`) and how far along that side it goes.
##
## `_build_frame`, `_seats_round` and `_seats_along` are the same functions as `Plan._frame`,
## `perimeter_points` and the straight runs in `tools/stadium/lib.py`; keep them the same.

const ARC := 10

const SIDE_NORMALS := {"+x": Vector2(1, 0), "-x": Vector2(-1, 0), "+z": Vector2(0, 1), "-z": Vector2(0, -1)}

var data: Dictionary
var _frame: Array = []
var _centre := Vector2.ZERO


static func open(path: String) -> Bowl:
	var bowl := Bowl.new()
	var json: JSON = load(path)
	bowl.data = json.data
	var c: Array = bowl.data.get("centre", [0.0, 0.0])
	bowl._centre = Vector2(float(c[0]), float(c[1]))
	bowl._build_frame()
	return bowl


## Whether people sit on benches built into the steps rather than on a seat each. A beach
## grandstand and a community hall's bleachers are planks; nobody bolts a chair to them.
func benches() -> bool:
	return bool(data.get("benches", false))


func _build_frame() -> void:
	var hx: float = data["inner_half"][0]
	var hz: float = data["inner_half"][1]
	var r: float = data.get("corner_radius", 0.01)
	_frame.clear()
	for corner in [[hx - r, hz - r, 0.0], [-(hx - r), hz - r, 90.0],
			[-(hx - r), -(hz - r), 180.0], [hx - r, -(hz - r), 270.0]]:
		for i in ARC + 1:
			var a := deg_to_rad(float(corner[2]) + 90.0 * i / ARC)
			var n := Vector2(cos(a), sin(a))
			_frame.append([_centre + Vector2(corner[0], corner[1]) + n * r, n])


## Seats as transforms in the venue's space: each at the middle of its row's tread, at
## the height of the tread, turned to face the court the way `Stands` turns the people
## down the two sides of a hall.
func seats() -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	var spacing: float = data["seat_spacing"]
	var gap := 0.0
	if data.has("aisles"):
		gap = float(data["aisles"]["width"]) * 0.5 + spacing * 0.45
	for tier: Dictionary in data["tiers"]:
		for row in int(tier["rows"]):
			var d: float = tier["first_offset"] + tier["depth"] * (row + 0.5)
			var y: float = tier["base"] + tier["rise"] * (row + 1)
			var places: Array = []
			if tier.has("runs"):
				for run: Dictionary in tier["runs"]:
					places.append_array(_seats_along(run, d, spacing, tier.get("gaps", [])))
			else:
				var aisles: Array[Vector2] = []
				for spot in aisle_spots():
					aisles.append(spot[0] + spot[1] * d)
				for seat in _seats_round(d, spacing):
					var at: Vector2 = seat[0]
					if aisles.any(func(a: Vector2) -> bool: return a.distance_to(at) < gap):
						continue
					places.append(seat)
			for seat in places:
				var at: Vector2 = seat[0]
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


## A point on a straight run: `along` its side, `d` out from the floor's edge.
func run_point(run: Dictionary, along: float, d: float) -> Vector2:
	var n: Vector2 = SIDE_NORMALS[run["side"]]
	var hx: float = data["inner_half"][0]
	var hz: float = data["inner_half"][1]
	if n.x != 0.0:
		return _centre + Vector2(n.x * (hx + d), along)
	return _centre + Vector2(along, n.y * (hz + d))


## Evenly spaced [point, outward normal] down one straight run at offset `d`, centred in
## the run, leaving out anybody standing in one of its gangways (`gaps`, as positions
## along the run, each `aisles.width` wide).
func _seats_along(run: Dictionary, d: float, spacing: float, gaps: Array) -> Array:
	var out: Array = []
	var n: Vector2 = SIDE_NORMALS[run["side"]]
	var lo: float = run["from"]
	var hi: float = run["to"]
	var count := int(floor((hi - lo) / spacing))
	var start := lo + ((hi - lo) - spacing * (count - 1)) * 0.5
	var half_gap := float(data.get("aisles", {}).get("width", 1.0)) * 0.5 + spacing * 0.3
	for i in count:
		var along := start + spacing * i
		if gaps.any(func(g: float) -> bool: return absf(g - along) < half_gap):
			continue
		out.append([run_point(run, along, d), n])
	return out


## [point on the podium face, outward normal] at the middle of every aisle.
func aisle_spots() -> Array:
	var spots: Array = []
	if not data.has("aisles"):
		return spots
	var hx: float = data["inner_half"][0]
	var hz: float = data["inner_half"][1]
	var r: float = data.get("corner_radius", 0.01)
	var aisles: Dictionary = data["aisles"]
	for side: float in [1.0, -1.0]:
		for z: float in aisles.get("side_z", []):
			spots.append([_centre + Vector2(side * hx, z), Vector2(side, 0.0)])
		for x: float in aisles.get("end_x", []):
			spots.append([_centre + Vector2(x, side * hz), Vector2(0.0, side)])
	for sx: float in [1.0, -1.0]:
		for sz: float in [1.0, -1.0]:
			for deg: float in aisles.get("corner_deg", []):
				var a := deg_to_rad(deg)
				var n := Vector2(sx * cos(a), sz * sin(a))
				spots.append([_centre + Vector2((hx - r) * sx, (hz - r) * sz) + n * r, n])
	return spots


## Where the venue's video screens hang, for the game to put the score on them: the
## centre of each, just in front of the modelled screen, turned so its +Z faces the court.
## A `cube` is the four-sided screen hung over the middle of an arena floor, and gives one
## spot per face, each looking outwards.
func screen_spots() -> Array[Dictionary]:
	var hx: float = data["inner_half"][0]
	var hz: float = data["inner_half"][1]
	var r: float = data.get("corner_radius", 0.01)
	var out: Array[Dictionary] = []
	for screen: Dictionary in data.get("screens", []):
		var size := Vector2(screen["size"][0], screen["size"][1])
		var y := float(screen["bottom"]) + size.y * 0.5
		if screen.get("cube", false):
			var middle := _centre + Vector2(float(screen["at"][0]), float(screen["at"][1]))
			for k in 4:
				var yaw := PI * 0.5 * k
				var n := Vector2(sin(yaw), cos(yaw))
				var at := middle + n * (size.x * 0.5 + 0.25 + 0.03)
				out.append({"at": Vector3(at.x, y, at.y), "turn": yaw, "size": size})
			continue
		var n := Vector2(float(screen["corner"][0]), float(screen["corner"][1])).normalized()
		var base := _centre + Vector2((hx - r) * screen["corner"][0], (hz - r) * screen["corner"][1]) + n * r
		var at := base + n * (float(screen["offset"]) - 0.45)
		out.append({"at": Vector3(at.x, y, at.y), "turn": atan2(-n.x, -n.y), "size": size})
	return out


## Where a balcony banner can hang, as [point, outward normal] at the front of `rail`'s
## offset, spread evenly round the bowl (or down its runs) — `count` of them. For
## `EventDressing`'s rail banners, which used to be placed off the old straight stands.
func rail_spots(count: int) -> Array:
	var rail: Dictionary = data.get("rail", {})
	if rail.is_empty() or count <= 0:
		return []
	var d: float = rail["offset"]
	var all: Array = []
	if rail.has("runs"):
		for run: Dictionary in rail["runs"]:
			all.append_array(_seats_along(run, d, 3.4, []))
	else:
		all = _seats_round(d, 3.4)
	var keep := []
	var step := maxf(1.0, float(all.size()) / float(count))
	var i := step * 0.5
	while int(i) < all.size() and keep.size() < count:
		keep.append(all[int(i)])
		i += step
	return keep
