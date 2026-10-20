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

import math

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

# How far apart the scaffold's standards are along the stand.
BAY = 2.4


def build(b, plan):
    for tier in plan["tiers"]:
        for run in tier["runs"]:
            _stand(b, plan, tier, run)


def _stand(b, plan, tier, run):
    rows, depth, rise, base, first = (tier["rows"], tier["depth"], tier["rise"], tier["base"],
                                      tier["first_offset"])
    lo, hi = run["from"], run["to"]
    gaps = tier.get("gaps", [])
    gap_w = plan["aisles"]["width"]
    nx, nz = plan.run_normal(run)
    yaw = math.atan2(nx, nz)

    def P(along, d, y):
        return plan.run_point(run, along, d, y)

    # Decks and bench planks, row by row. Each deck is a tread; the plank sits just behind
    # the middle of it at seat height, which is where a seated person's hips are.
    for r in range(rows):
        d0 = first + depth * r
        d1 = d0 + depth
        y = base + rise * (r + 1)
        b.run_band("deck", run, d0, y, d1, y, "up")
        b.run_band("deck", run, d0, y - 0.05, d0, y, "in")
        # The bench, broken at each gangway.
        cuts = [lo] + sum(([g - gap_w * 0.5, g + gap_w * 0.5] for g in gaps), []) + [hi]
        for k in range(0, len(cuts), 2):
            a0, a1 = cuts[k], cuts[k + 1]
            seat_d = d0 + depth * 0.62
            b.run_band("plank", run, seat_d - 0.15, y + 0.43, seat_d + 0.15, y + 0.43, "up",
                       along=(a0, a1))
            b.run_band("plank", run, seat_d - 0.15, y + 0.39, seat_d - 0.15, y + 0.43, "in",
                       along=(a0, a1))
            # Its legs, a pair every bay.
            a = a0 + 0.3
            while a < a1:
                b.box("scaffold", P(a, seat_d, y + 0.21), (0.05, 0.42, 0.05), yaw)
                a += BAY

    # A step up each gangway: a half-height block on every row, nosed in yellow.
    for g in gaps:
        for r in range(rows):
            d0 = first + depth * r
            y = base + rise * (r + 1)
            c = P(g, d0 + depth * 0.75, y + rise * 0.25)
            b.box("deck", c, (gap_w, rise * 0.5, depth * 0.5), yaw)
            for edge, top in ((d0 + 0.02, y), (d0 + depth * 0.5 + 0.02, y + rise * 0.5)):
                b.box("nosing", P(g, edge, top + 0.004), (gap_w * 0.96, 0.01, 0.04), yaw)
        # The first step, from the sand up to the front deck.
        b.box("deck", P(g, first - 0.25, (base + rise) * 0.5), (gap_w, base + rise, 0.5), yaw)

    # The scaffold underneath: a standard under every other row line in every bay, ledgers
    # tying them along and across, and a brace in alternate bays of the back.
    top = base + rise * rows
    back = first + depth * rows
    lines = [first + depth * r for r in range(0, rows + 1, 2)]
    if lines[-1] < back - 0.01:
        lines.append(back)
    stations = []
    a = lo + 0.15
    while a < hi:
        stations.append(a)
        a += BAY
    stations.append(hi - 0.15)

    def height_at(d):
        r = max(0, min(rows - 1, int((d - first) / depth - 1e-6)))
        return base + rise * (r + 1)

    for d in lines:
        h = height_at(d) - 0.05
        for a in stations:
            b.tube("scaffold", P(a, d, 0.0), P(a, d, h), 0.024)
        for y in (0.15, h * 0.5):
            if y < h:
                b.tube("scaffold", P(stations[0], d, y), P(stations[-1], d, y), 0.02)
    for a in stations:
        for i in range(len(lines) - 1):
            d_a, d_b = lines[i], lines[i + 1]
            y = min(height_at(d_a), height_at(d_b)) - 0.1
            b.tube("scaffold", P(a, d_a, y), P(a, d_b, y), 0.02)
            b.tube("scaffold", P(a, d_a, 0.15), P(a, d_b, 0.15), 0.02)
    for k in range(len(stations) - 1):
        if k % 2 == 0:
            b.tube("scaffold", P(stations[k], back, 0.15), P(stations[k + 1], back, top - 0.3), 0.02)

    # The guard rail along the top and down both open ends.
    rail = top + 1.05
    for a in stations:
        b.tube("scaffold", P(a, back - 0.05, top), P(a, back - 0.05, rail), 0.024)
    for y in (top + 0.5, rail):
        b.tube("scaffold", P(lo, back - 0.05, y), P(hi, back - 0.05, y), 0.024)
    for end_along in (lo, hi):
        for r in range(rows):
            d0 = first + depth * r
            y = base + rise * (r + 1)
            b.tube("scaffold", P(end_along, d0 + 0.05, y), P(end_along, d0 + 0.05, y + 1.0), 0.02)
        b.tube("scaffold", P(end_along, first + 0.05, base + rise + 1.0),
               P(end_along, back - 0.05, top + 1.0), 0.022)

    # The sponsor wrap: round the back from the sand to the top deck, and over the two
    # ends, which is what hides the scaffold from the rest of the beach.
    b.run_band("wrap", run, back + 0.06, 0.0, back + 0.06, top, "out")
    b.run_band("fabric", run, back + 0.05, 0.0, back + 0.05, top, "in")
    for end in (-1, 1):
        pts = [(first, 0.0), (back, 0.0), (back, top), (first, base + rise)]
        b.run_end("fabric", run, end, pts)
    # A skirt along the front, under the first deck.
    b.run_band("fabric", run, first - 0.02, 0.0, first - 0.02, base + rise - 0.05, "in")
