class_name Models
extends RefCounted

## Loads the downloaded Sketchfab models and makes them usable.
##
## Nothing that comes off an asset site arrives ready. Every model has its own idea
## of which way up it is, how big a metre is, and where its origin sits — one of
## these is two metres tall standing up, another is lying on its back with its origin
## in the middle of its chest. So everything goes through `_normalise`, which turns it
## the right way up, scales it to a real height and stands it on the floor at its own
## feet. After that the game can treat them all the same.
##
## If a model is missing — someone has cloned the repo without the assets, or a
## download failed — every one of these falls back to the boxes in `figure.gd`. A
## game that will not start because an athlete is missing is worse than a game with a
## box in it.

## Static models, animated by hand in player.gd.
##
## The rigged pair (low_poly_man / low_poly_woman, still in assets/) was tried first
## and abandoned. Their clips have the orientation and the root motion baked into the
## animation itself: `settle` measures them, stands them up correctly, and the moment
## the clip advances a frame it puts them straight back on their backs somewhere over
## the third row of the stands. Fixing that properly means extracting root motion and
## retargeting, which is a bigger job than the animation is worth here.
##
## Both files are kept. A character rigged in the ordinary way — the KayKit packs, or
## anything out of Mixamo — would drop into this exact code path and bring real
## locomotion with it.
const ATHLETE := "res://assets/sketchfab/olympic_athlete/olympic_athlete.glb"
const OFFICIAL := "res://assets/sketchfab/male_character_in_caual_clothing/male_character_in_caual_clothing.glb"
const RIGGED_ATHLETE := "res://assets/sketchfab/low_poly_man/low_poly_man.glb"

## The bone a racket goes in. Both models happen to name it the same way.
const RACKET_HAND := "R.hand_028"
const KIT := "res://assets/sketchfab/badminton_racket_and_shuttlecock_low_poly/badminton_racket_and_shuttlecock_low_poly.glb"

## Real heights, in metres.
const PLAYER_HEIGHT := 1.80
const OFFICIAL_HEIGHT := 1.76

## A badminton racket is about 67 cm long, and a shuttlecock about 8.5 cm.
const RACKET_LENGTH := 0.67
const SHUTTLE_LENGTH := 0.085


## A player, in their team's colour, holding a racket.
## A player. **Must be followed by `settle()` once it is in the tree** — see there.
static func player(team_colour: Color) -> Node3D:
	var figure := _load(ATHLETE, PLAYER_HEIGHT)
	if figure == null:
		return null

	figure.set_meta("bib_colour", team_colour)
	return figure


## Puts the team bib on and a racket in the hand. Kept separate from `settle` and run
## strictly after it, because both of these are added to the holder rather than to the
## model, and so do not scale with it — measured while fitting, the bib sat at a fixed
## height and set a floor the fit could never get under. Every player came out about
## 1.4 m tall no matter what scale the model was given.
static func dress_player(figure: Node3D) -> void:
	if figure == null:
		return
	# A bib, not a tint. Recolouring does not work: the kit is painted red in the
	# texture, and red times blue is dark red, so both teams looked like one team.
	_add_bib(figure, figure.get_meta("bib_colour", Color.WHITE))
	_hold_racket(figure)


## Puts a racket in the player's right hand, on the bone, so it moves with the arm.
##
## The alternative — hanging it off the figure at a fixed offset — was fine while
## everybody stood still and looks ridiculous the moment their arms start swinging.
static func _hold_racket(figure: Node3D) -> void:
	var held := racket()
	if held == null:
		return

	var skeleton := _find_skeleton(figure)
	var bone := -1 if skeleton == null else skeleton.find_bone(RACKET_HAND)

	if skeleton == null or bone < 0:
		# No hand to put it in, so it hangs at the side as it used to.
		held.position = Vector3(0.30, 0.74, 0.06)
		held.rotation = Vector3(deg_to_rad(-72.0), 0.0, deg_to_rad(-8.0))
		figure.add_child(held)
		figure.set_meta("racket", held)
		return

	var socket := BoneAttachment3D.new()
	socket.name = "RacketHand"
	socket.bone_name = RACKET_HAND
	skeleton.add_child(socket)
	socket.add_child(held)
	figure.set_meta("racket", held)

	# The skeleton lives inside a model that has been scaled to make the person a
	# real height, and anything parented to a bone inherits that. The racket was
	# already sized in metres, so the scaling has to be undone or it arrives either
	# enormous or invisible.
	held.position = Vector3(0.0, 0.06, 0.0)
	held.rotation = Vector3(deg_to_rad(90.0), 0.0, 0.0)

	# Anything parented to a bone inherits every scale between here and the model
	# root, and there is more than one. Rather than try to work out what they all
	# multiply to, the racket is measured where it has ended up and corrected.
	var box := _world_aabb(held)
	var longest := maxf(box.size.x, maxf(box.size.y, box.size.z))
	if longest > 0.0001:
		held.scale *= RACKET_LENGTH / longest


