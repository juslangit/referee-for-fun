"""What every venue in `tools/stadium/venues/` is built from.

Every venue is a JSON file in `assets/stadium/` that both this and the game read: the
builder models the steps, the game (`scripts/bowl.gd`) seats people on them from the
same numbers. The geometry here and the seat maths in `Bowl` are the same functions in
two languages and must be kept the same.

Two ways a tier of seats can run:

* **Round the bowl** (the default): every row follows the inside face of the podium wall,
  a rounded rectangle, offset outwards by some distance `d`. A point at offset `d` is
  `base + d * normal`, where `base` is the matching point on the face, so the rows stay
  parallel round the corners. A rounded rectangle whose corner radius is half its width
  is a circle, which is how a round hall is drawn with the same code.
* **In straight runs** (`"runs"` on the tier): a bank of seating down one side of the
  floor only, like a scaffold grandstand or a hall's bleachers. Each run names the side
  it stands on (`+x`, `-x`, `+z`, `-z`) and how far along that side it goes.

Coordinates are the game's: y up, the court long along z, the umpire on +x looking -x.
"""

import json
import math
import os

import bmesh
import bpy
from mathutils import Vector

ARC = 10  # segments per rounded corner; Bowl.ARC must match

SIDE_NORMALS = {"+x": (1.0, 0.0), "-x": (-1.0, 0.0), "+z": (0.0, 1.0), "-z": (0.0, -1.0)}


def V(x, y, z):
    """Godot coordinates (y up, court along z) to Blender's (z up). The glTF exporter turns
    them back, so the file arrives in Godot exactly as written here."""
    return (x, -z, y)


def load_plan(repo, venue):
    return Plan(json.load(open(os.path.join(repo, "assets/stadium", venue + ".json"))))


# --- the path every row follows ---------------------------------------------------------

class Plan:
    """A venue's numbers, and the rounded rectangle every row of its bowl is offset from."""

    def __init__(self, data):
        self.data = data
        self.hx, self.hz = data["inner_half"]
        self.r = data.get("corner_radius", 0.01)
        self.cx, self.cz = data.get("centre", [0.0, 0.0])
        self.frame = self._frame()

    def __getitem__(self, key):
        return self.data[key]

    def get(self, key, default=None):
        return self.data.get(key, default)

    def _frame(self):
        """The podium face as (base point, outward normal) pairs, once round. Corners are
        sampled; the straights between them are the gaps between consecutive corners."""
        hx, hz, r = self.hx, self.hz, self.r
        pts = []
        corners = [((hx - r), (hz - r), 0.0), (-(hx - r), (hz - r), 90.0),
                   (-(hx - r), -(hz - r), 180.0), ((hx - r), -(hz - r), 270.0)]
        for cx, cz, a0 in corners:
            for i in range(ARC + 1):
                a = math.radians(a0 + 90.0 * i / ARC)
                n = (math.cos(a), math.sin(a))
                pts.append(((self.cx + cx + r * n[0], self.cz + cz + r * n[1]), n))
        return pts

    def at(self, i, d, y):
        (bx, bz), (nx, nz) = self.frame[i % len(self.frame)]
        return (bx + d * nx, y, bz + d * nz)

    def perimeter_points(self, d, spacing):
        """Evenly spaced (point, normal, arc position) round the row at offset d."""
        loop = [(self.at(i, d, 0.0), self.frame[i][1]) for i in range(len(self.frame))]
        out = []
        carry = 0.0
        s = 0.0
        for i in range(len(loop)):
            (p0, n0), (p1, n1) = loop[i], loop[(i + 1) % len(loop)]
            seg = math.dist((p0[0], p0[2]), (p1[0], p1[2]))
            t = carry
            while t < seg:
                f = t / seg if seg > 0 else 0.0
                p = (p0[0] + (p1[0] - p0[0]) * f, 0.0, p0[2] + (p1[2] - p0[2]) * f)
                n = (n0[0] + (n1[0] - n0[0]) * f, n0[1] + (n1[1] - n0[1]) * f)
                ln = math.hypot(*n)
                out.append((p, (n[0] / ln, n[1] / ln), s + t))
                t += spacing
            carry = t - seg
            s += seg
        return out

    def aisle_spots(self):
        """(base point, normal) at the middle of each aisle, on the podium face."""
        spots = []
        aisles = self.data.get("aisles")
        if not aisles:
            return spots
        hx, hz, r = self.hx, self.hz, self.r
        for side in (1.0, -1.0):
            for z in aisles.get("side_z", []):
                spots.append(((self.cx + side * hx, self.cz + z), (side, 0.0)))
            for x in aisles.get("end_x", []):
                spots.append(((self.cx + x, self.cz + side * hz), (0.0, side)))
        for sx in (1.0, -1.0):
            for sz in (1.0, -1.0):
                for deg in aisles.get("corner_deg", []):
                    a = math.radians(deg)
                    n = (sx * math.cos(a), sz * math.sin(a))
                    spots.append(((self.cx + (hx - r) * sx + r * n[0],
                                   self.cz + (hz - r) * sz + r * n[1]), n))
        return spots

    # --- straight runs ------------------------------------------------------------------

    def run_point(self, run, along, d, y=0.0):
        """A point on a straight run: `along` its side, `d` out from the floor's edge."""
        nx, nz = SIDE_NORMALS[run["side"]]
        if nx != 0.0:
            return (self.cx + nx * (self.hx + d), y, self.cz + along)
        return (self.cx + along, y, self.cz + nz * (self.hz + d))

    def run_normal(self, run):
        return SIDE_NORMALS[run["side"]]


