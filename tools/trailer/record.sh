#!/usr/bin/env bash
# Records every shot of the trailer, straight out of the running game.
#
#   tools/trailer/record.sh
#
# Each line is one shot: name, scene, what it does, how many seconds of finished footage.
# `--write-movie` forces a fixed frame rate, so a shot recorded twice is the same shot.
# Recording runs at roughly a third of real time, so the whole set takes a few minutes.
set -u
GODOT=/Applications/Godot.app/Contents/MacOS/Godot
OUT=build/trailer
mkdir -p "$OUT"

shots=(
  "open|res://scenes/match.tscn|rally|7"
  "brief|res://scenes/match.tscn|brief|5"
  "honest|res://scenes/match.tscn|rally|9"
  "lie|res://scenes/match.tscn|lie|13"
  "tennis|res://scenes/tennis.tscn|rally|5"
  "volley|res://scenes/volleyball.tscn|rally|5"
  "beach|res://scenes/beach.tscn|rally|5"
  "tabletennis|res://scenes/table_tennis.tscn|rally|5"
  "takraw|res://scenes/sepak_takraw.tscn|rally|5"
  "career|res://scenes/match.tscn|career|5"
  "ending|res://scenes/match.tscn|ending|7"
)

for row in "${shots[@]}"; do
  IFS='|' read -r name scene shot seconds <<< "$row"
  frames=$(( (seconds + 8) * 60 ))
  printf '%-14s %s ' "$name" "${seconds}s"
  SHOT="$shot" SCENE="$scene" TIER=4 SECONDS="$seconds" \
    "$GODOT" --path . res://dev/trailer/_shot.tscn \
      --write-movie "$OUT/t_$name.avi" --fixed-fps 60 --quit-after "$frames" \
      > "/tmp/trailer_$name.log" 2>&1
  grep -a "movie length" "/tmp/trailer_$name.log" | head -1 || echo "FAILED"
done
