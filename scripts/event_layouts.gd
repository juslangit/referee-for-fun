class_name EventLayouts
extends RefCounted

## What each sport's event looks like, rung by rung, for `EventDressing` to build.
##
## Every sport's top rung is modelled on a real Malaysian event, researched on 2026-09-15 from
## broadcast footage and press photographs (the sources are in the knowledge base, under
## 07-references). The names are invented, and so is every sponsor — the look is borrowed, the
## branding is not:
##
## - **Badminton**: the Malaysia Open at Bukit Jalil — see `badminton`.
## - **Tennis**: the ATP Malaysian Open at Putra Stadium, which was played indoors.
## - **Table tennis**: the 2016 World Team Table Tennis Championships in Kuala Lumpur.
## - **Indoor volleyball**: SUKMA and the 2017 SEA Games — a bright hall, not a dark arena.
## - **Beach volleyball**: the FIVB World Tour stop at Pantai Cenang, Langkawi.
##
## The lower rungs are the same sport's ordinary Malaysian versions: a club or school event
## with a few printed boards, one camera and a handful of people.
##
## Every coordinate is in the court's own space, and every sport puts its umpire on +x
## looking towards -x. So what stands on the -x side is what the player looks at all match,
## and it is kept below the line of sight to the court; what stands at +x is behind them and
## is for the wide shots and the cutscenes. Nothing is placed where a line judge stands or a
## player runs.

const S := Venue.Tier.SCHOOL
const R := Venue.Tier.REGIONAL
const A := Venue.Tier.ARENA

## Shirt colours for the people who work the event.
const CREW_TEAL := Color(0.10, 0.55, 0.56)
const CREW_ORANGE := Color(0.95, 0.48, 0.10)
const CREW_YELLOW := Color(0.96, 0.80, 0.16)
const OFFICIAL_NAVY := Color(0.10, 0.14, 0.32)
const OFFICIAL_BLUE := Color(0.10, 0.28, 0.70)
const PHOTO_RED := Color(0.80, 0.12, 0.12)
const TV_BLACK := Color(0.08, 0.08, 0.10)


static func for_sport(sport: StringName) -> Dictionary:
	match sport:
		Career.TENNIS:
			return tennis()
		Career.TABLE_TENNIS:
			return table_tennis()
		Career.INDOOR:
			return indoor()
		Career.BEACH:
			return beach()
		_:
			return badminton()


## Which way a thing standing at `at` has to turn to face `target`.
static func facing(at: Vector3, target := Vector3.ZERO) -> float:
	return atan2(target.x - at.x, target.z - at.z)


static func _person(role: String, at: Vector3, shirt: Color, from: int, crouch := false,
		target := Vector3.ZERO) -> Dictionary:
	return {"role": role, "at": at, "shirt": shirt, "from": from, "crouch": crouch,
		"turn": facing(at, target)}


## The Nusantara Badminton Open. Badminton already has its own `Venue` — the truss, the lamps,
## the A-frame boards, the video wall, the second court — so this adds only what that lacks:
## the broadcast, the photographers in their bibs, the flags, and the event's name round the
## hall. The boards carry the sponsors' logos; see `Venue._add_board`.
static func badminton() -> Dictionary:
	var cameras := [
		{"at": Vector3(-4.6, 0.0, 10.9), "look": Vector3(0.0, 0.5, 0.0), "from": R},
		{"at": Vector3(4.6, 0.0, -11.2), "look": Vector3(0.0, 0.5, 0.0), "from": A},
		# At the top of the near stand, looking down the court: the main broadcast angle.
		{"at": Vector3(-12.5, 0.0, 3.0), "look": Vector3(0.0, 0.5, 0.0), "from": A, "high": true,
			"platform": 2.5},
	]
	var people := [
		_person("Photographer", Vector3(-2.4, 0.0, 10.35), PHOTO_RED, R, true),
		_person("Photographer", Vector3(-3.3, 0.0, -10.35), PHOTO_RED, A, true),
		_person("Photographer", Vector3(-2.3, 0.0, -10.35), PHOTO_RED, A, true),
		_person("Photographer", Vector3(-3.4, 0.0, 10.35), PHOTO_RED, A, true),
	]
	return {
		"logo": "logo_badminton",
		"cameras": cameras,
		"people": people,
		"hangings": [
			{"at": Vector3(0.0, 5.4, 13.2), "turn": PI, "size": Vector2(10.0, 2.8),
				"backing": Color(0.03, 0.22, 0.24), "from": R},
		],
		"rail_banners": {"per_level": [0, 3, 5], "sides": [-1.0], "logo_every": 3, "above": 2.0},
		"crowd_flags": {"per_level": [2, 10, 26]},
	}


