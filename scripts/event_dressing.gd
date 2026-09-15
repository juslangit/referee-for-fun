class_name EventDressing
extends Node3D

## What turns a court into an event: the sponsor boards, the screen, the television cameras
## and the people working them, the photographers, the banners, the flags in the crowd and
## everything that stands at the side of the court.
##
## Luqman asked on 2026-09-15 for every sport's environment to look like a real event, and
## chose Malaysian events as the reference, with all four kinds of dressing: crowd and
## atmosphere, television production and light, branding and screens, and the people and
## furniture at the side of the court. What each sport's top venue copies is in
## `EventLayouts`, with the event it is modelled on; the names on everything are invented,
## because the project carries no real tournaments or sponsors. The pictures came from OpenArt
## and were cut up by tools/events/prepare_event_art.gd.
##
## One shared builder, and each sport hands it a layout. **Nothing here touches the court**:
## lines, nets, posts and the umpire's chair stay where each sport's spec puts them, because
## those are the numbers the game judges by. And nothing here casts a shadow or holds a light
## — an LED board glows by its own material — because badminton's hall already runs close to
## sixty frames a second on Luqman's MacBook Air and every shadow caster is drawn again per
## light.
##
## Every item can say which rung of the ladder it first appears at (`from`). A school hall
## gets a few printed boards and one camera; the top of the ladder gets the whole broadcast.

## The pictures, as laid out by tools/events/prepare_event_art.gd.
const SPONSORS := [
	"teras_energy", "seri_bank", "rajawali_air", "segar", "kenari_telekom", "bayu_motor",
	"teratai_hotels", "kopi_kampung", "pelangi_pay", "sinar_elektrik", "rimba_sports",
	"cuti_cuti_nusa",
]
const BANNERS := [
	"malaysia_boleh", "jom_menang", "selamat_datang", "jalur_gemilang", "go_go_go",
	"kami_bersamamu",
]
const ART := "res://assets/events/"

## How long an LED board shows one sponsor before it moves on to the next.
const LED_SECONDS := 7.0

## A person working at the side of the court. The crowd's own model, so they belong to the
## same world as the people watching.
const PERSON := "res://assets/sketchfab/simple_low_poly_character/simple_low_poly_character.glb"
const TV_CAMERA := "res://assets/sketchfab/tv_camera/tv_camera.glb"
const PLASTIC_CHAIR := "res://assets/sketchfab/plastic_chair/plastic_chair.glb"
const UMBRELLA := "res://assets/sketchfab/beach_umbrella_low_poly/beach_umbrella_low_poly.glb"

var layout: Dictionary = {}
var stands: Stands
var tier := Venue.Tier.REGIONAL

var _textures := {}
var _materials := {}
var _led_faces: Array[MeshInstance3D] = []
var _led_left := LED_SECONDS
var _led_turn := 0
var _screen_score: Label3D


func dress(which: Venue.Tier) -> void:
	tier = which
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_led_faces.clear()
	_screen_score = null
	if layout.is_empty():
		return
	if layout.has("boards"):
		_build_boards(layout["boards"])
	if layout.has("screen") and _here(layout["screen"]):
		_build_screen(layout["screen"])
	for item in layout.get("hangings", []):
		if _here(item):
			_hang(item)
	for item in layout.get("cameras", []):
		if _here(item):
			_camera(item)
	for item in layout.get("props", []):
		if _here(item):
			_prop(item)
	for item in layout.get("people", []):
		if _here(item):
			_person(item)
	if layout.has("rail_banners"):
		_rail_banners(layout["rail_banners"])
	if layout.has("crowd_flags"):
		# Deferred to the end of the frame: every caller sets how full the stands are straight
		# after dressing, and the flags go only where somebody is sitting.
		_crowd_flags.call_deferred(layout["crowd_flags"])


## The colour this rung paints one of the court's own surfaces, or null to leave it as the
## court built it. The court asks, because the court owns its materials: `layout["paint"]`
## maps a surface's name to one entry per rung.
func paint(surface: String) -> Variant:
	var rungs: Array = layout.get("paint", {}).get(surface, [])
	if rungs.is_empty():
		return null
	return rungs[clampi(int(tier), 0, rungs.size() - 1)]


