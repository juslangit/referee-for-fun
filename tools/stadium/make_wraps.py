"""Prints the sponsor wraps that the venues hang on their stands: a strip of the event's own
invented sponsors (assets/events/sponsor_*.png) on a coloured vinyl, as one texture.

    python3 tools/stadium/make_wraps.py

Writes tools/stadium/textures/wrap_<name>.png, which the venue builders load. Run it again
after changing a sponsor logo.
"""

import os

from PIL import Image

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
EVENTS = os.path.join(REPO, "assets/events")
OUT = os.path.join(REPO, "tools/stadium/textures")

# name: (background RGB, sponsors left to right, also the event logo every so often)
WRAPS = {
    "beach": ((246, 246, 244), ["cuti_cuti_nusa", "segar", "rajawali_air", "teratai_hotels",
                                "kopi_kampung", "pelangi_pay"], "logo_beach"),
    "badminton": ((14, 18, 30), ["seri_bank", "kenari_telekom", "segar", "teras_energy",
                                 "pelangi_pay", "bayu_motor"], "logo_badminton"),
    "volleyball": ((240, 240, 238), ["teras_energy", "bayu_motor", "kopi_kampung", "rimba_sports",
                                     "segar", "seri_bank", "sinar_elektrik"], "logo_indoor"),
    "takraw": ((246, 246, 246), ["kenari_telekom", "rimba_sports", "seri_bank", "pelangi_pay",
                                 "segar", "kopi_kampung", "teras_energy"], "logo_sepak_takraw"),
    "table_tennis": ((150, 66, 72), ["pelangi_pay", "sinar_elektrik", "kenari_telekom", "seri_bank",
                                     "segar", "teras_energy"], "logo_table_tennis"),
}

TILE_H = 256
TILE_W = 512


def make(name, background, sponsors, logo):
    names = []
    for i, s in enumerate(sponsors):
        names.append("sponsor_" + s)
        if i % 3 == 2:
            names.append(logo)
    strip = Image.new("RGBA", (TILE_W * len(names), TILE_H), background + (255,))
    for i, n in enumerate(names):
        art = Image.open(os.path.join(EVENTS, n + ".png")).convert("RGBA")
        scale = min((TILE_W - 80) / art.width, (TILE_H - 50) / art.height)
        art = art.resize((max(1, int(art.width * scale)), max(1, int(art.height * scale))), Image.LANCZOS)
        x = i * TILE_W + (TILE_W - art.width) // 2
        y = (TILE_H - art.height) // 2
        strip.alpha_composite(art, (x, y))
    path = os.path.join(OUT, f"wrap_{name}.png")
    strip.convert("RGB").save(path)
    print(path, strip.size)


if __name__ == "__main__":
    for name, (bg, sponsors, logo) in WRAPS.items():
        make(name, bg, sponsors, logo)
