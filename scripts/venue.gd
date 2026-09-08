class_name Venue
extends Node3D

## Everything in the hall that is not the court, the people or the shuttle: the roof
## truss and the lamps hanging off it, the sponsor boards round the perimeter, the
## scoreboard, the bags and bottles at the ends, and the photographers' flashes.
##
## It exists because climbing the career ladder was invisible. The five venues differed
## only in numbers — crowd size, scrutiny, whether there was a camera — and every one of
## them looked like the same grey box. Three tiers of dressing means the player can see
## where they have got to without being told.
##
## Nothing in here touches the court geometry. The lines, the net and the posts stay
## exactly where CourtSpec puts them, because those are the numbers the game is
## judging and a downloaded model is not allowed near them.

enum Tier { SCHOOL, REGIONAL, ARENA }

## What each rung of the ladder looks like.
##
## `court_light` is the one that does most of the work. A school hall is lit flatly all
## over, like a room with the strip lights on. An arena is a dark bowl with the court
## burning in the middle of it, which is the whole visual language of televised sport.
##
## The bottom rung used to have almost nothing on it — no seats, no truss, no lamps, six
## boards. That was a mistake, and an invisible one to me: I was checking the arena while
## the game actually starts you in the school hall, so the venue I had been admiring in
## screenshots was one no new player would see for five matches. Every venue now gets the
## whole physical set. What a promotion buys you is the red carpet, the video wall, the
## hanging scoreboard and a hall full of people.
##
## Every venue is now lit the same way too: a dark hall with the court burning in the
## middle of it, and the stands falling away into shadow. Luqman asked for it at all five
## rather than as a reward for climbing, and for the full television contrast rather than
## a compromise that keeps the crowd readable. So the crowd is no longer readable in the
## way it was, and that is a real cost — the people in the stands are the only thing that
## tells the player how much trouble they are in. What is left of that signal is
## movement: the stands come up out of their seats on a point, and at the bigger venues
## the photographers' flashes go off, and both of those read perfectly well in the dark.
const TIERS := {
	Tier.SCHOOL: {
		"seats": true,
		"truss": true,
		"lamps": 8,
		"banners": 12,
		"scoreboard": false,
		"ambient": 0.20,
		"ambient_tint": Color(0.46, 0.48, 0.52),
		"court_light": 5.2,
		"flashes": 2,
		"kit": 2,
		# No drapes in a school hall. It has painted block walls and everybody can see
		# they are painted block walls, which is exactly what the reference photograph
		# of a club match shows.
		"curtain": false,
		"video_wall": false,
	},
	Tier.REGIONAL: {
		"seats": true,
		"truss": true,
		"lamps": 10,
		"banners": 16,
		"scoreboard": false,
		"ambient": 0.16,
		"ambient_tint": Color(0.40, 0.44, 0.54),
		"court_light": 6.2,
		"flashes": 6,
		"kit": 2,
		"curtain": true,
		"video_wall": false,
	},
	Tier.ARENA: {
		"seats": true,
		"truss": true,
		"lamps": 14,
		"banners": 20,
		"scoreboard": true,
		"ambient": 0.12,
		"ambient_tint": Color(0.30, 0.34, 0.46),
		"court_light": 7.0,
		"flashes": 14,
		"kit": 3,
		"curtain": true,
		"video_wall": true,
	},
}

## Where the neighbouring court is. Behind the chair, not in front of it: the umpire
## faces -X and the people over there are the only thing that ever tells the player how
## much trouble they are in. Buying some depth by putting a court between the chair and
## the crowd would have cost the game its one feedback channel.
const SECOND_COURT_X := 13.4

## How high the truss hangs, and how far apart the two runs of it are.
const TRUSS_HEIGHT := 8.1
const TRUSS_SPREAD := 4.4
const TRUSS_LENGTH := 11.0

## How big one board is: knee height, and a wedge wider at the floor than it is tall.
const BOARD_HEIGHT := 0.52
const BOARD_BASE := 0.62