## Repaints one of the court's materials for this rung, or puts back the colour the court
## built it with. The first colour a material is seen with is remembered on it, so a career
## that moves down the ladder as well as up gets the court's own colour back.
func apply_paint(surface: String, material: StandardMaterial3D) -> void:
	if material == null:
		return
	if not material.has_meta("built_colour"):
		material.set_meta("built_colour", material.albedo_color)
	var colour: Variant = paint(surface)
	material.albedo_color = colour if colour != null else material.get_meta("built_colour")


## Whether this rung is played under a roof. Tennis is the one sport that changes: the
## club courts are outdoors and the top of the ladder is an indoor stadium.
func indoors() -> bool:
	var rungs: Array = layout.get("indoors", [])
	if rungs.is_empty():
		return false
	return rungs[clampi(int(tier), 0, rungs.size() - 1)]


## The score on the big screen, where there is one.
func set_score(text: String) -> void:
	if _screen_score != null and is_instance_valid(_screen_score):
		_screen_score.text = text


## Whether an item belongs at this rung: from `from` up, and no higher than `until`.
func _here(item: Dictionary) -> bool:
	return int(tier) >= int(item.get("from", Venue.Tier.SCHOOL)) \
		and int(tier) <= int(item.get("until", Venue.Tier.ARENA))


# --- pictures -----------------------------------------------------------------------

func _texture(name: String) -> Texture2D:
	if _textures.has(name):
		return _textures[name]
	var path := ART + name + ".png"
	var found: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_textures[name] = found
	return found


## A flat picture, facing +Z in its own space, `size` metres, lit by the room or glowing.
func _picture(name: String, size: Vector2, glowing := false) -> MeshInstance3D:
	var quad := MeshInstance3D.new()
	quad.name = name.capitalize().replace(" ", "")
	var mesh := QuadMesh.new()
	mesh.size = size
	quad.mesh = mesh
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	quad.material_override = _picture_material(name, glowing)
	return quad


func _picture_material(name: String, glowing: bool) -> StandardMaterial3D:
	var key := name + ("*" if glowing else "")
	if _materials.has(key):
		return _materials[key]
	var paint := StandardMaterial3D.new()
	_materials[key] = paint
	paint.albedo_texture = _texture(name)
	paint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	paint.alpha_scissor_threshold = 0.4
	paint.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if glowing:
		paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	else:
		paint.roughness = 0.8
	return paint


## The size a picture should be to fit inside `box` without stretching it.
func _fit(name: String, box: Vector2) -> Vector2:
	var picture := _texture(name)
	if picture == null:
		return box
	var aspect := float(picture.get_width()) / float(picture.get_height())
	var w := box.x
	var h := w / aspect
	if h > box.y:
		h = box.y
		w = h * aspect
	return Vector2(w, h)


func _block(parent: Node3D, block_name: String, size: Vector3, where: Vector3, colour: Color,
		glowing := false) -> MeshInstance3D:
	var piece := MeshInstance3D.new()
	piece.name = block_name
	var box := BoxMesh.new()
	box.size = size
	piece.mesh = box
	piece.position = where
	piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var paint := StandardMaterial3D.new()
	paint.albedo_color = colour
	paint.roughness = 0.75
	if glowing:
		paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	piece.material_override = paint
	parent.add_child(piece)
	return piece


# --- the boards ---------------------------------------------------------------------

