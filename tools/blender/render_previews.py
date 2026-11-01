"""Render toon-style preview PNGs of the exported pet GLBs.

Run from the repo root (after build_pets.py):
  /Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup \
      -P tools/blender/render_previews.py -- --pet cat|dog|bunny|all [--no-lineup]

Imports assets/characters/<pet>.glb (so the previews check the real export), swaps the
materials for a 2-tone cel ramp and draws Freestyle outlines in #7A5233 on the materials
the game outlines.
Writes PNGs to tools/blender/previews/: <pet>_34.png, <pet>_side.png, <pet>_jaw.png,
<pet>_blink.png (1024x1024), <pet>_mouth.png (front row, 3/4 row; jaw 0 / 0.4 / 1.0),
<pet>_smile.png (closed smile), <pet>_nose_twitch.png (rest, twitch; pets with the key),
<pet>_actions.png and <pet>_actions_toys.png (one mid frame per clip in ACTION_FRAMES /
TOY_FRAMES), plus lineup.png (3072x1024).
"""

import argparse
import math
import sys
from pathlib import Path

import bpy
import numpy as np
from mathutils import Vector

HERE = Path(__file__).resolve().parent
REPO = HERE.parent.parent
GLB_DIR = REPO / "assets" / "characters"
OUT = HERE / "previews"
BG = "#FFF4E0"
LINE = "#7A5233"
PETS = ["cat", "dog", "bunny"]
# Same list as pet.gd OUTLINED: only these get the inverted-hull outline in the game.
OUTLINED = {"body", "ear", "paw", "collar", "collar_tag", "tail_puff"}
TILES = HERE / "out" / "tiles"
# (clip, seconds) for the action sheet, in sheet order
ACTION_FRAMES = [("yawn", 0.8), ("scratch_ear", 0.5), ("happy_wiggle", 0.4), ("laugh_tumble", 0.95),
                 ("wave", 0.42), ("drink", 0.75), ("lap", 0.9), ("bite", 0.22), ("chew", 0.14),
                 ("bat_paw_L", 0.24), ("bat_paw_R", 0.24), ("sniff", 0.36)]
TOY_FRAMES = [("excited", 0.26), ("sit_down", 0.45), ("sit_idle", 0.5), ("stand_up", 0.16),
              ("sit_hold_eat", 0.5), ("sit_hold_drink", 1.0), ("sit_lap", 0.84), ("sit_bat_L", 0.22),
              ("sit_bat_R", 0.22), ("lie_down", 0.62), ("lie_play", 0.2), ("get_up", 0.4),
              ("laugh", 0.28), ("head_shake", 0.25), ("run", 0.125), ("pounce", 0.42), ("jump", 0.26)]


def lin(hexstr):
    h = hexstr.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return [x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c]


def setup_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_EEVEE"
    sc.render.resolution_x = sc.render.resolution_y = 1024
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
    sc.render.line_thickness = 2.6
    vl = sc.view_layers[0]
    vl.use_freestyle = True
    fs = vl.freestyle_settings
    ls = fs.linesets[0] if fs.linesets else fs.linesets.new("pets")
    ls.select_by_visibility = True
    ls.select_by_edge_types = True
    ls.select_by_collection = True
    ls.select_silhouette = True
    ls.select_border = False
    ls.select_crease = False
    # faces of thin shells and the mouth are face-marked: no lines there, as in the game
    ls.select_by_face_marks = True
    ls.face_mark_negation = "EXCLUSIVE"
    ls.face_mark_condition = "ONE"
    ls.select_external_contour = True
    ls.select_contour = True
    if ls.linestyle is None:
        ls.linestyle = bpy.data.linestyles.new("outline")
    ls.linestyle.color = lin(LINE)
    ls.linestyle.thickness = 2.6
    pets = bpy.data.collections.new("pets")
    sc.collection.children.link(pets)
    ls.collection = pets

    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sun.data.energy = 3.0
    sun.rotation_euler = (-Vector((-0.55, -0.6, 0.6))).to_track_quat("-Z", "Y").to_euler()
    sc.collection.objects.link(sun)
    return sc, pets


