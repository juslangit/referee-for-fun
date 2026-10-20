"""The beach grandstands: temporary scaffold seating down both sides of the sand.

Modelled on the stands at a World Tour stop such as Pantai Cenang, Langkawi: aluminium
decks and bench planks on a galvanised scaffold you can see through from the side, a
white sponsor wrap round the back and the open ends, a guard rail along the top, and a
flight of steps up each gangway.

The stand the umpire looks at (-x) is kept low, six rows, so the sea and the horizon stay
in the picture over the heads of the crowd; the one behind the chair (+x) is ten rows and
only seen in the wide shots. Nobody sits on a seat of their own — they sit on the planks
(`benches` in the JSON), which is what these stands have.
"""

import lib


def materials():
    return {
        "deck": lib.plain("deck", (0.70, 0.72, 0.74, 1), 0.45, 0.7),
        "plank": lib.plain("plank", (0.80, 0.82, 0.84, 1), 0.35, 0.8),
        "scaffold": lib.plain("scaffold", (0.55, 0.57, 0.58, 1), 0.4, 0.85),
        "wrap": lib.picture("wrap", lib.TEXTURES + "/wrap_beach.png"),
        "fabric": lib.plain("fabric", (0.95, 0.95, 0.94, 1), 0.8),
        "nosing": lib.plain("nosing", (0.95, 0.75, 0.10, 1), 0.6),
        "boards": lib.plain("boards", (0.62, 0.48, 0.32, 1), 0.85),
    }


UV_METRES = {"wrap": 16.0}