## A ring of sponsor boards round a rectangle, facing in.
##
## `half` is the rectangle's half width (x) and half length (z) at the boards' inner face.
## `led` boards are black and their sponsor glows, and every so often they all move on to
## the next sponsor, which is what an LED ring does and what a printed one cannot. Printed
## boards take the board colour and a sponsor on it. `skip_x` leaves out a stretch of the
## side at +x either side of the net (`gap` metres each way) — the umpire's side of the court,
## where the chair and the players' seats are, and where boards would stand in the cutscenes'
## way. `out` moves the whole ring out from `half`, or in, when a sport already has a barrier
## there for the boards to be printed on.
func _build_boards(spec: Dictionary) -> void:
	var levels: Array = spec.get("levels", [{}, {}, {}])
	var level: Dictionary = levels[clampi(int(tier), 0, levels.size() - 1)]
	if level.get("none", false):
		return
	var half: Vector2 = spec["half"]
	var height: float = level.get("height", spec.get("height", 0.9))
	var length: float = spec.get("length", 3.0)
	var led: bool = level.get("led", false)
	var colour: Color = level.get("colour", spec.get("colour", Color(0.10, 0.20, 0.45)))
	var every: int = level.get("every", 1)
	var gap: float = spec.get("gap", 0.0)
	var out: float = spec.get("out", 0.05)
	var sponsors: Array = spec.get("sponsors", SPONSORS)

	var ring := Node3D.new()
	ring.name = "Boards"
	add_child(ring)
	var slots: Array = []
	# Down both sides, then across both ends.
	for side: float in [-1.0, 1.0]:
		var count := int(floor(half.y * 2.0 / length))
		for i in count:
			var z := -half.y + length * (float(i) + 0.5) + (half.y * 2.0 - length * count) * 0.5
			if side > 0.0 and absf(z) < gap:
				continue
			slots.append({"at": Vector3(side * (half.x + out), 0.0, z), "turn": -side * PI * 0.5})
	for end: float in ([-1.0, 1.0] if spec.get("ends", true) else []):
		var count := int(floor(half.x * 2.0 / length))
		for i in count:
			var x := -half.x + length * (float(i) + 0.5) + (half.x * 2.0 - length * count) * 0.5
			slots.append({"at": Vector3(x, 0.0, end * (half.y + out)), "turn": 0.0 if end < 0.0 else PI})

	for n in slots.size():
		if n % every != 0:
			continue
		var slot: Dictionary = slots[n]
		var sponsor_name := "sponsor_" + String(sponsors[(n / every) % sponsors.size()])
		if level.get("style", "") == "barrier":
			_prop({"kind": "barrier", "at": slot["at"], "turn": slot["turn"], "length": length - 0.1,
				"picture": sponsor_name})
			continue
		var board := Node3D.new()
		board.position = slot["at"]
		board.rotation.y = slot["turn"]
		ring.add_child(board)
		var face_colour := Color(0.02, 0.02, 0.03) if led else colour
		_block(board, "Board", Vector3(length - 0.06, height, 0.08), Vector3(0.0, height * 0.5, 0.0),
			face_colour, led)
		var logo := _picture(sponsor_name, _fit(sponsor_name, Vector2(length * 0.72, height * 0.78)), led)
		logo.position = Vector3(0.0, height * 0.5, 0.05)
		board.add_child(logo)
		if led:
			logo.set_meta("sponsor_index", (n / every) % sponsors.size())
			logo.set_meta("box", Vector2(length * 0.72, height * 0.78))
			_led_faces.append(logo)


func _process(delta: float) -> void:
	if _led_faces.is_empty():
		return
	_led_left -= delta
	if _led_left > 0.0:
		return
	_led_left = LED_SECONDS
	_led_turn += 1
	var sponsors: Array = layout.get("boards", {}).get("sponsors", SPONSORS)
	for face in _led_faces:
		if not is_instance_valid(face):
			continue
		var index: int = (int(face.get_meta("sponsor_index")) + _led_turn) % sponsors.size()
		var name := "sponsor_" + String(sponsors[index])
		face.material_override = _picture_material(name, true)
		(face.mesh as QuadMesh).size = _fit(name, face.get_meta("box"))


# --- the screen and the banners -----------------------------------------------------