## The sponsor boards. Invented names — a real one on a hoarding is somebody's
## trademark, and this is not the place to borrow one.
const BOARD_NAMES := [
	"KESTREL", "NORTHGATE", "AXIS SPORT", "MERIDIAN", "HALCYON",
	"BLUEPORT", "STRATA", "OAKLINE", "VERTEX", "CLEARWATER",
	"IRONWOOD", "SUMMIT",
]
const BOARD_COLOURS := [
	Color(0.10, 0.22, 0.46), Color(0.55, 0.11, 0.13), Color(0.10, 0.32, 0.24),
	Color(0.42, 0.28, 0.06), Color(0.20, 0.20, 0.24),
]

## How long a photographer's flash lasts, and how bright.
const FLASH_SECONDS := 0.10
const FLASH_ENERGY := 5.0

var tier := Tier.REGIONAL

var _lights: Node3D
var _flashes: Array[OmniLight3D] = []
var _flash_left: PackedFloat32Array = PackedFloat32Array()
var _scoreboard: Label3D
var _video_score: Label3D
var _corner_labels: Array[Label3D] = []
var _environment: WorldEnvironment
var _sun: DirectionalLight3D


## Builds the hall for one rung of the ladder. Safe to call again — everything it made
## last time is thrown away first, because a career moves between venues.
func dress(which: Tier) -> void:
	tier = which
	for child in get_children():
		# Detached before being freed, not just queued. queue_free happens at the end of
		# the frame, so the old lights and the new ones would both be in the world at
		# once — and two WorldEnvironments in one scene is a coin toss over which one
		# the renderer uses.
		remove_child(child)
		child.queue_free()
	_flashes.clear()
	_flash_left = PackedFloat32Array()

	var spec: Dictionary = TIERS[tier]
	_build_lighting(spec)
	if spec["truss"]:
		_build_truss()
	_build_lamps(spec)
	_build_banners(spec)
	_build_second_court(spec)
	_build_corner_boards()
	_build_officials()
	if spec["curtain"]:
		_build_curtain()
	if spec["video_wall"]:
		_build_video_wall()
	if spec["scoreboard"]:
		_build_scoreboard()
	_build_kit(spec)
	_build_flashes(spec)
	set_score(0, 0)


# --- light ----------------------------------------------------------------------

## The hall light and the light on the court, which are two different things.
##
## The court lamps are real spotlights aimed down at the middle. That matters for more
## than looks: a lit court inside a dark bowl is what makes the players read as the
## thing being watched, and it is the cheapest way to make a school hall and a final
## feel like different places.
func _build_lighting(spec: Dictionary) -> void:
	_environment = WorldEnvironment.new()
	_environment.name = "Air"
	var air := Environment.new()
	air.background_mode = Environment.BG_COLOR
	air.background_color = spec["ambient_tint"] * 0.35
	air.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	air.ambient_light_color = spec["ambient_tint"]
	air.ambient_light_energy = spec["ambient"]
	air.fog_enabled = true
	# Enough haze for the beams to have something to land on, and no more. A hall you
	# cannot see the far line through is a hall you cannot referee in.
	air.fog_light_color = Color(0.42, 0.48, 0.62)
	air.fog_density = 0.005
	air.fog_sky_affect = 0.0

	# The beams themselves. Without this the lamps light the floor and the air between
	# them and the floor stays empty, which is the one thing that says "the hall is dark
	# and the court is lit" rather than "somebody turned the brightness down".
	air.volumetric_fog_enabled = true
	air.volumetric_fog_density = 0.013
	air.volumetric_fog_albedo = Color(0.72, 0.78, 0.92)
	air.volumetric_fog_length = 42.0
	_environment.environment = air
	add_child(_environment)

	_sun = DirectionalLight3D.new()
	_sun.name = "HallLight"
	_sun.rotation = Vector3(deg_to_rad(-58.0), deg_to_rad(34.0), 0.0)
	# Barely there. It exists to put one clean shadow direction under the net and the
	# posts so they sit on the floor rather than floating over it; the light the player
	# actually reads by comes from the lamps on the truss.
	_sun.light_energy = 0.22 if tier == Tier.SCHOOL else 0.14
	_sun.shadow_enabled = true
	add_child(_sun)


