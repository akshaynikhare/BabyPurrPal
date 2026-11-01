"""Procedurally build the BabyPurrPal toy props and export one GLB each.

Run from the repo root:
  /Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup \
      -P tools/blender/build_props.py -- --prop milk|fish|yarn|bone|water|ball|carrot|clover|bell|all

Same look and export as build_pets.py: one flat named material per colour (one surface
each), smooth normals for the inverted-hull outline, pet units (the pets are ~0.9-1.0 tall).
Shapes are lathes, lofted tubes, cube-spheres and projected decals; bites are boolean cuts
whose new faces take the prop's lighter "bite" material.
Every object is a direct child of the GLB root. Its origin is the prop origin unless noted.
Blender is Z-up facing -Y; the glTF exporter converts that to Y-up facing +Z.
"""

import argparse
import math
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree
from mathutils.interpolate import poly_3d_calc

HERE = Path(__file__).resolve().parent
REPO = HERE.parent.parent
GLB_DIR = REPO / "assets" / "props"
PROPS = ["milk", "fish", "yarn", "bone", "water", "ball", "carrot", "clover", "bell"]
MAX_TRIS = 2500
X, Y, Z = Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))


# ---------------------------------------------------------------- math helpers

def lin(hexstr):
    h = hexstr.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return [x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c] + [1.0]


def mix(a, b, t):
    return a + (b - a) * t


def sd_ellipsoid(p, c, r):
    q0 = Vector(((p[0] - c[0]) / r[0], (p[1] - c[1]) / r[1], (p[2] - c[2]) / r[2]))
    q1 = Vector((q0.x / r[0], q0.y / r[1], q0.z / r[2]))
    k0, k1 = q0.length, q1.length
    if k1 < 1e-9:
        return -min(r)
    return k0 * (k0 - 1.0) / k1


def smin(a, b, k):
    if k <= 0:
        return min(a, b)
    h = max(k - abs(a - b), 0.0) / k
    return min(a, b) - h * h * k * 0.25


def blob_sdf(elements):
    """elements: list of (center, radii, blend_k). First element's k is ignored."""
    def f(p):
        d = None
        for c, r, k in elements:
            e = sd_ellipsoid(p, c, r)
            d = e if d is None else smin(d, e, k)
        return d
    return f


def spline1d(keys):
    """Smooth curve through (t, value) keys."""
    ts = [k[0] for k in keys]
    vs = [k[1] for k in keys]
    n = len(keys)
    ms = [(vs[min(i + 1, n - 1)] - vs[max(i - 1, 0)]) / (ts[min(i + 1, n - 1)] - ts[max(i - 1, 0)])
          for i in range(n)]

    def f(t):
        t = min(max(t, ts[0]), ts[-1])
        i = 0
        while i < n - 2 and t > ts[i + 1]:
            i += 1
        h = ts[i + 1] - ts[i]
        u = (t - ts[i]) / h
        return ((2 * u ** 3 - 3 * u * u + 1) * vs[i] + (u ** 3 - 2 * u * u + u) * h * ms[i]
                + (-2 * u ** 3 + 3 * u * u) * vs[i + 1] + (u ** 3 - u * u) * h * ms[i + 1])
    return f


def interp_r(profile, z):
    """r at height z on a (r, z) polyline sorted by z."""
    for (r0, z0), (r1, z1) in zip(profile, profile[1:]):
        if z0 <= z <= z1:
            return mix(r0, r1, (z - z0) / (z1 - z0))
    return profile[0][0] if z < profile[0][1] else profile[-1][0]


# ---------------------------------------------------------------- geometry builders

def orient_closed(verts, faces):
    vol = 0.0
    for f in faces:
        for i in range(1, len(f) - 1):
            vol += verts[f[0]].dot(verts[f[i]].cross(verts[f[i + 1]]))
    return faces if vol > 0 else [list(reversed(f)) for f in faces]


def radial_surface(center, sdf, n=8, rmax=0.3):
    """Cube-sphere whose vertices are pushed along rays from `center` onto sdf == 0."""
    import bmesh
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=2.0)
    bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=n - 1, use_grid_fill=True)
    bm.verts.index_update()
    center = Vector(center)
    verts = []
    for v in bm.verts:
        d = Vector([math.tan(c * math.pi / 4) for c in v.co]).normalized()
        lo, hi = 0.0, rmax
        for _ in range(30):
            mid = (lo + hi) * 0.5
            if sdf(center + d * mid) < 0:
                lo = mid
            else:
                hi = mid
        verts.append(center + d * lo)
    faces = [[v.index for v in f.verts] for f in bm.faces]
    bm.free()
    return verts, faces


def lathe(profile, segs, mats, phase=0.0):
    """Surface of revolution about +Z. profile: [(r, z)], r == 0 ends become poles.
    mats: one name, a name per profile segment, or fn(segment, j) -> name."""
    verts, faces, fm = [], [], []
    rings = []
    for r, z in profile:
        if r < 1e-9:
            rings.append([len(verts)])
            verts.append(Vector((0, 0, z)))
            continue
        ring = []
        for j in range(segs):
            a = phase + 2 * math.pi * j / segs
            ring.append(len(verts))
            verts.append(Vector((r * math.cos(a), r * math.sin(a), z)))
        rings.append(ring)
    for i in range(len(rings) - 1):
        a, b = rings[i], rings[i + 1]
        for j in range(segs):
            k = (j + 1) % segs
            if len(a) == 1:
                f = [a[0], b[k], b[j]]
            elif len(b) == 1:
                f = [a[j], a[k], b[0]]
            else:
                f = [a[j], a[k], b[k], b[j]]
            faces.append(f)
            fm.append(mats(i, j) if callable(mats) else (mats[i] if isinstance(mats, list) else mats))
    return verts, orient_closed(verts, faces), fm


