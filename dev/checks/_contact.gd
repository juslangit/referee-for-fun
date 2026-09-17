extends Node

## Do the players face the ball, and does the thing they hit it with actually touch it?
##
## The two faults this measures were reported from the chair on 2026-09-17 and neither of
## them could be seen in the code:
##
## **Backs turned.** A player going for a ball behind them turned round and ran away from
## the net, because the body was simply pointed at the heading. Nobody in a net sport does
## that: the ball is in front of you, your eyes stay on it, and you go back on your toes.
## So the worst turn away from square is measured on every frame anybody is moving, and a
## quarter turn past square — the angle at which the ball is behind them — is a failure.
##
## **The implement missing the ball.** Every contact in every sport was struck from
## wherever the ball happened to be, and the swing began on the frame it was struck, so the
## ball left while the racket was still going back. The gap between the ball and the racket
## head, the hand or the kicking foot is measured at the moment of every contact.
##
##     godot --headless --path . res://dev/checks/_contact.tscn --quit-after 120000
##     SPORT=badminton|beach|indoor|tennis|table_tennis|takraw   RALLIES=6
##
## Ends in PASS or FAIL.

## How many rallies of each sport to watch.
const RALLIES := 5

## A quarter turn. Past this the ball a player is going for is behind their back, which is
## the whole of the complaint.
const BACK_TURNED := PI / 2.0

## How far the implement may be from the ball at contact, in metres, at the median.
##
## Not zero, and it should not be: an arm is not a rail, and a ball met a hand's width from
## the middle of a racket face is a contact. Half a metre is not — that is the racket
## somewhere else entirely, which is what this used to measure.
const MEDIAN_GAP_AT_MOST := 0.35

## And the share of contacts that have to be inside a metre, which is what catches a sport
## that is right on average and wrong when it matters.
##
## A share rather than a cap on the worst one, because one sport has a known way of being
## badly wrong occasionally and it is not an animation fault: tennis plays its stroke when
## the ball falls below the strike ceiling on somebody's side, whether or not that somebody
## got there. A player who could not cover the ground still hits it. That is the rally AI's
## business rather than the racket's, and a cap on the worst contact would report it every
## run as though the contact had regressed.
const INSIDE_A_METRE_AT_LEAST := 0.75

## Which contacts count. Every sport rings `Sound.strike` on every contact and nothing else
## does, and the hall counts what it has been asked to play — so the frame that count goes
## up is the frame somebody played the ball. Guessing at it from the ball's velocity does
## not work: a tennis ball bounces on every stroke and a bounce looks exactly like a hit.
const STRIKES := &"strike"

## How far away somebody can be and still be the one who played it. Generous on purpose:
## the whole point is to catch a contact made by a player who is nowhere near it.
const NEAR_A_PLAYER := 3.5

var _problems: Array[String] = []


func _ready() -> void:
	for sport in _sports():
		await _watch(sport)
	print("PASS" if _problems.is_empty() else "FAIL:\n   " + "\n   ".join(_problems))
	get_tree().quit()


func _sports() -> Array:
	var only := OS.get_environment("SPORT")
	var all := ["badminton", "beach", "indoor", "tennis", "table_tennis", "takraw"]
	return [only] if all.has(only) else all


const SCENES := {
	"badminton": ["res://scenes/match.tscn", Career.BADMINTON],
	"beach": ["res://scenes/beach.tscn", Career.BEACH],
	"indoor": ["res://scenes/volleyball.tscn", Career.INDOOR],
	"tennis": ["res://scenes/tennis.tscn", Career.TENNIS],
	"table_tennis": ["res://scenes/table_tennis.tscn", Career.TABLE_TENNIS],
	"takraw": ["res://scenes/sepak_takraw.tscn", Career.TAKRAW],
}


