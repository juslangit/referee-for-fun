class_name Sides
extends RefCounted

## The two teams, and which half of the court each of them defends.
##
## RED plays the -Z half, BLUE plays the +Z half. From the umpire's chair RED is on
## the right and BLUE on the left.

enum Team { RED, BLUE, NONE }


static func opponent(team: Team) -> Team:
	match team:
		Team.RED: return Team.BLUE
		Team.BLUE: return Team.RED
		_: return Team.NONE


## Which direction along Z a team's own half lies in.
static func half_sign(team: Team) -> float:
	match team:
		Team.RED: return -1.0
		Team.BLUE: return 1.0
		_: return 0.0


## Whose half a point on the floor belongs to. Points beyond the back line still
## belong to the half they went towards — a shuttle that sails long is out at the
## receiver's end, not nobody's.
static func half_containing(z: float) -> Team:
	return Team.BLUE if z >= 0.0 else Team.RED


static func label(team: Team) -> String:
	match team:
		Team.RED: return "RED"
		Team.BLUE: return "BLUE"
		_: return "NOBODY"


static func colour(team: Team) -> Color:
	match team:
		Team.RED: return Color(0.90, 0.32, 0.30)
		Team.BLUE: return Color(0.36, 0.60, 0.92)
		_: return Color(0.80, 0.80, 0.80)