## A big video screen: the event's logo, and the score under it.
func _build_screen(spec: Dictionary) -> void:
	var screen := Node3D.new()
	screen.name = "VideoScreen"
	screen.position = spec["at"]
	screen.rotation.y = spec.get("turn", 0.0)
	add_child(screen)
	var size: Vector2 = spec.get("size", Vector2(8.0, 4.5))
	_block(screen, "Frame", Vector3(size.x + 0.4, size.y + 0.4, 0.3), Vector3.ZERO, Color(0.03, 0.03, 0.04))
	_block(screen, "Panel", Vector3(size.x, size.y, 0.05), Vector3(0.0, 0.0, 0.16),
		spec.get("colour", Color(0.02, 0.10, 0.16)), true)
	var logo_name := String(layout.get("logo", ""))
	if not logo_name.is_empty():
		var logo := _picture(logo_name, _fit(logo_name, Vector2(size.x * 0.5, size.y * 0.55)), true)
		logo.position = Vector3(-size.x * 0.22, size.y * 0.12, 0.2)
		screen.add_child(logo)
	_screen_score = Label3D.new()
	_screen_score.text = "0  -  0"
	_screen_score.font_size = 220
	_screen_score.pixel_size = size.y * 0.0012
	_screen_score.outline_size = 0
	_screen_score.modulate = Color(1.0, 0.82, 0.30)
	_screen_score.position = Vector3(size.x * 0.24, 0.0, 0.2)
	screen.add_child(_screen_score)
	if spec.has("legs"):
		for x: float in [-size.x * 0.4, size.x * 0.4]:
			_block(screen, "Leg", Vector3(0.18, spec["legs"], 0.18),
				Vector3(x, -size.y * 0.5 - spec["legs"] * 0.5, 0.0), Color(0.12, 0.12, 0.14))


## A banner or backdrop: a picture on a backing, hung or stood wherever the layout says.
func _hang(spec: Dictionary) -> void:
	var holder := Node3D.new()
	holder.name = "Hanging"
	holder.position = spec["at"]
	holder.rotation.y = spec.get("turn", 0.0)
	add_child(holder)
	var size: Vector2 = spec.get("size", Vector2(6.0, 1.2))
	var picture := String(spec.get("picture", layout.get("logo", "")))
	if spec.has("backing"):
		_block(holder, "Backing", Vector3(size.x, size.y, 0.04), Vector3.ZERO, spec["backing"],
			spec.get("glowing", false))
	if picture.is_empty():
		return
	var art := _picture(picture, _fit(picture, size * spec.get("fill", 0.86)), spec.get("glowing", false))
	art.position = Vector3(0.0, 0.0, 0.035)
	holder.add_child(art)
	if spec.get("both_sides", false):
		var back := _picture(picture, _fit(picture, size * spec.get("fill", 0.86)), spec.get("glowing", false))
		back.position = Vector3(0.0, 0.0, -0.035)
		back.rotation.y = PI
		holder.add_child(back)
	if spec.has("pole"):
		_block(holder, "Pole", Vector3(0.06, spec["pole"], 0.06),
			Vector3(-size.x * 0.5 - 0.05, -spec["pole"] * 0.5 + size.y * 0.5, 0.0), Color(0.75, 0.75, 0.78))


# --- people and things ----------------------------------------------------------------

## A television camera on its tripod with somebody behind it. `high` puts it on a platform.
func _camera(spec: Dictionary) -> void:
	var rig := Node3D.new()
	rig.name = "TVCamera"
	rig.position = spec["at"]
	add_child(rig)
	var lift := 0.0
	if spec.get("high", false):
		lift = spec.get("platform", 2.2)
		_block(rig, "Platform", Vector3(1.3, lift, 1.3), Vector3(0.0, lift * 0.5, 0.0), Color(0.30, 0.31, 0.34))
	var look: Vector3 = spec.get("look", Vector3.ZERO)
	var facing := Vector2(look.x - rig.position.x, look.z - rig.position.z)
	var turn := atan2(facing.x, facing.y)
	var camera := Props.node(TV_CAMERA, 1.45)
	if camera != null:
		camera.position = Vector3(0.0, lift, 0.0)
		# The model's lens looks down its own +Z, like the crowd's people.
		camera.rotation.y = turn
		_tint(camera, Color(0.16, 0.16, 0.18))
		_no_shadows(camera)
		rig.add_child(camera)
	var operator := Props.node(PERSON, 1.74)
	if operator != null:
		var back := Vector3(sin(turn), 0.0, cos(turn)) * -0.6
		operator.position = Vector3(back.x, lift, back.z)
		operator.rotation.y = turn
		_clothe(operator, spec.get("shirt", Color(0.08, 0.08, 0.10)))
		_no_shadows(operator)
		rig.add_child(operator)