def loft(path, frame, prof, n_len=16, n_around=16, cap0=0.25, cap1=0.25):
    """Closed tube along path(t), t in [0,1] (as in build_pets.py).
    frame(t) -> (side, front) unit vectors; prof(t) -> (half_width, half_thickness).
    Returns verts, faces, per-vertex t. Quads come first, ring by ring."""
    def closure(t):
        c = 1.0
        if cap0 > 0 and t < cap0:
            c *= math.sqrt(max(0.0, 1 - (1 - t / cap0) ** 2))
        if cap1 > 0 and t > 1 - cap1:
            c *= math.sqrt(max(0.0, 1 - (1 - (1 - t) / cap1) ** 2))
        return c

    verts, ts, faces = [], [], []
    rings = []
    for i in range(1, n_len):
        t = (1 - math.cos(math.pi * i / n_len)) / 2
        side, front = frame(t)
        a, b = prof(t)
        c = closure(t)
        ring = []
        for j in range(n_around):
            ang = 2 * math.pi * j / n_around
            p = Vector(path(t)) + side * (a * c * math.cos(ang)) + front * (b * c * math.sin(ang))
            ring.append(len(verts))
            verts.append(p)
            ts.append(t)
        rings.append(ring)
    p0 = len(verts); verts.append(Vector(path(0.0))); ts.append(0.0)
    p1 = len(verts); verts.append(Vector(path(1.0))); ts.append(1.0)
    for r in range(len(rings) - 1):
        a, b = rings[r], rings[r + 1]
        for j in range(n_around):
            k = (j + 1) % n_around
            faces.append([a[j], a[k], b[k], b[j]])
    first, last = rings[0], rings[-1]
    for j in range(n_around):
        k = (j + 1) % n_around
        faces.append([p0, first[k], first[j]])
        faces.append([p1, last[j], last[k]])
    return verts, orient_closed(verts, faces), ts


def straight(p0, p1):
    p0, p1 = Vector(p0), Vector(p1)
    return lambda t: p0.lerp(p1, t)


def polyline(points):
    """Smooth path through points (Catmull-Rom), t in [0,1]."""
    pts = [Vector(p) for p in points]
    n = len(pts) - 1

    def f(t):
        s = min(max(t, 0.0), 1.0) * n
        i = min(int(s), n - 1)
        u = s - i
        p0 = pts[max(i - 1, 0)]; p1 = pts[i]; p2 = pts[i + 1]; p3 = pts[min(i + 2, n)]
        return 0.5 * ((2 * p1) + (-p0 + p2) * u + (2 * p0 - 5 * p1 + 4 * p2 - p3) * u * u
                      + (-p0 + 3 * p1 - 3 * p2 + p3) * u * u * u)
    return f


def tube_frame(path, ref=Vector((0, -1, 0)), samples=200):
    """Rotation-minimising (parallel transport) frames, so curved tubes never twist."""
    def tangent(t):
        return (Vector(path(min(t + 0.005, 1.0))) - Vector(path(max(t - 0.005, 0.0)))).normalized()

    tan = tangent(0.0)
    front = ref - tan * ref.dot(tan)
    if front.length < 1e-6:
        front = Vector((1, 0, 0)) - tan * tan.x
    front.normalize()
    table = []
    for i in range(samples + 1):
        t = i / samples
        nt = tangent(t)
        front = (front - nt * front.dot(nt)).normalized()
        table.append((nt.cross(front).normalized(), front.copy()))

    def f(t):
        return table[min(int(round(t * samples)), samples)]
    return f


def plane_frame(normal):
    """Fixed loft frame for flat parts lying in the plane with this normal."""
    def make(path):
        tan = (Vector(path(1.0)) - Vector(path(0.0))).normalized()
        side = Vector(normal).cross(tan).normalized()
        return lambda t: (side, Vector(normal))
    return make


def round_tube(points, r0, r1, n_len, n_around, cap0=0.2, cap1=0.2, ref=Vector((0, -1, 0))):
    path = polyline(points) if len(points) > 2 else straight(*points)
    verts, faces, _ts = loft(path, tube_frame(path, ref), lambda t: (mix(r0, r1, t),) * 2,
                             n_len, n_around, cap0, cap1)
    return verts, faces


def ellipsoid(c, r, segs=12, rings=8):
    prof = [(math.sin(math.pi * i / rings), -math.cos(math.pi * i / rings)) for i in range(rings + 1)]
    verts, faces, _fm = lathe(prof, segs, "")
    return [Vector((c[0] + v.x * r[0], c[1] + v.y * r[1], c[2] + v.z * r[2])) for v in verts], faces


def box(lo, hi):
    verts = [Vector((x, y, z)) for x in (lo[0], hi[0]) for y in (lo[1], hi[1]) for z in (lo[2], hi[2])]
    faces = [[0, 1, 3, 2], [4, 6, 7, 5], [0, 4, 5, 1], [2, 3, 7, 6], [0, 2, 6, 4], [1, 5, 7, 3]]
    return verts, faces


def torus(c, n, R, r, nu, nv):
    n = Vector(n).normalized()
    a = n.orthogonal().normalized()
    b = n.cross(a)
    verts, faces = [], []
    for i in range(nu):
        u = 2 * math.pi * i / nu
        d = a * math.cos(u) + b * math.sin(u)
        for j in range(nv):
            v = 2 * math.pi * j / nv
            verts.append(Vector(c) + d * (R + r * math.cos(v)) + n * (r * math.sin(v)))
    for i in range(nu):
        for j in range(nv):
            i2, j2 = (i + 1) % nu, (j + 1) % nv
            faces.append([i * nv + j, i2 * nv + j, i2 * nv + j2, i * nv + j2])
    return verts, orient_closed(verts, faces)


def transform(verts, M, offset=Vector()):
    return [M @ Vector(v) + offset for v in verts]


# ---------------------------------------------------------------- surfaces & decals

class Surf:
    """Ray-cast target with smooth normals."""

    def __init__(self, verts, faces):
        self.v = verts
        self.tris = []
        for f in faces:
            for i in range(1, len(f) - 1):
                self.tris.append((f[0], f[i], f[i + 1]))
        self.bvh = BVHTree.FromPolygons(verts, self.tris)
        vn = [Vector() for _ in verts]
        for a, b, c in self.tris:
            n = (verts[b] - verts[a]).cross(verts[c] - verts[a])
            vn[a] += n; vn[b] += n; vn[c] += n
        self.vn = [n.normalized() for n in vn]

    def hit(self, origin, direction):
        loc, _n, idx, _d = self.bvh.ray_cast(origin, direction)
        if loc is None:
            loc, _n, idx, _d = self.bvh.find_nearest(origin + direction * 0.2)
        a, b, c = self.tris[idx]
        bw = poly_3d_calc([self.v[a], self.v[b], self.v[c]], loc)
        return loc, (self.vn[a] * bw[0] + self.vn[b] * bw[1] + self.vn[c] * bw[2]).normalized()


