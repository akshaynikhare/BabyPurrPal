"""Procedurally build the BabyPurrPal pets (cat, dog, bunny) and export one GLB each.

Run from the repo root:
  /Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup \
      -P tools/blender/build_pets.py -- --pet cat|dog|bunny|all

Modelling approach (no hand-made assets):
  * Head and torso are star-shaped implicit surfaces (smooth union of ellipsoids).
    The torso is sampled radially from a cube-sphere, which gives clean quad topology.
    The head is meshed as rings around the mouth (build_head): the mouth is a real
    opening into a bowl-shaped cavity with lips and a 3D tongue, and jaw_open, smile and
    nose_twitch move the head's own vertices. The muzzle colour is a thin copy of the
    head's muzzle rings, so it follows those keys exactly.
  * Limbs, ears and tails are lofted tubes.
  * Other colour regions (belly, patches, cheeks, eyes, nose) are thin "decal" shells
    ray-projected onto the surface. Their shape keys are alternate 2D layouts of the same
    decal topology re-projected, so the eyes always hug the face.
  * Skin weights are written explicitly per part.
  * Clips are keyframed per bone; face clips also key the head shape keys in the same
    action (a second slot), which the glTF exporter merges into one animation.
Blender is Z-up facing -Y; the glTF exporter converts that to Y-up facing +Z.
"""

import argparse
import math
import sys
from pathlib import Path

import bpy
import bmesh
from mathutils import Euler, Matrix, Vector
from mathutils.bvhtree import BVHTree
from mathutils.interpolate import poly_3d_calc

HERE = Path(__file__).resolve().parent
REPO = HERE.parent.parent
GLB_DIR = REPO / "assets" / "characters"
BLEND_DIR = HERE / "out"
FPS = 60
FWD = Vector((0, -1, 0))
SHAPE_KEYS = ["jaw_open", "blink_L", "blink_R", "smile", "ear_perk", "nose_twitch"]


# ---------------------------------------------------------------- math helpers

def lin(hexstr):
    h = hexstr.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return [x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c] + [1.0]


def smoothstep(a, b, x):
    t = min(max((x - a) / (b - a), 0.0), 1.0)
    return t * t * (3 - 2 * t)


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


def rot(deg):
    return Euler([math.radians(a) for a in deg], "XYZ").to_matrix()


def mirror_deg(deg):
    return (deg[0], -deg[1], -deg[2])


# ---------------------------------------------------------------- geometry builders

def radial_surface(center, sdf, n=20, rmax=1.2):
    """Cube-sphere whose vertices are pushed along rays from `center` onto sdf == 0."""
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


def loft(path, frame, prof, n_len=16, n_around=16, cap0=0.25, cap1=0.25):
    """Closed tube along path(t), t in [0,1].
    frame(t) -> (side, front) unit vectors; prof(t) -> (half_width, half_thickness).
    Ends are rounded by a circular closure over the first/last `cap` fraction.
    Returns verts, faces, per-vertex t."""
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


def orient_closed(verts, faces):
    vol = 0.0
    for f in faces:
        for i in range(1, len(f) - 1):
            vol += verts[f[0]].dot(verts[f[i]].cross(verts[f[i + 1]]))
    return faces if vol > 0 else [list(reversed(f)) for f in faces]


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


# ---------------------------------------------------------------- surfaces & decals

class Surf:
    """Ray-cast target with smooth normals and skin weights."""

    def __init__(self, verts, faces, weights):
        self.v = verts
        self.w = weights
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
            loc, _n, idx, _d = self.bvh.find_nearest(origin + direction * 0.3)
        a, b, c = self.tris[idx]
        bw = poly_3d_calc([self.v[a], self.v[b], self.v[c]], loc)
        n = (self.vn[a] * bw[0] + self.vn[b] * bw[1] + self.vn[c] * bw[2]).normalized()
        w = {}
        for vi, k in zip((a, b, c), bw):
            for bone, x in self.w[vi].items():
                w[bone] = w.get(bone, 0.0) + x * k
        return loc, n, w


class Frame:
    def __init__(self, anchor, n, up=Vector((0, 0, 1))):
        self.o = Vector(anchor)
        self.n = Vector(n).normalized()
        u = up.cross(self.n)  # u x v = n with v roughly along `up`
        u = Vector((1, 0, 0)) if u.length < 1e-6 else u
        self.u = (u - self.n * u.dot(self.n)).normalized()
        self.v = self.n.cross(self.u).normalized()


def face_frame(surf, x, z, bend=0.0):
    """Frame anchored where a forward ray at world (x, z) meets the surface.
    bend blends the projection direction from straight-forward toward the surface normal."""
    loc, n, _w = surf.hit(Vector((x, -2.0, z)), Vector((0, 1, 0)))
    d = (FWD * (1 - bend) + n * bend).normalized()
    return Frame(loc, d)


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


def project(surf, frame, pts2d, offsets):
    out, ws = [], []
    for (x, y), off in zip(pts2d, offsets):
        origin = frame.o + frame.n * 0.4 + frame.u * x + frame.v * y
        loc, n, w = surf.hit(origin, -frame.n)
        out.append(loc + n * off)
        ws.append(w)
    return out, ws


def star_outline(inside, samples=720):
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


def ellipse_in(cx, cy, rx, ry):
    return lambda x, y: ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 < 1


def heart_in(w, h):
    def f(x, y):
        X = x / w * 1.15
        Y = y / h * 1.15 + 0.15
        return (X * X + Y * Y - 1) ** 3 - X * X * Y ** 3 < 0
    return f


# ---------------------------------------------------------------- mesh accumulation

class Acc:
    def __init__(self):
        self.v, self.f, self.fm, self.w = [], [], [], []
        self.keys = {}

    def add(self, verts, faces, mat, weights, keys=None):
        base = len(self.v)
        self.v += [Vector(p) for p in verts]
        self.f += [[i + base for i in f] for f in faces]
        self.fm += mat if isinstance(mat, list) else [mat] * len(faces)
        self.w += weights if isinstance(weights, list) else [dict(weights) for _ in verts]
        for name, pos in (keys or {}).items():
            d = self.keys.setdefault(name, {})
            for i, p in enumerate(pos):
                d[base + i] = Vector(p)
        return base

    def tri_count(self):
        return sum(len(f) - 2 for f in self.f)


def add_decal_polar(acc, mat, surf, frame, shape, rings, segs, offset, keys=None):
    """shape(rho, theta) -> (x, y); offset(rho) -> normal offset.
    keys: name -> (surf, frame, shape, offset) alternate layouts."""
    params, faces = polar_topology(rings, segs)
    pts = [shape(r, t) for r, t in params]
    verts, ws = project(surf, frame, pts, [offset(r) for r, _t in params])
    kv = {}
    for name, (ks, kf, kshape, koff) in (keys or {}).items():
        kp = [kshape(r, t) for r, t in params]
        kv[name], _ = project(ks, kf, kp, [koff(r) for r, _t in params])
    base = acc.add(verts, faces, mat, ws, kv)
    return base, verts, faces, ws


# ---------------------------------------------------------------- face

def build_eye(acc, head, ex, ez, ew, eh, side, blink_key, bend=0.45):
    fr = face_frame(head, ex, ez, bend)
    dome = 0.010

    def rest(r, t):
        return (r * math.cos(t) * ew, r * math.sin(t) * eh)

    def arc(x):
        return -eh * 0.22 + eh * 0.30 * (x / ew) ** 2

    def closed(r, t):
        x = r * math.cos(t) * ew * 1.12
        return (x, arc(x) + r * math.sin(t) * eh * 0.11)

    _b, ev, ef, ew_ = add_decal_polar(
        acc, "eye", head, fr, rest, 6, 32, lambda r: 0.002 + dome * (1 - r * r),
        keys={blink_key: (head, fr, closed, lambda r: 0.0022 + 0.002 * (1 - r * r))})
    eye_surf = Surf(ev, ef, ew_)
    for hx, hy, hr in ((-0.38, 0.42, 0.36), (0.40, -0.40, 0.15)):
        cx, cy = hx * ew, hy * eh
        rr = hr * ew

        def hl(r, t, cx=cx, cy=cy, rr=rr):
            return (cx + r * math.cos(t) * rr, cy + r * math.sin(t) * rr)

        def hidden(r, t, cx=cx):
            x = cx * 0.2 + r * math.cos(t) * 0.0006
            return (x, arc(x) + r * math.sin(t) * 0.0006)

        add_decal_polar(acc, "eye_highlight", eye_surf, fr, hl, 2, 16, lambda r: 0.0012,
                        keys={blink_key: (head, fr, hidden, lambda r: 0.0016)})


def build_nose(acc, head, nz, nw, nh, dome, tri=0.16, twitch=None):
    """twitch: (field, lift) adds a nose_twitch layout: lifted, a little narrower and taller."""
    fr = face_frame(head, 0.0, nz, 0.0)

    def shape(r, t):
        k = 1 + tri * math.cos(3 * t + 1.5 * math.pi)
        return (r * k * math.cos(t) * nw, r * k * math.sin(t) * nh)

    _b, verts, _f, _w = add_decal_polar(acc, "nose", head, fr, shape, 5, 28,
                                        lambda r: 0.0045 + dome * (1 - r * r) ** 0.7)
    if twitch:
        field, lift = twitch
        c = fr.o
        tw = []
        for p in verts:
            q = p - c
            tw.append(c + Vector((q.x * 0.92, q.y, q.z * 1.07)) + Vector((0, -0.0006, lift)))
        acc.keys.setdefault("nose_twitch", {}).update({_b + i: p for i, p in enumerate(tw)})


# ---------------------------------------------------------------- head with a real mouth
#
# The head is one polar mesh around the mouth: rings run from the bottom of the mouth bag
# (oral cavity) out over the lips and muzzle to a pole at the back of the head. At rest
# the bag is a shallow pocket behind a thin slit (the dark "w" line); in jaw_open the lower
# face rotates down about a hinge and the bag unfolds into a bowl, so the opening is a real
# hole with depth. Near rings are placed by forward rays (exact X/Z layout on the face),
# far rings by rays from the head centre (azimuthal around the mouth axis).

SEGS = 56
LIP_D = (0.0016, 0.0036)
LIP_D_REST = (0.0011, 0.0024)
MUZZLE_RINGS = 5
FAR_RINGS = 30
BAG_Q = (0.2, 0.36, 0.52, 0.66, 0.79, 0.9, 0.965)
DEEP_Q = 0.6
MUZZLE_OFF = 0.0015


def march(sdf, origin, d, t1, step=0.004):
    """First sdf crossing along origin + d*t, starting outside."""
    prev, t = 0.0, 0.0
    while sdf(origin + d * t) >= 0:
        prev, t = t, t + step
        if t > t1:
            return None
    lo, hi = prev, t
    for _ in range(28):
        mid = (lo + hi) * 0.5
        if sdf(origin + d * mid) < 0:
            hi = mid
        else:
            lo = mid
    return origin + d * hi


def ray_out(sdf, c, d, rmax=1.2):
    lo, hi = 0.0, rmax
    for _ in range(30):
        mid = (lo + hi) * 0.5
        if sdf(c + d * mid) < 0:
            lo = mid
        else:
            hi = mid
    return c + d * lo


def soft_abs(u, e=0.004):
    return (math.sqrt(u * u + e) - math.sqrt(e)) / (math.sqrt(1 + e) - math.sqrt(e))


def vertex_normals(verts, faces):
    vn = [Vector() for _ in verts]
    for f in faces:
        for i in range(1, len(f) - 1):
            a, b, c = f[0], f[i], f[i + 1]
            n = (verts[b] - verts[a]).cross(verts[c] - verts[a])
            vn[a] += n; vn[b] += n; vn[c] += n
    return [n.normalized() for n in vn]


def rot_x(p, pivot, ang):
    return pivot + Matrix.Rotation(ang, 3, "X") @ (p - pivot)