## The Kuala Lumpur Tennis Open. Outdoors at the National Tennis Centre further down the
## ladder; at the top, indoors at a stadium, with a pale grey-blue surround, "KUALA LUMPUR"
## painted behind each baseline and a royal-blue backdrop with the event's name on it.
static func tennis() -> Dictionary:
	var surround_x := TennisSpec.HALF_WIDTH_DOUBLES + TennisSpec.SIDE_ROOM
	var surround_z := TennisSpec.HALF_LENGTH + TennisSpec.RUN_BACK
	var royal := Color(0.08, 0.20, 0.58)
	var props: Array = [
		# Outdoors: the green windbreak round the courts, and grass beyond it.
		{"kind": "enclosure", "at": Vector3.ZERO, "half": Vector2(17.0, 21.5), "height": 3.2,
			"colour": Color(0.10, 0.22, 0.16), "ground": Color(0.28, 0.40, 0.24), "from": S, "until": R},
		# Indoors: the stadium's walls, and the sponsors round them.
		{"kind": "enclosure", "at": Vector3.ZERO, "half": Vector2(17.5, 21.5), "height": 9.0,
			"colour": Color(0.08, 0.09, 0.12), "ground": Color(0.10, 0.10, 0.12), "from": A,
			"band": {"height": 5.2}},
		{"kind": "floor_text", "at": Vector3(0.0, 0.0, -15.6), "text": "KUALA LUMPUR",
			"colour": Color(1, 1, 1, 0.92), "size": 0.0052, "from": A},
		{"kind": "floor_text", "at": Vector3(0.0, 0.0, 15.6), "turn": PI, "text": "KUALA LUMPUR",
			"colour": Color(1, 1, 1, 0.92), "size": 0.0052, "from": A},
	]
	# The players' seats either side of the chair, with a cooler each.
	for z: float in [-2.3, 2.3]:
		props.append({"kind": "folding_chair", "at": Vector3(8.3, 0.0, z), "turn": PI * 0.5,
			"from": S, "until": S})
		props.append({"kind": "chair", "at": Vector3(8.3, 0.0, z), "turn": -PI * 0.5,
			"colour": Color(0.20, 0.35, 0.75), "from": R})
		props.append({"kind": "cooler", "at": Vector3(8.4, 0.0, z * 1.45), "colour": royal, "from": R})
	# Towel boxes at the back of the court, the diagonal the line judges are not on.
	for corner: Vector3 in [Vector3(-7.4, 0.0, -17.2), Vector3(7.4, 0.0, 17.2)]:
		props.append({"kind": "towel_box", "at": corner, "colour": royal, "from": R})

	var hangings: Array = []
	for end: float in [-1.0, 1.0]:
		var turn := 0.0 if end < 0.0 else PI
		# The backdrop behind each baseline: green cloth at the club, the event at the top.
		hangings.append({"at": Vector3(0.0, 1.2, end * (surround_z + 0.15)), "turn": turn,
			"size": Vector2(surround_x * 2.0 - 1.0, 2.4), "backing": Color(0.10, 0.26, 0.20),
			"picture": "sponsor_rimba_sports", "fill": 0.6, "from": S, "until": S})
		hangings.append({"at": Vector3(0.0, 1.2, end * (surround_z + 0.15)), "turn": turn,
			"size": Vector2(surround_x * 2.0 - 1.0, 2.4), "backing": royal, "fill": 0.9, "from": R})
		for x: float in [-5.8, 5.8]:
			hangings.append({"at": Vector3(x, 1.2, end * (surround_z + 0.1)), "turn": turn,
				"size": Vector2(4.2, 1.5), "picture": "sponsor_" + ("kenari_telekom" if x * end > 0.0 else "cuti_cuti_nusa"),
				"from": R})

	var cameras := [
		{"at": Vector3(-6.5, 0.0, -surround_z - 1.4), "look": Vector3(0.0, 1.0, 0.0), "high": true,
			"platform": 2.8, "from": S},
		{"at": Vector3(6.5, 0.0, surround_z + 1.4), "look": Vector3(0.0, 1.0, 0.0), "high": true,
			"platform": 2.8, "from": R},
		{"at": Vector3(-8.4, 0.0, 15.6), "look": Vector3(0.0, 0.8, 0.0), "from": A},
		{"at": Vector3(8.4, 0.0, -15.6), "look": Vector3(0.0, 0.8, 0.0), "from": A},
	]

	var people: Array = []
	# Ball kids: kneeling at each end of the net, and standing at the back corners.
	for x: float in [-(TennisSpec.POST_X + 0.5), TennisSpec.POST_X + 0.5]:
		for z: float in [-0.8, 0.8]:
			people.append(_person("BallKid", Vector3(x, 0.0, z), CREW_TEAL, R if x < 0.0 else A, true,
				Vector3(0.0, 0.0, z)))
	for corner: Vector3 in [Vector3(-4.4, 0.0, -17.3), Vector3(4.4, 0.0, 17.3),
			Vector3(4.4, 0.0, -17.3), Vector3(-4.4, 0.0, 17.3)]:
		people.append(_person("BallKid", corner, CREW_TEAL, R if corner.x * corner.z < 0.0 else A,
			false, Vector3(corner.x, 0.0, 0.0)))

	return {
		"logo": "logo_tennis",
		"indoors": [false, false, true],
		"paint": {
			"surround": [null, Color(0.14, 0.30, 0.36), Color(0.46, 0.54, 0.62)],
			"court": [null, null, Color(0.16, 0.32, 0.56)],
		},
		"boards": {
			"half": Vector2(surround_x, surround_z), "out": -0.3, "length": 3.0, "gap": 3.4,
			"ends": false,
			"sponsors": ["seri_bank", "rajawali_air", "teratai_hotels", "kenari_telekom",
				"pelangi_pay", "bayu_motor", "cuti_cuti_nusa", "segar"],
			"levels": [
				{"height": 0.9, "colour": Color(0.10, 0.26, 0.20), "every": 2},
				{"height": 1.0, "colour": Color(0.10, 0.22, 0.52)},
				{"height": 1.0, "colour": royal},
			],
		},
		"screen": {"at": Vector3(0.0, 6.0, -surround_z - 1.3), "size": Vector2(8.0, 4.2),
			"legs": 3.9, "from": A},
		"hangings": hangings,
		"cameras": cameras,
		"props": props,
		"people": people,
		"rail_banners": {"per_level": [0, 4, 6], "sides": [-1.0, 1.0], "logo_every": 3, "above": 1.8},
		"crowd_flags": {"per_level": [0, 10, 28]},
	}