class Frame:
    def __init__(self, anchor, n, up=Vector((0, 0, 1))):
        self.o = Vector(anchor)
        self.n = Vector(n).normalized()
        u = up.cross(self.n)  # u x v = n with v roughly along `up`
        u = Vector((1, 0, 0)) if u.length < 1e-6 else u
        self.u = (u - self.n * u.dot(self.n)).normalized()
        self.v = self.n.cross(self.u).normalized()


def polar_topology(rings, segs):
    """Index 0 = centre; returns params [(rho, theta)] and faces (CCW around +n)."""
    params = [(0.0, 0.0)]
    for r in range(1, rings + 1):
        for s in range(segs):
            params.append((r / rings, 2 * math.pi * s / segs))
    faces = []
    for s in range(segs):
        faces.append([0, 1 + s, 1 + (s + 1) % segs])
    for r in range(1, rings):
        a0 = 1 + (r - 1) * segs
        b0 = 1 + r * segs
        for s in range(segs):
            t = (s + 1) % segs
            faces.append([a0 + s, b0 + s, b0 + t, a0 + t])
    return params, faces


def star_outline(inside, samples=360):
    """Radius function r(theta) for a star-shaped region given inside(x, y)."""
    table = []
    for k in range(samples):
        th = 2 * math.pi * k / samples
        lo, hi = 0.0, 1.0
        for _ in range(30):
            mid = (lo + hi) / 2
            if inside(mid * math.cos(th), mid * math.sin(th)):
                lo = mid
            else:
                hi = mid
        table.append(lo)

    def r(th):
        s = (th % (2 * math.pi)) / (2 * math.pi) * samples
        i = int(s) % samples
        return mix(table[i], table[(i + 1) % samples], s - int(s))
    return r


def heart_in(w, h):
    def f(x, y):
        X_ = x / w * 1.15
        Y_ = y / h * 1.15 + 0.15
        return (X_ * X_ + Y_ * Y_ - 1) ** 3 - X_ * X_ * Y_ ** 3 < 0
    return f


def decal(acc, mat, surf, fr, shape, rings, segs, offset):
    """Polar patch ray-projected onto surf along -fr.n; shape(rho, theta) -> (x, y)."""
    params, faces = polar_topology(rings, segs)
    verts = []
    for r, t in params:
        x, y = shape(r, t)
        loc, n = surf.hit(fr.o + fr.n * 0.2 + fr.u * x + fr.v * y, -fr.n)
        verts.append(loc + n * offset(r))
    acc.add(verts, faces, mat)
    return verts, faces


def disc(rx, ry, cx=0.0, cy=0.0):
    return lambda r, t: (cx + r * math.cos(t) * rx, cy + r * math.sin(t) * ry)


def pillow(fr, rfun, extent, thick, rings, segs):
    """Closed flat leaf: a polar patch in frame fr, domed by `thick` on top, half that below."""
    params, top = polar_topology(rings, segs)
    rim0 = 1 + (rings - 1) * segs
    verts = []
    for r, t in params:
        rr = r * rfun(t) * extent
        verts.append(fr.o + fr.u * (rr * math.cos(t)) + fr.v * (rr * math.sin(t))
                     + fr.n * (thick * (1 - r * r)))
    remap = {}
    for i, (r, t) in enumerate(params):
        if i >= rim0:
            remap[i] = i
            continue
        remap[i] = len(verts)
        rr = r * rfun(t) * extent
        verts.append(fr.o + fr.u * (rr * math.cos(t)) + fr.v * (rr * math.sin(t))
                     - fr.n * (0.5 * thick * (1 - r * r)))
    bottom = [[remap[i] for i in reversed(f)] for f in top]
    return verts, orient_closed(verts, top + bottom)


# ---------------------------------------------------------------- mesh accumulation

class Acc:
    def __init__(self):
        self.v, self.f, self.fm = [], [], []

    def add(self, verts, faces, mat):
        base = len(self.v)
        self.v += [Vector(p) for p in verts]
        self.f += [[i + base for i in f] for f in faces]
        self.fm += mat if isinstance(mat, list) else [mat] * len(faces)
        return base

    def extend(self, other):
        self.add(other.v, other.f, other.fm)

    def tri_count(self):
        return sum(len(f) - 2 for f in self.f)


def make_materials(colors):
    mats = {}
    for name, spec in colors.items():
        hexcol, alpha = (spec, 1.0) if isinstance(spec, str) else spec
        m = bpy.data.materials.new(name)
        if m.node_tree is None:
            m.use_nodes = True
        bsdf = m.node_tree.nodes.get("Principled BSDF")
        bsdf.inputs["Base Color"].default_value = lin(hexcol)
        bsdf.inputs["Roughness"].default_value = 0.8
        m.diffuse_color = lin(hexcol)[:3] + [alpha]
        m.use_backface_culling = True
        if alpha < 1.0:
            bsdf.inputs["Alpha"].default_value = alpha
            m.surface_render_method = "BLENDED"
        mats[name] = m
    return mats


def acc_mesh(name, acc, mats):
    me = bpy.data.meshes.new(name)
    me.from_pydata([tuple(v) for v in acc.v], [], acc.f)
    used = list(dict.fromkeys(acc.fm))
    for m in used:
        me.materials.append(mats[m])
    me.polygons.foreach_set("material_index", [used.index(m) for m in acc.fm])
    me.validate()
    return me


