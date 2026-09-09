class_name Rotation
extends RefCounted

## Six players, six positions, and the order they are allowed to stand in.
##
## This is the bookkeeping a real second referee keeps on a sheet of paper, and it is
## the thing that makes indoor volleyball harder to officiate than any other sport in
## this game. Nothing about it is visible in the ball. It is entirely about where six
## people are standing at the instant of contact, relative to each other, according to
## an order fixed at the start of the set.
##
## The court positions are numbered the way the sport numbers them, which is not the way
## anybody would number them from scratch — they run anticlockwise from the server's
## corner:
##
##       4    3    2        <- front row, nearest the net
##       5    6    1        <- back row, 1 is the server's corner
##
## Rotation goes the other way: when a side wins back the serve, everybody moves one
## place **clockwise**, so the player in 2 goes to 1, 1 goes to 6, 6 goes to 5, and so
## on. That is why a lineup written as positions 1..6 rotates by *subtracting* one.
##
## Two things follow from this and they are the whole of the refereeing:
##
##   **Who serves.** Whoever is in position 1. Serving out of turn is a fault, and it
##   is invisible unless you know the order.
##
##   **Where everybody may stand.** At the moment the ball is struck for service, each
##   front-row player must have at least one foot nearer the net than their opposite
##   back-row player, and within each row the left, centre and right must be in that
##   order. Only at that instant — the moment the serve is contacted, everybody may go
##   wherever they like.

## Position numbers, in rotation order. Index 0 holds whoever is in position 1.
const POSITIONS := 6

## Which positions are front row. The three nearest the net.
const FRONT_ROW := [2, 3, 4]

## Which back-row position sits behind each front-row one. These three pairs are the
## whole of the front-to-back rule: 4 in front of 5, 3 in front of 6, 2 in front of 1.
const BEHIND := {4: 5, 3: 6, 2: 1}

## Where each position stands, as a fraction of the half court: x across, z back from
## the net. Multiplied out by the court, so this reads as a diagram rather than metres.
const SPOTS := {
	1: Vector2(-0.62, 0.74),
	2: Vector2(-0.62, 0.26),
	3: Vector2(0.0, 0.22),
	4: Vector2(0.62, 0.26),
	5: Vector2(0.62, 0.74),
	6: Vector2(0.0, 0.80),
}

## The six players of one side, in the order they rotate. This never changes during a
## set; what changes is how far it has turned.
var lineup: Array[int] = [0, 1, 2, 3, 4, 5]

## How many times this side has rotated. Only ever goes up.
var turns := 0

## Which of the six is the libero, or -1. The libero is not part of the rotation — they
## come on for a back-row player and go off again — so for placement they simply take
## the place of whoever they replaced.
var libero := -1


func reset(with_libero := -1) -> void:
	lineup = [0, 1, 2, 3, 4, 5]
	turns = 0
	libero = with_libero


## One place clockwise. Called when this side wins the serve back, never when they hold
## it — a side that keeps serving does not rotate, which is the rule most people who
## have played casually get wrong.
func rotate() -> void:
	turns += 1


## Which player is standing in a given position right now.
##
## Rotating clockwise means the lineup slides the other way, so position `p` is held by
## whoever started `turns` places further along it.
func player_in(position: int) -> int:
	var index := (position - 1 + turns) % POSITIONS
	return lineup[index]


## Which position a given player is standing in.
func position_of(player: int) -> int:
	for p in range(1, POSITIONS + 1):
		if player_in(p) == player:
			return p
	return 0


## Whoever is in position 1, and therefore the only player allowed to serve.
func server() -> int:
	return player_in(1)


func is_front_row(player: int) -> bool:
	return position_of(player) in FRONT_ROW


## Where each of the six should be standing for the serve, as court fractions keyed by
## player. `serving` spreads the receiving side out to receive instead, because a side
## waiting for a serve does not stand in its rotational spots — it stands in a
## reception formation, and only the *relationships* have to survive.
func spots(serving: bool) -> Dictionary:
	var placed := {}
	for p in range(1, POSITIONS + 1):
		var where: Vector2 = SPOTS[p]
		if not serving:
			# Receiving: everybody drops a little and spreads, which is what a passing
			# formation looks like without breaking a single positional relationship.
			where = Vector2(where.x * 1.12, clampf(where.y + 0.10, 0.20, 0.92))
		placed[player_in(p)] = where
	return placed


## Whether the six, as placed, actually satisfy the rules they are meant to.
##
## Used by the game to check its own honesty: when it decides to commit a positional
## fault it swaps two players, and this is what confirms the swap really did break
## something. A fault the rules cannot see is not a fault, it is a bug.
func is_legal(placed: Dictionary) -> bool:
	for p in range(1, POSITIONS + 1):
		var front := p in FRONT_ROW
		var here: Vector2 = placed.get(player_in(p), Vector2.ZERO)

		# Each front-row player must be nearer the net than the back-row player behind
		# them. The pairs are 4-5, 3-6 and 2-1.
		var behind: int = BEHIND.get(p, 0)
		if front and behind != 0:
			var back: Vector2 = placed.get(player_in(behind), Vector2.ZERO)
			if here.y >= back.y:
				return false

	# And within each row, left, centre and right must be in that order across the court.
	for row in [[4, 3, 2], [5, 6, 1]]:
		var left: Vector2 = placed.get(player_in(row[0]), Vector2.ZERO)
		var middle: Vector2 = placed.get(player_in(row[1]), Vector2.ZERO)
		var right: Vector2 = placed.get(player_in(row[2]), Vector2.ZERO)
		if not (left.x > middle.x and middle.x > right.x):
			return false

	return true