# --- the roof -------------------------------------------------------------------

func _build_truss() -> void:
	var runs := Node3D.new()
	runs.name = "Truss"
	add_child(runs)

	for side in [1.0, -1.0]:
		for section in [-1.0, 0.0, 1.0]:
			var piece := Props.node(Props.TRUSS, 0.80)
			if piece == null:
				return
			piece.position = Vector3(side * TRUSS_SPREAD, TRUSS_HEIGHT, section * TRUSS_LENGTH)
			# The truss model runs along its own X, and the hall is long along Z.
			piece.rotation.y = PI * 0.5
			runs.add_child(piece)


## Lamps hanging under the truss, each with a real spotlight in it aimed at the middle
## of the court. Fittings without light in them are stage dressing; these are what is
## actually lighting the rally.
func _build_lamps(spec: Dictionary) -> void:
	var count: int = spec["lamps"]
	if count <= 0:
		return

	_lights = Node3D.new()
	_lights.name = "Lamps"
	add_child(_lights)

	var energy: float = spec["court_light"]
	for i in count:
		var side := 1.0 if i % 2 == 0 else -1.0
		var along := (float(i / 2) / maxf(1.0, float(count / 2 - 1)) - 0.5) * 2.0
		var where := Vector3(side * TRUSS_SPREAD, TRUSS_HEIGHT - 0.45, along * 9.0)

		var fitting := Props.node(Props.LAMP, 0.55)
		if fitting != null:
			fitting.position = where
			_lights.add_child(fitting)

		var beam := SpotLight3D.new()
		beam.name = "Beam"
		beam.position = where
		beam.look_at_from_position(where, Vector3(0.0, 0.0, along * 3.0), Vector3.UP)
		beam.light_energy = energy
		beam.light_color = Color(1.0, 0.98, 0.94)
		beam.spot_range = 18.0
		beam.spot_angle = 34.0
		beam.spot_angle_attenuation = 0.8
		# Only one or two of them cast shadows. Twelve shadow-casting spotlights on a
		# hall full of people costs more than the rest of the game together, and the
		# court already has the sun's shadow on it.
		beam.shadow_enabled = i < 2
		_lights.add_child(beam)


# --- the perimeter --------------------------------------------------------------

## Sponsor boards, standing in a ring at the edge of the run-off.
##
## They are low wedges, not the tall flat panels that were here before. Every reference
## photograph of a real match shows the same object: a knee-high A-frame, a tent of two
## sloping faces, standing right at the edge of the apron and running the whole way
## round the court including behind both baselines. Getting the shape right matters more
## than the names on them — a waist-high vertical hoarding reads as a fence, and a court
## with a fence round it does not look like badminton.
func _build_banners(spec: Dictionary) -> void:
	var count: int = spec["banners"]
	if count <= 0:
		return

	var boards := Node3D.new()
	boards.name = "Boards"
	add_child(boards)

	var ring := _board_ring()
	# Spread whatever the venue can afford evenly round the ring rather than filling one
	# side and leaving the other bare.
	var step := float(ring.size()) / float(count)
	for i in count:
		var slot: Dictionary = ring[int(floor(float(i) * step)) % ring.size()]
		_add_board(boards, i, slot["where"], slot["turn"], slot["length"])