## Something that stands at the side of the court. The kinds are the ones real events use.
func _prop(spec: Dictionary) -> void:
	var kind := String(spec["kind"])
	var holder := Node3D.new()
	holder.name = kind.capitalize().replace(" ", "")
	holder.position = spec["at"]
	holder.rotation.y = spec.get("turn", 0.0)
	add_child(holder)
	var colour: Color = spec.get("colour", Color(0.2, 0.3, 0.6))
	match kind:
		"chair":
			# The chair's seat faces its own -X, so it gets a quarter turn to face `turn`.
			_model(holder, PLASTIC_CHAIR, 0.85, colour, PI * 0.5)
		"folding_chair":
			_model(holder, Props.FOLDING_CHAIR, 0.88)
		"bench":
			_block(holder, "Seat", Vector3(spec.get("length", 2.4), 0.06, 0.45), Vector3(0.0, 0.45, 0.0), colour)
			_block(holder, "Back", Vector3(spec.get("length", 2.4), 0.45, 0.05), Vector3(0.0, 0.72, -0.22), colour)
			for x: float in [-1.0, 1.0]:
				_block(holder, "Leg", Vector3(0.05, 0.45, 0.4),
					Vector3(x * (spec.get("length", 2.4) * 0.5 - 0.1), 0.225, 0.0), Color(0.15, 0.15, 0.17))
		"table":
			var w: float = spec.get("length", 2.4)
			_block(holder, "Top", Vector3(w, 0.05, 0.7), Vector3(0.0, 0.75, 0.0), Color(0.1, 0.1, 0.12))
			_block(holder, "Skirt", Vector3(w, 0.72, 0.04), Vector3(0.0, 0.37, 0.34), colour)
			if spec.has("picture"):
				var art := _picture(spec["picture"], _fit(spec["picture"], Vector2(w * 0.8, 0.6)))
				art.position = Vector3(0.0, 0.37, 0.37)
				holder.add_child(art)
		"monitor":
			_block(holder, "Stand", Vector3(0.08, 0.3, 0.08), Vector3(0.0, 0.15, 0.0), Color(0.1, 0.1, 0.1))
			_block(holder, "Screen", Vector3(0.6, 0.36, 0.04), Vector3(0.0, 0.46, 0.0), Color(0.05, 0.05, 0.06))
			var readout := _block(holder, "Glow", Vector3(0.55, 0.31, 0.01), Vector3(0.0, 0.46, 0.025),
				Color(0.05, 0.25, 0.18), true)
			readout.name = "Readout"
		"towel_box":
			_block(holder, "Box", Vector3(0.45, 0.8, 0.45), Vector3(0.0, 0.4, 0.0), colour)
		"cooler":
			_block(holder, "Cooler", Vector3(0.5, 0.55, 0.36), Vector3(0.0, 0.275, 0.0), colour)
			_block(holder, "Lid", Vector3(0.52, 0.06, 0.38), Vector3(0.0, 0.58, 0.0), Color(0.95, 0.95, 0.95))
		"umbrella":
			_model(holder, UMBRELLA, spec.get("height", 2.3))
		"sign":
			# A triangular A-frame sign standing by a net post, like "2 MINS INTERVAL".
			_block(holder, "Sign", Vector3(0.7, 0.9, 0.05), Vector3(0.0, 0.45, 0.0), colour)
			var label := Label3D.new()
			label.text = spec.get("text", "")
			label.font_size = 64
			label.pixel_size = 0.004
			label.outline_size = 0
			label.modulate = Color(1, 1, 1)
			label.position = Vector3(0.0, 0.5, 0.04)
			holder.add_child(label)
		"floor_panel":
			var size: Vector2 = spec.get("size", Vector2(2.0, 2.0))
			_block(holder, "Panel", Vector3(size.x, 0.004, size.y), Vector3(0.0, 0.002, 0.0), colour)
			if spec.has("inner"):
				_block(holder, "Inner", Vector3(size.x * 0.7, 0.004, size.y * 0.7), Vector3(0.0, 0.004, 0.0), spec["inner"])
		"floor_text":
			# Lettering painted on the run-off, like the city's name behind a tennis baseline.
			var words := Label3D.new()
			words.text = spec.get("text", "")
			words.font_size = 256
			words.pixel_size = spec.get("size", 0.006)
			words.outline_size = 0
			words.modulate = colour
			words.rotation.x = -PI * 0.5
			words.position = Vector3(0.0, spec.get("lift", 0.03), 0.0)
			words.shaded = true
			holder.add_child(words)
		"feather_flag":
			var tall: float = spec.get("height", 3.2)
			_block(holder, "Pole", Vector3(0.05, tall, 0.05), Vector3(0.0, tall * 0.5, 0.0), Color(0.8, 0.8, 0.82))
			_block(holder, "Cloth", Vector3(0.7, tall * 0.72, 0.02), Vector3(0.37, tall * 0.6, 0.0), colour)
			if spec.has("picture"):
				var art := _picture(spec["picture"], _fit(spec["picture"], Vector2(0.62, tall * 0.5)))
				art.position = Vector3(0.37, tall * 0.6, 0.02)
				art.rotation.z = PI * 0.5 if spec.get("sideways", false) else 0.0
				holder.add_child(art)
		"arch":
			var width: float = spec.get("width", 8.0)
			for x: float in [-1.0, 1.0]:
				var leg := _block(holder, "Leg", Vector3(0.8, 4.2, 0.8), Vector3(x * width * 0.5, 2.1, 0.0), colour)
				leg.mesh = CapsuleMesh.new()
				(leg.mesh as CapsuleMesh).radius = 0.42
				(leg.mesh as CapsuleMesh).height = 4.6
			var top := _block(holder, "Top", Vector3(width + 0.8, 0.9, 0.8), Vector3(0.0, 4.5, 0.0), colour)
			var logo_name := String(layout.get("logo", ""))
			if not logo_name.is_empty():
				var art := _picture(logo_name, _fit(logo_name, Vector2(width * 0.6, 0.8)))
				art.position = Vector3(0.0, 4.5, 0.42)
				holder.add_child(art)
		"barrier":
			var run: float = spec.get("length", 2.2)
			_block(holder, "Rail", Vector3(run, 0.05, 0.05), Vector3(0.0, 1.05, 0.0), Color(0.72, 0.73, 0.76))
			for x: float in [-1.0, 1.0]:
				_block(holder, "Foot", Vector3(0.05, 1.05, 0.5), Vector3(x * run * 0.5, 0.525, 0.0), Color(0.72, 0.73, 0.76))
			_block(holder, "Vinyl", Vector3(run - 0.1, 0.8, 0.02), Vector3(0.0, 0.62, 0.0), Color(0.96, 0.96, 0.95))
			if spec.has("picture"):
				var art := _picture(spec["picture"], _fit(spec["picture"], Vector2(run * 0.8, 0.68)))
				art.position = Vector3(0.0, 0.62, 0.02)
				holder.add_child(art)
		"podium":
			var tall: float = spec.get("height", 1.9)
			_block(holder, "Podium", Vector3(1.0, tall, 1.0), Vector3(0.0, tall * 0.5, 0.0), colour)
		"flagpoles":
			var count: int = spec.get("count", 6)
			for i in count:
				var x := (float(i) - float(count - 1) * 0.5) * 1.4
				_block(holder, "Pole", Vector3(0.06, 5.0, 0.06), Vector3(x, 2.5, 0.0), Color(0.85, 0.85, 0.88))
				var flag := _picture("banner_jalur_gemilang", Vector2(1.1, 0.55))
				flag.position = Vector3(x + 0.58, 4.6, 0.0)
				holder.add_child(flag)
		"ground":
			# Something under the whole event, where the sky's own horizon would otherwise
			# show through as a floor that goes on for ever.
			var size: Vector2 = spec.get("size", Vector2(200.0, 200.0))
			_block(holder, "Ground", Vector3(size.x, 0.02, size.y), Vector3(0.0, -0.02, 0.0), colour)
		"enclosure":
			# Four walls round the whole event: a hall's walls, or the green windbreak round an
			# outdoor court. Nothing overhead — the background is the roof.
			var half: Vector2 = spec["half"]
			var tall: float = spec.get("height", 8.0)
			for dir: float in [-1.0, 1.0]:
				_block(holder, "Wall", Vector3(0.3, tall, half.y * 2.0), Vector3(dir * half.x, tall * 0.5, 0.0), colour)
				_block(holder, "Wall", Vector3(half.x * 2.0, tall, 0.3), Vector3(0.0, tall * 0.5, dir * half.y), colour)
			if spec.has("ground"):
				_block(holder, "Ground", Vector3(half.x * 2.0, 0.02, half.y * 2.0), Vector3(0.0, -0.02, 0.0), spec["ground"])
			if spec.has("band"):
				# A band of sponsors round the walls at head height above the stands.
				var band: Dictionary = spec["band"]
				var names: Array = layout.get("boards", {}).get("sponsors", SPONSORS)
				var n := 0
				for dir: float in [-1.0, 1.0]:
					for along in int(half.y * 2.0 / 5.0):
						var z := -half.y + 5.0 * (float(along) + 0.5)
						var art := _picture("sponsor_" + String(names[n % names.size()]),
							_fit("sponsor_" + String(names[n % names.size()]), Vector2(3.6, 1.4)))
						n += 1
						art.position = Vector3(dir * (half.x - 0.2), band["height"], z)
						art.rotation.y = -dir * PI * 0.5
						holder.add_child(art)
		"palm":
			var tall: float = spec.get("height", 7.0)
			var lean: float = spec.get("lean", 0.12)
			var trunk := _block(holder, "Trunk", Vector3(0.3, tall, 0.3), Vector3(0.0, tall * 0.5, 0.0), Color(0.45, 0.36, 0.26))
			trunk.rotation.z = lean
			var crown := Vector3(-sin(lean) * tall, cos(lean) * tall, 0.0)
			for i in 7:
				var leaf := _block(holder, "Leaf", Vector3(3.2, 0.05, 0.6), crown, Color(0.20, 0.42, 0.18))
				leaf.rotation = Vector3(0.0, TAU * float(i) / 7.0, -0.35)
				leaf.position = crown + Vector3(cos(TAU * float(i) / 7.0), -0.5, -sin(TAU * float(i) / 7.0)) * 1.4
		"sea":
			var wide: float = spec.get("width", 400.0)
			var water := _block(holder, "Sea", Vector3(wide, 0.02, spec.get("depth", 300.0)),
				Vector3(0.0, -0.05, 0.0), Color(0.12, 0.62, 0.66))
			(water.material_override as StandardMaterial3D).roughness = 0.15
			(water.material_override as StandardMaterial3D).metallic = 0.2
			for island: Dictionary in spec.get("islands", []):
				var hill := MeshInstance3D.new()
				var sphere := SphereMesh.new()
				sphere.radius = island["radius"]
				sphere.height = island["radius"] * island.get("flat", 0.6)
				hill.mesh = sphere
				hill.position = island["at"]
				hill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				var green := StandardMaterial3D.new()
				green.albedo_color = Color(0.16, 0.34, 0.22)
				green.roughness = 0.95
				hill.material_override = green
				holder.add_child(hill)
	_no_shadows(holder)


