"""Render a toon-style preview sheet of the exported prop GLBs.

Run from the repo root (after build_props.py):
  /Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup \
      -P tools/blender/render_prop_previews.py -- [--no-scale]

Imports assets/props/<id>.glb (so the sheet checks the real export), swaps the materials
for the same 2-tone cel ramp as render_previews.py and draws Freestyle outlines in #7A5233
on every surface except liquid, highlight and glass (as the toy loader does).
Each configuration (every fish/carrot/clover stage, liquids full and half drained) gets a
front and a 3/4 cell at one shared scale; the red cross marks the prop origin.
Writes tools/blender/previews/props.png and props_scale.png (props next to the pets).
"""

import argparse
import math
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Vector

HERE = Path(__file__).resolve().parent
REPO = HERE.parent.parent
PROP_DIR = REPO / "assets" / "props"
PET_DIR = REPO / "assets" / "characters"
OUT = HERE / "previews"
BG = "#FFF4E0"
LINE = "#7A5233"
NO_OUTLINE = {"liquid", "highlight", "glass"}
CELL = 0.36
COLS = 4  # configurations per row (two cells each)
CONFIGS = ([("milk", None, 1.0), ("milk", None, 0.5)]
           + [("fish", k, 1.0) for k in range(4)]
           + [("yarn", None, 1.0), ("bone", None, 1.0), ("water", None, 1.0), ("water", None, 0.5),
              ("ball", None, 1.0), ("bell", None, 1.0)]
           + [("carrot", k, 1.0) for k in range(4)]
           + [("clover", k, 1.0) for k in range(4)])


def lin(hexstr):
    h = hexstr.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return [x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c]


def setup_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_EEVEE"
    sc.render.film_transparent = False
    sc.view_settings.view_transform = "Standard"
    sc.view_settings.look = "None"
    world = bpy.data.worlds.new("bg")
    world.use_nodes = True
    nt = world.node_tree
    bgn = nt.nodes.get("Background")
    bgn.inputs["Color"].default_value = lin(BG) + [1.0]
    # camera sees the pastel colour, but it adds no ambient light so the cel ramp reads
    dark = nt.nodes.new("ShaderNodeBackground")
    dark.inputs["Color"].default_value = (0, 0, 0, 1)
    lp = nt.nodes.new("ShaderNodeLightPath")
    mixs = nt.nodes.new("ShaderNodeMixShader")
    nt.links.new(lp.outputs["Is Camera Ray"], mixs.inputs[0])
    nt.links.new(dark.outputs[0], mixs.inputs[1])
    nt.links.new(bgn.outputs[0], mixs.inputs[2])
    nt.links.new(mixs.outputs[0], nt.nodes.get("World Output").inputs[0])
    sc.world = world
    try:
        sc.eevee.taa_render_samples = 16
    except AttributeError:
        pass
    sc.render.use_freestyle = True
    sc.render.line_thickness_mode = "ABSOLUTE"
    sc.render.line_thickness = 2.2
    vl = sc.view_layers[0]
    vl.use_freestyle = True
    fs = vl.freestyle_settings
    ls = fs.linesets[0] if fs.linesets else fs.linesets.new("props")
    ls.select_by_visibility = True
    ls.select_by_edge_types = True
    ls.select_by_collection = True
    ls.select_by_face_marks = True
    ls.face_mark_negation = "EXCLUSIVE"
    ls.face_mark_condition = "ONE"
    ls.select_silhouette = True
    ls.select_border = False
    ls.select_crease = False
    ls.select_external_contour = True
    ls.select_contour = True
    if ls.linestyle is None:
        ls.linestyle = bpy.data.linestyles.new("outline")
    ls.linestyle.color = lin(LINE)
    ls.linestyle.thickness = 2.2
    lines = bpy.data.collections.new("lines")
    plain = bpy.data.collections.new("plain")
    sc.collection.children.link(lines)
    sc.collection.children.link(plain)
    ls.collection = lines

    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sun.data.energy = 3.0
    sun.rotation_euler = (-Vector((-0.55, -0.6, 0.6))).to_track_quat("-Z", "Y").to_euler()
    sc.collection.objects.link(sun)
    return sc, lines, plain


def base_name(mat):
    return mat.name.split(".")[0]