def toonify(mat):
    if mat.get("toon"):
        return
    nt = mat.node_tree
    base = (1, 1, 1, 1)
    for n in nt.nodes:
        if n.type == "BSDF_PRINCIPLED":
            base = tuple(n.inputs["Base Color"].default_value)
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    dif = nt.nodes.new("ShaderNodeBsdfDiffuse")
    s2r = nt.nodes.new("ShaderNodeShaderToRGB")
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    mul = nt.nodes.new("ShaderNodeMix")
    emi = nt.nodes.new("ShaderNodeEmission")
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
    nt.links.new(emi.outputs[0], out.inputs[0])
    mat["toon"] = True


def import_pet(pet, pets, x=0.0, yaw=0.0):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(GLB_DIR / f"{pet}.glb"))
    new = [o for o in bpy.data.objects if o not in before]
    # the importer adds an unparented icosphere used as a bone display shape
    for o in [o for o in new if o.type == "MESH" and o.parent is None]:
        new.remove(o)
        bpy.data.objects.remove(o)
    for o in new:
        for c in list(o.users_collection):
            c.objects.unlink(o)
        pets.objects.link(o)
    roots = [o for o in new if o.parent is None]
    for r in roots:
        r.location.x += x
        r.rotation_mode = "XYZ"
        r.rotation_euler.z += math.radians(yaw)
    for o in new:
        if o.type == "ARMATURE" and o.animation_data:
            o.animation_data.action = None
            for pb in o.pose.bones:
                pb.matrix_basis.identity()
        if o.type == "MESH" and o.data.shape_keys and o.data.shape_keys.animation_data:
            o.data.shape_keys.animation_data.action = None
        if o.type == "MESH":
            names = [m.name.split(".")[0] for m in o.data.materials]
            marks = [names[p.material_index] not in OUTLINED for p in o.data.polygons]
            o.data.attributes.new("freestyle_face", "BOOLEAN", "FACE").data.foreach_set("value", marks)
            for m in o.data.materials:
                toonify(m)
    return new


def play(objs, name, t):
    """Pose bones and face shape keys at time t of clip `name` (its armature and KEY slots)."""
    act = bpy.data.actions.get(name)
    if act is None:
        print("missing action", name)
        return False
    for o in objs:
        ad = None
        if o.type == "ARMATURE":
            ad = o.animation_data
            kind = "OBJECT"
        elif o.type == "MESH" and o.data.shape_keys:
            ad = o.data.shape_keys.animation_data_create()
            kind = "KEY"
            for kb in o.data.shape_keys.key_blocks:
                kb.value = 0.0
        if ad is None:
            continue
        slots = [sl for sl in act.slots if sl.target_id_type == kind]
        ad.action = act if slots else None
        if slots:
            ad.action_slot = slots[0]
    bpy.context.scene.frame_set(int(round(t * bpy.context.scene.render.fps)))
    return True


def stop(objs):
    for o in objs:
        if o.type == "ARMATURE" and o.animation_data:
            o.animation_data.action = None
            for pb in o.pose.bones:
                pb.matrix_basis.identity()
        elif o.type == "MESH" and o.data.shape_keys and o.data.shape_keys.animation_data:
            o.data.shape_keys.animation_data.action = None


def shape(objs, **vals):
    for o in objs:
        keys = o.data.shape_keys if o.type == "MESH" else None
        if not keys:
            continue
        for kb in keys.key_blocks:
            if kb.name in vals:
                kb.value = vals[kb.name]
            elif kb.name != "Basis":
                kb.value = 0.0


def floor_shadow(sc, x=0.0, r=0.3):
    bpy.ops.mesh.primitive_circle_add(vertices=48, radius=r, fill_type="NGON", location=(x, 0.0, 0.001))
    o = bpy.context.active_object
    o.scale.y = 0.75
    m = bpy.data.materials.new("shadow")
    m.use_nodes = True
    nt = m.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    e = nt.nodes.new("ShaderNodeEmission")
    e.inputs[0].default_value = lin("#EFD9BC") + [1.0]
    nt.links.new(e.outputs[0], nt.nodes.new("ShaderNodeOutputMaterial").inputs[0])
    o.data.materials.append(m)
    return o