## Somebody who works at the event: a ball kid, a raker, a photographer, the scorer.
func _person(spec: Dictionary) -> void:
	var person := Props.node(PERSON, spec.get("height", 1.72))
	if person == null:
		return
	person.name = String(spec.get("role", "Crew")).capitalize().replace(" ", "")
	person.position = spec["at"]
	person.rotation.y = spec.get("turn", 0.0)
	if spec.get("crouch", false):
		person.scale = Vector3(1.0, 0.62, 1.0)
	_clothe(person, spec.get("shirt", Color(0.9, 0.5, 0.1)), spec.get("trousers", Color(0.10, 0.11, 0.14)))
	_no_shadows(person)
	add_child(person)


func _model(parent: Node3D, path: String, height: float, tint := Color(-1, -1, -1),
		yaw := 0.0) -> void:
	var model := Props.node(path, height)
	if model == null:
		return
	model.rotation.y = yaw
	if tint.r >= 0.0:
		_tint(model, tint)
	parent.add_child(model)


## Puts a person in the event's colours. The crowd's model is five flat materials, and only two
## are clothes: `Material.004` is the shirt and `Material.005` the trousers. Tinting the whole
## model turns the face and the hair the shirt's colour too — a courtside full of orange
## mannequins, which is what the first attempt looked like.
const SHIRT_MATERIAL := "Material.004"
const TROUSERS_MATERIAL := "Material.005"