def toonify(mat):
    if mat.get("toon"):
        return
    nt = mat.node_tree
    base, alpha = (1, 1, 1, 1), 1.0
    for n in nt.nodes:
        if n.type == "BSDF_PRINCIPLED":
            base = tuple(n.inputs["Base Color"].default_value)
            alpha = n.inputs["Alpha"].default_value
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    emi = nt.nodes.new("ShaderNodeEmission")
    if base_name(mat) == "highlight":
        emi.inputs[0].default_value = base
    else:
        dif = nt.nodes.new("ShaderNodeBsdfDiffuse")
        s2r = nt.nodes.new("ShaderNodeShaderToRGB")
        ramp = nt.nodes.new("ShaderNodeValToRGB")
        mul = nt.nodes.new("ShaderNodeMix")
        dif.inputs["Color"].default_value = (1, 1, 1, 1)
        cr = ramp.color_ramp
        cr.interpolation = "CONSTANT"
        cr.elements[0].position = 0.0
        cr.elements[0].color = (0.8, 0.76, 0.78, 1)
        cr.elements[1].position = 0.22
        cr.elements[1].color = (1, 1, 1, 1)
        mul.data_type = "RGBA"
        mul.blend_type = "MULTIPLY"
        mul.inputs[0].default_value = 1.0
        mul.inputs[6].default_value = base
        nt.links.new(dif.outputs[0], s2r.inputs[0])
        nt.links.new(s2r.outputs[0], ramp.inputs[0])
        nt.links.new(ramp.outputs[0], mul.inputs[7])
        nt.links.new(mul.outputs[2], emi.inputs[0])
    shader = emi.outputs[0]
    if alpha < 1.0:
        tr = nt.nodes.new("ShaderNodeBsdfTransparent")
        mx = nt.nodes.new("ShaderNodeMixShader")
        mx.inputs[0].default_value = alpha
        nt.links.new(tr.outputs[0], mx.inputs[1])
        nt.links.new(emi.outputs[0], mx.inputs[2])
        shader = mx.outputs[0]
        mat.surface_render_method = "BLENDED"
    nt.links.new(shader, out.inputs[0])
    mat["toon"] = True


def mark_unlined(obj):
    """Freestyle face marks on the surfaces the toy loader leaves without an outline."""
    me = obj.data
    names = [base_name(m) for m in me.materials]
    if not names:
        return
    attr = me.attributes.get("freestyle_face") or me.attributes.new("freestyle_face", "BOOLEAN", "FACE")
    attr.data.foreach_set("value", [names[p.material_index] in NO_OUTLINE for p in me.polygons])


def import_glb(path, lines, plain):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(path))
    new = [o for o in bpy.data.objects if o not in before]
    for o in new:
        for c in list(o.users_collection):
            c.objects.unlink(o)
        (lines if o.type in ("MESH", "ARMATURE") else plain).objects.link(o)
        if o.type == "MESH":
            for m in o.data.materials:
                toonify(m)
            mark_unlined(o)
            # stochastic transparent shadows only add noise to a cel look
            o.visible_shadow = not any(base_name(m) == "glass" for m in o.data.materials)
    return new


def flat_material(name, hexcol):
    m = bpy.data.materials.get(name)
    if m:
        return m
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    e = nt.nodes.new("ShaderNodeEmission")
    e.inputs[0].default_value = lin(hexcol) + [1.0]
    nt.links.new(e.outputs[0], nt.nodes.new("ShaderNodeOutputMaterial").inputs[0])
    return m


def origin_cross(parent, plain, size=0.045):
    me = bpy.data.meshes.new("cross")
    v, f = [], []
    t = 0.0016
    for axis in range(3):
        lo = [-t] * 3
        hi = [t] * 3
        lo[axis], hi[axis] = -size / 2, size / 2
        b = len(v)
        v += [(x, y, z) for x in (lo[0], hi[0]) for y in (lo[1], hi[1]) for z in (lo[2], hi[2])]
        f += [[b + i for i in q] for q in ([0, 1, 3, 2], [4, 6, 7, 5], [0, 4, 5, 1], [2, 3, 7, 6], [0, 2, 6, 4], [1, 5, 7, 3])]
    me.from_pydata(v, [], f)
    me.materials.append(flat_material("origin", "#E5484D"))
    o = bpy.data.objects.new("origin", me)
    plain.objects.link(o)
    o.parent = parent
    return o


def label(text, at, rot, plain, size=0.022):
    cu = bpy.data.curves.new("label", "FONT")
    cu.body = text
    cu.align_x = "CENTER"
    cu.size = size
    o = bpy.data.objects.new("label", cu)
    o.data.materials.append(flat_material("ink", LINE))
    o.matrix_world = Matrix.Translation(at) @ rot.to_4x4()
    plain.objects.link(o)


def place_config(prop, stage, fill, lines, plain, pos, M):
    """Import one configuration, centre its visible bounds on `pos`, rotate it by M."""
    objs = import_glb(PROP_DIR / f"{prop}.glb", lines, plain)
    for o in list(objs):
        if stage is not None and "_stage" in o.name and not o.name.startswith(f"{prop}_stage{stage}"):
            objs.remove(o)
            bpy.data.objects.remove(o)
    for o in objs:
        if o.name.split(".")[0].endswith("_liquid"):
            o.scale.z *= fill
    pivot = bpy.data.objects.new(f"{prop}_pivot", None)
    plain.objects.link(pivot)
    for o in objs:
        if o.parent is None:
            o.parent = pivot
    bpy.context.view_layer.update()
    pts = [o.matrix_world @ Vector(c) for o in objs if o.type == "MESH" for c in o.bound_box]
    center = (Vector([min(p[i] for p in pts) for i in range(3)]) + Vector([max(p[i] for p in pts) for i in range(3)])) / 2
    for o in objs:
        if o.parent == pivot:
            o.location -= center
    cross = origin_cross(pivot, plain)
    cross.location = -center
    pivot.matrix_world = Matrix.Translation(pos) @ M.to_4x4()
    return objs