## Every place a board can stand: down both sidelines and across both ends, just
## outside the apron.
func _board_ring() -> Array:
	var ring: Array = []
	var out_x := Court.run_off_x() + 0.34
	var out_z := Court.run_off_z() + 0.34

	var along := 3.05
	var down_side := int(ceil(Court.run_off_z() * 2.0 / along))
	for side in [-1.0, 1.0]:
		for i in down_side:
			var z := (float(i) - float(down_side - 1) * 0.5) * along
			ring.append({
				# The wedge is built with its length down Z and its printed face looking
				# along its own -X, so a board on the +X side of the court already faces
				# the right way and only the far side needs turning.
				"where": Vector3(side * out_x, 0.0, z),
				"turn": 0.0 if side > 0.0 else PI,
				"length": along - 0.12,
			})

	# The ends are covered short of the corners. A board run that reaches the full width
	# meets the side run at right angles and the two grow through each other, which is
	# also why a real venue leaves a gap there to walk through.
	var across := 2.85
	var span := Court.run_off_x() * 2.0 - 1.9
	var down_end := int(ceil(span / across))
	for end in [-1.0, 1.0]:
		for i in down_end:
			var x := (float(i) - float(down_end - 1) * 0.5) * (span / float(down_end))
			ring.append({
				# A quarter turn lays the length along X and swings the printed face to
				# look up or down the court instead of across it.
				"where": Vector3(x, 0.0, end * out_z),
				"turn": -PI * 0.5 * end,
				"length": across - 0.12,
			})
	return ring


## One wedge, with a name printed down its court-facing slope.
func _add_board(parent: Node3D, index: int, where: Vector3, turn: float, length: float) -> void:
	var board := MeshInstance3D.new()
	board.name = "Board"
	board.mesh = _wedge_mesh(length, BOARD_BASE, BOARD_HEIGHT)
	board.position = where
	board.rotation.y = turn
	var paint := StandardMaterial3D.new()
	paint.albedo_color = BOARD_COLOURS[index % BOARD_COLOURS.size()]
	paint.roughness = 0.55
	board.material_override = paint
	parent.add_child(board)

	# The name is a Label3D rather than a painted texture, because a texture with words
	# in it has to be drawn, saved, imported and kept in step with the language the game
	# is written in. A label is text, and text can simply be read.
	var writing := Label3D.new()
	writing.text = BOARD_NAMES[index % BOARD_NAMES.size()]
	writing.font_size = 110
	writing.pixel_size = 0.0026
	writing.outline_size = 0
	writing.modulate = Color(0.97, 0.97, 0.94)
	writing.double_sided = false
	# Laid on the sloping face and lifted a hair clear of it so the two do not fight.
	#
	# Two rotations, and both are needed. The quarter turn swings the text off the end of
	# the wedge and onto its side, and the lean lays it down the slope. Without the first
	# one the name is printed on the triangular end cap, which is eleven centimetres wide.
	var lean := atan2(BOARD_BASE * 0.5, BOARD_HEIGHT)
	var face := Node3D.new()
	face.position = where
	face.rotation.y = turn
	parent.add_child(face)
	writing.position = Vector3(-BOARD_BASE * 0.27, BOARD_HEIGHT * 0.52, 0.0)
	writing.rotation = Vector3(-lean, -PI * 0.5, 0.0)
	face.add_child(writing)


## A tent of two sloping faces: the shape every advertising board at a real match is.
##
## Built by hand rather than from a BoxMesh because a box has to be leaned over to look
## like this, and a leaned box has a visible bottom edge lifted off the floor.
func _wedge_mesh(length: float, base: float, height: float) -> ArrayMesh:
	var half := length * 0.5
	var out := base * 0.5

	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Cross-section: floor from -out to +out, apex above the middle. Extruded along Z.
	var a := Vector3(-out, 0.0, 0.0)
	var b := Vector3(out, 0.0, 0.0)
	var c := Vector3(0.0, height, 0.0)
	var front := [a, c]
	var back := [c, b]
	var floorline := [b, a]

	for pair in [front, back, floorline]:
		var p0: Vector3 = pair[0]
		var p1: Vector3 = pair[1]
		_quad(tool,
			p0 + Vector3(0.0, 0.0, -half), p1 + Vector3(0.0, 0.0, -half),
			p1 + Vector3(0.0, 0.0, half), p0 + Vector3(0.0, 0.0, half))

	# The two triangular ends.
	for z: float in [-half, half]:
		var flip: bool = z > 0.0
		var t0 := a + Vector3(0.0, 0.0, z)
		var t1 := b + Vector3(0.0, 0.0, z)
		var t2 := c + Vector3(0.0, 0.0, z)
		if flip:
			tool.add_vertex(t0); tool.add_vertex(t1); tool.add_vertex(t2)
		else:
			tool.add_vertex(t2); tool.add_vertex(t1); tool.add_vertex(t0)

	tool.generate_normals()
	return tool.commit()


