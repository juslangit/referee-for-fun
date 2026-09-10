class_name TableTennisSpec
extends RefCounted

## The table, in metres, and what counts as on it.
##
## ITTF: 2.74 by 1.525, standing 76 cm off the floor, with a net 15.25 cm high. It is the
## smallest playing surface in this game by a wide margin — a tennis court is thirty
## times its area — and that is the whole reason the sport is worth refereeing. Everything
## happens inside two and a half metres, at up to 25 m/s, a few feet from the umpire.

const HALF_LENGTH := 1.37
const HALF_WIDTH := 0.7625
const HEIGHT := 0.76

## The net: low, and the full width of the table plus a little each side.
const NET_HEIGHT := 0.1525
const NET_OVERHANG := 0.1525

## The white line down the middle. It matters only in doubles, where the serve must
## cross it diagonally, and is painted in singles anyway.
const CENTRE_LINE_WIDTH := 0.003
const LINE_WIDTH := 0.02

## How much of the edge counts as the edge.
##
## **The edge ball is this sport's own call, and it is a hair's breadth wide.** A ball
## that clips the top edge of the table is IN, and one that clips the vertical side below
## it is OUT — and the two are separated by the thickness of the tabletop, about two
## centimetres. It is decided by a sound and a deflection, at speed, and the umpire is the
## only person in the room at table height.
const EDGE_BAND := 0.02

const LINE_TOLERANCE := 0.0001


## Whether the ball landed on the table at all.
static func is_in(landing: Vector3) -> bool:
	return (
		absf(landing.x) <= HALF_WIDTH + LINE_TOLERANCE
		and absf(landing.z) <= HALF_LENGTH + LINE_TOLERANCE
	)


## How far from the nearest edge, in metres. Positive on the table, negative off it.
static func margin(landing: Vector3) -> float:
	var slack_x := HALF_WIDTH - absf(landing.x)
	var slack_z := HALF_LENGTH - absf(landing.z)
	if slack_x < 0.0 or slack_z < 0.0:
		var over := Vector2(maxf(0.0, -slack_x), maxf(0.0, -slack_z))
		return -over.length()
	return minf(slack_x, slack_z)


## Whether this landing was on the edge itself, either just on or just off.
##
## Both are within a couple of centimetres of the same place and sound almost the same.
## Which of the two it was decides the point, and nobody but the umpire has a view of it.
static func on_the_edge(landing: Vector3) -> bool:
	return absf(margin(landing)) <= EDGE_BAND


## Whether a serve landed correctly: once on the server's own half, then over.
static func is_a_good_serve(first: Vector3, second: Vector3, from: float) -> bool:
	if not is_in(first) or not is_in(second):
		return false
	if signf(first.z) != signf(from):
		return false
	return signf(second.z) == -signf(from)
