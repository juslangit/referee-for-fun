"""Builds one of the game's venues in Blender and exports it for the game.

Run inside the shared Blender, through the MCP (never a headless Blender of its own):

    REPO = "<repo>"; VENUE = "badminton_arena"
    exec(open(REPO + "/tools/stadium/build_stadium.py").read())

`VENUE` names a file in `assets/stadium/` (`tennis_stadium` if it is not set). That JSON
holds every number the venue is built from, and its `builder` names the module in
`tools/stadium/venues/` that models it. The game reads the same JSON (`scripts/bowl.gd`)
to seat the crowd on the steps, so change a venue there, re-run this, and both follow.

Each venue is built in a scene of its own, so whatever else is open in that Blender is
left alone. It writes `assets/stadium/<venue>.glb` and saves that scene alone to
`tools/stadium/<venue>.blend`.

The shared parts — the row maths, the mesh builder, the materials, the export — are in
`tools/stadium/lib.py`.
"""

import importlib
import json
import os
import sys

REPO = globals().get("REPO") or os.path.expanduser("~/Desktop/projects/game/referee-for-fun")
VENUE = globals().get("VENUE") or "tennis_stadium"

_here = os.path.join(REPO, "tools/stadium")
if _here not in sys.path:
    sys.path.insert(0, _here)
import lib  # noqa: E402

importlib.reload(lib)
_builder = json.load(open(os.path.join(REPO, "assets/stadium", VENUE + ".json")))["builder"]
_module = importlib.import_module("venues." + _builder)
importlib.reload(_module)
lib.run(REPO, VENUE, _module.build, _module.materials, _module.UV_METRES,
        scene=getattr(_module, "SCENE", None))
