#!/usr/bin/env bash
# One approved T-pose drawing to a rigged, animated character in the game's format.
#
#   tools/tripo/build_person.sh <name> <drawing.png> <faces> <height_m>
#
# Tripo (about 40 credits) -> upright -> Meshy rig (5) -> clean_rig realistic -> rig_clips.
# Each paid step records its task first, so running it again resumes instead of paying.
set -euo pipefail
name=$1 image=$2 faces=$3 height=$4
B=/Applications/Blender.app/Contents/MacOS/Blender
square="${image%.png}_square.png"
python3 - "$image" "$square" <<'PY'
import sys
from PIL import Image
im = Image.open(sys.argv[1]).convert("RGB")
side = max(im.size)
sq = Image.new("RGB", (side, side), im.getpixel((5, 5)))
sq.paste(im, ((side - im.width) // 2, (side - im.height) // 2))
sq.save(sys.argv[2])
PY
python3 tools/tripo/tripo.py make "$name" "$square" --faces "$faces" | tail -1
$B --background --python tools/tripo/upright.py -- "assets/tripo/$name/$name.glb" \
  "assets/tripo/$name/${name}_upright.glb" -90 2>&1 | grep -E "SIZE|Error" || true
python3 tools/tripo/rig_person.py "$name" "$height" | tail -1
$B --background --python tools/tripo/clean_rig.py -- "$name" realistic 2>&1 | grep -E "rror|wrote" || true
$B --background --python tools/meshy/rig_clips.py -- "$name" 2>&1 | grep -E "rror|missing|wrote|export" | tail -3 || true
ls -la "assets/meshy/$name/${name}_animated.glb"