static func _world_aabb(node: Node3D) -> AABB:
	var box := AABB()
	var started := false
	for child in _every(node):
		if child is VisualInstance3D:
			var shape: AABB = (child as VisualInstance3D).get_aabb()
			if shape.size == Vector3.ZERO:
				continue
			var here: AABB = child.global_transform * shape
			box = here if not started else box.merge(here)
			started = true
	return box


## A band round the chest in the team's colour, bright enough to read across a hall.
static func _add_bib(figure: Node3D, colour: Color) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 0.75

	# Sized to hug the chest. The first attempt was a good deal larger and every
	# player was wearing a sandwich board.
	for band in [[1.21, 0.15], [1.03, 0.04]]:
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.325, band[1], 0.225)
		var instance := MeshInstance3D.new()
		instance.name = "Bib"
		instance.mesh = mesh
		instance.position = Vector3(0.0, band[0], 0.0)
		instance.material_override = material
		instance.layers = Figure.PEOPLE_LAYER
		figure.add_child(instance)


## A line judge. Deliberately not in either team's colours.
## The AnimationPlayer inside a model, if it has one.
static func animator(figure: Node) -> AnimationPlayer:
	for child in _every(figure):
		if child is AnimationPlayer:
			return child
	return null


## Finds an animation whose name mentions any of `words`, because every model names
## its clips differently — one calls it "Run" and the next "Armature|walk2".
static func clip_named(player: AnimationPlayer, words: Array) -> String:
	if player == null:
		return ""
	for word in words:
		for name in player.get_animation_list():
			if String(name).to_lower().contains(String(word).to_lower()):
				return name
	return ""


## Makes a clip loop. Almost every downloaded animation arrives set to play once.
static func make_looping(player: AnimationPlayer, clip: String) -> void:
	if player == null or clip.is_empty() or not player.has_animation(clip):
		return
	var animation: Animation = player.get_animation(clip)
	animation.loop_mode = Animation.LOOP_LINEAR


static func _find_skeleton(node: Node) -> Skeleton3D:
	for child in _every(node):
		if child is Skeleton3D:
			return child
	return null


## Sizes a model and stands it on the floor, then puts a racket in its hand if it is
## a player. This cannot happen when the model is built, which is the whole reason it
## is a separate call.
##
## A rigged character's mesh is skinned: its shape comes from the skeleton, and until
## the skeleton has entered the tree and posed itself, asking the mesh how big it is
## returns the raw bind-pose numbers in whatever units the artist happened to use.
## Sizing from those made every player about ten times too tall — the first thing
## visible on court was a pair of shoes the size of cars.
static func settle(figure: Node3D) -> void:
	if figure == null or figure.get_child_count() == 0:
		return
	# Rackets and shuttlecocks were sized when they were cut out of their pack and
	# have no business being resized to the height of a person.
	if not figure.has_meta("target_height"):
		return
	var model: Node3D = figure.get_child(0)
	var height: float = figure.get_meta("target_height", 1.80)

	var box := _in_tree_bounds(figure)

	# Stand it up if it arrived on its back. Exporters disagree about which axis is
	# up, and guessing per model was how the line judge ended up ten metres wide
	# earlier — so it is measured instead. A person is reliably taller than they are
	# deep, so a figure longer front-to-back than it is tall is lying down.
	if box.size.z > box.size.y * 1.4:
		model.rotation.x = deg_to_rad(-90.0)
		box = _in_tree_bounds(figure)

	if box.size.y > 0.001:
		var factor := height / box.size.y
		model.scale *= factor
		figure.set_meta("model_scale", model.scale.y)
		box = _in_tree_bounds(figure)

	# Feet on the floor, centred where the game thinks the person is standing.
	model.position -= Vector3(box.get_center().x, box.position.y, box.get_center().z)


## The size of everything under `figure`, measured in `figure`'s own space, with the
## skeleton posed. Only meaningful once the node is in the tree.
static func _in_tree_bounds(figure: Node3D) -> AABB:
	var into := figure.global_transform.affine_inverse()
	var box := AABB()
	var started := false
	for child in _every(figure):
		if not child is VisualInstance3D:
			continue
		# The mesh's own bind-pose bounds, not the engine's. VisualInstance3D.get_aabb()
		# on a skinned mesh is padded out to cover everywhere the animation might throw
		# a limb, which for a running character is most of a stride — measured from
		# that, a 1.8 m man came out 1.4 m tall and two and a third metres deep.
		var shape := AABB()
		if child is MeshInstance3D and (child as MeshInstance3D).mesh != null:
			shape = (child as MeshInstance3D).mesh.get_aabb()
		else:
			shape = (child as VisualInstance3D).get_aabb()
		if shape.size == Vector3.ZERO:
			continue

		# A skinned mesh is placed by its skeleton rather than by its own node.
		var placed_by: Node3D = child
		if child is MeshInstance3D:
			var driver: Node = child.get_node_or_null((child as MeshInstance3D).skeleton)
			if driver is Skeleton3D:
				placed_by = driver

		var here: AABB = (into * placed_by.global_transform) * shape
		box = here if not started else box.merge(here)
		started = true
	return box