func _quad(tool: SurfaceTool, p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3) -> void:
	tool.add_vertex(p0); tool.add_vertex(p1); tool.add_vertex(p2)
	tool.add_vertex(p0); tool.add_vertex(p2); tool.add_vertex(p3)


# --- the court next door -------------------------------------------------------

## The neighbouring court, dressed and empty.
##
## Every photograph of a real tournament has one, and it is what makes a hall read as a
## venue rather than as a room with a court in it. Nobody plays on it: a second rally
## moving in the corner of your eye while you are trying to judge a line is not
## atmosphere, it is a distraction from the one job the game asks of you.
##
## The lines are the real BWF set from CourtSpec rather than an approximation. It would
## be decoration nobody measures, but drawing a badminton court wrong in a game about
## judging badminton courts is not a corner worth cutting.
func _build_second_court(spec: Dictionary) -> void:
	var next_door := Node3D.new()
	next_door.name = "SecondCourt"
	next_door.position = Vector3(SECOND_COURT_X, 0.0, 0.0)
	add_child(next_door)

	var apron := Color(0.62, 0.09, 0.11) if tier == Tier.ARENA else Color(0.09, 0.27, 0.21)
	_slab(next_door, "RunOff", Vector3(Court.run_off_x() * 2.0, 0.01, Court.run_off_z() * 2.0),
		Vector3(0.0, 0.005, 0.0), apron)
	_slab(next_door, "Mat", Vector3(
			CourtSpec.HALF_WIDTH_DOUBLES * 2.0 + Court.MAT_MARGIN * 2.0, 0.01,
			CourtSpec.HALF_LENGTH * 2.0 + Court.MAT_MARGIN * 2.0),
		Vector3(0.0, 0.015, 0.0), Color(0.10, 0.30, 0.24))

	var chalk := Color(0.95, 0.95, 0.92)
	var wide := CourtSpec.HALF_WIDTH_DOUBLES
	var thin := CourtSpec.HALF_WIDTH_SINGLES
	var back := CourtSpec.HALF_LENGTH
	var w := 0.04
	for x: float in [-wide, wide, -thin, thin]:
		_slab(next_door, "Line", Vector3(w, 0.004, back * 2.0), Vector3(x, 0.024, 0.0), chalk)
	for z: float in [-back, back, -CourtSpec.SHORT_SERVICE_LINE, CourtSpec.SHORT_SERVICE_LINE,
			-CourtSpec.LONG_SERVICE_LINE_DOUBLES, CourtSpec.LONG_SERVICE_LINE_DOUBLES]:
		_slab(next_door, "Line", Vector3(wide * 2.0, 0.004, w), Vector3(0.0, 0.024, z), chalk)
	for side: float in [-1.0, 1.0]:
		var from := CourtSpec.SHORT_SERVICE_LINE
		_slab(next_door, "Centre", Vector3(w, 0.004, back - from),
			Vector3(0.0, 0.024, side * (back + from) * 0.5), chalk)

	# Posts and a net, so it reads as a court rather than as a painted rectangle.
	for side: float in [-1.0, 1.0]:
		_slab(next_door, "Post", Vector3(0.08, 1.55, 0.08),
			Vector3(side * wide, 0.775, 0.0), Color(0.15, 0.15, 0.17))
	var mesh := _slab(next_door, "Net", Vector3(wide * 2.0, 0.76, 0.02),
		Vector3(0.0, 1.15, 0.0), Color(0.08, 0.08, 0.09))
	var netting: StandardMaterial3D = mesh.material_override
	netting.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	netting.albedo_color.a = 0.5
	netting.cull_mode = BaseMaterial3D.CULL_DISABLED
	_slab(next_door, "NetTape", Vector3(wide * 2.0, 0.07, 0.024),
		Vector3(0.0, 1.5, 0.0), Color(0.96, 0.96, 0.94))

	# Its own ring of boards, thinned right down — it is scenery, not a second venue.
	var boards: int = maxi(4, int(spec["banners"]) / 2)
	var ring := _board_ring()
	var step := float(ring.size()) / float(boards)
	for i in boards:
		var slot: Dictionary = ring[int(floor(float(i) * step)) % ring.size()]
		_add_board(next_door, i + 3, slot["where"], slot["turn"], slot["length"])