func _clothe(model: Node, shirt: Color, trousers := Color(0.10, 0.11, 0.14)) -> void:
	for child in _every(model):
		if not (child is MeshInstance3D) or (child as MeshInstance3D).mesh == null:
			continue
		var mesh := child as MeshInstance3D
		for s in mesh.mesh.get_surface_count():
			var base := mesh.mesh.surface_get_material(s)
			if base == null:
				continue
			var colour: Variant = null
			if base.resource_name == SHIRT_MATERIAL:
				colour = shirt
			elif base.resource_name == TROUSERS_MATERIAL:
				colour = trousers
			if colour == null or not (base is StandardMaterial3D):
				continue
			var paint: StandardMaterial3D = base.duplicate()
			paint.albedo_color = colour
			mesh.set_surface_override_material(s, paint)


## Colours a whole model. The crowd's people are painted, and a colour multiplied over the
## painting reads as their shirt without losing the face.
func _tint(model: Node, colour: Color) -> void:
	for child in _every(model):
		if child is MeshInstance3D:
			var mesh := child as MeshInstance3D
			for s in mesh.get_surface_override_material_count():
				var base := mesh.mesh.surface_get_material(s) if mesh.mesh != null else null
				var paint: StandardMaterial3D = base.duplicate() if base is StandardMaterial3D else StandardMaterial3D.new()
				paint.albedo_color = colour
				mesh.set_surface_override_material(s, paint)


