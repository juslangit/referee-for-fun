---
workflow: general-video
flow: automation
storyboard: no
message: "You are the umpire, not the athlete — and every close call is yours to bend."
destination: website + itch-style game page + release asset
aspect: 1920x1080
language: en
length: 90s
angle: same story as the v0.2.1 trailer, re-recorded on v0.3.0
---

## Intent

The v0.3.0 trailer for Referee For Fun, replacing the v0.2.1 one (Luqman, 2026-10-21: "the trailer is
old, create a new one"). Same arc that worked: every sports game puts you on the court → this one puts
you in the chair → the rally is real → somebody tells you who they would like to win → you bend the
calls → the hall notices → six sports, one reputation → thrown off → "how long before somebody
notices?". Sly, a little comic, broadcast-sports in look.

## Assets

- `../../../build/trailer/t_*.avi` — shots recorded out of the running game by `tools/trailer/record.sh`
  (Godot movie writer, 60 fps, with game audio). Nothing staged. Converted to `assets/shots/*.mp4`.
- `../music/quirky_cinematic_song.flac` — music bed, Freesound 701691, CC0. Builds from -28 dB to -12 dB by 85 s.
- `../../../assets/fonts/BarlowCondensed-Bold.ttf` — the game's own display face.
- `../../../assets/ui/title_logo.png` — the game logo (white outline type, transparent).

## Customizations

- Animated HyperFrames titles (not static cards): type that slams in, a broadcast score-bar wipe, the
  reputation number counting down, the logo lock-up at the end.
- New CC0 music bed, kept under the game's own crowd, whistle and commentary.

## Notes

- About 90 s. Game sound must stay audible: the music is a bed, not the lead.
- Show the new v0.3.0 venues: a community hall at the bottom of the ladder and the arenas at the top.