static func official() -> Node3D:
	# No correcting rotation, despite the mesh inside this one measuring 1.83 x 0.31 x
	# 1.80 and looking exactly like a Z-up export lying on its back. That figure is
	# the mesh's *local* box, and Sketchfab's exporter has already put a quarter turn
	# on the node above it. Adding another one laid the poor man flat and made him ten
	# metres wide. Measure the assembled model, not the mesh inside it.
	return _load(OFFICIAL, OFFICIAL_HEIGHT)


static func racket() -> Node3D:
	return _part(KIT, "Obj_Racket", RACKET_LENGTH)


static func shuttlecock() -> Node3D:
	return _part(KIT, "Gp_Shuttle", SHUTTLE_LENGTH)


static func has_assets() -> bool:
	return ResourceLoader.exists(ATHLETE) and ResourceLoader.exists(KIT)


# --- making a downloaded model behave ------------------------------------------

## Instantiates a model, turns it upright, scales it to `height` and stands it on the
## floor with its feet at the origin.
## Instantiates a model and records the height it should end up. The sizing itself
## happens in settle(), once it is in the tree.
static func _load(path: String, height: float) -> Node3D:
	if not ResourceLoader.exists(path):
		return null
	var scene: PackedScene = load(path)
	if scene == null:
		return null

	var holder := Node3D.new()
	holder.name = path.get_file().get_basename()

	# holder -> pivot -> model. The pivot exists because the upright correction and
	# the scaling have to live on a node the animation cannot reach: these clips are
	# authored Z-up and animate the model root itself, so a rotation put there is
	# thrown away the moment anything starts playing and everybody lies down again.
	var pivot := Node3D.new()
	pivot.name = "Pivot"
	holder.add_child(pivot)

	var model: Node3D = scene.instantiate()
	pivot.add_child(model)
	holder.set_meta("target_height", height)
	holder.set_meta("model_scale", 1.0)
	_set_layer(holder, Figure.PEOPLE_LAYER)
	return holder


## Pulls one named piece out of a model — a racket out of a pack that also contains
## a shuttlecock and two spare rackets — and scales it on its longest side.
static func _part(path: String, part_name: String, length: float) -> Node3D:
	if not ResourceLoader.exists(path):
		return null
	var scene: PackedScene = load(path)
	if scene == null:
		return null

	var whole: Node3D = scene.instantiate()
	var found := _find(whole, part_name)
	if found == null:
		whole.queue_free()
		return null

	# Lift it out of the pack, and throw the rest away.
	var holder := Node3D.new()
	holder.name = part_name
	found.get_parent().remove_child(found)
	found.owner = null
	holder.add_child(found)
	whole.queue_free()

	var box := _bounds(found)
	var longest := maxf(box.size.x, maxf(box.size.y, box.size.z))
	if longest > 0.001:
		found.scale = Vector3.ONE * (length / longest)
		box = _bounds(found)
		found.position -= box.get_center()

	_set_layer(holder, Figure.PEOPLE_LAYER)
	return holder


## Multiplies every material by a colour, which tints a textured model without
## throwing the texture away — setting a material_override would lose it entirely.
static func _tint(node: Node, colour: Color) -> void:
	for child in _every(node):
		if not child is MeshInstance3D or child.mesh == null:
			continue
		for surface in child.mesh.get_surface_count():
			var material: Material = child.mesh.surface_get_material(surface)
			var tinted: StandardMaterial3D
			if material is StandardMaterial3D:
				tinted = material.duplicate()
			else:
				tinted = StandardMaterial3D.new()
			# Multiplying a dark kit by a dark colour gives black. The tint is
			# lightened so the team still reads at a glance, which matters more here
			# than the exact shade of somebody's shirt.
			tinted.albedo_color = colour.lerp(Color.WHITE, 0.30) * 1.35
			child.set_surface_override_material(surface, tinted)


## The size of everything under `node`, in `node`'s own space.
##
## Written as a descent that carries the transform down rather than a walk back up
## the parents, which is what the first version did and got wrong: a model given a
## quarter turn came back with its unrotated size, so it was scaled by the wrong
## dimension and ended up five times too big and still lying on its back.
static func _bounds(node: Node3D) -> AABB:
	var found := _gather(node, Transform3D.IDENTITY, AABB(), [false])
	return found


static func _gather(node: Node, so_far: Transform3D, box: AABB, started: Array) -> AABB:
	var here := so_far
	if node is Node3D:
		here = so_far * (node as Node3D).transform

	if node is MeshInstance3D and node.mesh != null:
		var piece: AABB = here * node.mesh.get_aabb()
		box = piece if not started[0] else box.merge(piece)
		started[0] = true

	for child in node.get_children():
		box = _gather(child, here, box, started)
	return box


static func _set_layer(node: Node, layer: int) -> void:
	for child in _every(node):
		if child is VisualInstance3D:
			child.layers = layer


static func _find(node: Node, wanted: String) -> Node3D:
	for child in _every(node):
		if child.name == wanted and child is Node3D:
			return child
	return null


static func _every(node: Node) -> Array:
	var found := [node]
	for child in node.get_children():
		found.append_array(_every(child))
	return found