def subtract(acc, cutters, mats, cut_mat):
    """Boolean-subtract closed meshes [(verts, faces)] from acc; the new faces get cut_mat."""
    sc = bpy.context.scene
    obj = bpy.data.objects.new("_cut", acc_mesh("_cut", acc, mats))
    sc.collection.objects.link(obj)
    tmp = [obj]
    for i, (cv, cf) in enumerate(cutters):
        c = Acc()
        c.add(cv, orient_closed([Vector(v) for v in cv], cf), cut_mat)
        co = bpy.data.objects.new(f"_cutter{i}", acc_mesh(f"_cutter{i}", c, mats))
        sc.collection.objects.link(co)
        co.hide_render = True
        tmp.append(co)
        mod = obj.modifiers.new(f"cut{i}", "BOOLEAN")
        mod.operation = "DIFFERENCE"
        mod.solver = "EXACT"
        mod.material_mode = "TRANSFER"
        mod.object = co
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(obj.evaluated_get(dg))
    names = [m.name for m in me.materials]
    out = Acc()
    out.v = [v.co.copy() for v in me.vertices]
    out.f = [list(p.vertices) for p in me.polygons]
    out.fm = [names[p.material_index] for p in me.polygons]
    for o in tmp:
        data = o.data
        bpy.data.objects.remove(o)
        bpy.data.meshes.remove(data)
    bpy.data.meshes.remove(me)
    return out


def make_object(name, acc, mats, origin=(0, 0, 0)):
    """Mesh object whose origin sits at `origin` (prop space); vertices stay where they are."""
    o = Vector(origin)
    shifted = Acc()
    shifted.add([v - o for v in acc.v], acc.f, acc.fm)
    me = acc_mesh(name, shifted, mats)
    me.shade_smooth()
    # flat colours need no UVs, but Godot wants them to build tangents: simple spherical map
    uv = me.uv_layers.new(name="UVMap")
    co = [me.vertices[l.vertex_index].co for l in me.loops]
    uv.data.foreach_set("uv", [c for p in co for c in (math.atan2(p.x, -p.y) / (2 * math.pi) + 0.5, p.z)])
    obj = bpy.data.objects.new(name, me)
    obj.location = o
    bpy.context.scene.collection.objects.link(obj)
    return obj


# ---------------------------------------------------------------- milk

MILK_COLORS = dict(glass=("#CDE6F8", 0.28), highlight="#FFFFFF", liquid="#FFF8EA",
                   saucer="#FFC4CF", saucer_rim="#FFF4EA")


def build_milk(mats):
    saucer = [(0, 0.0), (0.040, 0.0), (0.045, 0.002), (0.049, 0.006), (0.078, 0.0125), (0.091, 0.0172),
              (0.0965, 0.0205), (0.0965, 0.0245), (0.0925, 0.0262), (0.086, 0.0235), (0.064, 0.0148),
              (0.054, 0.0112), (0.050, 0.0105), (0, 0.0102)]
    rim = {5, 6, 7, 8}
    sv, sf, sm = lathe(saucer, 28, lambda i, j: "saucer_rim" if i in rim else "saucer")
    s = Acc(); s.add(sv, sf, sm)

    gz = 0.0102  # glass stands on the saucer well
    outer = [(0.0, 0.0), (0.038, 0.0), (0.045, 0.0018), (0.0495, 0.0068), (0.052, 0.018), (0.0555, 0.05),
             (0.0575, 0.088), (0.0568, 0.125), (0.0556, 0.152), (0.0558, 0.1605)]
    inner = [(0.0, 0.0135), (0.033, 0.0135), (0.0405, 0.0165), (0.0445, 0.023), (0.0485, 0.05),
             (0.0508, 0.088), (0.0503, 0.125), (0.0494, 0.152), (0.0496, 0.1605)]
    lip = [(0.0549, 0.1648), (0.0527, 0.1662), (0.0505, 0.1648)]
    prof = outer + lip + list(reversed(inner))
    gv, gf, gm = lathe([(r, z + gz) for r, z in prof], 24, "glass")
    g = Acc(); g.add(gv, gf, gm)

    # highlight stripes sit just outside the outer wall (front-left, plus one on the back)
    def stripe(ang, z0, z1, half, nv=6):
        verts, faces = [], []
        for i in range(nv + 1):
            z = mix(z0, z1, i / nv)
            w = half * math.sqrt(max(0.0, 1 - (2 * i / nv - 1) ** 6))
            r = interp_r(outer[1:], z) + 0.0011
            for a in (ang - w, ang + w):
                verts.append(Vector((r * math.cos(a), r * math.sin(a), z + gz)))
        for i in range(nv):
            a = 2 * i
            faces.append([a, a + 2, a + 3, a + 1])
        # faces must point outward: flip if the first one points inward
        n = (verts[2] - verts[0]).cross(verts[1] - verts[0])
        if n.dot(Vector((verts[0].x, verts[0].y, 0))) < 0:
            faces = [list(reversed(f)) for f in faces]
        g.add(verts, faces, "highlight")

    front = math.radians(-90 - 38)
    stripe(front, 0.03, 0.128, 0.11)
    stripe(front + 0.36, 0.035, 0.07, 0.05, 4)
    stripe(front + math.pi, 0.05, 0.12, 0.08, 4)

    lz = gz + 0.0135  # liquid bottom = glass inner floor
    top = 0.118
    lprof = [(0, 0.0), (0.030, 0.0)]
    for z in (0.003, 0.0095, 0.03, 0.07, top - 0.0035):
        lprof.append((interp_r(inner[1:], z + 0.0135) - 0.0022, z))
    lprof += [(lprof[-1][0] - 0.003, top), (0, top + 0.0012)]
    lv, lf, lm = lathe(lprof, 24, "liquid")
    li = Acc(); li.add([v + Vector((0, 0, lz)) for v in lv], lf, lm)
    return [("milk_glass", g, (0, 0, gz)), ("milk_liquid", li, (0, 0, lz)), ("milk_saucer", s, (0, 0, 0))]


# ---------------------------------------------------------------- fish

FISH_COLORS = dict(fish_body="#FFB48A", fish_belly="#FFE6D0", fish_fin="#F79DB2", fish_bite="#FFD2C6",
                   fish_bone="#FFF6E8", eye="#3B2416", highlight="#FFFFFF")
FISH_X0, FISH_X1 = -0.07, 0.11  # body loft: tail end -> nose
FISH_H = spline1d([(0, 0.015), (0.12, 0.016), (0.3, 0.03), (0.5, 0.044), (0.66, 0.049), (0.82, 0.045),
                   (0.93, 0.036), (1.0, 0.03)])