func _slab(parent: Node3D, slab_name: String, size: Vector3, where: Vector3,
		colour: Color) -> MeshInstance3D:
	var piece := MeshInstance3D.new()
	piece.name = slab_name
	var box := BoxMesh.new()
	box.size = size
	piece.mesh = box
	piece.position = where
	var paint := StandardMaterial3D.new()
	paint.albedo_color = colour
	paint.roughness = 0.85
	piece.material_override = paint
	parent.add_child(piece)
	return piece


# --- the things round the edge of the court -------------------------------------

## The little score displays that stand at the corners of a real court, at floor level
## just outside the boards. They say the same thing as everything else that shows the
## score, which is the point: the umpire's decision is repeated back at them from every
## direction in the hall.
func _build_corner_boards() -> void:
	var corners := Node3D.new()
	corners.name = "CornerBoards"
	add_child(corners)

	_corner_labels.clear()
	for z: float in [-1.0, 1.0]:
		var stand := Node3D.new()
		stand.position = Vector3(-Court.run_off_x() - 0.30, 0.0, z * (Court.run_off_z() - 2.2))
		stand.rotation.y = PI * 0.5
		corners.add_child(stand)

		_slab(stand, "Case", Vector3(0.86, 0.62, 0.14), Vector3(0.0, 0.31, 0.0),
			Color(0.05, 0.06, 0.08))
		var readout := Label3D.new()
		readout.font_size = 90
		readout.pixel_size = 0.0032
		readout.outline_size = 0
		readout.modulate = Color(1.0, 0.74, 0.20)
		readout.position = Vector3(0.0, 0.34, -0.08)
		readout.rotation.y = PI
		stand.add_child(readout)
		_corner_labels.append(readout)


## The table the match referee and the service judge sit at, behind the baseline boards
## with a row of chairs along it. Present in every reference photograph, and the only
## other officials in the building.
func _build_officials() -> void:
	var desk := Node3D.new()
	desk.name = "Officials"
	desk.position = Vector3(0.0, 0.0, -Court.run_off_z() - 1.35)
	add_child(desk)

	_slab(desk, "Table", Vector3(2.60, 0.06, 0.72), Vector3(0.0, 0.74, 0.0),
		Color(0.16, 0.17, 0.20))
	_slab(desk, "Skirt", Vector3(2.60, 0.72, 0.04), Vector3(0.0, 0.37, -0.34),
		Color(0.90, 0.90, 0.88))
	for x: float in [-1.24, 1.24]:
		_slab(desk, "Leg", Vector3(0.06, 0.74, 0.66), Vector3(x, 0.37, 0.0),
			Color(0.13, 0.14, 0.16))

	for x: float in [-0.85, 0.0, 0.85]:
		var chair := Props.node(Props.FOLDING_CHAIR, 0.88)
		if chair == null:
			break
		chair.position = Vector3(x, 0.0, -0.62)
		chair.rotation.y = PI
		desk.add_child(chair)