# --- mesh building ----------------------------------------------------------------------

class Builder:
    """One mesh per material, so a venue is a handful of draw calls."""

    def __init__(self, plan, materials):
        self.plan = plan
        self.materials = materials
        self.parts = {}

    def bm(self, material):
        if material not in self.parts:
            self.parts[material] = bmesh.new()
        return self.parts[material]

    def quad(self, material, a, b, c, d, facing):
        """A quad from Godot points, wound so its normal points along `facing`."""
        bm = self.bm(material)
        vs = [bm.verts.new(V(*p)) for p in (a, b, c, d)]
        f = bm.faces.new(vs)
        f.normal_update()
        want = V(*facing)
        if f.normal.dot(want) < 0.0:
            f.normal_flip()

    def tri(self, material, a, b, c, facing):
        bm = self.bm(material)
        vs = [bm.verts.new(V(*p)) for p in (a, b, c)]
        f = bm.faces.new(vs)
        f.normal_update()
        if f.normal.dot(V(*facing)) < 0.0:
            f.normal_flip()

    def band(self, material, d0, y0, d1, y1, facing):
        """A strip all the way round, from (d0, y0) to (d1, y1) in the offset-height plane.
        `facing` is "up", "down", "in" (towards the court) or "out"."""
        plan = self.plan
        n = len(plan.frame)
        for i in range(n):
            j = (i + 1) % n
            a, b = plan.at(i, d0, y0), plan.at(j, d0, y0)
            c, d = plan.at(j, d1, y1), plan.at(i, d1, y1)
            nx, nz = plan.frame[i][1]
            f = {"up": (0, 1, 0), "down": (0, -1, 0),
                 "in": (-nx, 0, -nz), "out": (nx, 0, nz)}[facing]
            self.quad(material, a, b, c, d, f)

    def run_band(self, material, run, d0, y0, d1, y1, facing, along=None):
        """The same as `band`, down one straight run instead of all the way round."""
        lo, hi = along if along is not None else (run["from"], run["to"])
        plan = self.plan
        nx, nz = plan.run_normal(run)
        a, b = plan.run_point(run, lo, d0, y0), plan.run_point(run, hi, d0, y0)
        c, d = plan.run_point(run, hi, d1, y1), plan.run_point(run, lo, d1, y1)
        f = {"up": (0, 1, 0), "down": (0, -1, 0), "in": (-nx, 0, -nz), "out": (nx, 0, nz)}[facing]
        self.quad(material, a, b, c, d, f)

    def run_end(self, material, run, end, points):
        """A flat polygon closing one end of a run, given as (d, y) points."""
        plan = self.plan
        along = run["from"] if end < 0 else run["to"]
        nx, nz = plan.run_normal(run)
        # The end faces along the run, away from its middle.
        tx, tz = (-nz, nx) if nx != 0.0 else (nz, -nx)
        tx, tz = abs(tx), abs(tz)
        facing = (tx * end, 0.0, tz * end)
        bm = self.bm(material)
        vs = [bm.verts.new(V(*plan.run_point(run, along, d, y))) for d, y in points]
        f = bm.faces.new(vs)
        f.normal_update()
        if f.normal.dot(V(*facing)) < 0.0:
            f.normal_flip()

    def box(self, material, centre, size, yaw=0.0):
        """An upright box in Godot space, `yaw` about y. Size is (across, up, along)."""
        cx, cy, cz = centre
        hx, hy, hz = size[0] / 2, size[1] / 2, size[2] / 2
        c, s = math.cos(yaw), math.sin(yaw)

        def P(x, y, z):
            return (cx + x * c + z * s, cy + y, cz - x * s + z * c)

        corners = {k: P(*k) for k in [(sx * hx, sy * hy, sz * hz)
                                       for sx in (-1, 1) for sy in (-1, 1) for sz in (-1, 1)]}
        faces = [
            ((1, 0, 0), [(hx, -hy, -hz), (hx, hy, -hz), (hx, hy, hz), (hx, -hy, hz)]),
            ((-1, 0, 0), [(-hx, -hy, -hz), (-hx, -hy, hz), (-hx, hy, hz), (-hx, hy, -hz)]),
            ((0, 1, 0), [(-hx, hy, -hz), (-hx, hy, hz), (hx, hy, hz), (hx, hy, -hz)]),
            ((0, -1, 0), [(-hx, -hy, -hz), (hx, -hy, -hz), (hx, -hy, hz), (-hx, -hy, hz)]),
            ((0, 0, 1), [(-hx, -hy, hz), (hx, -hy, hz), (hx, hy, hz), (-hx, hy, hz)]),
            ((0, 0, -1), [(-hx, -hy, -hz), (-hx, hy, -hz), (hx, hy, -hz), (hx, -hy, -hz)]),
        ]
        for (nx, ny, nz), quad in faces:
            facing = (nx * c + nz * s, ny, -nx * s + nz * c)
            self.quad(material, *[corners[q] for q in quad], facing)

    def beam(self, material, p0, p1, width, height):
        """A box from p0 to p1 (Godot points), width across and height up."""
        dx, dy, dz = p1[0] - p0[0], p1[1] - p0[1], p1[2] - p0[2]
        length = math.sqrt(dx * dx + dy * dy + dz * dz)
        if length < 1e-6:
            return
        mid = ((p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2, (p0[2] + p1[2]) / 2)
        bm = self.bm(material)
        tmp = bmesh.new()
        bmesh.ops.create_cube(tmp, size=1.0)
        for v in tmp.verts:
            v.co.x *= width
            v.co.y *= length
            v.co.z *= height
        # Point the cube's +y (Blender) along the beam.
        d = Vector(V(dx, dy, dz)).normalized()
        rot = Vector((0, 1, 0)).rotation_difference(d).to_matrix().to_4x4()
        bmesh.ops.transform(tmp, matrix=rot, verts=tmp.verts)
        bmesh.ops.translate(tmp, vec=Vector(V(*mid)), verts=tmp.verts)
        me = bpy.data.meshes.new("tmp")
        tmp.to_mesh(me)
        tmp.free()
        bm.from_mesh(me)
        bpy.data.meshes.remove(me)

    def tube(self, material, p0, p1, radius, sides=6):
        """A round bar from p0 to p1: scaffold, rails, cables."""
        dx, dy, dz = p1[0] - p0[0], p1[1] - p0[1], p1[2] - p0[2]
        length = math.sqrt(dx * dx + dy * dy + dz * dz)
        if length < 1e-6:
            return
        bm = self.bm(material)
        tmp = bmesh.new()
        bmesh.ops.create_cone(tmp, cap_ends=False, segments=sides, radius1=radius,
                              radius2=radius, depth=length)
        d = Vector(V(dx, dy, dz)).normalized()
        rot = Vector((0, 0, 1)).rotation_difference(d).to_matrix().to_4x4()
        bmesh.ops.transform(tmp, matrix=rot, verts=tmp.verts)
        mid = ((p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2, (p0[2] + p1[2]) / 2)
        bmesh.ops.translate(tmp, vec=Vector(V(*mid)), verts=tmp.verts)
        me = bpy.data.meshes.new("tmp")
        tmp.to_mesh(me)
        tmp.free()
        bm.from_mesh(me)
        bpy.data.meshes.remove(me)

    def finish(self, collection, uv_metres):
        objects = []
        for material, bm in self.parts.items():
            me = bpy.data.meshes.new(material)
            bm.to_mesh(me)
            bm.free()
            _uv_by_box(me, uv_metres.get(material, 2.0))
            me.materials.append(self.materials[material])
            ob = bpy.data.objects.new(material.capitalize(), me)
            collection.objects.link(ob)
            objects.append(ob)
        return objects


def _uv_by_box(me, metres):
    """World-scale UVs by box projection: each face takes the two axes it is flattest
    across. One texture repeat per `metres`, so concrete is concrete-sized everywhere.

    A sponsor wrap (`wrap_*`) is a printed strip, not a surface that repeats: each upright
    face shows the strip's whole height, top to bottom, and runs along it at the image's own
    aspect, which is what `metres` holds for it (the image's width over its height)."""
    me.uv_layers.new(name="UVMap")
    uv = me.uv_layers.active.data
    if me.name.startswith("wrap"):
        for poly in me.polygons:
            zs = [me.vertices[me.loops[li].vertex_index].co.z for li in poly.loop_indices]
            lo, hi = min(zs), max(zs)
            height = max(hi - lo, 1e-3)
            n = poly.normal
            horizontal = 0 if abs(n.y) > abs(n.x) else 1
            for li in poly.loop_indices:
                co = me.vertices[me.loops[li].vertex_index].co
                along = co.x if horizontal == 0 else co.y
                if (n.y if horizontal == 0 else -n.x) > 0:
                    along = -along
                uv[li].uv = (along / (height * metres), (co.z - lo) / height)
        return
    for poly in me.polygons:
        n = poly.normal
        ax = max(range(3), key=lambda k: abs(n[k]))
        for li in poly.loop_indices:
            co = me.vertices[me.loops[li].vertex_index].co
            if ax == 0:
                u, v = co.y, co.z
            elif ax == 1:
                u, v = co.x, co.z
            else:
                u, v = co.x, co.y
            uv[li].uv = (u / metres, v / metres)


# --- materials --------------------------------------------------------------------------

TEXTURES = None  # set by run()


def textured(name, tex, tint=(1, 1, 1, 1), metallic=0.0):
    """A Poly Haven 1k set from tools/stadium/textures: <tex>_diff/_rough/_nor_gl_1k.jpg."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Metallic"].default_value = metallic

    def img(kind, colour):
        node = nt.nodes.new("ShaderNodeTexImage")
        node.image = bpy.data.images.load(os.path.join(TEXTURES, f"{tex}_{kind}_1k.jpg"),
                                          check_existing=True)
        if not colour:
            node.image.colorspace_settings.name = "Non-Color"
        return node
    diff = img("diff", True)
    if tint != (1, 1, 1, 1):
        mix = nt.nodes.new("ShaderNodeMix")
        mix.data_type = "RGBA"
        mix.blend_type = "MULTIPLY"
        mix.inputs["Factor"].default_value = 1.0
        mix.inputs["B"].default_value = tint
        nt.links.new(diff.outputs["Color"], mix.inputs["A"])
        nt.links.new(mix.outputs["Result"], bsdf.inputs["Base Color"])
    else:
        nt.links.new(diff.outputs["Color"], bsdf.inputs["Base Color"])
    rough = img("rough", False)
    nt.links.new(rough.outputs["Color"], bsdf.inputs["Roughness"])
    nor = img("nor_gl", False)
    nmap = nt.nodes.new("ShaderNodeNormalMap")
    nt.links.new(nor.outputs["Color"], nmap.inputs["Color"])
    nt.links.new(nmap.outputs["Normal"], bsdf.inputs["Normal"])
    return m


def picture(name, file, emission=0.0, alpha=False):
    """A single image (art, signs), optionally glowing, optionally cut out by its alpha."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    node = nt.nodes.new("ShaderNodeTexImage")
    node.image = bpy.data.images.load(file, check_existing=True)
    nt.links.new(node.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.6
    if emission > 0.0:
        nt.links.new(node.outputs["Color"], bsdf.inputs["Emission Color"])
        bsdf.inputs["Emission Strength"].default_value = emission
    if alpha:
        nt.links.new(node.outputs["Alpha"], bsdf.inputs["Alpha"])
        m.surface_render_method = "DITHERED"
    return m


def plain(name, colour, rough=0.5, metallic=0.0, emission=None, alpha=1.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = colour
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metallic
    if emission:
        bsdf.inputs["Emission Color"].default_value = emission[0]
        bsdf.inputs["Emission Strength"].default_value = emission[1]
    if alpha < 1.0:
        bsdf.inputs["Alpha"].default_value = alpha
        m.surface_render_method = "BLENDED"
    return m


# --- the parts most venues share --------------------------------------------------------

def tier_top(tier):
    return tier["base"] + tier["rise"] * tier["rows"]


def perimeter_tier(b, tier, material="steps"):
    """Rows of treads and risers all the way round. Tread r is at base + rise * (r + 1),
    from first_offset + depth * r to the next row — the same numbers `Bowl` seats people on."""
    prev = tier["base"]
    for r in range(tier["rows"]):
        d0 = tier["first_offset"] + tier["depth"] * r
        d1 = d0 + tier["depth"]
        h = tier["base"] + tier["rise"] * (r + 1)
        b.band(material, d0, prev, d0, h, "in")
        b.band(material, d0, h, d1, h, "up")
        prev = h
    # The back of the last row, down to whatever is behind it.
    last = tier["first_offset"] + tier["depth"] * tier["rows"]
    b.band(material, last, prev, last, prev - 0.01, "in")


def run_tier(b, tier, run, material="steps", end_material=None, close_back=True):
    """The same rows down one straight run, with its two ends closed off."""
    prev = tier["base"]
    profile = [(tier["first_offset"], 0.0), (tier["first_offset"], tier["base"])]
    for r in range(tier["rows"]):
        d0 = tier["first_offset"] + tier["depth"] * r
        d1 = d0 + tier["depth"]
        h = tier["base"] + tier["rise"] * (r + 1)
        b.run_band(material, run, d0, prev, d0, h, "in")
        b.run_band(material, run, d0, h, d1, h, "up")
        profile += [(d0, h), (d1, h)]
        prev = h
    last = tier["first_offset"] + tier["depth"] * tier["rows"]
    if close_back:
        b.run_band(end_material or material, run, last, 0.0, last, prev, "out")
    profile.append((last, 0.0))
    # The two ends, as stepped polygons. A concave outline cannot be one face, so each
    # step is its own quad down to the floor.
    em = end_material or material
    for end in (-1, 1):
        for r in range(tier["rows"]):
            d0 = tier["first_offset"] + tier["depth"] * r
            d1 = d0 + tier["depth"]
            h = tier["base"] + tier["rise"] * (r + 1)
            b.run_end(em, run, end, [(d0, 0.0), (d1, 0.0), (d1, h), (d0, h)])


def aisles(b, plan, steps="steps", nosing="nosing", steel="steel", rails=True):
    """Two steps a row up every aisle, a yellow nosing on each, and a handrail."""
    w = plan["aisles"]["width"]
    for (bx, bz), (nx, nz) in plan.aisle_spots():
        yaw = math.atan2(nx, nz)
        for tier in plan["tiers"]:
            if "runs" in tier:
                continue
            for r in range(tier["rows"]):
                d0 = tier["first_offset"] + tier["depth"] * r
                h = tier["base"] + tier["rise"] * (r + 1)
                # The half step, on the back half of this row's tread.
                mid = d0 + tier["depth"] * 0.75
                y = h + tier["rise"] * 0.25
                c = (bx + nx * mid, y, bz + nz * mid)
                b.box(steps, c, (w, tier["rise"] * 0.5, tier["depth"] * 0.5), yaw)
                for edge, top in ((d0 + 0.02, h), (d0 + tier["depth"] * 0.5 + 0.02, h + tier["rise"] * 0.5)):
                    b.box(nosing, (bx + nx * edge, top + 0.004, bz + nz * edge),
                          (w * 0.96, 0.01, 0.04), yaw)
            if not rails:
                continue
            # A rail up the middle of the aisle, on posts every few rows.
            first = tier["first_offset"] + tier["depth"] * 0.5
            last = tier["first_offset"] + tier["depth"] * (tier["rows"] - 0.5)
            y0 = tier["base"] + tier["rise"] + 0.9
            y1 = tier_top(tier) + 0.9
            b.beam(steel, (bx + nx * first, y0, bz + nz * first),
                   (bx + nx * last, y1, bz + nz * last), 0.05, 0.05)
            for r in range(0, tier["rows"], 3):
                d = tier["first_offset"] + tier["depth"] * (r + 0.5)
                h = tier["base"] + tier["rise"] * (r + 1)
                b.box(steel, (bx + nx * d, h + 0.45, bz + nz * d), (0.05, 0.9, 0.05), yaw)


def screens(b, plan, frame="dark", face="screen", steel="steel", hang_to=None):
    """Video screens: hung in the bowl's corners, or as a cube over the middle of the floor.
    The game puts the score on them from `Bowl.screen_spots`, which reads the same numbers."""
    for sc in plan.get("screens", []):
        w, h = sc["size"]
        if sc.get("cube"):
            cx, cz = plan.cx + sc["at"][0], plan.cz + sc["at"][1]
            cy = sc["bottom"] + h * 0.5
            half = w * 0.5 + 0.25
            b.box(frame, (cx, cy, cz), (w + 0.5, h + 0.4, w + 0.5))
            for yaw in (0.0, math.pi * 0.5, math.pi, math.pi * 1.5):
                n = (math.sin(yaw), math.cos(yaw))
                b.box(face, (cx + n[0] * half, cy, cz + n[1] * half), (w, h, 0.02), yaw)
            # A smaller ring of screens under the big one, as on every arena cube.
            b.box(frame, (cx, sc["bottom"] - 0.6, cz), (w * 0.8, 1.0, w * 0.8))
            top = hang_to if hang_to is not None else sc["bottom"] + h + 6.0
            for sx in (-1, 1):
                for sz in (-1, 1):
                    p = (cx + sx * w * 0.35, sc["bottom"] + h + 0.2, cz + sz * w * 0.35)
                    b.tube(steel, p, (p[0], top, p[2]), 0.03)
            continue
        sx, sz = sc["corner"]
        n = (sx * math.sqrt(0.5), sz * math.sqrt(0.5))
        base = (plan.cx + (plan.hx - plan.r) * sx + plan.r * n[0],
                plan.cz + (plan.hz - plan.r) * sz + plan.r * n[1])
        d = sc["offset"]
        c = (base[0] + n[0] * d, sc["bottom"] + h * 0.5, base[1] + n[1] * d)
        yaw = math.atan2(n[0], n[1])
        b.box(frame, c, (w + 0.4, h + 0.4, 0.5), yaw)
        f = (c[0] - n[0] * 0.27, c[1], c[2] - n[1] * 0.27)
        b.box(face, f, (w, h, 0.02), yaw)
        top = hang_to if hang_to is not None else sc["bottom"] + h + 4.0
        for side in (-1, 1):
            off = side * w * 0.35
            rx, rz = c[0] + n[1] * off, c[2] - n[0] * off
            b.beam(steel, (rx, sc["bottom"] + h + 0.2, rz), (rx, top, rz), 0.08, 0.08)


def lighting_rig_cables(b, plan, steel="steel", roof_at=None):
    """Chains from the roof down to where `HallLight` hangs its truss, so the game's own
    lighting rig is seen to hang from the building rather than float in it. The numbers
    are HallLight's multiples of the court; see `rig` in the venue's JSON. The rig hangs
    over the court, which is at the origin whatever the building's own centre is.
    `roof_at(x)` gives the roof's height over x, for a pitched roof; otherwise `rig.roof`."""
    rig = plan.get("rig")
    if not rig:
        return
    spread = rig["half_width"] * 1.443
    run = rig["half_length"] * 1.642
    y = rig["hall_height"] * 0.90
    for side in (1.0, -1.0):
        x = side * spread
        top = roof_at(x) if roof_at else rig["roof"]
        for section in (-1.0, 0.0, 1.0):
            for end in (-0.4, 0.4):
                z = section * run + end * run * 0.8
                b.tube(steel, (x, y + 0.4, z), (x, top, z), 0.02, 4)


# --- run --------------------------------------------------------------------------------

def run(repo, venue, build, make_materials, uv_metres, scene=None):
    """Builds one venue in a scene of its own, exports it to assets/stadium/<venue>.glb and
    saves that scene alone to tools/stadium/<venue>.blend."""
    global TEXTURES
    TEXTURES = os.path.join(repo, "tools/stadium/textures")
    plan = load_plan(repo, venue)
    name = scene or "".join(w.capitalize() for w in venue.split("_"))
    sc = bpy.data.scenes.get(name) or bpy.data.scenes.new(name)
    for ob in list(sc.collection.all_objects):
        if ob.type == "MESH":
            bpy.data.objects.remove(ob, do_unlink=True)
    for coll in list(sc.collection.children):
        bpy.data.collections.remove(coll)
    # Last run's meshes and materials, so this run's get their own names back rather
    # than "steps.001" — the game finds some parts by name.
    for me in list(bpy.data.meshes):
        if me.users == 0:
            bpy.data.meshes.remove(me)
    for m in list(bpy.data.materials):
        if m.users == 0:
            bpy.data.materials.remove(m)
    # A builder that paints each venue its own colours takes the plan.
    materials = make_materials(plan) if make_materials.__code__.co_argcount else make_materials()
    # Named for the venue, since every venue's scene shares one Blender and two "steps" would
    # come out as "steps.001".
    for key, m in materials.items():
        m.name = f"{venue}_{key}"
    coll = bpy.data.collections.new(name)
    sc.collection.children.link(coll)
    b = Builder(plan, materials)
    build(b, plan)
    objects = b.finish(coll, uv_metres)
    # Every surface is meant to be seen from one side; glass and cloth are not. By the key a
    # venue gave it, since another venue's scene in the same Blender may already hold a
    # material of that name and this one has been called "glass.001".
    for key, m in b.materials.items():
        m.use_backface_culling = key not in ("glass", "cloth", "net", "fabric", "drape", "wrap")
    window = bpy.context.window
    if window is not None:
        window.scene = sc
    out = os.path.join(repo, "assets/stadium", venue + ".glb")
    bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", use_active_scene=True,
                              export_apply=True, export_yup=True)
    blend = os.path.join(repo, "tools/stadium", venue + ".blend")
    bpy.data.libraries.write(blend, {sc}, path_remap="RELATIVE_ALL", fake_user=True, compress=True)
    tris = sum(sum(len(p.vertices) - 2 for p in ob.data.polygons) for ob in objects)
    print(f"{venue}: {len(objects)} meshes, {tris} triangles -> {out}")
    return tris


# --- temporary and folding stands ---------------------------------------------------------

# How far apart a stand's frame uprights are along it.
BAY = 2.4


def bleacher(b, plan, tier, run, deck="deck", plank="plank", frame="frame", nosing="nosing",
             wrap=None, skirt=None, rail_height=1.05, seat_height=0.43):
    """A stand of decks and bench planks on an open frame, down one straight run: a beach
    grandstand's scaffold, or a hall's folding bleachers. A seated person's hips are at
    `seat_height` over their tread, just behind its middle, which is where the plank is.

    `wrap` hangs a printed cloth round the back and both ends (the beach); `skirt` closes
    the front under the first deck."""
    rows, depth, rise, base, first = (tier["rows"], tier["depth"], tier["rise"], tier["base"],
                                      tier["first_offset"])
    lo, hi = run["from"], run["to"]
    gaps = tier.get("gaps", [])
    gap_w = plan["aisles"]["width"] if "aisles" in plan.data else 1.0
    nx, nz = plan.run_normal(run)
    yaw = math.atan2(nx, nz)

    def P(along, d, y):
        return plan.run_point(run, along, d, y)

    for r in range(rows):
        d0 = first + depth * r
        d1 = d0 + depth
        y = base + rise * (r + 1)
        b.run_band(deck, run, d0, y, d1, y, "up")
        b.run_band(deck, run, d0, y - 0.05, d0, y, "in")
        cuts = [lo] + sum(([g - gap_w * 0.5, g + gap_w * 0.5] for g in gaps), []) + [hi]
        for k in range(0, len(cuts), 2):
            a0, a1 = cuts[k], cuts[k + 1]
            seat_d = d0 + depth * 0.62
            b.run_band(plank, run, seat_d - 0.15, y + seat_height, seat_d + 0.15, y + seat_height,
                       "up", along=(a0, a1))
            b.run_band(plank, run, seat_d - 0.15, y + seat_height - 0.04, seat_d - 0.15,
                       y + seat_height, "in", along=(a0, a1))
            a = a0 + 0.3
            while a < a1:
                b.box(frame, P(a, seat_d, y + seat_height * 0.5), (0.05, seat_height, 0.05), yaw)
                a += BAY

    for g in gaps:
        for r in range(rows):
            d0 = first + depth * r
            y = base + rise * (r + 1)
            b.box(deck, P(g, d0 + depth * 0.75, y + rise * 0.25), (gap_w, rise * 0.5, depth * 0.5), yaw)
            for edge, top in ((d0 + 0.02, y), (d0 + depth * 0.5 + 0.02, y + rise * 0.5)):
                b.box(nosing, P(g, edge, top + 0.004), (gap_w * 0.96, 0.01, 0.04), yaw)
        b.box(deck, P(g, first - 0.25, (base + rise) * 0.5), (gap_w, base + rise, 0.5), yaw)

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
            b.tube(frame, P(a, d, 0.0), P(a, d, h), 0.024)
        for y in (0.15, h * 0.5):
            if y < h:
                b.tube(frame, P(stations[0], d, y), P(stations[-1], d, y), 0.02)
    for a in stations:
        for i in range(len(lines) - 1):
            d_a, d_b = lines[i], lines[i + 1]
            y = min(height_at(d_a), height_at(d_b)) - 0.1
            b.tube(frame, P(a, d_a, y), P(a, d_b, y), 0.02)
            b.tube(frame, P(a, d_a, 0.15), P(a, d_b, 0.15), 0.02)
    for k in range(len(stations) - 1):
        if k % 2 == 0:
            b.tube(frame, P(stations[k], back, 0.15), P(stations[k + 1], back, top - 0.3), 0.02)

    rail = top + rail_height
    for a in stations:
        b.tube(frame, P(a, back - 0.05, top), P(a, back - 0.05, rail), 0.024)
    for y in (top + rail_height * 0.5, rail):
        b.tube(frame, P(lo, back - 0.05, y), P(hi, back - 0.05, y), 0.024)
    for end_along in (lo, hi):
        for r in range(rows):
            d0 = first + depth * r
            y = base + rise * (r + 1)
            b.tube(frame, P(end_along, d0 + 0.05, y), P(end_along, d0 + 0.05, y + 1.0), 0.02)
        b.tube(frame, P(end_along, first + 0.05, base + rise + 1.0),
               P(end_along, back - 0.05, top + 1.0), 0.022)

    if wrap:
        b.run_band(wrap, run, back + 0.06, 0.0, back + 0.06, top, "out")
        b.run_band(skirt or wrap, run, back + 0.05, 0.0, back + 0.05, top, "in")
        for end in (-1, 1):
            b.run_end(skirt or wrap, run, end, [(first, 0.0), (back, 0.0), (back, top), (first, base + rise)])
    if skirt:
        b.run_band(skirt, run, first - 0.02, 0.0, first - 0.02, base + rise - 0.05, "in")