def ortho_camera(sc, forward, up, width):
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    sc.collection.objects.link(cam)
    sc.camera = cam
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = width
    cam.data.sensor_fit = "HORIZONTAL"
    cam.location = -forward * 4.0
    cam.rotation_euler = forward.to_track_quat("-Z", "Y").to_euler()
    cam.data.clip_start = 0.01
    cam.data.clip_end = 10.0
    return cam


def sheet():
    sc, lines, plain = setup_scene()
    el = math.radians(10)
    forward = Vector((0, math.cos(el), -math.sin(el)))
    up = Vector((0, math.sin(el), math.cos(el)))
    right = Vector((1, 0, 0))
    rows = math.ceil(len(CONFIGS) / COLS)
    row_h = CELL + 0.05
    width, height = COLS * 2 * CELL, rows * row_h
    sc.render.resolution_x = 2560
    sc.render.resolution_y = round(2560 * height / width)
    cam = ortho_camera(sc, forward, up, width)
    cam_rot = cam.rotation_euler.to_matrix()
    three_q = Matrix.Rotation(math.radians(18), 3, right) @ Matrix.Rotation(math.radians(-38), 3, "Z")
    for i, (prop, stage, fill) in enumerate(CONFIGS):
        col, row = i % COLS, i // COLS
        cy = height / 2 - row_h * row - CELL / 2 - 0.01
        for k, M in enumerate((Matrix.Identity(3), three_q)):
            cx = -width / 2 + CELL * (2 * col + k + 0.5)
            place_config(prop, stage, fill, lines, plain, right * cx + up * cy, M)
        name = prop + (f" stage {stage}" if stage is not None else "") + (" half" if fill < 1 else "")
        label(f"{name}   (front | 3/4)", right * (-width / 2 + CELL * (2 * col + 1)) + up * (cy - CELL / 2 - 0.012),
              cam_rot, plain)
    render(sc, "props.png")


def import_pet(pet, lines, plain, x):
    objs = import_glb(PET_DIR / f"{pet}.glb", lines, plain)
    # the importer adds an unparented icosphere used as a bone display shape
    for o in [o for o in objs if o.type == "MESH" and o.parent is None]:
        objs.remove(o)
        bpy.data.objects.remove(o)
    for o in objs:
        if o.parent is None:
            o.location.x += x
        if o.type == "ARMATURE" and o.animation_data:
            o.animation_data.action = None
            for pb in o.pose.bones:
                pb.matrix_basis.identity()
        if o.type == "MESH" and o.data.shape_keys:
            for kb in o.data.shape_keys.key_blocks:
                kb.value = 0.0


def scale_lineup():
    """Each pet with its three toys on the floor in front of it (the bell hangs at paw height)."""
    sc, lines, plain = setup_scene()
    sc.render.resolution_x, sc.render.resolution_y = 3072, 1152
    toys = {"cat": ["milk", "fish", "yarn"], "dog": ["bone", "water", "ball"], "bunny": ["carrot", "clover", "bell"]}
    for i, (pet, props) in enumerate(toys.items()):
        x = (i - 1) * 1.0
        import_pet(pet, lines, plain, x - 0.22)
        for k, prop in enumerate(props):
            objs = import_glb(PROP_DIR / f"{prop}.glb", lines, plain)
            for o in list(objs):
                if "_stage" in o.name and "_stage0" not in o.name:
                    objs.remove(o)
                    bpy.data.objects.remove(o)
            lift = {"fish": 0.05, "bone": 0.045, "carrot": 0.124, "bell": 0.38}.get(prop, 0.0)
            for o in objs:
                if o.parent is None:
                    o.location += Vector((x + 0.06 + 0.15 * k, -0.25, lift))
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    sc.collection.objects.link(cam)
    sc.camera = cam
    cam.data.lens = 50
    cam.data.sensor_fit = "VERTICAL"
    cam.data.sensor_height = 24.0
    t = Vector((0, 0, 0.44))
    e = math.radians(8)
    d = 0.66 / math.tan(math.atan(12.0 / 50))
    cam.location = t + Vector((0, -math.cos(e), math.sin(e))) * d
    cam.rotation_euler = (t - cam.location).to_track_quat("-Z", "Y").to_euler()
    render(sc, "props_scale.png")


def render(sc, name):
    sc.render.filepath = str(OUT / name)
    bpy.ops.render.render(write_still=True)
    print("wrote", OUT / name)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--no-scale", action="store_true", help="skip props_scale.png")
    args = ap.parse_args(argv)
    OUT.mkdir(parents=True, exist_ok=True)
    sheet()
    if not args.no_scale:
        scale_lineup()


if __name__ == "__main__":
    main()