## Black drapes down the long walls. They cost nothing and they hide the plain painted
## box the hall is really made of, which is what the curtain does at a real venue too.
func _build_curtain() -> void:
	var drapes := Node3D.new()
	drapes.name = "Curtain"
	add_child(drapes)

	# Tall enough to reach most of the way up the wall. At half the wall's height it
	# read as a black slab hanging in mid air rather than as a curtain on a wall.
	var height := 7.6
	for z: float in [-1.0, 1.0]:
		_slab(drapes, "Drape",
			Vector3(Court.HALL_MAX_X - Court.HALL_MIN_X - 1.0, height, 0.12),
			Vector3((Court.HALL_MAX_X + Court.HALL_MIN_X) * 0.5, height * 0.5,
				z * (Court.HALL_LENGTH * 0.5 - 0.35)),
			Color(0.045, 0.050, 0.060))


## The big screen at the end of the hall. It carries the score, so the scoreline is
## being shouted back at the umpire from the wall as well as from over their head.
func _build_video_wall() -> void:
	var wall := Node3D.new()
	wall.name = "VideoWall"
	wall.position = Vector3(0.0, 0.0, -Court.HALL_LENGTH * 0.5 + 0.9)
	add_child(wall)

	_slab(wall, "Frame", Vector3(9.6, 4.0, 0.25), Vector3(0.0, 4.6, 0.0),
		Color(0.03, 0.035, 0.045))
	var screen := _slab(wall, "Screen", Vector3(9.0, 3.4, 0.06), Vector3(0.0, 4.6, 0.16),
		Color(0.06, 0.10, 0.16))
	var glow: StandardMaterial3D = screen.material_override
	glow.emission_enabled = true
	glow.emission = Color(0.10, 0.22, 0.42)
	glow.emission_energy_multiplier = 1.4

	_video_score = Label3D.new()
	_video_score.font_size = 200
	_video_score.pixel_size = 0.0090
	_video_score.outline_size = 0
	_video_score.modulate = Color(1.0, 0.80, 0.26)
	_video_score.position = Vector3(0.0, 4.9, 0.22)
	wall.add_child(_video_score)

	var caption := Label3D.new()
	caption.text = "MEN'S DOUBLES"
	caption.font_size = 100
	caption.pixel_size = 0.0060
	caption.outline_size = 0
	caption.modulate = Color(0.70, 0.80, 0.95)
	caption.position = Vector3(0.0, 3.5, 0.22)
	wall.add_child(caption)


## A board hanging over the middle of the court with the score on it. It is wired to
## the real score, so it is one more thing in the hall that says out loud what the
## umpire has just decided.
func _build_scoreboard() -> void:
	var hanging := Node3D.new()
	hanging.name = "Scoreboard"
	hanging.position = Vector3(0.0, 6.4, 0.0)
	add_child(hanging)

	for turn in [0.0, PI * 0.5, PI, PI * 1.5]:
		var face := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(2.6, 1.5, 0.08)
		face.mesh = box
		face.position = Vector3(sin(turn) * 1.3, 0.0, cos(turn) * 1.3)
		face.rotation.y = turn
		var paint := StandardMaterial3D.new()
		paint.albedo_color = Color(0.06, 0.07, 0.09)
		paint.roughness = 0.5
		face.material_override = paint
		hanging.add_child(face)

	_scoreboard = Label3D.new()
	_scoreboard.name = "Score"
	_scoreboard.text = "0  -  0"
	_scoreboard.font_size = 150
	_scoreboard.pixel_size = 0.0060
	_scoreboard.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_scoreboard.modulate = Color(1.0, 0.72, 0.20)
	_scoreboard.outline_size = 0
	_scoreboard.no_depth_test = true
	hanging.add_child(_scoreboard)