func _no_shadows(model: Node) -> void:
	for child in _every(model):
		if child is GeometryInstance3D:
			(child as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _every(root: Node) -> Array:
	var found: Array = [root]
	for child in root.get_children():
		found.append_array(_every(child))
	return found


# --- the crowd ------------------------------------------------------------------------

## Supporters' banners along the back of the stands, above the last row, where a real hall
## hangs them off the balcony rail — and, at the top rung, the event's name between them.
## Placed from the stands' own numbers, so they follow a stand that moves.
func _rail_banners(spec: Dictionary) -> void:
	if stands == null:
		return
	var levels: Array = spec.get("per_level", [0, 4, 8])
	var count: int = levels[clampi(int(tier), 0, levels.size() - 1)]
	if count <= 0:
		return
	var n := 0
	for side: float in spec.get("sides", [-1.0]):
		var start := stands.far_row_x if side > 0.0 else stands.near_row_x
		var x := side * (start + stands.row_depth * stands.rows + 0.15)
		var y: float = stands.row_rise * stands.rows + float(spec.get("above", 2.2))
		var run := stands.half_length * 2.0
		for i in count:
			var z := -stands.half_length + run * (float(i) + 0.5) / float(count)
			var picture := "banner_" + String(BANNERS[n % BANNERS.size()])
			if spec.get("logo_every", 0) > 0 and i % int(spec["logo_every"]) == int(spec["logo_every"]) / 2:
				picture = String(layout.get("logo", picture))
			n += 1
			var size := _fit(picture, Vector2(minf(3.2, run / float(count) - 0.3), 1.3))
			var banner := _picture(picture, size)
			banner.position = Vector3(x, y, z)
			banner.rotation.y = -side * PI * 0.5
			add_child(banner)


## Flags held up in the crowd: the national flag mostly, and the odd supporters' banner.
func _crowd_flags(spec: Dictionary) -> void:
	if stands == null:
		return
	var levels: Array = spec.get("per_level", [0, 10, 30])
	var count: int = levels[clampi(int(tier), 0, levels.size() - 1)]
	if count <= 0:
		return
	var holder := Node3D.new()
	holder.name = "CrowdFlags"
	add_child(holder)
	var spots := stands.held_up_spots(count)
	for i in spots.size():
		var seat: Transform3D = stands.global_transform * spots[i]
		var picture := "banner_jalur_gemilang" if i % 4 != 3 else "banner_" + String(BANNERS[i % BANNERS.size()])
		var flag := _picture(picture, Vector2(0.9, 0.5))
		# Held above the head, facing the court the way the person is.
		var facing := -seat.basis.z.normalized()
		holder.add_child(flag)
		flag.global_position = seat.origin + Vector3.UP * 2.05 + facing * 0.1
		flag.look_at(flag.global_position - facing, Vector3.UP)
		(flag.material_override as StandardMaterial3D).cull_mode = BaseMaterial3D.CULL_DISABLED