FISH_W = spline1d([(0, 0.0075), (0.3, 0.017), (0.55, 0.026), (0.78, 0.028), (1.0, 0.024)])


def fish_t(x):
    return (x - FISH_X0) / (FISH_X1 - FISH_X0)


def fish_body():
    n_len, n_around = 12, 10
    path = straight((FISH_X0, 0, 0), (FISH_X1, 0, 0))
    verts, faces, _ts = loft(path, lambda t: (Z, -Y), lambda t: (FISH_H(t), FISH_W(t)),
                             n_len, n_around, 0.06, 0.2)
    # quads come ring by ring; j counts from the top (+Z) toward the camera (-Y) and round
    nq = (n_len - 2) * n_around
    mats = ["fish_belly" if f < nq and 3 <= f % n_around <= 6 else "fish_body" for f in range(len(faces))]
    a = Acc(); a.add(verts, faces, mats)
    return a


def fish_fins(dorsal=True):
    a = Acc()
    for sz in (1, -1):  # tail: two rounded lobes with a V between them
        path = straight((-0.05, 0, 0.004 * sz), (-0.112, 0, 0.043 * sz))
        v, f, _ = loft(path, plane_frame(Y)(path), lambda t: (0.009 + 0.013 * t, 0.006), 6, 6, 0.15, 0.4)
        a.add(v, f, "fish_fin")
    if dorsal:
        path = straight((0.05, 0, 0.036), (0.016, 0, 0.068))
        v, f, _ = loft(path, plane_frame(Y)(path), lambda t: (0.017 * (1 - t) + 0.007, 0.0042), 6, 6, 0.0, 0.45)
        a.add(v, f, "fish_fin")
    return a


def fish_eye(acc, surf):
    loc, n = surf.hit(Vector((0.074, -0.2, 0.012)), Y)
    fr = Frame(loc, (n - Y).normalized())
    w = 0.0105
    ev, ef = decal(acc, "eye", surf, fr, disc(w, w * 1.18), 2, 12, lambda r: 0.0012 + 0.004 * (1 - r * r))
    decal(acc, "highlight", Surf(ev, ef), fr, disc(0.0034, 0.0034, -0.0034, 0.005), 1, 6, lambda r: 0.0005)


def fish_bones(x0, x1, ribs):
    a = Acc()
    v, f = round_tube([(x0, 0, 0), (x1, 0, 0)], 0.0045, 0.0045, 6, 6, 0.1, 0.1)
    a.add(v, f, "fish_bone")
    for x in ribs:
        h = FISH_H(fish_t(x)) * 0.82
        for sz in (1, -1):
            v, f = round_tube([(x + 0.002, 0, 0), (x - 0.003, 0, sz * h * 0.55), (x - 0.01, 0, sz * h)],
                              0.0034, 0.0028, 5, 4, 0.12, 0.3)
            a.add(v, f, "fish_bone")
    return a


def bite_spheres(points, r):
    """Bite cutters: round in the side view, long enough to go through the fish."""
    return [ellipsoid(p, (r, 0.05, r), 8, 6) for p in points]


def build_fish(mats):
    body = fish_body()
    surf = Surf(body.v, body.f)

    def head(xc, r, zs):
        cut = [box((-0.2, -0.1, -0.1), (xc, 0.1, 0.1))] + bite_spheres([(xc, 0, z) for z in zs], r)
        return subtract(body, cut, mats, "fish_bite")

    def tail():
        return subtract(body, [box((-0.046, -0.1, -0.1), (0.2, 0.1, 0.1))], mats, "fish_bite")

    bitten = subtract(body, bite_spheres([(-0.033, 0, 0.03), (-0.012, 0, 0.038), (0.009, 0, 0.045)], 0.021),
                      mats, "fish_bite")
    stages = [[body, fish_fins()],
              [bitten, fish_fins()],
              [head(-0.012, 0.019, (-0.03, 0.0, 0.03)), tail(), fish_fins(),
               fish_bones(-0.052, 0.016, (-0.032, -0.016))],
              [head(0.036, 0.018, (-0.028, 0.0, 0.028)), tail(), fish_fins(dorsal=False),
               fish_bones(-0.052, 0.06, (-0.03, -0.008, 0.014))]]
    out = []
    for i, parts in enumerate(stages):
        a = Acc()
        for p in parts:
            a.extend(p)
        fish_eye(a, surf)
        out.append((f"fish_stage{i}", a, (0, 0, 0)))
    return out


# ---------------------------------------------------------------- yarn

YARN_COLORS = dict(yarn="#F9AFC6", yarn_strand="#F193B2")
YARN_R = 0.066


def build_yarn(mats):
    ball = Acc()
    bv, bf = radial_surface((0, 0, 0), lambda p: p.length - YARN_R, n=6)
    ball.add(bv, bf, "yarn")
    bands = [(Vector((0.35, -0.25, 1.0)), (-0.017, 0.0, 0.017)),
             (Vector((1.0, 0.3, -0.25)), (-0.017, 0.0, 0.017)),
             (Vector((-0.3, 1.0, 0.45)), (-0.009, 0.009))]
    for nrm, offs in bands:
        nrm = nrm.normalized()
        for d in offs:
            R = math.sqrt((YARN_R + 0.0008) ** 2 - d * d)
            v, f = torus(nrm * d, nrm, R, 0.0052, 20, 5)
            ball.add(v, f, "yarn_strand")
    lowest = min(v.z for v in ball.v)
    c = Vector((0, 0, -lowest))
    ball.v = [v + c for v in ball.v]

    # loose end: leaves the ball low on the right and curls on the floor
    start = c + Vector((0.64, -0.2, -0.74)).normalized() * (YARN_R - 0.004)
    pts = [start, start + Vector((0.022, -0.012, -0.012)), Vector((0.098, -0.05, 0.0058)),
           Vector((0.13, -0.068, 0.0058)), Vector((0.152, -0.056, 0.0058)), Vector((0.148, -0.036, 0.0058)),
           Vector((0.133, -0.036, 0.0058))]
    tail = Acc()
    v, f = round_tube(pts, 0.0052, 0.0052, 18, 6, 0.04, 0.12, ref=Z)
    tail.add(v, f, "yarn_strand")
    return [("yarn_ball", ball, c), ("yarn_tail", tail, start)]