func _watch(sport: String) -> void:
	var arena: Node = load(str(SCENES[sport][0])).instantiate()
	arena.print_truth_while_testing = false
	add_child(arena)
	await get_tree().physics_frame
	arena.career = Career.new()
	arena.career.sport = SCENES[sport][1]
	arena.settings.taught = true
	arena.settings.taught_beach = true
	arena.settings.taught_indoor = true
	arena.settings.taught_tennis = true
	arena.settings.taught_table_tennis = true
	arena.settings.taught_takraw = true
	if arena.has_method("rebuild_players"):
		arena.rebuild_players()
	arena.ui.match_requested.emit()
	await get_tree().process_frame
	if arena.pressure.exists():
		arena.ui.briefing_acknowledged.emit()
		await get_tree().process_frame
	arena.begin_match()
	for f in 4:
		await get_tree().process_frame

	var worst_turn := 0.0
	var turned_away := 0
	var moving_frames := 0
	var gaps: Array[float] = []
	var was_moving := {}
	var strikes_before := 0
	var judged := 0
	var loud := OS.has_environment("EVERY")

	for frame in 40000:
		await get_tree().physics_frame
		var ball: Node3D = arena.ball_in_play()
		if arena._phase == arena.Phase.IN_PLAY and ball != null and is_instance_valid(ball):
			# --- which way are they facing -------------------------------------------
			for player in arena.players:
				var moved: float = player.position.distance_to(
					was_moving.get(player, player.position))
				was_moving[player] = player.position
				if moved < 0.004:
					continue
				moving_frames += 1
				var off: float = absf(wrapf(
					player.rotation.y - player.across_the_net(), -PI, PI))
				worst_turn = maxf(worst_turn, off)
				if off > BACK_TURNED:
					turned_away += 1
			# --- and did the implement touch the ball ---------------------------------
			var struck: int = int(arena.sound.heard.get(STRIKES, 0))
			if struck > strikes_before:
				var gap := _gap_at_the_contact(arena, ball.global_position, loud)
				if gap >= 0.0:
					gaps.append(gap)
			strikes_before = struck
		else:
			strikes_before = int(arena.sound.heard.get(STRIKES, 0))

		if arena._phase == arena.Phase.READY:
			arena.start_rally()
		elif arena._phase == arena.Phase.AWAITING_CALL:
			arena._awaiting_since = Time.get_ticks_msec()
			arena.make_call(&"in" if arena.current_rally().was_in else &"out")
			for f in 3:
				await get_tree().process_frame
			judged += 1
			if judged >= RALLIES or arena.board.is_over:
				break

	gaps.sort()
	var median: float = gaps[gaps.size() / 2] if not gaps.is_empty() else -1.0
	var worst: float = gaps[-1] if not gaps.is_empty() else -1.0
	var close := 0
	for gap in gaps:
		if gap <= 1.0:
			close += 1
	var share := float(close) / maxf(1.0, float(gaps.size()))
	print("%-13s worst turn off square %3.0f deg (%d of %d moving frames past square), "
		% [sport, rad_to_deg(worst_turn), turned_away, moving_frames]
		+ "%d contacts, implement to ball: median %.2f m, %.0f%% inside a metre, worst %.2f m"
		% [gaps.size(), median, share * 100.0, worst])

	if turned_away > 0:
		_problems.append("%s: somebody had their back to the net on %d frames (worst %.0f deg)"
			% [sport, turned_away, rad_to_deg(worst_turn)])
	if gaps.size() < 4:
		_problems.append("%s: only %d contacts seen, too few to judge" % [sport, gaps.size()])
	else:
		if median > MEDIAN_GAP_AT_MOST:
			_problems.append("%s: the implement is %.2f m off the ball at the median contact"
				% [sport, median])
		if share < INSIDE_A_METRE_AT_LEAST:
			_problems.append("%s: only %.0f%% of contacts were inside a metre of the implement"
				% [sport, share * 100.0])

	arena.queue_free()
	await get_tree().process_frame


## How far the ball was from the implement of whoever played it, or -1 when nobody was near
## enough for this to have been a contact at all — which is what a bounce looks like.
func _gap_at_the_contact(arena: Node, ball: Vector3, loud := false) -> float:
	var best := -1.0
	var who: Player = null
	for player in arena.players:
		if player.distance_to(ball) > NEAR_A_PLAYER:
			continue
		var gap: float = player.hitting_point().distance_to(ball)
		if best < 0.0 or gap < best:
			best = gap
			who = player
	if loud and who != null:
		print("   ball %v  %s at %v playing %s, implement at %v, gap %.2f m" % [
			ball, who.name, who.position, who.playing_clip(), who.hitting_point(), best])
	return best
