# Referee For Fun

A 3D game where you are the referee, not the athlete.

You sit in the umpire's chair. The match is simulated in front of you with real
physics, so the game always knows exactly where the shuttle landed. You do not have
to tell it. Pick a team to favour before the match and bend every close call their
way — the only thing stopping you is how much suspicion the crowd, the players and
the coaches will tolerate.

Badminton first. Volleyball second.

- **Engine:** Godot 4.7.2, GDScript
- **Platform:** desktop, keyboard + mouse
- **Notes:** `~/.claude/knowledge/projects/referee-for-fun/`

## Folders
| Folder | Contents |
|---|---|
| `scenes/` | `match.tscn` — the one scene the game runs. Everything else is built in code. |
| `scripts/` | All the GDScript: the rally, the calls, suspicion, the hall, the interface. |
| `assets/` | Models, audio and interface art, filed by where each came from. |
| `tools/` | Scripts that *make* assets — Blender, Meshy and the sound synthesiser. Not shipped. |
| `dev/` | Scenes that look at the game rather than being part of it. See `dev/README.md`. |

Nothing lives in the project root except this file, `CREDITS.md` and `project.godot`.
