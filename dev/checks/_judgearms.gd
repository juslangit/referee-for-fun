extends Node

## Can the line judge's arms be found and posed?
##
## The officials are a downloaded model on a different rig from the athletes, so the
## clip pipeline that authored the badminton and volleyball animations does not reach
## them. Their OUT signal is posed in code instead — which only works if the arm bones
## can be found under one of the names some rig somewhere uses for them.

func _ready() -> void:
	var judge := LineJudge.new()
	judge.seated = false
	add_child(judge)
	for f in 4:
		await get_tree().process_frame

	var skeleton := Models.skeleton_of(judge)
	if skeleton == null:
		print("the official has no skeleton — the signal will have to stay a bubble")
		get_tree().quit()
		return

	print("the official's skeleton has %d bones" % skeleton.get_bone_count())
	var arms := Models.arms_of(skeleton)
	for side in ["right", "left"]:
		var at: int = arms[side]
		print("   %-6s arm: %s" % [
			side, skeleton.get_bone_name(at) if at >= 0 else "NOT FOUND"])

	if arms["right"] < 0 and arms["left"] < 0:
		print()
		print("names this rig actually uses, in case none of the guesses fit:")
		for i in skeleton.get_bone_count():
			var name := skeleton.get_bone_name(i)
			if "arm" in name.to_lower() or "shoulder" in name.to_lower():
				print("   %s" % name)
	get_tree().quit()