# ---------------------------------------------------------------- bone

BONE_COLORS = dict(bone="#FFF0D4")


def build_bone(mats):
    a = Acc()
    rk, dz, xe = 0.0255, 0.0205, 0.0845
    for sx in (1, -1):
        c = Vector((sx * xe, 0, 0))
        sdf = blob_sdf([(c + Vector((0, 0, dz)), (rk, rk * 0.92, rk), 0),
                        (c + Vector((0, 0, -dz)), (rk, rk * 0.92, rk), 0.012)])
        v, f = radial_surface(c, sdf, n=7, rmax=0.1)
        a.add(v, f, "bone")
    r = spline1d([(0, 0.022), (0.2, 0.0185), (0.5, 0.0172), (0.8, 0.0185), (1, 0.022)])
    path = straight((-xe, 0, 0), (xe, 0, 0))
    v, f, _ = loft(path, lambda t: (Z, -Y), lambda t: (r(t), r(t) * 0.94), 11, 14, 0.05, 0.05)
    a.add(v, f, "bone")
    return [("bone", a, (0, 0, 0))]


# ---------------------------------------------------------------- water

WATER_COLORS = dict(bowl="#8FCBF2", bowl_rim="#D2ECFB", bowl_paw="#FFF8EE", liquid="#CDEEFF", highlight="#FFFFFF")


def build_water(mats):
    outer = [(0, 0.0), (0.098, 0.0), (0.106, 0.0025), (0.110, 0.008), (0.119, 0.034), (0.126, 0.052),
             (0.1295, 0.0585)]
    lip = [(0.129, 0.0635), (0.1245, 0.0655), (0.1195, 0.0638)]
    inner = [(0, 0.0145), (0.07, 0.0145), (0.081, 0.017), (0.088, 0.022), (0.101, 0.042), (0.1155, 0.0605)]
    prof = outer + lip + list(reversed(inner))
    rim0 = len(outer) - 1
    bv, bf, bm = lathe(prof, 32, lambda i, j: "bowl_rim" if rim0 <= i < rim0 + 4 else "bowl")
    bowl = Acc(); bowl.add(bv, bf, bm)

    # paw print embossed on the front wall
    surf = Surf(bv, bf)
    pads = [(0.0, 0.027, 0.0105, 0.0088)] + [(dx, 0.04 + dz, 0.0047, 0.0052) for dx, dz in
                                            ((-0.0135, 0.0), (-0.0047, 0.0063), (0.0047, 0.0063), (0.0135, 0.0))]
    for x, z, w, h in pads:
        loc, n = surf.hit(Vector((x, -0.3, z)), Y)
        decal(bowl, "bowl_paw", surf, Frame(loc, n), disc(w, h), 2, 12, lambda r: 0.0012 + 0.0016 * (1 - r * r))

    lz = 0.0145
    level = 0.031
    lprof = [(0, 0.0), (0.068, 0.0)]
    for z in (0.0016, 0.006, 0.013, 0.022, level - 0.0025):
        lprof.append((interp_r(inner[1:], z + lz) - 0.0018, z))
    lprof += [(lprof[-1][0] - 0.0025, level), (0, level)]
    lv, lf, lm = lathe(lprof, 32, "liquid")
    water = Acc(); water.add([v + Vector((0, 0, lz)) for v in lv], lf, lm)
    for x, y, w, h, rot in ((-0.035, -0.035, 0.02, 0.006, -0.5), (0.0, -0.05, 0.007, 0.004, -0.4)):
        params, faces = polar_topology(1, 10)
        ca, sa = math.cos(rot), math.sin(rot)
        verts = []
        for r, t in params:
            px, py = r * math.cos(t) * w, r * math.sin(t) * h
            verts.append(Vector((x + px * ca - py * sa, y + px * sa + py * ca, lz + level + 0.0008)))
        water.add(verts, faces, "highlight")
    return [("water_bowl", bowl, (0, 0, 0)), ("water_liquid", water, (0, 0, lz))]


# ---------------------------------------------------------------- ball

BALL_COLORS = dict(ball_yellow="#FFD166", ball_mint="#8ED9C8", ball_cap="#FFF6EA")
BALL_R = 0.08