## Puts the score on the hanging board. Called by the match, so the hall and the HUD
## never disagree about what it is.
func set_score(red: int, blue: int) -> void:
	if _scoreboard != null and is_instance_valid(_scoreboard):
		_scoreboard.text = "%d  -  %d" % [red, blue]
	if _video_score != null and is_instance_valid(_video_score):
		_video_score.text = "%d   -   %d" % [red, blue]
	for readout in _corner_labels:
		if is_instance_valid(readout):
			readout.text = "%d : %d" % [red, blue]


# --- what a match leaves lying about --------------------------------------------

## Bags, bottles and a bench at each end. A hall with nobody's belongings in it reads
## as a showroom; a hall with a bag dumped by the back line reads as one somebody is
## playing in.
func _build_kit(spec: Dictionary) -> void:
	var amount: int = spec["kit"]
	var kit := Node3D.new()
	kit.name = "Kit"
	add_child(kit)

	# Behind the baseline boards, not beside the court. They used to stand less than a
	# metre outside the sideline, which is inside the run-off — the strip a player
	# sprints into chasing a shuttle past the line, and the strip the overhead camera
	# looks at. A bag there is both a trip hazard and the thing covering up the landing
	# in the one picture that is meant to settle it.
	var out_z := Court.run_off_z() + 1.15
	for end: float in [1.0, -1.0]:
		var bench := Props.node(Props.BENCH, 0.95)
		if bench != null:
			bench.position = Vector3(2.35, 0.0, end * out_z)
			bench.rotation.y = 0.0 if end < 0.0 else PI
			kit.add_child(bench)

		for i in amount:
			var bag := Props.node(Props.BAG, 0.38)
			if bag != null:
				bag.position = Vector3(1.35 - 0.55 * float(i), 0.0, end * (out_z + 0.30))
				bag.rotation.y = randf_range(-0.6, 0.6)
				kit.add_child(bag)

			var bottle := Props.node(Props.BOTTLE, 0.26)
			if bottle != null:
				bottle.position = Vector3(2.35 + 0.22 * float(i) - 0.2, 0.50, end * (out_z - 0.18))
				kit.add_child(bottle)


# --- the photographers ----------------------------------------------------------

## A pool of flashes going off in the stands. They are only ever fired on a point, so
## the hall reacting is another thing the player sees out of the corner of their eye
## while deciding whether they have got away with something.
func _build_flashes(spec: Dictionary) -> void:
	var count: int = spec["flashes"]
	if count <= 0:
		return

	for i in count:
		var pop := OmniLight3D.new()
		pop.name = "Flash"
		pop.light_color = Color(0.86, 0.92, 1.0)
		pop.light_energy = 0.0
		pop.omni_range = 5.5
		pop.shadow_enabled = false
		pop.visible = false
		add_child(pop)
		_flashes.append(pop)
	_flash_left.resize(count)


## Sets the photographers off. Each one picks a fresh seat in the stands, so the same
## fourteen lights read as a hall full of cameras.
func flash() -> void:
	for i in _flashes.size():
		if _flash_left[i] > 0.0 or randf() > 0.7:
			continue
		var side := 1.0 if randf() < 0.5 else -1.0
		_flashes[i].position = Vector3(
			side * randf_range(5.0, 9.0),
			randf_range(1.4, 3.2),
			randf_range(-9.5, 9.5)
		)
		_flashes[i].visible = true
		_flash_left[i] = FLASH_SECONDS * randf_range(0.7, 1.6)


func _process(delta: float) -> void:
	for i in _flashes.size():
		if _flash_left[i] <= 0.0:
			continue
		_flash_left[i] = maxf(_flash_left[i] - delta, 0.0)
		var through := _flash_left[i] / FLASH_SECONDS
		_flashes[i].light_energy = FLASH_ENERGY * minf(through, 1.0)
		if _flash_left[i] <= 0.0:
			_flashes[i].visible = false
