# dev

Scenes that exist to look at the game rather than to be part of it.

None of these ship. Each one loads `scenes/match.tscn`, drives it from the outside, and
either prints numbers or saves a picture into `shots/`. They live here because a game
about millimetres cannot be checked by eye, and almost every real bug in this project was
found by one of them printing something that disagreed with what the screen appeared to
show — a shuttle landing a centimetre inside the floor, a crowd stretched five times its
height, a racket balanced across a player's fist, a whistle that measured 0 Hz.

Run one with:

    /Applications/Godot.app/Contents/MacOS/Godot --path . res://dev/_fairplay.tscn --quit-after 20000

The ones worth keeping in mind:

| scene | what it answers |
|---|---|
| `_fairplay` | Does an honest umpire get punished? Plays a match calling only the truth, then again calling every fault, and reports the suspicion each ends on. Set `UMPIRE=perfect` for the second. |
| `_aimcheck` | Can a player land a shuttle on a line? Reports the miss in millimetres against a line 40 mm wide. |
| `_flow` | Does the front end still reach a rally? Presses only the things a player can press. |
| `_teach` | The lesson, page by page, and whether a first-timer is shown it unasked. |
| `_menus` | The three front-of-game screens. |
| `_seat`, `_layout`, `_close` | The hall from the chair, from above, and up close. `TIER=0..2` picks the venue. |
| `_card`, `_courtmap` | Regenerate the artwork in `assets/ui/`. |
| `_rotation` | Does the serve come from the right service court and cross the right diagonal? 400 serves, 50 per score per side. |
| `_pressure` | The four reasons to lie: how often each turns up, what it does to a career, whether a grudge follows you into the next match, and — the one that matters — whether an honest umpire is still able to climb. |
| `_debt` | Does the umpire's own first visible mistake trap them? Checks both that the trap fires and that it never fires on a call the hall could not see. |
| `_props`, `_people` | Every downloaded model in a row, at the size it is used, so a model that arrived upside down is seen before three hundred of it are put in the stands. |

`shots/` is where they write. It is ignored by git — the pictures are output, not source.
