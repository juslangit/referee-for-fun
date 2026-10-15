#!/usr/bin/env python3
"""Flattens a Tripo texture to the concept's own palette.

    tools/tripo/flatten_texture.py <in.png> <out.png>

Why: Tripo bakes noise, soft lighting and brown smudges into its textures (streaks down
the legs, smears on the jaw). Style C, the one Luqman chose on 2026-10-15, is flat clean
colour, so each texel is snapped to the nearest colour of a palette measured off the
approved concept (`dev/concepts/2026-10-15/athlete_C_blue_single.png`), then specks are
voted away with a mode filter. The palette is the blue kit's; the other kits are
repainted from this one afterwards, so they inherit the clean sheet.
"""

import sys

from PIL import Image, ImageFilter

PALETTE = [
    (215, 161, 125),   # skin
    (186, 132, 104),   # skin in shade: knees, ears, under the jaw
    (48, 82, 179),     # kit
    (32, 54, 146),     # kit trim and side panels
    (24, 40, 122),     # shorts in shade
    (105, 64, 44),     # hair
    (236, 236, 232),   # socks, eye whites
    (38, 30, 30),      # eyes, brows
    (150, 92, 78),     # mouth
]
SIZE = 2048


def nearest(rgb):
    r, g, b = rgb
    # Weighted RGB distance: close enough to perceptual for nine well-spaced colours.
    return min(PALETTE, key=lambda p: 2 * (p[0] - r) ** 2 + 4 * (p[1] - g) ** 2 + 3 * (p[2] - b) ** 2)


def main():
    src = Image.open(sys.argv[1]).convert("RGB").resize((SIZE, SIZE), Image.LANCZOS)
    src = src.filter(ImageFilter.MedianFilter(3))
    lut = {}
    out = src.copy()
    px = out.load()
    for y in range(SIZE):
        for x in range(SIZE):
            c = px[x, y]
            key = (c[0] >> 2, c[1] >> 2, c[2] >> 2)
            if key not in lut:
                lut[key] = nearest(c)
            px[x, y] = lut[key]
    out = out.filter(ImageFilter.ModeFilter(5))
    out.save(sys.argv[2])
    print(f"wrote {sys.argv[2]}")


if __name__ == "__main__":
    main()