def build_ball(mats):
    rings, segs = 16, 32
    prof = [(BALL_R * math.sin(math.pi * i / rings), -BALL_R * math.cos(math.pi * i / rings))
            for i in range(rings + 1)]

    def mat(i, j):
        if i == 0 or i == rings - 1:
            return "ball_cap"
        return "ball_yellow" if (j // 4) % 2 == 0 else "ball_mint"

    v, f, m = lathe(prof, segs, mat)
    # tilt the pole toward the camera and up so the gores read as a pinwheel
    M = (-Y + Z * 0.9 + X * 0.35).normalized().to_track_quat("Z", "Y").to_matrix()
    c = Vector((0, 0, BALL_R))
    a = Acc(); a.add(transform(v, M, c), f, m)
    return [("ball", a, c)]


# ---------------------------------------------------------------- carrot

CARROT_COLORS = dict(carrot="#FFA35A", carrot_line="#EC8240", carrot_bite="#FFD59C",
                     carrot_leaf="#8FD3A4", carrot_leaf_dark="#6FC08C")
CARROT_GRIP = 0.052  # grip point above the crown (lower third of the 0.155 root)
CARROT_LINES = [(0.04, ((-115, -40), (60, 120))), (0.065, ((-60, 5), (145, 180))),
                (0.09, ((-140, -85), (20, 80))), (0.115, ((-75, -25), (110, 170)))]


def carrot_root():
    """Lathe from the crown (bottom pole) to the tip, with grooves where the darker lines are."""
    keys = [(0.026, 0.005), (0.0305, 0.012), (0.032, 0.022), (0.0305, 0.04), (0.0278, 0.065), (0.0228, 0.09),
            (0.0168, 0.115), (0.0102, 0.135), (0.0048, 0.1485), (0.0016, 0.1542)]
    rof = spline1d([(z, r) for r, z in keys])
    half = 0.0021
    zs = [z for _r, z in keys if all(abs(z - s) > half + 0.002 for s, _a in CARROT_LINES)]
    zs += [s + d for s, _a in CARROT_LINES for d in (-half, half)]
    prof = [(0, 0.0), (0.017, 0.0008)]
    for z in sorted(zs):
        groove = any(abs(z - s) <= half + 1e-6 for s, _a in CARROT_LINES)
        prof.append((rof(z) - (0.0009 if groove else 0.0), z))
    prof.append((0, 0.1556))
    line_seg = {i: arcs for i in range(len(prof) - 1) for s, arcs in CARROT_LINES
                if abs(prof[i][1] - (s - half)) < 1e-6}
    segs = 16

    def mat(i, j):
        ang = math.degrees(2 * math.pi * (j + 0.5) / segs)
        ang = ang - 360 if ang > 180 else ang
        return "carrot_line" if any(lo <= ang <= hi for lo, hi in line_seg.get(i, ())) else "carrot"

    v, f, m = lathe(prof, segs, mat)
    a = Acc(); a.add([p - Vector((0, 0, CARROT_GRIP)) for p in v], f, m)
    return a


def carrot_bite(top, r, rad, n, phase):
    """Cutters removing the root above `top` (crown space) with a scalloped, bitten edge."""
    zc = top + r * 0.5 - CARROT_GRIP
    cut = [box((-0.1, -0.1, zc), (0.1, 0.1, 0.3))]
    for k in range(n):
        a = phase + 2 * math.pi * k / n
        cut.append(ellipsoid((rad * math.cos(a), rad * math.sin(a), zc), (r, r, r), 10, 6))
    return cut


def build_carrot(mats):
    root = carrot_root()
    stages = [root,
              subtract(root, carrot_bite(0.11, 0.013, 0.0175, 3, 1.0), mats, "carrot_bite"),
              subtract(root, carrot_bite(0.074, 0.017, 0.026, 4, 0.4), mats, "carrot_bite"),
              subtract(root, carrot_bite(0.026, 0.008, 0.0315, 6, 0.3), mats, "carrot_bite")]
    leaves = Acc()
    crown = Vector((0, 0, -CARROT_GRIP + 0.004))
    for ang, tilt, length, mat in ((0, 0, 0.074, "carrot_leaf"), (36, -12, 0.062, "carrot_leaf_dark"),
                                   (-34, 12, 0.064, "carrot_leaf_dark"), (68, 18, 0.046, "carrot_leaf"),
                                   (-70, -20, 0.047, "carrot_leaf")):
        a = math.radians(ang)
        d = Vector((math.sin(a), math.sin(math.radians(tilt)) * 0.6, -math.cos(a))).normalized()
        bend = Vector((math.sin(a) * 0.35, 0, 0))
        path = polyline([crown, crown + d * length * 0.5 + bend * length * 0.2, crown + d * length + bend * length * 0.5])
        nrm = Y if abs(ang) < 50 else Vector((math.copysign(0.3, ang), 1, 0)).normalized()
        v, f, _ = loft(path, tube_frame(path, nrm),
                       lambda t: (0.0028 + 0.0112 * math.sin(math.pi * t ** 0.75) ** 0.8, 0.0032), 7, 6, 0.06, 0.25)
        leaves.add(v, f, mat)
    out = [(f"carrot_stage{i}", s, (0, 0, 0)) for i, s in enumerate(stages)]
    out.append(("carrot_leaves", leaves, crown))
    return out


# ---------------------------------------------------------------- clover

CLOVER_COLORS = dict(grass="#A9DFA2", clover="#6EC58C")
CLOVERS = [  # (x, y, hub height, spin deg, scale); stage k keeps CLOVERS[k:]
    (0.004, -0.03, 0.062, 8, 1.0),
    (-0.07, 0.008, 0.052, -14, 0.9),
    (0.072, 0.012, 0.055, 22, 0.94),
]


def clover_tuft():
    a = Acc()
    prof = [(0, 0.0), (0.08, 0.0), (0.079, 0.011), (0.056, 0.025), (0.024, 0.031), (0, 0.032)]
    v, f, m = lathe(prof, 12, "grass")
    a.add([Vector((p.x, p.y * 0.72, p.z)) for p in v], f, m)
    for ang, h in ((-155, 0.026), (-120, 0.034), (-88, 0.028), (-55, 0.034), (-22, 0.026), (150, 0.028), (30, 0.03)):
        out = Vector((math.cos(math.radians(ang)), 0.72 * math.sin(math.radians(ang)), 0))
        base = Vector((out.x * 0.068, out.y * 0.068, 0.006))
        tip = base + out.normalized() * 0.016 + Z * h
        path = polyline([base, base.lerp(tip, 0.5) - out * 0.003, tip])
        v, f, _ = loft(path, tube_frame(path, -out.normalized()), lambda t: (0.0115 * (1 - t ** 1.4) + 0.0008, 0.0026),
                       4, 4, 0.0, 0.1)
        a.add(v, f, "grass")
    return a


def clover(x, y, h, spin, s):
    a = Acc()
    base = Vector((x, y, 0.02))
    hub = Vector((x, y - 0.01, h))
    v, f = round_tube([base, hub], 0.0064, 0.0058, 4, 5, 0.0, 0.2)
    a.add(v, f, "clover")
    rfun = star_outline(heart_in(0.5, 0.5))
    face = Frame(hub, Vector((0.12 * x / 0.07, -0.72, 0.68)))  # trefoil faces the camera and up
    for k in range(3):
        ang = math.radians(90 + spin + 120 * k)
        out = face.u * math.cos(ang) + face.v * math.sin(ang)
        fr = Frame(hub + out * 0.021 * s + face.n * 0.003, (face.n + out * 0.25).normalized(), up=out)
        v, f = pillow(fr, rfun, 0.05 * s, 0.004, 2, 10)
        a.add(v, f, "clover")
    return a


def build_clover(mats):
    stages = []
    for k in range(4):
        a = clover_tuft()
        for spec in CLOVERS[k:]:
            a.extend(clover(*spec))
        stages.append(a)
    return [(f"clover_stage{i}", s, (0, 0, 0)) for i, s in enumerate(stages)]


# ---------------------------------------------------------------- bell

BELL_COLORS = dict(bell="#FFD166", bell_band="#F5B544", bell_inner="#D99A45", ribbon="#F7A8BA")


def build_bell(mats):
    # hollow lathe: outer top pole -> down the outside -> round the lip -> up the inside
    outer = [(0, 0.088), (0.012, 0.0868), (0.0215, 0.0828), (0.0285, 0.0745), (0.032, 0.061), (0.0338, 0.046),
             (0.0372, 0.031), (0.0425, 0.0185), (0.0475, 0.0118), (0.0525, 0.0062), (0.0552, 0.0022)]
    lip = [(0.0548, -0.0012), (0.0515, -0.0018), (0.0488, 0.0008)]
    inner = [(0.0445, 0.0065), (0.0385, 0.0155), (0.0325, 0.03), (0.0287, 0.046), (0.0262, 0.06),
             (0.0205, 0.0712), (0.011, 0.077), (0, 0.0782)]
    prof = outer + lip + inner
    n_out = len(outer)

    def mat(i, j):
        if i >= n_out + len(lip) - 1:
            return "bell_inner"
        if 7 <= i <= 8:
            return "bell_band"
        return "bell"

    bv, bf, bm = lathe(prof, 22, mat)
    body = Acc(); body.add(bv, bf, bm)
    v, f = ellipsoid((0, 0, -0.005), (0.0125, 0.0125, 0.0125), 10, 7)  # clapper
    body.add(v, f, "bell_band")
    v, f, m = lathe([(0, -0.004), (0.0028, -0.004), (0.0028, 0.08), (0, 0.08)], 6, "bell_inner")
    body.add(v, f, m)
    v, f, m = lathe([(0, 0.084), (0.0085, 0.0845), (0.0105, 0.091), (0.0085, 0.0975), (0, 0.0985)], 12, "bell_band")
    body.add(v, f, m)

    # ribbon: a teardrop loop facing the camera from the knob up to the hang point, bow on the knob
    knob = 0.0975
    hang = knob + 0.058
    ribbon = Acc()
    n = 24
    loop = []
    for k in range(n):
        th = 2 * math.pi * k / n
        x = 0.019 * math.sin(th) * (0.55 + 0.45 * math.sin(th / 2))
        loop.append(Vector((x, 0, knob - 0.002 + (hang - knob + 0.002) * 0.5 * (1 - math.cos(th)))))
    verts, faces = [], []
    for i, p in enumerate(loop):
        tan = (loop[(i + 1) % n] - loop[i - 1]).normalized()
        side = Y.cross(tan).normalized()
        for j in range(6):
            a = 2 * math.pi * j / 6
            verts.append(p + side * (0.0055 * math.cos(a)) + Y * (0.0024 * math.sin(a)))
    for i in range(n):
        for j in range(6):
            i2, j2 = (i + 1) % n, (j + 1) % 6
            faces.append([i * 6 + j, i2 * 6 + j, i2 * 6 + j2, i * 6 + j2])
    ribbon.add(verts, orient_closed(verts, faces), "ribbon")
    knot = Vector((0, -0.0095, knob - 0.004))
    v, f = ellipsoid(knot, (0.0072, 0.0058, 0.0066), 10, 6)
    ribbon.add(v, f, "ribbon")
    for sx in (1, -1):
        c = knot + Vector((sx * 0.0165, 0.001, 0.002))
        v, f = radial_surface(c, blob_sdf([(c, (0.0155, 0.005, 0.0105), 0)]), n=3, rmax=0.05)
        ribbon.add(transform([p - c for p in v], Matrix.Rotation(sx * -0.25, 3, Y), c), f, "ribbon")
    # the whole prop hangs from the ribbon top: that point becomes the prop origin
    off = Vector((0, 0, -max(p.z for p in ribbon.v)))
    for a in (body, ribbon):
        a.v = [p + off for p in a.v]
    return [("bell_body", body, (0, 0, knob + 0.001 + off.z)), ("bell_ribbon", ribbon, (0, 0, 0))]


# ---------------------------------------------------------------- driver

SPECS = {
    "milk": (MILK_COLORS, build_milk),
    "fish": (FISH_COLORS, build_fish),
    "yarn": (YARN_COLORS, build_yarn),
    "bone": (BONE_COLORS, build_bone),
    "water": (WATER_COLORS, build_water),
    "ball": (BALL_COLORS, build_ball),
    "carrot": (CARROT_COLORS, build_carrot),
    "clover": (CLOVER_COLORS, build_clover),
    "bell": (BELL_COLORS, build_bell),
}


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.preferences.filepaths.save_version = 0


def build(prop):
    colors, fn = SPECS[prop]
    reset_scene()
    mats = make_materials(colors)
    parts = fn(mats)
    for name, acc, origin in parts:
        make_object(name, acc, mats, origin)
    tris = {n: a.tri_count() for n, a, _o in parts}
    # stages are shown one at a time: the budget is what is on screen at once
    stages = [t for n, t in tris.items() if "_stage" in n]
    shown = sum(t for n, t in tris.items() if "_stage" not in n) + max(stages, default=0)
    lo = Vector([min(v[i] for _n, a, _o in parts for v in a.v) for i in range(3)])
    hi = Vector([max(v[i] for _n, a, _o in parts for v in a.v) for i in range(3)])
    size = hi - lo
    detail = " ".join(f"{n}={t}" for n, t in tris.items())
    print(f"[{prop}] tris glb={sum(tris.values())} shown={shown} ({detail}) "
          f"size x={size.x:.3f} y={size.y:.3f} z={size.z:.3f} zmin={lo.z:.3f}")
    assert shown <= MAX_TRIS, f"{prop}: {shown} triangles on screen"

    GLB_DIR.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=str(GLB_DIR / f"{prop}.glb"),
        export_format="GLB",
        export_apply=False,
        export_skins=True,
        export_morph=True,
        export_morph_normal=True,
        export_animations=True,
        export_animation_mode="ACTIONS",
        export_def_bones=True,
        export_yup=True,
    )


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--prop", default="all", choices=PROPS + ["all"])
    args = ap.parse_args(argv)
    for prop in PROPS if args.prop == "all" else [args.prop]:
        build(prop)


if __name__ == "__main__":
    main()