def camera(sc, target, az, el, fit, lens=50.0, aspect=1.0):
    cam = sc.camera
    if cam is None:
        cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
        sc.collection.objects.link(cam)
        sc.camera = cam
    cam.data.lens = lens
    cam.data.sensor_fit = "VERTICAL"
    cam.data.sensor_height = 24.0
    fov = 2 * math.atan(12.0 / lens)
    d = (fit / 2) / math.tan(fov / 2)
    t = Vector(target)
    a, e = math.radians(az), math.radians(el)
    cam.location = t + Vector((math.sin(a) * math.cos(e), -math.cos(a) * math.cos(e), math.sin(e))) * d
    cam.rotation_euler = (t - cam.location).to_track_quat("-Z", "Y").to_euler()
    cam.data.clip_start = 0.01


def render(sc, name):
    sc.render.filepath = str(OUT / name)
    bpy.ops.render.render(write_still=True)
    print("wrote", OUT / name)


def head_target(objs):
    for o in objs:
        if o.type == "MESH" and o.name.split(".")[0].endswith("_head"):
            zs = [v.co.z for v in o.data.vertices]
            ys = [v.co.y for v in o.data.vertices]
            # the face sits at the bottom half of the head (ears excluded via median)
            zs.sort()
            return Vector((0, 0, zs[len(zs) // 2] - 0.03))
    return Vector((0, 0, 0.6))


def mouth_target(objs):
    """Centre of the lip ring at rest."""
    for o in objs:
        if o.type == "MESH" and o.name.split(".")[0].endswith("_head"):
            names = [m.name.split(".")[0] for m in o.data.materials]
            vs = {i for p in o.data.polygons if names[p.material_index] == "lip" for i in p.vertices}
            if vs:
                return o.matrix_world @ (sum((o.data.vertices[i].co for i in vs), Vector()) / len(vs))
    return head_target(objs) - Vector((0, 0, 0.06))


def sheet(paths, cols, name):
    """Lay equal-size tile PNGs out in rows of `cols` and save as OUT/name."""
    imgs = [bpy.data.images.load(str(p)) for p in paths]
    w, h = imgs[0].size
    rows = (len(imgs) + cols - 1) // cols
    out = np.ones((rows * h, cols * w, 4), dtype=np.float32)
    for i, im in enumerate(imgs):
        r, c = i // cols, i % cols
        out[(rows - 1 - r) * h:(rows - r) * h, c * w:(c + 1) * w] = np.array(im.pixels[:]).reshape(h, w, 4)
        bpy.data.images.remove(im)
    img = bpy.data.images.new(name, cols * w, rows * h, alpha=True)
    img.pixels.foreach_set(out.ravel())
    img.filepath_raw = str(OUT / name)
    img.file_format = "PNG"
    img.save()
    print("wrote", OUT / name)


def tile(sc, name):
    sc.render.filepath = str(TILES / name)
    bpy.ops.render.render(write_still=True)
    return TILES / name


def pet_views(pet):
    sc, pets = setup_scene()
    objs = import_pet(pet, pets)
    floor_shadow(sc)
    top = max((o.matrix_world @ Vector(c)).z for o in objs if o.type == "MESH" for c in o.bound_box)
    mid = Vector((0, 0, top / 2))
    shape(objs)
    camera(sc, mid + Vector((0, 0, 0.02)), 32, 10, top * 1.18)
    render(sc, f"{pet}_34.png")
    camera(sc, mid + Vector((0, 0, 0.02)), 90, 6, top * 1.18)
    render(sc, f"{pet}_side.png")
    ht = head_target(objs)
    camera(sc, ht, 12, 4, 0.62, lens=70)
    shape(objs, jaw_open=1.0)
    render(sc, f"{pet}_jaw.png")
    shape(objs, blink_L=1.0, blink_R=1.0)
    render(sc, f"{pet}_blink.png")

    # face close-ups at the stage camera's height (about 12 degrees above)
    sc.render.resolution_x = sc.render.resolution_y = 640
    face = mouth_target(objs) + Vector((0, 0, 0.045))
    tiles = []
    for az in (0, 32):
        camera(sc, face, az, 12, 0.36, lens=70)
        for j in (0.0, 0.4, 1.0):
            shape(objs, jaw_open=j)
            tiles.append(tile(sc, f"{pet}_mouth_{az}_{j}.png"))
    sheet(tiles, 3, f"{pet}_mouth.png")
    camera(sc, face, 0, 12, 0.36, lens=70)
    shape(objs, smile=1.0)
    render(sc, f"{pet}_smile.png")
    keys = {kb.name for o in objs if o.type == "MESH" and o.data.shape_keys for kb in o.data.shape_keys.key_blocks}
    if "nose_twitch" in keys:
        camera(sc, mouth_target(objs) + Vector((0, 0, 0.01)), 0, 12, 0.16, lens=70)
        tiles = []
        for v in (0.0, 1.0):
            shape(objs, nose_twitch=v)
            tiles.append(tile(sc, f"{pet}_nose_{v}.png"))
        sheet(tiles, 2, f"{pet}_nose_twitch.png")

    # one mid frame of each clip, full body
    sc.render.resolution_x = sc.render.resolution_y = 512
    shape(objs)
    for frames, out, cols in ((ACTION_FRAMES, f"{pet}_actions.png", 4), (TOY_FRAMES, f"{pet}_actions_toys.png", 6)):
        tiles = []
        for name, t in frames:
            if play(objs, name, t):
                camera(sc, mid + Vector((0, 0, 0.1)), 32, 10, top * 1.45)
                tiles.append(tile(sc, f"{pet}_act_{name}.png"))
        stop(objs)
        if tiles:
            sheet(tiles, cols, out)


def poses(pet):
    """Debug contact renders of key action frames (written to tools/blender/out/)."""
    sc, pets = setup_scene()
    sc.render.resolution_x = sc.render.resolution_y = 512
    objs = import_pet(pet, pets)
    floor_shadow(sc)
    shape(objs)
    camera(sc, (0, 0, 0.55), 32, 10, 1.35)
    picks = {"happy_bounce": 0.3, "giggle": 0.3, "paw_highfive_L": 0.2, "paw_highfive_R": 0.2,
             "listen_nod": 0.15, "walk_in": 0.0, "look_around": 0.5, "stretch": 0.8,
             "ear_perk": 0.2, "idle_breathe": 1.1}
    for name, t in picks.items():
        if not play(objs, name, t):
            continue
        sc.render.filepath = str(HERE / "out" / f"{pet}_pose_{name}.png")
        bpy.ops.render.render(write_still=True)
    stop(objs)
    for key in ("smile", "ear_perk"):
        shape(objs, **{key: 1.0})
        camera(sc, head_target(objs), 12, 4, 0.75, lens=70)
        sc.render.filepath = str(HERE / "out" / f"{pet}_key_{key}.png")
        bpy.ops.render.render(write_still=True)


def lineup():
    sc, pets = setup_scene()
    sc.render.resolution_x = 3072
    tops = []
    for i, pet in enumerate(PETS):
        x = (i - 1) * 0.82
        objs = import_pet(pet, pets, x, yaw=-24)
        floor_shadow(sc, x)
        shape(objs)
        tops.append(max((o.matrix_world @ Vector(c)).z for o in objs if o.type == "MESH" for c in o.bound_box))
    top = max(tops)
    camera(sc, (0, 0, top / 2 + 0.01), 0, 8, top * 1.22)
    render(sc, "lineup.png")


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--pet", default="all", choices=PETS + ["all"])
    ap.add_argument("--no-lineup", action="store_true")
    ap.add_argument("--poses", action="store_true", help="debug action renders to out/")
    args = ap.parse_args(argv)
    OUT.mkdir(parents=True, exist_ok=True)
    for pet in PETS if args.pet == "all" else [args.pet]:
        if args.poses:
            poses(pet)
        else:
            pet_views(pet)
    if not args.no_lineup and not args.poses:
        lineup()


if __name__ == "__main__":
    main()