## The Shah Alam Table Tennis Championships, modelled on the 2016 World Team Championships in
## Kuala Lumpur. Purple floor at the top, black LED barriers with
## the sponsors glowing on them, a salmon-coloured hall with a sponsor band round it, and the
## camera up on a platform behind the end barrier.
static func table_tennis() -> Dictionary:
	var bx := TableTennisTable.BARRIER_X
	var bz := TableTennisTable.BARRIER_Z
	var props: Array = [
		{"kind": "enclosure", "at": Vector3.ZERO, "half": Vector2(9.8, 8.4), "height": 7.5,
			"colour": Color(0.30, 0.31, 0.34), "ground": Color(0.18, 0.18, 0.20), "from": S, "until": R},
		{"kind": "enclosure", "at": Vector3.ZERO, "half": Vector2(9.8, 8.4), "height": 7.5,
			"colour": Color(0.56, 0.36, 0.33), "ground": Color(0.18, 0.16, 0.20), "from": A,
			"band": {"height": 4.6}},
	]
	# Towel boxes at the ends of the playing area, and the coaches' chairs in the corners.
	for z: float in [-1.0, 1.0]:
		props.append({"kind": "towel_box", "at": Vector3(-bx + 0.35, 0.0, z * (bz - 0.35)),
			"colour": Color(0.08, 0.08, 0.10), "from": R})
		var seat := Vector3(bx - 0.4, 0.0, z * (bz - 0.45))
		props.append({"kind": "chair", "at": seat, "turn": facing(seat), "colour": Color(0.75, 0.12, 0.45),
			"from": R})
	var hangings: Array = []
	# Vertical banners down from the roof behind both stands.
	for side: float in [-1.0, 1.0]:
		for z: float in [-3.4, 3.4]:
			hangings.append({"at": Vector3(side * 9.4, 4.6, z), "turn": -side * PI * 0.5,
				"size": Vector2(1.4, 3.6), "backing": Color(0.62, 0.10, 0.42), "fill": 0.9,
				"picture": "logo_table_tennis", "from": R})
	return {
		"logo": "logo_table_tennis",
		"paint": {
			"floor": [null, Color(0.40, 0.14, 0.14), Color(0.30, 0.15, 0.38)],
			"barrier": [null, null, Color(0.02, 0.02, 0.03)],
		},
		"boards": {
			"half": Vector2(bx, bz), "out": -0.09, "length": 1.4,
			"sponsors": ["pelangi_pay", "sinar_elektrik", "kenari_telekom", "seri_bank", "segar", "teras_energy"],
			"levels": [
				{"none": true},
				{"height": 0.70, "colour": Color(0.10, 0.18, 0.34), "every": 2},
				{"height": 0.70, "led": true},
			],
		},
		"screen": {"at": Vector3(0.0, 4.8, -bz - 1.4), "size": Vector2(5.2, 2.9), "from": A,
			"colour": Color(0.14, 0.03, 0.12)},
		"hangings": hangings,
		"cameras": [
			{"at": Vector3(0.0, 0.0, bz + 1.3), "look": Vector3(0.0, 0.8, 0.0), "high": true,
				"platform": 2.4, "from": S},
			{"at": Vector3(-bx - 1.0, 0.0, -bz - 1.5), "look": Vector3(0.0, 0.8, 0.0), "high": true,
				"platform": 2.4, "from": A},
		],
		"props": props,
		"people": [
			_person("Photographer", Vector3(-2.6, 0.0, bz + 0.25), PHOTO_RED, A, true),
			_person("Photographer", Vector3(2.6, 0.0, -bz - 0.25), PHOTO_RED, A, true),
		],
		"rail_banners": {"per_level": [0, 2, 4], "sides": [-1.0, 1.0], "logo_every": 2, "above": 1.1},
		"crowd_flags": {"per_level": [0, 6, 16]},
	}