def build_head(S, acc):
    """Adds the head surface, mouth bag, tongue and muzzle to acc with their shape keys."""
    hc = Vector(S["head_c"])
    sdf = blob_sdf(S["head"])
    m = S["mouth"]
    mz, W0, a, W1, H = m["z"], m["W0"], m["a"], m["W1"], m["H"]
    gap = m.get("gap", 0.0065)
    smile_lift = 0.008
    Hp = H * 0.3
    phis = [2 * math.pi * j / SEGS for j in range(SEGS)]

    def front(x, y):
        return march(sdf, Vector((x, -0.7, mz + y)), Vector((0, 1, 0)), 1.4)

    def w_line(u, amp, e=0.004):
        return -amp * math.sin(math.pi * soft_abs(u, e))

    def opening(ph, k):
        return math.copysign(abs(math.sin(ph)) ** k, math.sin(ph))

    def rim_rest(ph):
        # the lower edge's peak is rounded so the lip band below it cannot fold over itself
        u = math.cos(ph)
        return (W0 * u, w_line(u, a, 0.004 if math.sin(ph) > 0 else 0.03) + 0.5 * gap * opening(ph, 0.8))

    def rim_open(ph):
        u = math.cos(ph)
        s = math.sin(ph)
        y = w_line(u, a * 0.45) + (0.002 * s if s > 0 else -Hp * abs(s) ** 1.1)
        return (W1 * u, y)

    def rim_smile(ph):
        u = math.cos(ph)
        y = (w_line(u, a * 0.35) - 0.014 * (1 - u * u) + smile_lift * u ** 4
             + 0.6 * gap * opening(ph, 0.8))
        return (W0 * 1.3 * u, y)

    # muzzle outline (same lobes as the old muzzle decal) as a star around the mouth centre
    dz = mz - S["muzzle_z"]
    ins = [ellipse_in(cx, cy, rx, ry) for cx, cy, rx, ry in S["muzzle"]]
    r_mz = star_outline(lambda x, y: any(f(x, y + dz) for f in ins))

    def muzzle_pt(ph):
        psi = math.atan2(0.7 * math.sin(ph), math.cos(ph))
        r = r_mz(psi)
        return (r * math.cos(psi), r * math.sin(psi))

    def near_rings(rim, lip_d=LIP_D):
        """Param (x, y) rings: rim, lip band, muzzle rings out to the muzzle outline."""
        rings = [[rim(ph) for ph in phis]]
        pts = [Vector(p) for p in rings[0]]
        nrm = []
        for j in range(SEGS):
            t = pts[(j + 1) % SEGS] - pts[j - 1]
            nrm.append(Vector((t.y, -t.x)).normalized())
        nrm = [(nrm[j - 1] + nrm[j] * 2 + nrm[(j + 1) % SEGS]).normalized() for j in range(SEGS)]
        for d in lip_d:
            rings.append([(p.x + n.x * d, p.y + n.y * d) for p, n in zip(pts, nrm)])
        # muzzle rings leave the lip along its normal, then bend toward the muzzle outline
        lip = [Vector(p) for p in rings[-1]]
        outline = [Vector(muzzle_pt(ph)) for ph in phis]
        ctrl = [p + (n + (o - p).normalized()).normalized() * (0.4 * (o - p).length)
                for p, n, o in zip(lip, nrm, outline)]
        for i in range(1, MUZZLE_RINGS + 1):
            s = (i / MUZZLE_RINGS) ** 1.25
            rings.append([tuple(p * (1 - s) ** 2 + c * (2 * s * (1 - s)) + o * s * s)
                          for p, c, o in zip(lip, ctrl, outline)])
        return rings

    def to3d(rings):
        return [[front(x, y) for x, y in ring] for ring in rings]

    near_rest = near_rings(rim_rest, LIP_D_REST)
    near_open = near_rings(rim_open)
    near_smile = near_rings(rim_smile)
    rest3 = to3d(near_rest)
    open3 = to3d(near_open)
    smile3 = to3d(near_smile)

    def cheek_raise(p):
        """Smiling pushes the cheeks above the mouth corners up a little."""
        cx = W0 * 1.3 + 0.014
        d = math.hypot(abs(p.x) - cx, p.z - mz - 0.022) / 0.035
        return p + Vector((0, -0.0008, 0.003)) * max(0.0, 1 - d * d) ** 2

    smile3 = [[cheek_raise(p) for p in ring] for ring in smile3]

    # far rings: azimuthal around the mouth axis, from the muzzle outline to the back pole
    mc = front(0.0, 0.0)
    A = (mc - hc).normalized()
    U = Vector((1, 0, 0))
    V = (Vector((0, 0, 1)) - A * A.z).normalized()
    start = []
    for p, ph in zip(rest3[-1], phis):
        d = (p - hc).normalized()
        th = math.acos(max(-1.0, min(1.0, d.dot(A))))
        az = math.atan2(d.dot(V), d.dot(U))
        dphi = (ph - az + math.pi) % (2 * math.pi) - math.pi
        start.append((th, az, dphi))
    far = []
    for i in range(1, FAR_RINGS + 1):
        t = i / (FAR_RINGS + 1)
        f = t ** 1.15
        ring = []
        for th0, az0, dphi in start:
            th = mix(th0, math.pi, f)
            az = az0 + dphi * smoothstep(0.0, 1.0, t)
            d = A * math.cos(th) + (U * math.cos(az) + V * math.sin(az)) * math.sin(th)
            ring.append(ray_out(sdf, hc, d))
        far.append(ring)
    back_pole = ray_out(sdf, hc, -A)

    # jaw: lower face rotates down about a hinge behind the mouth, weighted by a soft mask
    hinge = Vector((0, mc.y + 0.185, mc.z + 0.02))
    lower_lip = open3[0][SEGS * 3 // 4]
    jaw_ang = H * 0.7 / (lower_lip - hinge).length

    def jaw_mask(p, side):
        x = p.x
        dy = p.z - mz - (w_line(max(-1.0, min(1.0, x / W0)), a) if abs(x) < W0 else 0.0)
        vert = side if side is not None else smoothstep(0.0, 0.015, -dy)
        w = W0 + 1.5 * max(0.0, -dy)
        lat = max(0.0, 1 - (x / w) ** 2) ** 0.6
        fade = 1 - smoothstep(-0.12, -0.02, p.y - hc.y)
        return vert * lat * fade

    sides = [1.0 if math.sin(ph) < -1e-6 else 0.0 for ph in phis]
    open3 = [[rot_x(p, hinge, jaw_ang * jaw_mask(q, sd)) for p, q, sd in zip(ring, rring, sides)]
             for ring, rring in zip(open3, rest3)]
    far_open = [[rot_x(p, hinge, jaw_ang * jaw_mask(p, None)) for p in ring] for ring in far]
    pole_open = rot_x(back_pole, hinge, jaw_ang * jaw_mask(back_pole, None))

    # mouth bag: pocket behind the slit at rest, a bowl with a slight undercut when open
    def bag(rim, depth, undercut):
        c = sum(rim, Vector()) / len(rim)
        pole_y = max(p.y for p in rim) + depth
        rings = []
        for q in BAG_Q:
            L = math.sin(math.pi * q / 2) * (1 + undercut * math.sin(math.pi * q))
            k = math.cos(math.pi * q / 2)
            rings.append([Vector((c.x + (p.x - c.x) * L, p.y + (pole_y - p.y) * k, c.z + (p.z - c.z) * L))
                          for p in rim])
        return Vector((c.x, pole_y, c.z)), rings

    depth = m.get("depth", H * 0.62)
    bag_rest = bag(rest3[0], 0.007, 0.0)
    bag_open = bag(open3[0], depth, 0.12)
    bag_smile = bag(smile3[0], 0.007, 0.0)

    def assemble(bag_, near3, far_, pole):
        pts = [bag_[0]]
        for ring in bag_[1] + near3 + far_:
            pts += ring
        return pts + [pole]

    verts = assemble(bag_rest, rest3, far, back_pole)
    states = {"jaw_open": assemble(bag_open, open3, far_open, pole_open),
              "smile": assemble(bag_smile, smile3, [[cheek_raise(p) for p in r] for r in far], back_pole)}

    # faces, ring by ring from the bag pole outward; materials per band
    n_rings = len(BAG_Q) + len(rest3) + FAR_RINGS
    q_of = list(BAG_Q) + [1.0]
    faces, mats = [], []

    def ring_mat(r):
        """Material of the band between ring r and r + 1 (r = -1: bag pole fan)."""
        nb = len(BAG_Q)
        if r < nb:
            qa = 0.0 if r < 0 else q_of[r]
            return "mouth_deep" if qa < DEEP_Q else ("lip" if qa >= 0.965 else "mouth_inner")
        if r < nb + len(LIP_D):
            return "lip"
        return "body"

    def ring_v(r, j):
        return 1 + r * SEGS + j % SEGS

    for j in range(SEGS):
        faces.append([0, ring_v(0, j + 1), ring_v(0, j)])
        mats.append(ring_mat(-1))
    for r in range(n_rings - 1):
        mt = ring_mat(r)
        for j in range(SEGS):
            faces.append([ring_v(r, j), ring_v(r, j + 1), ring_v(r + 1, j + 1), ring_v(r + 1, j)])
            mats.append(mt)
    last = len(verts) - 1
    for j in range(SEGS):
        faces.append([last, ring_v(n_rings - 1, j), ring_v(n_rings - 1, j + 1)])
        mats.append("body")
    faces = orient_closed(verts, faces)

    # tongue: rounded slab with a centre groove, hidden in the pocket at rest
    tw_, tl, tt = W1 * 0.56, m.get("tongue_len", 0.026), 0.0105

    def t_prof(t):
        return (tw_ * (1 - 0.12 * t), tt * (1 - 0.15 * t))

    tpath = straight((0, -tl, 0), (0, tl, 0))
    tv, tf, _tts = loft(tpath, lambda t: (Vector((1, 0, 0)), Vector((0, 0, 1))), t_prof, 12, 20, 0.4, 0.3)
    for v in tv:
        if v.z > 0:
            tip = smoothstep(-tl, -0.2 * tl, v.y)
            v.z -= 0.0013 * tip * math.exp(-(v.x / (0.4 * tw_)) ** 2) * (v.z / tt)
    lo_rest = rest3[0][SEGS * 3 // 4]
    lo_open = open3[0][SEGS * 3 // 4]
    lo_smile = smile3[0][SEGS * 3 // 4]
    R = Matrix.Rotation(jaw_ang, 3, "X")
    t_open_c = lo_open + R @ Vector((0, tl + 0.0035, tt * 0.25))
    t_rest_c = bag_rest[0] + Vector((0, 0.012, -gap * 0.3))
    tongue_rest = [t_rest_c + v * 0.08 for v in tv]
    tongue_keys = {"jaw_open": [t_open_c + R @ v for v in tv],
                   "smile": [p + (lo_smile - lo_rest) for p in tongue_rest]}

    # muzzle colour: a thin copy of the muzzle rings floating over the head surface
    nb = len(BAG_Q)
    k0 = nb + len(LIP_D)
    k1 = nb + len(rest3) - 1
    mfaces = []
    for r in range(k1 - k0):
        for j in range(SEGS):
            a_, b_ = r * SEGS + j, r * SEGS + (j + 1) % SEGS
            mfaces.append([a_, b_, b_ + SEGS, a_ + SEGS])

    def muzzle_copy(pts):
        vn = vertex_normals(pts, faces)
        out = []
        for r in range(k0, k1 + 1):
            for j in range(SEGS):
                i = ring_v(r, j)
                out.append(pts[i] + vn[i] * MUZZLE_OFF)
        return out

    m_rest = muzzle_copy(verts)
    m_keys = {k: muzzle_copy(v) for k, v in states.items()}
    if orient_closed_like(m_rest, mfaces, verts, faces, ring_v(k0, 0)):
        mfaces = [list(reversed(f)) for f in mfaces]

    # optional nose twitch: the nose and the muzzle around it lift a few mm
    twitch = None
    if S.get("nose_twitch"):
        nz = S["nose"]
        nc = front(0.0, nz["z"] - mz)
        lift = 0.0035

        def field(p):
            k = (1 - smoothstep(0.4, 1.0, (p - nc).length / 0.045)) * smoothstep(mz - 0.006, mz + 0.004, p.z)
            above = smoothstep(0.0, 0.01, p.z - nc.z - nz["h"]) * k
            return Vector((0, -0.0008 * above, lift * k))

        twitch = (field, lift)
        states["nose_twitch"] = [p + field(p) for p in verts]
        m_keys["nose_twitch"] = [p + field(p) for p in m_rest]
        tongue_keys["nose_twitch"] = [p + field(p) for p in tongue_rest]

    w = {"head": 1.0}
    acc.add(verts, faces, mats, [dict(w) for _ in verts], states)
    acc.add(tongue_rest, orient_closed(tongue_rest, tf), "tongue", [dict(w) for _ in tv], tongue_keys)
    acc.add(m_rest, mfaces, "belly", [dict(w) for _ in m_rest], m_keys)
    return sdf, twitch


def orient_closed_like(dverts, dfaces, verts, faces, ref):
    """True if the decal faces point opposite to the surface normal at vertex ref."""
    vn = vertex_normals(verts, faces)[ref]
    f = dfaces[0]
    n = (dverts[f[1]] - dverts[f[0]]).cross(dverts[f[2]] - dverts[f[0]])
    return n.dot(vn) < 0


def build_patch(acc, mat, surf, frame, inside, extent, offset=0.0015, rings=6, segs=40):
    rfun = star_outline(inside)

    def shape(r, t):
        rr = r * rfun(t) * extent
        return (rr * math.cos(t), rr * math.sin(t))

    add_decal_polar(acc, mat, surf, frame, shape, rings, segs, lambda r: offset)


# ---------------------------------------------------------------- ears

def add_ear(acc, mat, inner_mat, path, frame, prof, weight_fn, perk_rot, pivot, inner=None,
            n_len=14, n_around=14, cap0=0.2, cap1=0.3):
    verts, faces, ts = loft(path, frame, prof, n_len, n_around, cap0, cap1)
    ws = [weight_fn(t) for t in ts]
    R = rot(perk_rot)
    pv = Vector(pivot)

    def perk(p):
        return pv + R @ (Vector(p) - pv)

    acc.add(verts, faces, mat, ws, {"ear_perk": [perk(p) for p in verts]})
    if inner:
        surf = Surf(verts, faces, ws)
        anchor_t, iw, ih, off_y = inner
        side, front = frame(anchor_t)
        c = Vector(path(anchor_t))
        fr = Frame(c, front, up=(Vector(path(min(anchor_t + 0.05, 1))) - c).normalized())

        def shape(r, t):
            y = math.sin(t)
            w = iw * (1 - 0.45 * (y * 0.5 + 0.5))
            return (r * math.cos(t) * w, r * y * ih + off_y)

        params, ifaces = polar_topology(4, 24)
        pts = [shape(r, t) for r, t in params]
        iverts, iws = project(surf, fr, pts, [0.0015] * len(pts))
        acc.add(iverts, ifaces, inner_mat, iws, {"ear_perk": [perk(p) for p in iverts]})


# ---------------------------------------------------------------- pet specs

def spec_cat():
    return dict(
        name="cat",
        colors=dict(body="#F6D7A7", patch="#E9A15B", ear="#E9A15B", paw="#FFF4E0", belly="#FFF4E0", ear_inner="#F4B4A4",
                    eye="#3B2416", eye_highlight="#FFFFFF", nose="#9A5F45",
                    mouth_inner="#8E2B3A", mouth_deep="#56152A", lip="#E7A39A", tongue="#FF8FA3",
                    cheek="#F7B9A8"),
        head_c=(0, 0, 0.655),
        head=[((0, 0, 0.655), (0.268, 0.228, 0.226), 0),
              ((0.112, -0.05, 0.585), (0.155, 0.14, 0.115), 0.08),
              ((-0.112, -0.05, 0.585), (0.155, 0.14, 0.115), 0.08),
              ((0, -0.165, 0.58), (0.085, 0.07, 0.062), 0.06)],
        torso=[((0, 0.0, 0.195), (0.2, 0.18, 0.185), 0),
               ((0, 0.0, 0.33), (0.15, 0.135, 0.115), 0.1)],
        foot=dict(c=(0.088, -0.07, 0.042), r=(0.066, 0.086, 0.047)),
        arm=dict(sh=(0.12, -0.03, 0.34), paw=(0.205, -0.13, 0.215), r0=0.045, r1=0.056),
        hip=(0.08, -0.03, 0.11),
        neck_z=0.42,
        eye=dict(x=0.12, z=0.652, w=0.043, h=0.056),
        nose=dict(z=0.606, w=0.021, h=0.0155, dome=0.007),
        mouth=dict(z=0.592, W0=0.032, a=0.012, W1=0.052, H=0.068),
        muzzle=[(-0.04, -0.02, 0.06, 0.045), (0.04, -0.02, 0.06, 0.045), (0, 0.0, 0.04, 0.04)],
        muzzle_z=0.6,
        cheek=dict(x=0.168, z=0.585, w=0.034, h=0.022),
        nose_twitch=True,
        socks=True,
        ears="cat",
        tail="cat",
    )


def spec_dog():
    return dict(
        name="dog",
        colors=dict(body="#E8B04B", ear="#B97A3A", belly="#FFF1D6", ear_inner="#B97A3A",
                    eye="#3B2416", eye_highlight="#FFFFFF", nose="#5E3D28",
                    mouth_inner="#8E2B3A", mouth_deep="#56152A", lip="#E19A8E", tongue="#FF8FA3",
                    cheek="#F2A27A", collar="#5FC2C0", collar_tag="#F7D46B"),
        head_c=(0, 0, 0.65),
        head=[((0, 0, 0.655), (0.255, 0.225, 0.222), 0),
              ((0.11, -0.05, 0.582), (0.145, 0.135, 0.108), 0.08),
              ((-0.11, -0.05, 0.582), (0.145, 0.135, 0.108), 0.08),
              ((0, -0.17, 0.572), (0.11, 0.09, 0.077), 0.07)],
        torso=[((0, 0.0, 0.205), (0.195, 0.175, 0.2), 0),
               ((0, 0.0, 0.345), (0.15, 0.135, 0.12), 0.1)],
        foot=dict(c=(0.09, -0.07, 0.044), r=(0.068, 0.09, 0.049)),
        arm=dict(sh=(0.118, -0.015, 0.35), paw=(0.192, -0.085, 0.212), r0=0.045, r1=0.056),
        hip=(0.08, -0.03, 0.11),
        neck_z=0.42,
        eye=dict(x=0.112, z=0.672, w=0.039, h=0.05),
        nose=dict(z=0.61, w=0.036, h=0.024, dome=0.016),
        mouth=dict(z=0.588, W0=0.036, a=0.013, W1=0.058, H=0.072),
        muzzle=[(-0.045, -0.01, 0.07, 0.05), (0.045, -0.01, 0.07, 0.05), (0, 0.01, 0.055, 0.05)],
        muzzle_z=0.592,
        cheek=None,
        socks=False,
        ears="dog",
        tail="dog",
        collar=True,
    )


def spec_bunny():
    return dict(
        name="bunny",
        colors=dict(body="#FAF6F2", belly="#FFFFFF", ear_inner="#F7B6C2", eye="#3B2416",
                    eye_highlight="#FFFFFF", nose="#E58A9E", mouth_inner="#8E2B3A",
                    mouth_deep="#56152A", lip="#EFA9B6", tongue="#FF8FA3", cheek="#F9BFCB",
                    tail_puff="#FFFFFF"),
        head_c=(0, 0, 0.6),
        head=[((0, 0, 0.605), (0.25, 0.215, 0.212), 0),
              ((0.115, -0.045, 0.535), (0.16, 0.14, 0.118), 0.08),
              ((-0.115, -0.045, 0.535), (0.16, 0.14, 0.118), 0.08),
              ((0, -0.158, 0.535), (0.072, 0.058, 0.052), 0.05)],
        torso=[((0, 0.0, 0.19), (0.19, 0.175, 0.185), 0),
               ((0, 0.0, 0.31), (0.14, 0.125, 0.11), 0.1)],
        foot=dict(c=(0.088, -0.085, 0.036), r=(0.062, 0.105, 0.04)),
        arm=dict(sh=(0.11, -0.02, 0.32), paw=(0.178, -0.09, 0.195), r0=0.04, r1=0.05),
        hip=(0.08, -0.03, 0.1),
        neck_z=0.39,
        eye=dict(x=0.12, z=0.612, w=0.041, h=0.051),
        nose=dict(z=0.557, w=0.017, h=0.012, dome=0.006),
        mouth=dict(z=0.546, W0=0.026, a=0.01, W1=0.046, H=0.062),
        muzzle=[(-0.034, -0.012, 0.05, 0.04), (0.034, -0.012, 0.05, 0.04)],
        muzzle_z=0.55,
        cheek=dict(x=0.165, z=0.54, w=0.04, h=0.026),
        nose_twitch=True,
        socks=False,
        ears="bunny",
        tail="bunny",
    )


SPECS = {"cat": spec_cat, "dog": spec_dog, "bunny": spec_bunny}


# ---------------------------------------------------------------- pet assembly

def build_geometry(S):
    head = Acc()
    body = Acc()
    bones = {}
    hc = Vector(S["head_c"])

    # --- head with mouth, then decals projected on a fine copy of the same surface
    hsdf, twitch = build_head(S, head)
    rv, rf = radial_surface(hc, hsdf, n=40)
    hs = Surf(rv, rf, [{"head": 1.0} for _ in rv])

    # --- cheeks / patches
    if S["cheek"]:
        c = S["cheek"]
        for sx in (1, -1):
            build_patch(head, "cheek", hs, face_frame(hs, sx * c["x"], c["z"], 0.7),
                        ellipse_in(0, 0, c["w"], c["h"]), 1.0, offset=0.0016, rings=3, segs=24)
    if S["name"] == "cat":
        d = Vector((0, -0.55, 0.84)).normalized()
        loc, n, _w = hs.hit(hc + d * 1.0, -d)
        build_patch(head, "patch", hs, Frame(loc, (n + d).normalized(), up=Vector((0, 1, 0.4))),
                    heart_in(0.075, 0.07), 1.0, offset=0.0015)

    # --- eyes, nose
    e = S["eye"]
    build_eye(head, hs, e["x"], e["z"], e["w"], e["h"], "L", "blink_L")
    build_eye(head, hs, -e["x"], e["z"], e["w"], e["h"], "R", "blink_R")
    nz = S["nose"]
    build_nose(head, hs, nz["z"], nz["w"], nz["h"], nz["dome"], twitch=twitch)

    # --- ears
    build_ears(S, head, hs, hsdf, hc, bones)

    # --- torso
    tsdf = blob_sdf(S["torso"])
    tc = Vector((0, 0, (S["torso"][0][0][2] + S["torso"][1][0][2]) / 2))
    tv, tf = radial_surface(tc, tsdf, n=14)
    tw = []
    for p in tv:
        k = smoothstep(0.2, 0.34, p.z)
        tw.append({"spine": 1 - k, "chest": k} if 0 < k < 1 else ({"chest": 1.0} if k >= 1 else {"spine": 1.0}))
    body.add(tv, tf, "body", tw)
    ts = Surf(tv, tf, tw)
    bz = S["torso"][0][0][2]
    build_patch(body, "belly", ts, face_frame(ts, 0, bz + 0.02, 0.0),
                ellipse_in(0, 0, 0.12, 0.13), 1.0)
    if S["name"] == "cat":
        d = Vector((0.15, 1, 0.35)).normalized()
        loc, n, _w = ts.hit(tc + d * 1.0, -d)
        build_patch(body, "patch", ts, Frame(loc, n, up=Vector((0, 0, 1))),
                    ellipse_in(0, 0, 0.11, 0.09), 1.0)

    # --- arms & feet
    a = S["arm"]
    for sx, sfx in ((1, "L"), (-1, "R")):
        sh = Vector((sx * a["sh"][0], a["sh"][1], a["sh"][2]))
        paw = Vector((sx * a["paw"][0], a["paw"][1], a["paw"][2]))
        path = straight(sh, paw)
        av, af, at = loft(path, tube_frame(path), lambda t: (mix(a["r0"], a["r1"], t),) * 2,
                          12, 14, 0.3, 0.42)
        mats = []
        for f in af:
            tt = sum(at[i] for i in f) / len(f)
            mats.append("paw" if S["socks"] and tt > 0.74 else "body")
        body.add(av, af, mats, {f"arm_{sfx}": 1.0})
        bones[f"arm_{sfx}"] = (sh, paw, "chest")
        if sfx == "R":
            # where props held in the paws sit (GDScript attaches them to this bone)
            d = (paw - sh).normalized()
            bones["hold"] = (paw - d * 0.02, paw + d * 0.01, "arm_R")

        fo = S["foot"]
        fc = Vector((sx * fo["c"][0], fo["c"][1], fo["c"][2]))
        fv, ff = radial_surface(fc, blob_sdf([(fc, fo["r"], 0)]), n=7)
        body.add(fv, ff, "paw" if S["socks"] else "body", {f"leg_{sfx}": 1.0})
        hip = Vector((sx * S["hip"][0], S["hip"][1], S["hip"][2]))
        bones[f"leg_{sfx}"] = (hip, fc + Vector((0, 0, -0.01)), "root")

    # --- tail
    build_tail(S, body, bones)

    # --- collar
    if S.get("collar"):
        build_collar(S, body, ts)

    # --- core bones
    nzk = S["neck_z"]
    bones["root"] = (Vector((0, 0, 0)), Vector((0, 0, 0.08)), None)
    bones["spine"] = (Vector((0, 0, 0.02)), Vector((0, 0, 0.26)), "root")
    bones["chest"] = (Vector((0, 0, 0.26)), Vector((0, 0, nzk)), "spine")
    bones["head"] = (Vector((0, 0, nzk)), Vector((0, 0, hc.z + 0.2)), "chest")
    return head, body, bones


def build_ears(S, head, hs, hsdf, hc, bones):
    kind = S["ears"]
    for sx, sfx in ((1, "L"), (-1, "R")):
        bone = f"ear_{sfx}"
        if kind == "cat":
            base = Vector((sx * 0.148, 0.0, 0.8))
            d = Vector((sx * 0.5, 0.12, 1.0)).normalized()
            tip = base + d * 0.2
            path = straight(base, tip)
            side = Vector((1, 0, 0)) - d * d.x
            side.normalize()
            front = side.cross(d).normalized()
            if front.y > 0:
                front = -front

            def frame(t, side=side, front=front):
                return side, front

            def prof(t):
                return (0.092 * (1 - 0.82 * t ** 0.9), 0.034 * (1 - 0.55 * t))

            add_ear(head, "ear", "ear_inner", path, frame, prof, lambda t, b=bone: {b: 1.0},
                    (8, -sx * 10, 0), base, inner=(0.42, 0.05, 0.065, -0.004),
                    cap0=0.15, cap1=0.22)
            bones[bone] = (base, tip, "head")
        elif kind == "dog":
            pts = []
            for k in range(6):
                t = k / 5
                z = mix(0.835, 0.575, t)
                y = mix(0.02, -0.02, t)
                # follow the head side, just outside the surface
                lo, hi = 0.0, 0.6
                for _ in range(30):
                    mid = (lo + hi) / 2
                    if hsdf(Vector((mid, y, z))) < 0:
                        lo = mid
                    else:
                        hi = mid
                x = lo + 0.032 + 0.05 * t * t - 0.03 * (1 - t) ** 3
                pts.append(Vector((sx * x, y, z)))
            path = polyline(pts)

            def frame(t, path=path, sx=sx):
                tan = (path(min(t + 0.01, 1)) - path(max(t - 0.01, 0))).normalized()
                out = Vector((sx, 0, 0))
                front = (out - tan * out.dot(tan)).normalized()
                side = tan.cross(front).normalized()
                return side, front

            def prof(t):
                w = 0.06 + 0.035 * math.sin(math.pi * min(t * 1.15, 1.0))
                return (w, 0.024)

            add_ear(head, "ear", None, path, frame, prof, lambda t, b=bone: {b: 1.0},
                    (0, -sx * 38, 0), pts[0], cap0=0.12, cap1=0.3)
            bones[bone] = (pts[0], pts[-1], "head")
        else:
            base = Vector((sx * 0.085, 0.02, 0.73))
            d = Vector((sx * 0.2, 0.08, 1.0)).normalized()
            L = 0.4
            tip = base + d * L
            mid = base + d * (L * 0.5)
            path = straight(base, tip)
            side = Vector((1, 0, 0)) - d * d.x
            side.normalize()
            front = side.cross(d).normalized()
            if front.y > 0:
                front = -front

            def frame(t, side=side, front=front):
                return side, front

            def prof(t):
                w = 0.04 + 0.03 * math.sin(math.pi * min(t * 1.05, 1.0)) ** 0.8
                return (w, 0.028 * (1 - 0.3 * t))

            def wfn(t, b=bone):
                k = smoothstep(0.42, 0.62, t)
                if k <= 0:
                    return {b: 1.0}
                if k >= 1:
                    return {b + "_tip": 1.0}
                return {b: 1 - k, b + "_tip": k}

            add_ear(head, "body", "ear_inner", path, frame, prof, wfn,
                    (6, -sx * 7, 0), base, inner=(0.55, 0.036, 0.15, 0.0),
                    n_len=22, cap0=0.12, cap1=0.2)
            bones[bone] = (base, mid, "head")
            bones[bone + "_tip"] = (mid, tip, bone)


def build_tail(S, body, bones):
    kind = S["tail"]
    if kind == "bunny":
        c = Vector((0, 0.19, 0.13))

        def puff(p):
            q = p - c
            n = q.normalized() if q.length > 1e-6 else Vector((0, 0, 1))
            bump = 0.006 * (math.sin(9 * n.x) * math.sin(9 * n.y) * math.sin(9 * n.z))
            return q.length - (0.066 + bump)

        pv, pf = radial_surface(c, puff, n=9, rmax=0.2)
        body.add(pv, pf, "tail_puff", {"tail": 1.0})
        bones["tail"] = (Vector((0, 0.15, 0.12)), Vector((0, 0.24, 0.15)), "spine")
        return
    if kind == "cat":
        pts = [(0, 0.12, 0.1), (0.06, 0.24, 0.13), (0.14, 0.31, 0.26), (0.13, 0.3, 0.42), (0.07, 0.27, 0.5)]
        r0, r1, tipmat = 0.034, 0.032, "paw"
        mat = "ear"
        names = ["tail", "tail_2", "tail_3"]
    else:
        pts = [(0, 0.13, 0.16), (0, 0.22, 0.22), (0.01, 0.27, 0.31), (0.03, 0.27, 0.38)]
        r0, r1, tipmat = 0.036, 0.022, "body"
        mat = "body"
        names = ["tail", "tail_2"]
    path = polyline(pts)
    tv, tf, tt = loft(path, tube_frame(path, Vector((0, 0, 1))), lambda t: (mix(r0, r1, t),) * 2,
                      20, 12, 0.1, 0.18)
    n = len(names)

    def wfn(t):
        s = t * n - 0.5
        w = {}
        for i, nm in enumerate(names):
            x = max(0.0, 1 - abs(s - i))
            if s < 0 and i == 0 or s > n - 1 and i == n - 1:
                x = 1.0
            if x > 0:
                w[nm] = x
        tot = sum(w.values())
        return {k: v / tot for k, v in w.items()}

    mats = []
    for f in tf:
        t = sum(tt[i] for i in f) / len(f)
        mats.append(tipmat if t > 0.8 else mat)
    body.add(tv, tf, mats, [wfn(t) for t in tt])
    for i, nm in enumerate(names):
        bones[nm] = (path(i / n), path((i + 1) / n), "spine" if i == 0 else names[i - 1])


def build_collar(S, body, ts):
    z = S["neck_z"] + 0.005
    verts, faces = [], []
    nu, nv = 40, 8
    for i in range(nu):
        a = 2 * math.pi * i / nu
        d = Vector((math.cos(a), math.sin(a), 0))
        # radius: torso surface at this height plus a little air
        loc, _n, _w = ts.hit(Vector((0, 0, z)) + d * 0.6, -d)
        R = (loc - Vector((0, 0, z))).length + 0.012
        for j in range(nv):
            b = 2 * math.pi * j / nv
            p = Vector((0, 0, z)) + d * (R + 0.02 * math.cos(b)) + Vector((0, 0, 0.016 * math.sin(b)))
            verts.append(p)
    for i in range(nu):
        for j in range(nv):
            a = i * nv + j
            b = ((i + 1) % nu) * nv + j
            c = ((i + 1) % nu) * nv + (j + 1) % nv
            d_ = i * nv + (j + 1) % nv
            faces.append([a, b, c, d_])
    body.add(verts, orient_closed(verts, faces), "collar", {"chest": 1.0})
    # little tag hanging at the front
    front = Vector((0, -1, 0))
    loc, _n, _w = ts.hit(Vector((0, 0, z - 0.03)) + front * 0.6, -front)
    tc = loc + _n * 0.006
    tv, tf = radial_surface(tc, blob_sdf([(tc, (0.026, 0.009, 0.026), 0)]), n=5, rmax=0.1)
    body.add(tv, tf, "collar_tag", {"chest": 1.0})


# ---------------------------------------------------------------- blender objects

def make_materials(S):
    mats = {}
    for name, hexcol in S["colors"].items():
        m = bpy.data.materials.new(name)
        if m.node_tree is None:
            m.use_nodes = True
        bsdf = m.node_tree.nodes.get("Principled BSDF")
        bsdf.inputs["Base Color"].default_value = lin(hexcol)
        bsdf.inputs["Roughness"].default_value = 0.8
        m.diffuse_color = lin(hexcol)
        mats[name] = m
    return mats


def make_object(name, acc, mats, arm):
    me = bpy.data.meshes.new(name)
    me.from_pydata([tuple(v) for v in acc.v], [], acc.f)
    used = []
    for m in acc.fm:
        if m not in used:
            used.append(m)
    for m in used:
        me.materials.append(mats[m])
    me.polygons.foreach_set("material_index", [used.index(m) for m in acc.fm])
    me.validate()
    me.shade_smooth()
    # flat colours need no UVs, but Godot wants them to build tangents: simple spherical map
    uv = me.uv_layers.new(name="UVMap")
    co = [me.vertices[l.vertex_index].co for l in me.loops]
    uv.data.foreach_set("uv", [c for p in co for c in (math.atan2(p.x, -p.y) / (2 * math.pi) + 0.5, p.z)])
    obj = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(obj)
    groups = {}
    for i, w in enumerate(acc.w):
        tot = sum(w.values())
        for b, x in w.items():
            if x / tot < 0.01:
                continue
            if b not in groups:
                groups[b] = obj.vertex_groups.new(name=b)
            groups[b].add([i], x / tot, "REPLACE")
    if acc.keys:
        obj.shape_key_add(name="Basis", from_mix=False)
        for k in SHAPE_KEYS:
            if k in acc.keys:
                kb = obj.shape_key_add(name=k, from_mix=False)
                for vi, p in acc.keys[k].items():
                    kb.data[vi].co = p
    obj.parent = arm
    mod = obj.modifiers.new("Armature", "ARMATURE")
    mod.object = arm
    return obj


def make_armature(name, bones):
    arm_data = bpy.data.armatures.new(name)
    arm = bpy.data.objects.new(name, arm_data)
    bpy.context.scene.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    order = ["root", "spine", "chest", "head"] + sorted(k for k in bones if k not in ("root", "spine", "chest", "head"))
    # parents must exist before children
    done = {}
    pending = list(order)
    while pending:
        for nm in list(pending):
            h, t, parent = bones[nm]
            if parent and parent not in done:
                continue
            eb = arm_data.edit_bones.new(nm)
            eb.head, eb.tail = Vector(h), Vector(t)
            eb.roll = 0.0
            eb.use_deform = True
            if nm == "hold":
                # props must not stretch when the arm does
                eb.inherit_scale = "NONE"
            if parent:
                eb.parent = done[parent]
                eb.use_connect = False
            done[nm] = eb
            pending.remove(nm)
    bpy.ops.object.mode_set(mode="OBJECT")
    return arm


# ---------------------------------------------------------------- animation

class Animator:
    def __init__(self, arm, head=None):
        self.arm = arm
        self.head = head
        self.M = {b.name: b.matrix_local.to_3x3() for b in arm.data.bones}
        self.dir = {b.name: (b.tail_local - b.head_local).normalized() for b in arm.data.bones}
        arm.animation_data_create()

    def resolve_at(self, pose):
        """Specs with "at" (armature-space point) get the rotation and stretch that put the
        bone's tail there, given the parents' poses in the same key (unkeyed bones at rest)."""
        if not any("at" in sp for sp in pose.values()):
            return pose
        pose = dict(pose)
        posed = {}
        for b in self.arm.data.bones:
            sp = pose.get(b.name, {})
            rest = b.matrix_local
            if b.parent:
                base = posed[b.parent.name] @ b.parent.matrix_local.inverted() @ rest
            else:
                base = rest.copy()
            if "at" in sp:
                d = base.inverted().to_3x3() @ (Vector(sp["at"]) - base.translation)
                k = d.length / b.length
                sp = {"q": Vector((0, 1, 0)).rotation_difference(d.normalized()), "s": (1, k, 1)}
                pose[b.name] = sp
                basis = sp["q"].to_matrix().to_4x4() @ Matrix.Diagonal((1, k, 1, 1))
            else:
                q, loc, sc = self.basis(b.name, sp.get("r"), sp.get("l"), sp.get("s"), sp.get("a"))
                basis = Matrix.Translation(loc or Vector()) @ (q or Euler((0, 0, 0)).to_quaternion()).to_matrix().to_4x4()
                if sc:
                    basis = basis @ Matrix.Diagonal((sc[0], sc[1], sc[2], 1))
            posed[b.name] = base @ basis
        return pose

    def basis(self, bone, r=None, l=None, s=None, a=None):
        """r: armature-space euler (deg); a: armature-space direction to aim the bone at."""
        M = self.M[bone]
        Mi = M.inverted()
        if a:
            r_arm = self.dir[bone].rotation_difference(Vector(a).normalized()).to_matrix()
            q = (Mi @ r_arm @ M).to_quaternion()
        else:
            q = (Mi @ rot(r) @ M).to_quaternion() if r else None
        loc = Mi @ Vector(l) if l else None
        return q, loc, s

    def action(self, name, dur, keys, loop=False, face=None):
        """face: [(t, {shape_key: value})] keyed in the same action (its own slot), 0 at both ends."""
        arm = self.arm
        act = bpy.data.actions.new(name)
        arm.animation_data.action = act
        end = dur * FPS
        names = [b.name for b in arm.pose.bones]
        timeline = {}
        for t, pose in keys:
            timeline.setdefault(round(t * FPS, 3), {}).update(pose)
        for f in (0.0, end):
            timeline.setdefault(f, {})
        if loop:
            timeline[end] = dict(timeline.get(0.0, {}))
        last_q = {}
        for f in sorted(timeline):
            pose = self.resolve_at(timeline[f])
            edge = f in (0.0, end)
            for nm in names:
                pb = arm.pose.bones[nm]
                spec = pose.get(nm)
                if spec is None and not edge:
                    continue
                spec = spec or {}
                q, loc, s = self.basis(nm, spec.get("r"), spec.get("l"), spec.get("s"), spec.get("a"))
                q = spec.get("q", q)
                pb.rotation_mode = "QUATERNION"
                if q is not None or edge:
                    q = q if q is not None else Euler((0, 0, 0)).to_quaternion()
                    if nm in last_q and last_q[nm].dot(q) < 0:
                        q = -q
                    last_q[nm] = q
                    pb.rotation_quaternion = q
                    pb.keyframe_insert("rotation_quaternion", frame=f, group=nm)
                if loc is not None or edge:
                    pb.location = loc if loc is not None else Vector()
                    pb.keyframe_insert("location", frame=f, group=nm)
                if s is not None or edge:
                    pb.scale = s if s is not None else (1, 1, 1)
                    pb.keyframe_insert("scale", frame=f, group=nm)
        act.use_frame_range = True
        act.frame_start = 0
        act.frame_end = end
        act.use_cyclic = loop
        act.use_fake_user = True
        track = arm.animation_data.nla_tracks.new()
        track.name = name
        track.strips.new(name, 0, act)
        track.mute = True
        arm.animation_data.action = None
        for pb in arm.pose.bones:
            pb.rotation_quaternion = (1, 0, 0, 0)
            pb.location = (0, 0, 0)
            pb.scale = (1, 1, 1)
        if face and self.head:
            self.face_keys(name, act, end, face)

    def face_keys(self, name, act, end, face):
        sk = self.head.data.shape_keys
        used = {k for _t, vals in face for k in vals if k in sk.key_blocks}
        if not used:
            return
        if sk.animation_data is None:
            sk.animation_data_create()
        slot = act.slots.new(id_type="KEY", name=name)
        sk.animation_data.action = act
        sk.animation_data.action_slot = slot
        for t, vals in [(0.0, {k: 0.0 for k in used})] + face + [(end / FPS, {k: 0.0 for k in used})]:
            for k, v in vals.items():
                if k in used:
                    kb = sk.key_blocks[k]
                    kb.value = v
                    kb.keyframe_insert("value", frame=round(t * FPS, 3))
        track = sk.animation_data.nla_tracks.new()
        track.name = name
        strip = track.strips.new(name, 0, act)
        strip.action_slot = slot
        track.mute = True
        sk.animation_data.action = None
        for k in used:
            sk.key_blocks[k].value = 0.0


def sym(prefix, r=None, l=None, s=None, a=None, mirror=True):
    """Pose entries for prefix_L / prefix_R; values given for _L and mirrored for _R."""
    out = {}
    for sfx, m in (("L", False), ("R", True)):
        e = {}
        if r is not None:
            e["r"] = mirror_deg(r) if m and mirror else r
        if l is not None:
            e["l"] = (-l[0], l[1], l[2]) if m and mirror else l
        if s is not None:
            e["s"] = s
        if a is not None:
            e["a"] = (-a[0], a[1], a[2]) if m and mirror else a
        out[f"{prefix}_{sfx}"] = e
    return out


def P(*dicts):
    out = {}
    for d in dicts:
        out.update(d)
    return out


def sq(w, h):
    return (w, h, w)


def build_actions(arm, S, head=None):
    A = Animator(arm, head)
    bones = {b.name for b in arm.data.bones}
    tails = [n for n in ("tail", "tail_2", "tail_3") if n in bones]
    dog = S["ears"] == "dog"
    bunny = S["ears"] == "bunny"
    perk = (0, -32, 0) if dog else ((10, -10, 0) if bunny else (10, -12, 0))
    droop = (0, 14, 0) if dog else (-12, 14, 0)

    def ears(r, s=None):
        d = sym("ear", r=r, s=s)
        if bunny:
            tip = tuple(x * 0.6 for x in r)
            d.update({"ear_L_tip": {"r": tip}, "ear_R_tip": {"r": mirror_deg(tip)}})
        return d

    def tail(z, x=0.0):
        d = {}
        for i, n in enumerate(tails):
            k = 1.0 + 0.5 * i
            d[n] = {"r": (x * k, 0, z * k)}
        return d

    T = 2.2
    A.action("idle_breathe", T, [
        (0.0, P({"chest": {"s": sq(1.0, 1.0)}, "spine": {"s": sq(1.0, 1.0)},
                 "head": {"r": (1.0, 0, 0)}}, tail(-8), ears((0, 0, 0)))),
        (T * 0.5, P({"chest": {"s": sq(1.035, 1.015)}, "spine": {"s": sq(1.015, 1.01)},
                     "head": {"r": (-1.5, 1.5, 0)}}, tail(8), ears((-3, 3, 0)),
                    sym("arm", r=(0, -3, 0)))),
        (T * 0.25, P(sym("arm", r=(0, -1.5, 0)))),
        (T * 0.75, P(sym("arm", r=(0, -1.5, 0)))),
    ], loop=True)

    A.action("happy_bounce", 0.8, [
        (0.13, P({"spine": {"s": sq(1.13, 0.84)}, "head": {"r": (7, 0, 0)}, "root": {"l": (0, 0, 0)}},
                 sym("arm", r=(0, 12, 0)), ears((0, 0, 0)))),
        (0.3, P({"root": {"l": (0, 0, 0.15)}, "spine": {"s": sq(0.93, 1.1)}, "head": {"r": (-8, 0, 0)}},
                sym("arm", a=(0.85, -0.35, 0.4)), ears(droop), tail(0, -20), sym("leg", r=(-12, 0, 0)))),
        (0.47, P({"root": {"l": (0, 0, 0.05)}, "spine": {"s": sq(0.97, 1.05)}},
                 sym("arm", a=(0.8, -0.45, 0.05)))),
        (0.55, P({"root": {"l": (0, 0, 0)}, "spine": {"s": sq(1.11, 0.88)}, "head": {"r": (5, 0, 0)}},
                 sym("arm", r=(0, -5, 0)), ears(perk), sym("leg", r=(0, 0, 0)))),
        (0.67, P({"spine": {"s": sq(0.97, 1.04)}, "head": {"r": (-2, 0, 0)}})),
    ])

    wob = []
    for i in range(6):
        t = 0.06 + i * 0.12
        sgn = 1 if i % 2 == 0 else -1
        amp = 1.0 - i * 0.12
        wob.append((t, P({"chest": {"r": (0, 7 * sgn * amp, 0), "s": sq(1.0 + 0.05 * amp, 0.96)},
                          "spine": {"s": sq(1.0 + 0.03 * amp, 0.97 + 0.02 * (i % 2))},
                          "head": {"r": (-7 * amp, -4 * sgn * amp, 0)}},
                         sym("arm", r=(-25, 22, 0)), ears(perk if sgn > 0 else (0, 0, 0)),
                         tail(14 * sgn))))
    A.action("giggle", 0.8, wob)

    for sfx, m in (("L", 1), ("R", -1)):
        arm_b = f"arm_{sfx}"
        up = (m * 0.72, -0.62, 0.6)
        A.action(f"paw_highfive_{sfx}", 0.6, [
            (0.08, {"chest": {"r": (-3, -m * 2, 0)}, arm_b: {"a": (m * 0.6, -0.6, -0.3)}}),
            (0.2, {"chest": {"r": (4, m * 6, 0)}, "head": {"r": (-6, m * 6, m * 8)},
                   arm_b: {"a": up, "s": (1.0, 1.12, 1.0)}}),
            (0.27, {arm_b: {"a": (m * 0.7, -0.68, 0.52), "s": (1.18, 0.92, 1.18)},
                    "spine": {"s": sq(1.04, 0.97)}}),
            (0.36, {arm_b: {"a": up, "s": (1, 1.1, 1)}, "spine": {"s": sq(1, 1)},
                    "head": {"r": (-4, m * 5, m * 6)}}),
            (0.5, {arm_b: {"r": (-15, 0, 0), "s": (1, 1, 1)}, "chest": {"r": (0, 0, 0)}, "head": {"r": (1, 0, 0)}}),
        ])

    A.action("listen_nod", 0.8, [
        (0.15, P({"head": {"r": (12, 0, 7)}, "chest": {"r": (3, 0, 0)}}, ears(perk))),
        (0.32, P({"head": {"r": (-3, 0, 7)}})),
        (0.48, P({"head": {"r": (9, 0, 6)}, "chest": {"r": (2, 0, 0)}})),
        (0.64, P({"head": {"r": (0, 0, 3)}, "chest": {"r": (0, 0, 0)}}, ears(perk))),
    ])

    W = 0.55
    h = W / 2
    lift = 0.035

    def walk_pose(side):
        lean = 7 * side
        lifted = "leg_R" if side > 0 else "leg_L"
        planted = "leg_L" if side > 0 else "leg_R"
        return P({"root": {"r": (0, lean, 0), "l": (0, 0, 0)},
                  "spine": {"s": sq(1.04, 0.96)},
                  "head": {"r": (0, -lean * 0.5, 0)},
                  lifted: {"r": (-18, 0, 0), "l": (0, 0, lift)},
                  planted: {"r": (8, 0, 0), "l": (0, 0, 0)},
                  "arm_L": {"r": (-18 * side, -4, 0)}, "arm_R": {"r": (18 * side, 4, 0)}},
                 tail(16 * side), ears((0, 4 * side, 0)))

    def walk_pass():
        return P({"root": {"r": (0, 0, 0), "l": (0, 0, 0.03)},
                  "spine": {"s": sq(0.98, 1.03)},
                  "leg_L": {"r": (-5, 0, 0), "l": (0, 0, lift * 0.4)},
                  "leg_R": {"r": (-5, 0, 0), "l": (0, 0, lift * 0.4)},
                  "arm_L": {"r": (0, -2, 0)}, "arm_R": {"r": (0, 2, 0)}}, tail(0))

    A.action("walk_in", W, [
        (0.0, walk_pose(1)), (h * 0.5, walk_pass()), (h, walk_pose(-1)), (h * 1.5, walk_pass()),
    ], loop=True)

    # each turn: small counter-move, overshoot, settle; ears trail the head
    A.action("look_around", 2.0, [
        (0.08, P({"head": {"r": (-1, 0, -4)}})),
        (0.26, P({"head": {"r": (-4, 0, 32)}, "chest": {"r": (0, 0, 8)}})),
        (0.32, P(ears((0, 8, 0)))),
        (0.4, P({"head": {"r": (-4, 0, 27)}, "chest": {"r": (0, 0, 7)}}, ears((0, 4, 0)))),
        (0.75, P({"head": {"r": (-6, -5, 30)}, "chest": {"r": (0, 0, 8)}})),
        (1.02, P({"head": {"r": (-2, 0, -3)}, "chest": {"r": (0, 0, -1)}})),
        (1.08, P(ears(perk))),
        (1.14, P({"head": {"r": (-2, 0, 1)}, "chest": {"r": (0, 0, 0)}})),
        (1.34, P({"head": {"r": (-4, 0, -32)}, "chest": {"r": (0, 0, -8)}})),
        (1.4, P(ears((0, -8, 0)))),
        (1.48, P({"head": {"r": (-4, 0, -27)}, "chest": {"r": (0, 0, -7)}}, ears((0, -4, 0)))),
        (1.7, P({"head": {"r": (-6, 5, -30)}, "chest": {"r": (0, 0, -8)}})),
    ])

    A.action("stretch", 1.6, [
        (0.3, P({"spine": {"s": sq(1.06, 0.93)}, "head": {"r": (9, 0, 0)}},
                sym("arm", r=(-10, 15, 0)), ears(droop))),
        (0.7, P({"spine": {"s": sq(0.93, 1.12)}, "chest": {"r": (-8, 0, 0)}, "head": {"r": (-16, 0, 0)},
                 "root": {"l": (0, 0, 0.01)}},
                sym("arm", a=(0.62, -0.3, 0.75), s=(1.0, 1.15, 1.0)), ears(perk, s=(1, 1.08, 1)),
                sym("leg", r=(4, 0, 0)))),
        (1.0, P({"spine": {"s": sq(0.94, 1.11)}, "chest": {"r": (-7, 0, 0)}, "head": {"r": (-14, 3, 0)}},
                sym("arm", a=(0.66, -0.3, 0.7), s=(1.0, 1.12, 1.0)))),
        (1.22, P({"spine": {"s": sq(1.07, 0.93)}, "chest": {"r": (2, 0, 0)}, "head": {"r": (4, 0, 0)},
                  "root": {"l": (0, 0, 0)}},
                 sym("arm", r=(0, -10, 0), s=(1, 1, 1)), ears((0, 0, 0), s=(1, 1, 1)),
                 sym("leg", r=(0, 0, 0)))),
        (1.42, P({"spine": {"s": sq(0.98, 1.02)}})),
    ])

    over = tuple(x * 1.3 for x in perk)
    A.action("ear_perk", 0.6, [
        (0.04, P(ears(tuple(-x * 0.2 for x in perk)))),
        (0.12, P(ears(over, s=(1.0, 1.1, 1.0)), {"head": {"r": (-4, 0, 0)}})),
        (0.22, P(ears(perk, s=(1.0, 1.05, 1.0)), {"head": {"r": (-2, 0, 0)}})),
        (0.42, P(ears(perk, s=(1.0, 1.06, 1.0)), {"head": {"r": (-2, 0, 0)}})),
    ])

    build_new_actions(A, S, bones, tails, ears, tail, perk, droop)
    build_toy_actions(A, S, tails, ears, tail, perk, droop)


def build_new_actions(A, S, bones, tails, ears, tail, perk, droop):
    """Play, talk-back and toy clips. Each starts and ends at the rest pose and moves with
    anticipation, overshoot and settle. face keys drive the head shape keys in the same clip."""
    dog = S["ears"] == "dog"
    bunny = S["ears"] == "bunny"
    back = (24, 0, 0) if dog else (-24, 8, 0)

    def eyes(v):
        return {"blink_L": v, "blink_R": v}

    def ears_same(r, tip=None):
        """Both ears swing the same way (head shakes), unlike ears() which mirrors."""
        d = {"ear_L": {"r": r}, "ear_R": {"r": r}}
        if bunny:
            t = tip or tuple(x * 0.6 for x in r)
            d.update({"ear_L_tip": {"r": t}, "ear_R_tip": {"r": t}})
        return d

    # yawn: dip, head back with the mouth wide and eyes shut, stretch, release past rest, settle
    A.action("yawn", 1.6, [
        (0.14, P({"head": {"r": (7, 0, 0)}, "chest": {"r": (3, 0, 0), "s": sq(1.03, 0.97)},
                  "spine": {"s": sq(1.03, 0.97)}}, ears(droop))),
        (0.5, P({"head": {"r": (-24, 0, 4)}, "chest": {"r": (-9, 0, 0), "s": sq(0.95, 1.07)},
                 "spine": {"s": sq(0.96, 1.06)}, "root": {"l": (0, 0, 0.01)}},
                sym("arm", a=(0.85, -0.25, 0.35), s=(1, 1.08, 1)), ears(back), tail(10, -12))),
        (0.95, P({"head": {"r": (-27, 0, -3)}, "chest": {"r": (-10, 0, 0), "s": sq(0.95, 1.08)}},
                 sym("arm", a=(0.88, -0.2, 0.42), s=(1, 1.1, 1)))),
        (1.18, P({"head": {"r": (8, 0, 0)}, "chest": {"r": (2, 0, 0), "s": sq(1.05, 0.95)},
                  "spine": {"s": sq(1.04, 0.96)}, "root": {"l": (0, 0, 0)}},
                 sym("arm", r=(0, -4, 0), s=(1, 1, 1)), ears(perk), tail(-6))),
        (1.36, P({"head": {"r": (-3, 0, 0)}, "chest": {"r": (0, 0, 0), "s": sq(0.99, 1.01)},
                  "spine": {"s": sq(1, 1)}}, sym("arm", r=(0, 1, 0)), ears((0, 0, 0)))),
    ], face=[(0.2, {"jaw_open": 0.08, **eyes(0.2)}), (0.5, {"jaw_open": 0.9, **eyes(0.85)}),
             (0.95, {"jaw_open": 1.0, **eyes(0.9)}), (1.15, {"jaw_open": 0.12, **eyes(0.4)}),
             (1.3, {"jaw_open": 0.0, **eyes(0.0)})])

    # scratch_ear: left paw scratches by the ear, head tilted into it, then a shake-off
    flat = {k: v for k, v in ears(droop).items() if "_L" in k}
    sc = [(0.1, P({"arm_L": {"a": (0.7, 0.15, -0.7)}, "head": {"r": (0, -5, 0)}})),
          (0.3, P({"arm_L": {"a": (0.5, -0.46, 0.73), "s": (1, 1.45, 1)}, "head": {"r": (8, 18, 10)},
                   "chest": {"r": (0, -5, 0)}}, flat))]
    for i in range(8):
        k = 1 if i % 2 == 0 else -1
        sc.append((0.37 + i * 0.065, P({"arm_L": {"a": (0.5 + 0.08 * k, -0.46, 0.73 - 0.08 * k), "s": (1, 1.45, 1)},
                                        "head": {"r": (8 + k, 18 + 2 * k, 10)}})))
    sc += [
        (0.9, P({"arm_L": {"r": (6, 4, 0), "s": (1, 1, 1)}, "head": {"r": (0, 0, 0)}, "chest": {"r": (0, 0, 0)}},
                {"ear_L": {"r": (0, 0, 0)}})),
        (0.96, P({"head": {"r": (-2, 0, 16)}, "chest": {"r": (0, 0, -4)}}, ears_same((0, -12, 0)))),
        (1.04, P({"head": {"r": (-2, 0, -14)}, "chest": {"r": (0, 0, 4)}}, ears_same((0, 14, 0)))),
        (1.11, P({"head": {"r": (-1, 0, 9)}, "chest": {"r": (0, 0, -2)}}, ears_same((0, -10, 0)))),
        (1.18, P({"head": {"r": (0, 0, -4)}, "chest": {"r": (0, 0, 1)}, "arm_L": {"r": (0, 0, 0)}},
                 ears_same((0, 6, 0)))),
        (1.24, P(ears_same((0, -2, 0)))),
    ]
    A.action("scratch_ear", 1.3, sc, face=[(0.3, eyes(0.7)), (0.85, eyes(0.6)), (0.95, eyes(0.0)),
                                           (0.3, {"smile": 0.6}), (0.9, {"smile": 0.5})])

    # happy_wiggle: species flavour
    if dog:
        wig = [(0.08, P({"spine": {"s": sq(1.05, 0.95)}, "head": {"r": (5, 0, 0)}}))]
        for i in range(6):
            k = 1 if i % 2 == 0 else -1
            amp = (1.0, 1.0, 1.0, 0.85, 0.55, 0.25)[i]
            wig.append((0.18 + 0.12 * i, P({"root": {"r": (0, 4 * k * amp, 12 * k * amp)},
                                            "chest": {"r": (0, -3 * k * amp, -12 * k * amp)},
                                            "head": {"r": (-3, -4 * k * amp, 0)}, "spine": {"s": sq(1, 1)}},
                                           tail(-35 * k * amp), ears_same((0, 14 * k * amp, 0)))))
        wig.append((0.92, P({"root": {"r": (0, 0, 0)}, "chest": {"r": (0, 0, 0)}, "head": {"r": (-1, 0, 0)}},
                            tail(0), ears_same((0, 0, 0)))))
        face = [(0.15, {"smile": 0.9, **eyes(0.4)}), (0.85, {"smile": 0.6, **eyes(0.2)})]
    elif bunny:
        def flop(r, tip):
            return {"ear_L": {"r": r}, "ear_R": {"r": mirror_deg(r)},
                    "ear_L_tip": {"r": tip}, "ear_R_tip": {"r": mirror_deg(tip)}}
        wig = [
            (0.12, P({"spine": {"s": sq(1.12, 0.86)}, "root": {"l": (0, 0, -0.005)}, "head": {"r": (6, 0, 0)}},
                     flop((-8, 6, 0), (-6, 0, 0)), sym("leg", r=(-6, 0, 0)))),
            (0.27, P({"root": {"l": (0, 0, 0.15), "r": (0, 0, 22)}, "spine": {"s": sq(0.92, 1.1), "r": (0, 0, -10)},
                      "head": {"r": (-6, 0, -8)}}, flop((-30, 18, 0), (-25, 0, 0)), sym("leg", r=(35, 0, 0)),
                     sym("arm", a=(0.8, -0.3, 0.3)))),
            (0.4, P({"root": {"l": (0, 0, 0.17), "r": (0, 0, -16)}, "spine": {"s": sq(0.96, 1.05), "r": (0, 0, 10)},
                     "head": {"r": (-2, 0, 8)}}, flop((-12, 10, 0), (20, 0, 0)), sym("leg", r=(20, 0, 0)))),
            (0.54, P({"root": {"l": (0, 0, 0), "r": (0, 0, -4)}, "spine": {"s": sq(1.14, 0.86), "r": (0, 0, 0)},
                      "head": {"r": (8, 0, 0)}}, flop((10, -4, 0), (25, 0, 0)), sym("leg", r=(0, 0, 0)),
                     sym("arm", r=(0, -6, 0)))),
            (0.68, P({"root": {"r": (0, 0, 2)}, "spine": {"s": sq(0.96, 1.05)}, "head": {"r": (-3, 0, 0)}},
                     flop((-8, 4, 0), (-12, 0, 0)))),
            (0.84, P({"root": {"r": (0, 0, 0)}, "spine": {"s": sq(1.01, 0.99)}, "head": {"r": (0, 0, 0)}},
                     flop((2, 0, 0), (4, 0, 0)), sym("arm", r=(0, 0, 0)))),
        ]
        face = [(0.25, {"smile": 1.0, **eyes(0.55)}), (0.8, {"smile": 0.6, **eyes(0.3)})]
    else:
        wig = [(0.1, P({"chest": {"r": (0, -4, -4)}, "head": {"r": (0, -4, 0)}})),
               (0.38, P({"chest": {"r": (2, 10, 12)}, "spine": {"r": (0, 4, 4)}, "head": {"r": (0, 16, 10)}},
                        ears(droop))),
               (0.66, P({"chest": {"r": (2, -8, -10)}, "spine": {"r": (0, -3, -3)}, "head": {"r": (0, -12, -8)}},
                        ears((0, 0, 0)))),
               (0.84, P({"chest": {"r": (0, 3, 3)}, "spine": {"r": (0, 0, 0)}, "head": {"r": (0, 3, 2)}},
                        ears(perk)))]
        # tail swish: a wave travelling down the tail
        for i, n in enumerate(tails):
            for t, z in ((0.15, -25), (0.45, 30), (0.75, -15)):
                wig.append((t + 0.07 * i, {n: {"r": (0, 0, z * (1 + 0.4 * i))}}))
        face = [(0.2, {"smile": 0.9, **eyes(0.6)}), (0.8, {"smile": 0.7, **eyes(0.5)})]
    A.action("happy_wiggle", 1.0, wig, face=face)

    # laugh_tumble: giggle forward, fall back onto the bottom, kick and rock, roll back up
    lt = [
        (0.12, P({"head": {"r": (8, 0, 0)}, "chest": {"r": (5, 0, 0)}, "spine": {"s": sq(1.05, 0.95)}})),
        (0.3, P({"root": {"r": (-14, 0, 0), "l": (0, 0.01, 0.005)}, "head": {"r": (-10, 0, 0)},
                 "chest": {"r": (-2, 0, 0)}, "spine": {"s": sq(0.97, 1.03)}},
                sym("arm", a=(0.8, -0.3, 0.5)), ears(back), sym("leg", r=(-15, 0, 0)))),
        (0.48, P({"root": {"r": (-30, 0, 0), "l": (0, 0.03, 0.015)}, "spine": {"s": sq(1.14, 0.86)},
                  "head": {"r": (10, 0, 0)}}, sym("leg", r=(-40, 0, 0)), ears(perk))),
        (0.6, P({"root": {"r": (-34, 0, 0)}, "spine": {"s": sq(0.97, 1.04)}, "head": {"r": (-14, 0, 0)}})),
    ]
    jaw = [(0.12, {"jaw_open": 0.35, "smile": 0.8, **eyes(0.6)}), (0.3, {"jaw_open": 0.55}), (0.5, {"jaw_open": 0.2})]
    for i in range(6):
        k = 1 if i % 2 == 0 else -1
        t = 0.72 + i * 0.13
        lt.append((t, P({"root": {"r": (-31 - 4 * k, 0, 3 * k)}, "head": {"r": (-10 + 5 * k, 0, 4 * k)},
                         "chest": {"s": sq(1.0 + 0.03 * k, 1.0 - 0.03 * k)},
                         "leg_L": {"r": (-55 if k > 0 else -25, 0, 0)},
                         "leg_R": {"r": (-25 if k > 0 else -55, 0, 0)}},
                        sym("arm", a=(0.75, -0.45 + 0.1 * k, 0.2 + 0.25 * k)), ears(perk if k > 0 else (0, 0, 0)),
                        tail(14 * k))))
        jaw.append((t, {"jaw_open": 0.65 if k > 0 else 0.25}))
    lt += [
        (1.56, P({"root": {"r": (9, 0, 0), "l": (0, 0, 0.035)}, "spine": {"s": sq(0.95, 1.06)}, "head": {"r": (6, 0, 0)},
                  "chest": {"s": sq(1, 1)}}, sym("leg", r=(4, 0, 0)), sym("arm", r=(0, 4, 0)), ears(droop), tail(0))),
        (1.74, P({"root": {"r": (-3, 0, 0), "l": (0, 0, 0)}, "spine": {"s": sq(1.07, 0.94)}, "head": {"r": (-4, 0, 0)}},
                 sym("leg", r=(0, 0, 0)), ears(perk))),
        (1.92, P({"root": {"r": (1, 0, 0)}, "spine": {"s": sq(0.99, 1.01)}, "head": {"r": (1, 0, 0)}},
                 sym("arm", r=(0, 0, 0)), ears((0, 0, 0)))),
    ]
    jaw += [(1.56, {"jaw_open": 0.15, "smile": 0.7, **eyes(0.3)}), (1.9, {"jaw_open": 0.0, "smile": 0.3, **eyes(0.0)})]
    A.action("laugh_tumble", 2.2, lt, face=jaw)

    # wave: left paw (screen right in the stage's 3/4 view) up and waving, head tilted
    A.action("wave", 1.2, [
        (0.1, P({"arm_L": {"a": (0.75, 0.2, -0.62)}, "chest": {"r": (0, -3, 0)}, "head": {"r": (0, -3, 0)}})),
        (0.3, P({"arm_L": {"a": (0.45, -0.38, 0.81), "s": (1, 1.42, 1)}, "chest": {"r": (0, -6, 2)},
                 "head": {"r": (-3, -10, 6)}}, ears(perk))),
        (0.42, P({"arm_L": {"a": (0.8, -0.3, 0.52), "s": (1, 1.35, 1)}, "head": {"r": (-3, -12, 6)}})),
        (0.56, P({"arm_L": {"a": (0.3, -0.4, 0.87), "s": (1, 1.35, 1)}, "head": {"r": (-3, -9, 6)}})),
        (0.7, P({"arm_L": {"a": (0.8, -0.3, 0.52)}, "head": {"r": (-3, -12, 6)}})),
        (0.84, P({"arm_L": {"a": (0.32, -0.4, 0.86)}, "head": {"r": (-3, -10, 6)}})),
        (0.98, P({"arm_L": {"r": (6, 4, 0), "s": (1, 1, 1)}, "chest": {"r": (0, -1, 0)}, "head": {"r": (1, 3, 1)}},
                 ears((0, 0, 0)))),
        (1.1, P({"arm_L": {"r": (-1, 0, 0)}, "chest": {"r": (0, 0, 0)}, "head": {"r": (0, 0, 0)}})),
    ], face=[(0.25, {"smile": 0.9}), (0.95, {"smile": 0.7})])

    # drink: paws hold a cup at the mouth, head back, three gulps, satisfied settle and a lick
    hold = sym("arm", a=(-0.1, -0.75, 0.65), s=(1, 1.15, 1))
    dr = [(0.15, P({"head": {"r": (6, 0, 0)}, "chest": {"r": (3, 0, 0)}}, hold)),
          (0.45, P({"head": {"r": (-20, 0, 0)}, "chest": {"r": (-6, 0, 0), "s": sq(0.98, 1.03)}},
                   sym("arm", a=(-0.15, -0.55, 0.82), s=(1, 1.25, 1)), ears(perk)))]
    sip = [(0.45, {"jaw_open": 0.15})]
    for t in (0.7, 1.1, 1.5):
        dr += [(t, P({"head": {"r": (-16, 0, 0)}, "chest": {"s": sq(1.01, 1.0)}})),
               (t + 0.14, P({"head": {"r": (-21, 0, 0)}, "chest": {"s": sq(0.98, 1.04)}}))]
        sip += [(t, {"jaw_open": 0.32}), (t + 0.14, {"jaw_open": 0.05})]
    dr += [
        (1.85, P({"head": {"r": (5, 0, 0)}, "chest": {"r": (2, 0, 0), "s": sq(1.03, 0.97)}},
                 sym("arm", r=(0, -4, 0), s=(1, 1, 1)), ears((0, 0, 0)))),
        (2.05, P({"head": {"r": (-3, 0, 2)}, "chest": {"r": (0, 0, 0), "s": sq(1, 1)}}, sym("arm", r=(0, 1, 0)))),
        (2.22, P({"head": {"r": (0, 0, 0)}})),
    ]
    sip += [(1.66, {"jaw_open": 0.0}), (1.85, {"smile": 0.8, **eyes(0.5)}), (2.0, {"jaw_open": 0.22}),
            (2.12, {"jaw_open": 0.0}), (2.3, {"smile": 0.3, **eyes(0.0)})]
    A.action("drink", 2.4, dr, face=sip)

    # lap: lean down over a floor bowl (spine and chest bend), four quick laps, back up
    # crouch (root down, feet kept planted) so the mouth gets low without reaching too far forward
    low = P({"spine": {"r": (12, 0, 0), "s": sq(1.05, 0.94)}, "chest": {"r": (17, 0, 0)},
             "root": {"l": (0, 0.03, -0.04)}}, sym("leg", l=(0, 0, 0.04)))
    lp = [(0.15, P({"head": {"r": (-6, 0, 0)}, "chest": {"r": (-2, 0, 0)}}, ears(perk))),
          (0.5, P(low, {"spine": {"r": (14, 0, 0), "s": sq(1.07, 0.92)}, "chest": {"r": (20, 0, 0)},
                        "head": {"r": (34, 0, 0)}}, sym("arm", a=(0.35, -0.55, -0.76)))),
          (0.62, P(low, {"head": {"r": (27, 0, 0)}}))]
    lap_face = []
    for i in range(4):
        t = 0.72 + i * 0.24
        lp += [(t, P({"head": {"r": (34, 0, 0)}})), (t + 0.12, P({"head": {"r": (27, 0, 0)}}))]
        lap_face += [(t, {"jaw_open": 0.14}), (t + 0.12, {"jaw_open": 0.02})]
    lp += [
        (1.6, P(low, {"head": {"r": (27, 0, 0)}})),
        (1.78, P({"spine": {"r": (0, 0, 0), "s": sq(0.97, 1.04)}, "chest": {"r": (-4, 0, 0)}, "root": {"l": (0, 0, 0)},
                  "head": {"r": (-6, 0, 0)}}, sym("arm", r=(0, -3, 0)), sym("leg", l=(0, 0, 0)), ears(perk))),
        (1.9, P({"chest": {"r": (1, 0, 0)}, "head": {"r": (1, 0, 0)}, "spine": {"s": sq(1, 1)}},
                sym("arm", r=(0, 0, 0)), ears((0, 0, 0)))),
    ]
    lap_face += [(1.75, {"jaw_open": 0.0, "smile": 0.6}), (1.95, {"smile": 0.3})]
    A.action("lap", 2.0, lp, face=lap_face)

    # bite: head back, lunge with the jaw wide, snap shut, settle (chains cleanly)
    A.action("bite", 0.6, [
        (0.1, P({"head": {"r": (-10, 0, 0)}, "chest": {"r": (-4, 0, 0)}}, ears(perk))),
        (0.22, P({"head": {"r": (12, 0, 0)}, "chest": {"r": (8, 0, 0)}, "root": {"l": (0, -0.025, 0)}})),
        (0.3, P({"head": {"r": (15, 0, 0)}, "chest": {"r": (9, 0, 0), "s": sq(1.03, 0.97)}})),
        (0.42, P({"head": {"r": (-3, 0, 0)}, "chest": {"r": (-1, 0, 0), "s": sq(1, 1)}, "root": {"l": (0, 0, 0)}},
                 ears((0, 0, 0)))),
        (0.52, P({"head": {"r": (1, 0, 0)}, "chest": {"r": (0, 0, 0)}})),
    ], face=[(0.1, {"jaw_open": 0.25}), (0.22, {"jaw_open": 1.0}), (0.29, {"jaw_open": 0.0}),
             (0.35, {"jaw_open": 0.06}), (0.42, {"jaw_open": 0.0})])

    # chew: three happy munches with a side-to-side wobble and bouncing ears
    ch, chf = [], [(0.06, {"smile": 0.7, **eyes(0.35)})]
    for i in range(3):
        k = 1 if i % 2 == 0 else -1
        t = 0.06 + i * 0.28
        ch += [(t + 0.08, P({"head": {"r": (-3, 0, 4 * k)}, "chest": {"s": sq(0.99, 1.01)}}, ears((-6, 0, 0)))),
               (t + 0.2, P({"head": {"r": (3, 0, 2 * k)}, "chest": {"s": sq(1.02, 0.98)}}, ears((5, 0, 0))))]
        chf += [(t + 0.08, {"jaw_open": 0.4}), (t + 0.2, {"jaw_open": 0.03})]
    ch.append((0.9, P({"head": {"r": (-1, 0, -1)}, "chest": {"s": sq(1, 1)}}, ears((0, 0, 0)))))
    chf.append((0.9, {"smile": 0.4, **eyes(0.1)}))
    A.action("chew", 1.0, ch, face=chf)

    # bat_paw: the paw swipes in toward the middle at floor level, weight shifts away, head follows
    for sfx, m in (("L", 1), ("R", -1)):
        arm_b = f"arm_{sfx}"
        A.action(f"bat_paw_{sfx}", 0.6, [
            (0.1, P({arm_b: {"a": (m * 0.92, -0.2, -0.33), "s": (1, 1.1, 1)}, "chest": {"r": (-2, m * 4, m * 4)},
                     "head": {"r": (8, m * 4, m * 10)}}, ears(perk))),
            (0.22, P({arm_b: {"a": (-m * 0.1, -0.75, -0.65), "s": (1, 1.32, 1)},
                      "chest": {"r": (7, -m * 6, -m * 10)}, "spine": {"r": (3, 0, 0)},
                      "root": {"r": (0, -m * 4, 0)}, "head": {"r": (12, -m * 3, -m * 6)}})),
            (0.31, P({arm_b: {"a": (-m * 0.3, -0.72, -0.62), "s": (1, 1.25, 1)},
                      "head": {"r": (11, -m * 3, -m * 10)}})),
            (0.45, P({arm_b: {"r": (6, 0, 0), "s": (1, 1, 1)}, "chest": {"r": (-1, 0, 0)}, "spine": {"r": (0, 0, 0)},
                      "root": {"r": (0, m * 1, 0)}, "head": {"r": (-2, 0, 0)}}, ears((0, 0, 0)))),
        ], face=[(0.2, {"smile": 0.6}), (0.5, {"smile": 0.2})])

    # sniff: head down to a floor prop, two quick nose pokes, back up with a little shake
    A.action("sniff", 0.8, [
        (0.1, P({"head": {"r": (-6, 0, 0)}}, ears(perk))),
        (0.28, P({"spine": {"r": (8, 0, 0)}, "chest": {"r": (16, 0, 0)}, "head": {"r": (22, 0, 0)}}, ears(perk))),
        (0.36, P({"head": {"r": (28, 0, 0)}, "chest": {"r": (18, 0, 0)}})),
        (0.42, P({"head": {"r": (21, 0, 0)}})),
        (0.48, P({"head": {"r": (28, 0, 0)}})),
        (0.54, P({"head": {"r": (21, 0, 0)}, "chest": {"r": (16, 0, 0)}})),
        (0.64, P({"spine": {"r": (0, 0, 0)}, "chest": {"r": (-2, 0, 0)}, "head": {"r": (-4, 0, 9)}},
                 ears_same((0, -8, 0)))),
        (0.7, P({"head": {"r": (-2, 0, -7)}}, ears_same((0, 8, 0)))),
        (0.75, P({"head": {"r": (0, 0, 3)}, "chest": {"r": (0, 0, 0)}}, ears_same((0, -2, 0)))),
    ], face=[(0.34, {"nose_twitch": 1.0}), (0.4, {"nose_twitch": 0.0}), (0.46, {"nose_twitch": 1.0}),
             (0.52, {"nose_twitch": 0.0})])


# Seated toy play: sit_down ends on SIT, which every sit_* clip starts (and ends) on;
# lie_down ends on LIE, which lie_play loops on and get_up starts from.
LAP = Vector((0, -0.2, 0.26))         # paws together in the lap (armature space)
EAT = Vector((0, -0.25, 0.43))        # paws holding food up under the mouth
SIP = Vector((0, -0.24, 0.46))        # paws holding a cup at the mouth


def paws(p):
    """Both front paws meet at p; the right one carries the hold bone."""
    return {"arm_R": {"at": tuple(p + Vector((-0.022, 0, 0)))},
            "arm_L": {"at": tuple(p + Vector((0.022, 0, 0)))}}


def build_toy_actions(A, S, tails, ears, tail, perk, droop):
    dog = S["ears"] == "dog"
    bunny = S["ears"] == "bunny"
    back = (24, 0, 0) if dog else (-24, 8, 0)
    flat = (30, 0, 0) if dog else (-34, 14, 0)

    def eyes(v):
        return {"blink_L": v, "blink_R": v}

    def ears_same(r):
        d = {"ear_L": {"r": r}, "ear_R": {"r": r}}
        if bunny:
            t = tuple(x * 0.6 for x in r)
            d.update({"ear_L_tip": {"r": t}, "ear_R_tip": {"r": t}})
        return d

    def sit(*extra, hold=LAP, head=(4, 0, 0)):
        return P({"root": {"r": (-3, 0, 0), "l": (0, 0.01, -0.028)}, "spine": {"s": sq(1.04, 0.95)},
                  "chest": {"r": (-2, 0, 0)}, "head": {"r": head}},
                 sym("leg", r=(-72, 0, 0)), tail(-10, 10), ears((0, 0, 0)), paws(hold), *extra)

    SIT = sit()

    # excited: two bouncy hops with a half spin there and back, ears up, tail going
    A.action("excited", 1.2, [
        (0.1, P({"spine": {"s": sq(1.12, 0.86)}, "head": {"r": (6, 0, 0)}}, ears((0, 0, 0)))),
        (0.26, P({"root": {"l": (0, 0, 0.11), "r": (0, 0, 28)}, "spine": {"s": sq(0.92, 1.1)},
                  "head": {"r": (-8, 0, 0)}}, sym("arm", a=(0.8, -0.3, 0.45)), ears(perk), tail(30),
                 sym("leg", r=(18, 0, 0)))),
        (0.42, P({"root": {"l": (0, 0, 0), "r": (0, 0, 20)}, "spine": {"s": sq(1.12, 0.87)},
                  "head": {"r": (6, 0, 0)}}, sym("arm", r=(0, -6, 0)), tail(-30), sym("leg", r=(0, 0, 0)))),
        (0.6, P({"root": {"l": (0, 0, 0.13), "r": (0, 0, -6)}, "spine": {"s": sq(0.92, 1.1)},
                 "head": {"r": (-8, 0, 0)}}, sym("arm", a=(0.8, -0.3, 0.45)), ears(perk), tail(30),
                sym("leg", r=(18, 0, 0)))),
        (0.76, P({"root": {"l": (0, 0, 0), "r": (0, 0, 2)}, "spine": {"s": sq(1.12, 0.87)},
                  "head": {"r": (6, 0, 0)}}, sym("arm", r=(0, -6, 0)), tail(-30), sym("leg", r=(0, 0, 0)))),
        (0.88, P({"spine": {"r": (0, 0, 8), "s": sq(0.98, 1.03)}, "head": {"r": (-2, 0, -4)}}, tail(25))),
        (0.98, P({"spine": {"r": (0, 0, -6), "s": sq(1.01, 0.99)}, "head": {"r": (0, 0, 3)}}, tail(-20))),
        (1.08, P({"spine": {"r": (0, 0, 2), "s": sq(1, 1)}, "root": {"r": (0, 0, 0)}, "head": {"r": (0, 0, 0)}},
                 sym("arm", r=(0, 0, 0)), tail(8), ears((0, 0, 0)))),
    ], face=[(0.1, {"smile": 1.0, **eyes(0.3)}), (1.0, {"smile": 0.8, **eyes(0.2)})])

    # sit_down / sit_idle / stand_up
    A.action("sit_down", 0.7, [
        (0.12, P({"spine": {"s": sq(0.96, 1.05)}, "head": {"r": (-4, 0, 0)}}, ears(perk))),
        (0.45, P(SIT, {"root": {"r": (-5, 0, 0), "l": (0, 0.01, -0.036)}, "spine": {"s": sq(1.08, 0.91)},
                       "head": {"r": (8, 0, 0)}})),
        (0.58, P(SIT, {"root": {"r": (-2, 0, 0), "l": (0, 0.01, -0.026)}, "spine": {"s": sq(1.03, 0.96)}})),
        (0.7, SIT),
    ])
    A.action("sit_idle", 2.0, [
        (0.0, SIT),
        (1.0, sit({"chest": {"r": (-2, 0, 0), "s": sq(1.03, 1.015)}}, ears((-3, 3, 0)), tail(-4, 14),
                  head=(2, 2, 0))),
        (0.5, P(tail(-14, 10))),
        (1.5, P(tail(-6, 12))),
    ], loop=True)
    A.action("stand_up", 0.7, [
        (0.0, SIT),
        (0.16, P(SIT, {"root": {"r": (4, 0, 0), "l": (0, 0, -0.03)}, "chest": {"r": (6, 0, 0)},
                       "head": {"r": (6, 0, 0)}})),
        (0.38, P({"root": {"r": (-2, 0, 0), "l": (0, 0, 0.025)}, "spine": {"s": sq(0.94, 1.07)},
                  "chest": {"r": (0, 0, 0)}, "head": {"r": (-4, 0, 0)}},
                 sym("leg", r=(8, 0, 0)), sym("arm", r=(0, -6, 0), s=(1, 1, 1)), tail(0), ears(perk))),
        (0.52, P({"root": {"r": (1, 0, 0), "l": (0, 0, 0)}, "spine": {"s": sq(1.05, 0.95)}, "head": {"r": (2, 0, 0)}},
                 sym("leg", r=(0, 0, 0)), sym("arm", r=(0, 1, 0)))),
        (0.62, P({"root": {"r": (0, 0, 0)}, "spine": {"s": sq(0.99, 1.01)}}, ears((0, 0, 0)))),
    ])

    # sit_hold_eat: raise the food to the mouth, three chews with head bobs, back to the lap
    he = [(0.0, SIT), (0.16, sit(hold=EAT, head=(16, 0, 0)))]
    hf = [(0.08, {"smile": 0.6, **eyes(0.3)})]
    for i in range(3):
        t = 0.24 + i * 0.25
        k = 1 if i % 2 == 0 else -1
        he += [(t, sit(hold=EAT + Vector((0, 0, 0.006)), head=(11, 0, 3 * k))),
               (t + 0.12, sit(hold=EAT, head=(18, 0, 2 * k)))]
        hf += [(t, {"jaw_open": 0.45}), (t + 0.12, {"jaw_open": 0.04})]
    he += [(1.06, sit(hold=EAT, head=(12, 0, 0))), (1.2, SIT)]
    hf += [(1.05, {"jaw_open": 0.0, "smile": 0.5, **eyes(0.2)})]
    A.action("sit_hold_eat", 1.2, he, face=hf)

    # sit_hold_drink: cup from the lap to the mouth, head tips back, three gulps, cup down
    hd = [(0.0, SIT), (0.5, sit(hold=SIP, head=(-4, 0, 0))), (0.6, sit(hold=SIP, head=(-9, 0, 0)))]
    df = [(0.4, {"jaw_open": 0.15})]
    for t in (0.75, 1.15, 1.55):
        hd += [(t, sit(hold=SIP, head=(-5, 0, 0))), (t + 0.16, sit(hold=SIP, head=(-10, 0, 0)))]
        df += [(t, {"jaw_open": 0.32}), (t + 0.16, {"jaw_open": 0.05})]
    hd += [(1.9, sit(hold=SIP, head=(-6, 0, 0))), (2.25, sit(hold=LAP + Vector((0, 0, 0.01)), head=(6, 0, 0))),
           (2.4, SIT)]
    df += [(1.9, {"jaw_open": 0.0, "smile": 0.7, **eyes(0.4)}), (2.3, {"smile": 0.4, **eyes(0.0)})]
    A.action("sit_hold_drink", 2.4, hd, face=df)

    # sit_lap: lean down to a floor bowl, four laps, back up
    low = {"spine": {"r": (14, 0, 0), "s": sq(1.06, 0.93)}, "chest": {"r": (24, 0, 0)}}
    sl = [(0.0, SIT), (0.15, sit(head=(-4, 0, 0))),
          (0.5, sit(low, {"head": {"r": (34, 0, 0)}}, hold=LAP + Vector((0, -0.03, -0.05)))),
          (0.62, sit(low, {"head": {"r": (27, 0, 0)}}, hold=LAP + Vector((0, -0.03, -0.05))))]
    lf = []
    for i in range(4):
        t = 0.72 + i * 0.24
        sl += [(t, sit(low, {"head": {"r": (34, 0, 0)}}, hold=LAP + Vector((0, -0.03, -0.05)))),
               (t + 0.12, sit(low, {"head": {"r": (27, 0, 0)}}, hold=LAP + Vector((0, -0.03, -0.05))))]
        lf += [(t, {"jaw_open": 0.14}), (t + 0.12, {"jaw_open": 0.02})]
    sl += [(1.8, sit(head=(-5, 0, 0))), (2.0, SIT)]
    lf += [(1.8, {"jaw_open": 0.0, "smile": 0.5}), (1.95, {"smile": 0.0})]
    A.action("sit_lap", 2.0, sl, face=lf)

    # sit_bat: one paw swipes in at a floor toy, body leans away, head follows
    for sfx, m in (("L", 1), ("R", -1)):
        arm_b, other = f"arm_{sfx}", f"arm_{'R' if sfx == 'L' else 'L'}"
        out = Vector((m * 0.2, -0.17, 0.2))
        inn = Vector((-m * 0.02, -0.27, 0.13))
        A.action(f"sit_bat_{sfx}", 0.6, [
            (0.0, SIT),
            (0.1, sit({arm_b: {"at": tuple(out)}, "chest": {"r": (-2, m * 4, m * 6)}, "head": {"r": (10, m * 4, m * 10)}})),
            (0.22, sit({arm_b: {"at": tuple(inn)}, "chest": {"r": (8, -m * 6, -m * 10)},
                        "head": {"r": (16, -m * 3, -m * 6)}, "root": {"r": (-3, -m * 5, 0), "l": (0, 0.01, -0.028)}})),
            (0.31, sit({arm_b: {"at": tuple(inn + Vector((-m * 0.04, 0, 0.01)))}, "head": {"r": (14, -m * 3, -m * 10)}})),
            (0.45, sit({"head": {"r": (2, 0, 0)}})),
            (0.6, SIT),
        ], face=[(0.2, {"smile": 0.6}), (0.5, {"smile": 0.2})])

    # lying on the back: lie_down from standing, lie_play loop, get_up back to rest
    def lie(*extra, arms=((0.35, -0.9, 0.1), (0.35, -0.9, 0.1)), head=(36, 0, 0)):
        aL, aR = arms
        return P({"root": {"r": (-80, 0, 0), "l": (0, 0.02, 0.175)}, "spine": {"s": sq(1.04, 0.97)},
                  "head": {"r": head}, "arm_L": {"a": aL}, "arm_R": {"a": (-aR[0], aR[1], aR[2])}},
                 sym("leg", r=(-50, 0, 0)), {"tail": {"r": (75, 0, 0)}}, ears(back), *extra)

    LIE = lie()
    A.action("lie_down", 0.8, [
        (0.14, P({"spine": {"s": sq(1.1, 0.88)}, "head": {"r": (8, 0, 0)}, "root": {"l": (0, 0, -0.01)}})),
        (0.42, P({"root": {"r": (-50, 0, 0), "l": (0, 0.02, 0.1)}, "spine": {"s": sq(0.96, 1.05)},
                  "head": {"r": (20, 0, 0)}}, sym("leg", r=(-30, 0, 0)), sym("arm", a=(0.6, -0.6, 0.4)))),
        (0.62, lie({"root": {"r": (-86, 0, 0), "l": (0, 0.02, 0.17)}, "spine": {"s": sq(1.1, 0.9)}},
                   head=(42, 0, 0))),
        (0.8, LIE),
    ], face=[(0.5, {"smile": 0.8, "jaw_open": 0.2}), (0.75, {"jaw_open": 0.0})])
    lp = [(0.0, LIE)]
    for i in range(4):
        k = 1 if i % 2 == 0 else -1
        t = 0.2 + i * 0.4
        lp.append((t, lie({"root": {"r": (-80, 3 * k, 6 * k), "l": (0, 0.02, 0.175)},
                           "leg_L": {"r": (-62 if k > 0 else -38, 0, 0)}, "leg_R": {"r": (-38 if k > 0 else -62, 0, 0)}},
                          arms=((0.2, -0.5, 0.85), (0.4, -0.85, 0.2)) if k > 0 else ((0.4, -0.85, 0.2), (0.2, -0.5, 0.85)),
                          head=(30, 0, 4 * k))))
    A.action("lie_play", 1.6, lp, loop=True,
             face=[(0.1, {"smile": 0.9, **eyes(0.2)}), (0.8, {"smile": 1.0, "jaw_open": 0.3}),
                   (1.0, {"jaw_open": 0.05}), (1.5, {"smile": 0.9, **eyes(0.2)})])
    A.action("get_up", 0.8, [
        (0.0, LIE),
        (0.12, lie({"root": {"r": (-84, 0, 0), "l": (0, 0.02, 0.175)}}, head=(46, 0, 0))),
        (0.38, P({"root": {"r": (-30, 0, 0), "l": (0, 0.01, 0.07)}, "spine": {"s": sq(1.06, 0.95)},
                  "head": {"r": (14, 0, 0)}}, sym("leg", r=(-20, 0, 0)), sym("arm", a=(0.6, -0.6, -0.4)), tail(0),
                 ears(droop))),
        (0.55, P({"root": {"r": (6, 0, 0), "l": (0, 0, 0.02)}, "spine": {"s": sq(0.95, 1.06)}, "head": {"r": (-6, 0, 0)}},
                 sym("leg", r=(4, 0, 0)), sym("arm", r=(0, -5, 0)), ears(perk))),
        (0.68, P({"root": {"r": (-1, 0, 0), "l": (0, 0, 0)}, "spine": {"s": sq(1.04, 0.96)}, "head": {"r": (2, 0, 0)}},
                 sym("leg", r=(0, 0, 0)), sym("arm", r=(0, 1, 0)), ears((0, 0, 0)))),
    ])

    # laugh: head back, three belly shakes with paws on the belly, ears flop, mouth open
    belly = Vector((0, -0.19, 0.24))
    la = [(0.1, P({"head": {"r": (6, 0, 0)}, "spine": {"s": sq(1.05, 0.95)}}))]
    lf = [(0.1, {"smile": 1.0, "jaw_open": 0.3, **eyes(0.7)})]
    for i in range(3):
        t = 0.28 + i * 0.25
        la += [(t, P({"head": {"r": (-16, 0, 4)}, "chest": {"r": (-6, 0, 0), "s": sq(1.05, 0.95)},
                      "spine": {"s": sq(1.06, 0.94)}}, paws(belly), ears(droop))),
               (t + 0.12, P({"head": {"r": (-10, 0, -3)}, "chest": {"r": (-3, 0, 0), "s": sq(0.97, 1.04)},
                             "spine": {"s": sq(0.98, 1.03)}}, paws(belly + Vector((0, 0, 0.012))), ears((0, 0, 0))))]
        lf += [(t, {"jaw_open": 0.75}), (t + 0.12, {"jaw_open": 0.35})]
    la += [(1.0, P({"head": {"r": (3, 0, 0)}, "chest": {"r": (0, 0, 0), "s": sq(1, 1)}, "spine": {"s": sq(1, 1)}},
                   sym("arm", r=(0, -4, 0), s=(1, 1, 1)), ears(perk))),
           (1.1, P({"head": {"r": (-1, 0, 0)}}, sym("arm", r=(0, 0, 0)), ears((0, 0, 0))))]
    lf += [(1.0, {"jaw_open": 0.0, "smile": 0.6, **eyes(0.2)})]
    A.action("laugh", 1.2, la, face=lf)

    # head_shake: a quick shake after an ear touch, ears flapping behind the head
    A.action("head_shake", 0.6, [
        (0.06, P({"head": {"r": (4, 0, -5)}})),
        (0.15, P({"head": {"r": (0, 0, 18)}, "chest": {"r": (0, 0, -3)}}, ears_same((0, -10, 0)))),
        (0.25, P({"head": {"r": (0, 0, -16)}, "chest": {"r": (0, 0, 3)}}, ears_same((0, 16, 0)))),
        (0.34, P({"head": {"r": (0, 0, 10)}, "chest": {"r": (0, 0, -2)}}, ears_same((0, -14, 0)))),
        (0.43, P({"head": {"r": (0, 0, -5)}, "chest": {"r": (0, 0, 1)}}, ears_same((0, 9, 0)))),
        (0.51, P({"head": {"r": (0, 0, 2)}, "chest": {"r": (0, 0, 0)}}, ears_same((0, -3, 0)))),
    ], face=[(0.1, eyes(0.6)), (0.45, eyes(0.3)), (0.55, eyes(0.0))])

    # run: bounding gallop, two strides per loop, no root translation (GDScript moves the pet)
    gather = P({"root": {"r": (8, 0, 0)}, "spine": {"s": sq(1.07, 0.9)}, "chest": {"r": (6, 0, 0)},
                "head": {"r": (-6, 0, 0)}}, sym("leg", r=(-30, 0, 0)), sym("arm", a=(0.45, 0.2, -0.85)),
               ears(back), tail(0, -25))
    reach = P({"root": {"r": (-6, 0, 0)}, "spine": {"s": sq(0.94, 1.08)}, "chest": {"r": (-4, 0, 0)},
               "head": {"r": (4, 0, 0)}}, sym("leg", r=(30, 0, 0)), sym("arm", a=(0.4, -0.85, -0.2)),
              ears(tuple(x * 1.3 for x in back)), tail(0, -35))
    A.action("run", 0.5, [(0.0, gather), (0.125, reach), (0.25, gather), (0.375, reach)], loop=True)

    # pounce: crouch with a bottom wiggle, leap (height only; GDScript moves it forward), squash, settle
    crouch = {"spine": {"s": sq(1.12, 0.85)}, "chest": {"r": (10, 0, 0)}, "head": {"r": (-8, 0, 0)}}
    A.action("pounce", 0.9, [
        (0.1, P(crouch, {"root": {"l": (0, 0.02, -0.02)}}, ears(flat), tail(0, -10))),
        (0.15, P({"root": {"r": (0, 0, 6), "l": (0, 0.02, -0.02)}})),
        (0.2, P({"root": {"r": (0, 0, -6), "l": (0, 0.02, -0.02)}})),
        (0.25, P(crouch, {"root": {"r": (0, 0, 0), "l": (0, 0.02, -0.025)}})),
        (0.42, P({"root": {"l": (0, 0, 0.25), "r": (18, 0, 0)}, "spine": {"s": sq(0.9, 1.14)},
                  "chest": {"r": (-6, 0, 0)}, "head": {"r": (-10, 0, 0)}},
                 sym("arm", a=(0.3, -0.92, 0.2), s=(1, 1.15, 1)), sym("leg", r=(35, 0, 0)), ears(back), tail(0, -30))),
        (0.6, P({"root": {"l": (0, 0, 0), "r": (6, 0, 0)}, "spine": {"s": sq(1.16, 0.84)}, "chest": {"r": (8, 0, 0)},
                 "head": {"r": (10, 0, 0)}}, sym("arm", a=(0.4, -0.75, -0.5), s=(1, 1, 1)),
                sym("leg", r=(0, 0, 0)), ears(perk), tail(0, 0))),
        (0.72, P({"root": {"r": (-2, 0, 0)}, "spine": {"s": sq(0.96, 1.05)}, "chest": {"r": (-2, 0, 0)},
                  "head": {"r": (-3, 0, 0)}}, sym("arm", r=(0, -3, 0)))),
        (0.82, P({"root": {"r": (0, 0, 0)}, "spine": {"s": sq(1.01, 0.99)}, "chest": {"r": (0, 0, 0)},
                  "head": {"r": (0, 0, 0)}}, sym("arm", r=(0, 0, 0)), ears((0, 0, 0)))),
    ], face=[(0.25, {"smile": 0.5}), (0.42, {"jaw_open": 0.5, "smile": 0.9}), (0.62, {"jaw_open": 0.0}),
             (0.85, {"smile": 0.3})])

    # jump: a happy hop in place
    A.action("jump", 0.6, [
        (0.1, P({"spine": {"s": sq(1.12, 0.86)}, "head": {"r": (6, 0, 0)}}, sym("arm", r=(0, 8, 0)))),
        (0.26, P({"root": {"l": (0, 0, 0.14)}, "spine": {"s": sq(0.92, 1.1)}, "head": {"r": (-8, 0, 0)}},
                 sym("arm", a=(0.8, -0.3, 0.45)), sym("leg", r=(15, 0, 0)), ears(perk), tail(20))),
        (0.4, P({"root": {"l": (0, 0, 0)}, "spine": {"s": sq(1.12, 0.87)}, "head": {"r": (5, 0, 0)}},
                sym("arm", r=(0, -6, 0)), sym("leg", r=(0, 0, 0)), tail(-10))),
        (0.5, P({"spine": {"s": sq(0.97, 1.03)}, "head": {"r": (-2, 0, 0)}}, sym("arm", r=(0, 1, 0)), ears((0, 0, 0)))),
    ], face=[(0.15, {"smile": 0.9}), (0.5, {"smile": 0.4})])


# ---------------------------------------------------------------- driver

def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.preferences.filepaths.save_version = 0
    sc = bpy.context.scene
    sc.render.fps = FPS
    sc.frame_start = 0
    sc.frame_end = 132


def shift_to_floor(head, body, bones):
    minz = min(min(v.z for v in head.v), min(v.z for v in body.v))
    off = Vector((0, 0, -minz))
    for acc in (head, body):
        acc.v = [v + off for v in acc.v]
        for d in acc.keys.values():
            for k in d:
                d[k] = d[k] + off
    for k, (h, t, p) in bones.items():
        bones[k] = (Vector(h) + (off if k != "root" else Vector()), Vector(t) + (off if k != "root" else Vector()), p)
    bones["root"] = (Vector((0, 0, 0)), Vector((0, 0, 0.08)), None)


def build(pet):
    S = SPECS[pet]()
    reset_scene()
    head, body, bones = build_geometry(S)
    shift_to_floor(head, body, bones)
    mats = make_materials(S)
    arm = make_armature(f"{pet}_rig", bones)
    h = make_object(f"{pet}_head", head, mats, arm)
    b = make_object(f"{pet}_body", body, mats, arm)
    build_actions(arm, S, h)
    tris = head.tri_count() + body.tri_count()
    zmax = max(max(v.z for v in head.v), max(v.z for v in body.v))
    print(f"[{pet}] tris head={head.tri_count()} body={body.tri_count()} total={tris} height={zmax:.3f}")
    assert tris <= 15000, f"{pet}: {tris} triangles"

    BLEND_DIR.mkdir(parents=True, exist_ok=True)
    GLB_DIR.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND_DIR / f"{pet}.blend"))
    bpy.ops.export_scene.gltf(
        filepath=str(GLB_DIR / f"{pet}.glb"),
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
    ap.add_argument("--pet", default="all", choices=["cat", "dog", "bunny", "all"])
    args = ap.parse_args(argv)
    for pet in (["cat", "dog", "bunny"] if args.pet == "all" else [args.pet]):
        build(pet)


if __name__ == "__main__":
    main()
