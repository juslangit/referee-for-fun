#!/usr/bin/env python3
"""Repaints the shirt on a Meshy character's texture, leaving skin and shorts alone.

    tools/meshy/recolour_kit.py player_red  libero 52
    tools/meshy/recolour_kit.py player_blue libero 52 220

Why this exists
---------------
The libero has to be identifiable at a glance — that is the entire reason the
different-shirt rule exists in the sport. The game used to do it by strapping a
`BoxMesh` to the chest bone (`Models.wear_bib`), and it looked like exactly what it
was: a block. Luqman, 2026-09-17, on a screenshot of it: "change to different cloth,
dont put block like that".

The comment above `wear_bib` gives the reason it was a box: a material tint multiplies
the whole texture, so tinting a red kit yellow gives a dirty red rather than a yellow
shirt — and it would stain the skin and the shorts with it too.

The answer is to repaint the shirt in the texture rather than tint the model. The kit
is painted into one 2048x2048 PNG in clearly separated regions — the shirt sits around
rgb(186, 62, 61), the shorts around rgb(59, 60, 70), the skin around rgb(239, 196, 170)
— so the shirt can be selected on its own and given a new hue.

Hue only. Saturation and value are kept exactly as they were, so every fold, seam and
shadow painted into the fabric survives the change; the shirt looks like the same
garment in another colour rather than a flat patch of paint. Selecting on "much more
red than green or blue" is what keeps the skin out of it: skin is only 1.2x redder
than it is green, while the shirt is 3x.
"""

import colorsys
import pathlib
import sys

from PIL import Image

HERE = pathlib.Path(__file__).resolve().parent
ASSETS = HERE.parent.parent / "assets" / "meshy"

## A shirt is found by its hue and by being a proper colour rather than a shade.
##
## The first version selected "much redder than green or blue", which worked on the red
## kit and found 318 pixels of the blue one — the rule described red rather than
## describing a shirt. Hue plus saturation describes a shirt: the red kit sits near 0
## degrees, the blue at 220, and the things that must not be repainted are all excluded
## by saturation alone — skin is 0.32, the white trim and the grey shoes are under 0.05.
HUE_TOLERANCE = 32.0
MIN_SATURATION = 0.45
MIN_VALUE = 0.12

## The shoes carry red flashes and are caught by the same rule, which turned them the
## shirt's new colour along with it. They live in a known band of the sheet, so they are
## simply excluded: UV space here puts the feet in the bottom fifth.
SHOE_BAND = 0.80

## A rotated hue alone is not enough. The kit's red is deep, and keeping its saturation
## and value gives a deep version of the new hue — a red shirt turned to hue 48 comes out
## orange rather than yellow, which is no use to a libero who has to be told apart from a
## team-mate in red at a glance. So saturation and value are pulled towards a floor as
## well, which lifts the garment to a kit colour while the *relative* light and shade of
## every fold is preserved.
LIFT_TO_VALUE = 0.92
LIFT_TO_SATURATION = 0.88
LIFT = 0.6


def _apart(a: float, b: float) -> float:
    """Degrees between two hues, the short way round the wheel."""
    gap = abs(a - b) % 360.0
    return min(gap, 360.0 - gap)


def repaint(source: Image.Image, hue: float, from_hue: float) -> tuple[Image.Image, int]:
    out = source.copy().convert("RGB")
    px = out.load()
    w, h = out.size
    floor_y = int(h * SHOE_BAND)
    touched = 0
    for y in range(h):
        if y >= floor_y:
            continue
        for x in range(w):
            r, g, b = px[x, y]
            hue_here, s, v = colorsys.rgb_to_hsv(r / 255.0, g / 255.0, b / 255.0)
            if s < MIN_SATURATION or v < MIN_VALUE:
                continue
            if _apart(hue_here * 360.0, from_hue) > HUE_TOLERANCE:
                continue
            # Towards a kit colour, not merely rotated. The lerp keeps the difference
            # between a lit fold and a shadowed one, so the fabric still reads as fabric.
            s = s + (LIFT_TO_SATURATION - s) * LIFT
            v = v + (LIFT_TO_VALUE - v) * LIFT
            nr, ng, nb = colorsys.hsv_to_rgb(hue, min(1.0, s), min(1.0, v))
            px[x, y] = (int(nr * 255), int(ng * 255), int(nb * 255))
            touched += 1
    return out, touched


def main() -> None:
    if len(sys.argv) < 4:
        sys.exit(__doc__)
    name, label, degrees = sys.argv[1], sys.argv[2], float(sys.argv[3])
    # Which kit is being repainted. Red sits at 0, the blue kit at 220.
    from_hue = float(sys.argv[4]) if len(sys.argv) > 4 else 0.0
    source = ASSETS / name / f"{name}_animated_texture_0.png"
    if not source.exists():
        sys.exit(f"no texture at {source}")
    out_dir = ASSETS / f"{name}_{label}"
    out_dir.mkdir(parents=True, exist_ok=True)
    target = out_dir / f"{name}_{label}_texture.png"

    image = Image.open(source)
    painted, touched = repaint(image, degrees / 360.0, from_hue)
    painted.save(target)
    share = 100.0 * touched / (image.size[0] * image.size[1])
    print(f"repainted {touched} pixels ({share:.1f}% of the sheet) to hue {degrees:.0f}")
    print(f"wrote {target.relative_to(ASSETS.parent.parent)}")


if __name__ == "__main__":
    main()