## The Gemilang Volleyball Championship: a bright sports hall, an orange court in a teal free
## zone, blue posts, the scorer's table and the team benches on the side opposite the first
## referee, state-style bunting round the balcony, and the wau kite on the end wall.
static func indoor() -> Dictionary:
	var fx := VolleySpec.HALF_WIDTH + VolleySpec.FREE_ZONE
	var fz := VolleySpec.HALF_LENGTH + VolleySpec.FREE_ZONE
	var hall_z := VolleySpec.HALF_LENGTH + VolleyCourt.FLOOR_MARGIN
	var props: Array = [
		{"kind": "table", "at": Vector3(-fx + 1.1, 0.0, 0.0), "turn": PI * 0.5, "length": 2.4,
			"colour": Color(0.08, 0.30, 0.52), "picture": "logo_indoor", "from": R},
		{"kind": "monitor", "at": Vector3(-fx + 1.1, 0.77, 0.5), "turn": PI * 0.5, "from": A},
	]
	# The benches down the scorer's side, clear of the toss in front of the table
	# (VolleyCutscene.TOSS_ALONG) so it is not filmed through one.
	for z: float in [-7.0, 7.0]:
		props.append({"kind": "bench", "at": Vector3(-fx + 0.6, 0.0, z), "turn": PI * 0.5, "length": 3.2,
			"colour": Color(0.12, 0.25, 0.60) if z < 0.0 else Color(0.70, 0.16, 0.14), "from": S})
	for chair_z: float in [-0.7, 0.7]:
		var seat := Vector3(-fx + 0.35, 0.0, chair_z)
		# The folding chair's seat faces its own -Z, so facing +x is a quarter turn clockwise.
		props.append({"kind": "folding_chair", "at": seat, "turn": -PI * 0.5, "from": R})
	var hangings := [
		{"at": Vector3(0.0, 6.4, hall_z - 0.25), "turn": PI, "size": Vector2(9.0, 3.6),
			"backing": Color(0.96, 0.95, 0.92), "from": R},
		{"at": Vector3(0.0, 5.6, hall_z - 0.25), "turn": PI, "size": Vector2(6.0, 1.6),
			"picture": "banner_selamat_datang", "fill": 1.0, "from": S, "until": S},
	]
	var people := []
	for corner: Vector3 in [Vector3(fx - 0.4, 0.0, fz - 0.4), Vector3(-fx + 0.4, 0.0, -fz + 0.4),
			Vector3(fx - 0.4, 0.0, -fz + 0.4), Vector3(-fx + 0.4, 0.0, fz - 0.4)]:
		people.append(_person("BallRetriever", corner, CREW_YELLOW, R))
	people.append(_person("Scorer", Vector3(-fx + 0.35, 0.0, 0.0), OFFICIAL_NAVY, R, false,
		Vector3(0.0, 0.0, 0.0)))
	# The quick moppers, crouched at the corners of the court ready to wipe.
	for z: float in [-VolleySpec.HALF_LENGTH - 1.0, VolleySpec.HALF_LENGTH + 1.0]:
		people.append(_person("Mopper", Vector3(-fx + 0.6, 0.0, z), Color(0.9, 0.9, 0.92), A, true))
	return {
		"logo": "logo_indoor",
		"paint": {
			"free_zone": [null, Color(0.14, 0.44, 0.50), Color(0.10, 0.42, 0.56)],
			"posts": [null, Color(0.14, 0.30, 0.66), Color(0.12, 0.26, 0.72)],
			"hall": [Color(0.74, 0.71, 0.62), Color(0.52, 0.55, 0.60), Color(0.30, 0.33, 0.40)],
		},
		"boards": {
			"half": Vector2(fx, fz), "out": 0.3, "length": 3.0, "gap": 2.2,
			"sponsors": ["teras_energy", "bayu_motor", "kopi_kampung", "rimba_sports", "segar",
				"seri_bank", "sinar_elektrik"],
			"levels": [
				{"height": 0.9, "colour": Color(0.12, 0.24, 0.55), "every": 3},
				{"height": 0.9, "colour": Color(0.06, 0.20, 0.42)},
				{"height": 0.9, "led": true},
			],
		},
		"screen": {"at": Vector3(0.0, 6.6, -hall_z + 0.35), "size": Vector2(8.0, 4.4), "from": A},
		"hangings": hangings,
		"cameras": [
			{"at": Vector3(-7.4, 0.0, fz + 1.0), "look": Vector3(0.0, 1.0, 0.0), "from": S},
			{"at": Vector3(fx + 0.2, 0.0, -fz - 1.0), "look": Vector3(0.0, 1.0, 0.0), "high": true,
				"platform": 2.2, "from": R},
			{"at": Vector3(-fx - 0.2, 0.0, -fz - 1.0), "look": Vector3(0.0, 1.0, 0.0), "high": true,
				"platform": 2.2, "from": A},
		],
		"props": props,
		"people": people,
		"rail_banners": {"per_level": [2, 5, 7], "sides": [-1.0, 1.0], "logo_every": 3, "above": 2.0},
		"crowd_flags": {"per_level": [0, 12, 30]},
	}


