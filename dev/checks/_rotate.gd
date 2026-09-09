extends Node

## Does the rotation actually rotate the way volleyball rotates?
##
## This is the piece the whole indoor sport hangs off, and none of it is visible in the
## ball, so it has to be checked as arithmetic before anything is built on it. Four
## questions: does one turn move everybody one place clockwise, does the right person
## end up serving, does the front row change when it should, and does the legality test
## actually reject the arrangements it is supposed to?

func _ready() -> void:
	_one_turn_at_a_time()
	print()
	_who_serves()
	print()
	_the_legality_test()
	get_tree().quit()


func _one_turn_at_a_time() -> void:
	print("six turns puts everybody back where they started")
	var rota := Rotation.new()
	rota.reset()

	print("%-7s %-30s %s" % ["turns", "positions 1..6 hold player", "front row"])
	for turn in 7:
		var holding: Array[String] = []
		var front: Array[String] = []
		for p in range(1, 7):
			holding.append(str(rota.player_in(p)))
			if p in Rotation.FRONT_ROW:
				front.append(str(rota.player_in(p)))
		print("%-7d %-30s %s" % [rota.turns, ", ".join(holding), ", ".join(front)])
		rota.rotate()

	rota.reset()
	var before := rota.player_in(2)
	rota.rotate()
	print("  the player in position 2 moves to position 1: %s" % [
		"yes" if rota.player_in(1) == before else "NO"])


func _who_serves() -> void:
	print("the server is whoever is in position 1")
	var rota := Rotation.new()
	rota.reset()
	var seen: Array[String] = []
	for turn in 6:
		seen.append(str(rota.server()))
		rota.rotate()
	print("  over six turns, the serve passes to: %s" % ", ".join(seen))
	print("  everybody served exactly once: %s" % [
		"yes" if _all_different(seen) else "NO"])


func _all_different(values: Array[String]) -> bool:
	var seen := {}
	for v in values:
		if seen.has(v):
			return false
		seen[v] = true
	return true


func _the_legality_test() -> void:
	print("the positional rules, and what breaks them")
	var rota := Rotation.new()
	rota.reset()

	var proper := rota.spots(true)
	print("  the six standing where the rules put them:      %s" % [
		"legal" if rota.is_legal(proper) else "ILLEGAL — the spots themselves are wrong"])

	var receiving := rota.spots(false)
	print("  the same six spread out to receive a serve:     %s" % [
		"legal" if rota.is_legal(receiving) else "ILLEGAL — reception broke a relationship"])

	# A front-row player standing behind their own back-row player.
	var overlapped := proper.duplicate()
	var front: int = rota.player_in(3)
	var back: int = rota.player_in(6)
	var swap: Vector2 = overlapped[front]
	overlapped[front] = overlapped[back]
	overlapped[back] = swap
	print("  centre front and centre back swapped:           %s" % [
		"legal — THE TEST IS BLIND" if rota.is_legal(overlapped) else "illegal, correctly"])

	# Two players in the same row the wrong way round.
	var crossed := proper.duplicate()
	var left: int = rota.player_in(4)
	var right: int = rota.player_in(2)
	var across: Vector2 = crossed[left]
	crossed[left] = crossed[right]
	crossed[right] = across
	print("  left front and right front crossed over:        %s" % [
		"legal — THE TEST IS BLIND" if rota.is_legal(crossed) else "illegal, correctly"])