## The Pantai Cenang Beach Volleyball Open: the sea and the islands off Langkawi behind the
## stands, white vinyl sponsor banners on metal crowd barriers, yellow posts, team chairs under
## umbrellas beside the scorer's table, feather flags, an inflatable arch, and the crew in orange.
static func beach() -> Dictionary:
	var sx := BeachSpec.HALF_WIDTH + BeachCourt.SAND_MARGIN
	var sz := BeachSpec.HALF_LENGTH + BeachCourt.SAND_MARGIN
	var fx := BeachSpec.HALF_WIDTH + BeachSpec.FREE_ZONE
	var props: Array = [
		{"kind": "ground", "at": Vector3(0.0, 0.0, 0.0), "size": Vector2(160.0, 400.0),
			"colour": Color(0.90, 0.82, 0.64), "from": S},
		{"kind": "sea", "at": Vector3(-2080.0, 0.0, 0.0), "width": 4000.0, "depth": 6000.0, "from": S,
			"islands": [
				{"at": Vector3(1880.0, -4.0, -120.0), "radius": 60.0, "flat": 0.55},
				{"at": Vector3(1780.0, -6.0, 150.0), "radius": 90.0, "flat": 0.5},
				{"at": Vector3(1600.0, -10.0, -10.0), "radius": 140.0, "flat": 0.45},
			]},
		{"kind": "table", "at": Vector3(-fx + 1.6, 0.0, 0.0), "turn": PI * 0.5, "length": 1.8,
			"colour": Color(0.06, 0.30, 0.62), "picture": "logo_beach", "from": R},
		{"kind": "arch", "at": Vector3(0.0, 0.0, sz + 5.0), "turn": PI, "width": 9.0,
			"colour": Color(0.08, 0.36, 0.78), "from": A},
	]
	# The teams' chairs and umbrellas either side of the scorer's table, with a cooler each —
	# far enough along that the coin toss in front of the table (BeachCutscene.TOSS_ALONG) is
	# not filmed through an umbrella.
	for z: float in [-4.8, 4.8]:
		for dz: float in [-0.45, 0.45]:
			props.append({"kind": "chair", "at": Vector3(-fx + 1.2, 0.0, z + dz), "turn": PI * 0.5,
				"colour": Color(0.95, 0.95, 0.95), "from": S})
		props.append({"kind": "umbrella", "at": Vector3(-fx + 1.4, 0.0, z), "height": 2.4, "from": R})
		props.append({"kind": "cooler", "at": Vector3(-fx + 1.1, 0.0, z + signf(z) * 1.1),
			"colour": Color(0.10, 0.40, 0.80), "from": S})
	# Feather flags at both ends of the sand.
	for end: float in [-1.0, 1.0]:
		for x: float in [-8.5, -5.0, 5.0, 8.5]:
			props.append({"kind": "feather_flag", "at": Vector3(x, 0.0, end * (sz + 1.4)),
				"turn": 0.0 if end < 0.0 else PI, "height": 3.4,
				"colour": Color(0.10, 0.62, 0.70) if int(x) % 2 == 0 else Color(0.96, 0.78, 0.12),
				"from": R if absf(x) > 6.0 else A})
	# Palms behind the stand at the umpire's back, where the beach goes inland.
	for i in 6:
		props.append({"kind": "palm", "at": Vector3(18.0 + float(i % 2) * 4.0, 0.0, -14.0 + float(i) * 5.6),
			"height": 7.0 + float(i % 3), "lean": 0.08 + 0.05 * float(i % 3), "turn": float(i) * 1.3,
			"from": S})

	var people := [
		_person("Scorer", Vector3(-fx + 1.0, 0.0, 0.0), OFFICIAL_BLUE, R),
	]
	for corner: Vector3 in [Vector3(-fx + 0.6, 0.0, sz - 1.6), Vector3(fx - 0.6, 0.0, -sz + 1.6),
			Vector3(fx - 0.6, 0.0, sz - 1.6), Vector3(-fx + 0.6, 0.0, -sz + 1.6)]:
		people.append(_person("BallCrew", corner, CREW_ORANGE, R))
	for z: float in [-6.0, 6.0]:
		people.append(_person("Raker", Vector3(-fx + 0.3, 0.0, z + 1.8 * signf(z)), CREW_ORANGE, A, true))

	return {
		"logo": "logo_beach",
		"paint": {
			"posts": [null, Color(0.96, 0.78, 0.12), Color(0.96, 0.78, 0.12)],
			"tape": [null, null, Color(0.96, 0.78, 0.12)],
		},
		"boards": {
			"half": Vector2(sx - 0.9, sz - 0.3), "out": 0.0, "length": 2.4, "gap": 2.6,
			"sponsors": ["cuti_cuti_nusa", "segar", "rajawali_air", "teratai_hotels", "kopi_kampung",
				"pelangi_pay"],
			"levels": [
				{"height": 0.8, "colour": Color(0.06, 0.06, 0.07), "every": 3},
				{"style": "barrier", "every": 2},
				{"style": "barrier"},
			],
		},
		"screen": {"at": Vector3(0.0, 5.4, -sz - 3.0), "size": Vector2(7.0, 4.0), "legs": 3.4, "from": A},
		"cameras": [
			{"at": Vector3(2.4, 0.0, sz + 1.2), "look": Vector3(0.0, 1.0, 0.0), "high": true,
				"platform": 3.2, "from": R},
			{"at": Vector3(-2.4, 0.0, -sz - 1.2), "look": Vector3(0.0, 1.0, 0.0), "high": true,
				"platform": 3.2, "from": A},
			{"at": Vector3(fx + 0.3, 0.0, sz - 2.6), "look": Vector3(0.0, 1.0, 0.0), "from": A},
		],
		"props": props,
		"people": people,
		"rail_banners": {"per_level": [0, 3, 5], "sides": [-1.0, 1.0], "logo_every": 3, "above": 1.8},
		"crowd_flags": {"per_level": [0, 8, 24]},
	}
