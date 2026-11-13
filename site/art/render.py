"""Renders the 3D pieces of the Levels website: a white desk "mixer" with three
fader slots and black caps at the brand symbol's heights (y 76 / 36 / 58 in the
120 viewBox -> 30%, 80%, 52.5% of the travel).

Run headless (does not touch any open Blender session):
  /Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup \
      -P site/art/render.py -- [--preview] [--only hero,top,macro]
Writes transparent PNGs (with a soft contact shadow) to site/public/renders/.
"""
import math
import os
import sys

import bpy
from mathutils import Vector

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
PREVIEW = "--preview" in ARGS
ONLY = None
if "--only" in ARGS:
    ONLY = set(ARGS[ARGS.index("--only") + 1].split(","))

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "public", "renders")
os.makedirs(OUT, exist_ok=True)

# Fader travel positions from the brand symbol (fraction from the front end).
KNOBS = {-0.75: 0.30, 0.0: 0.80, 0.75: 0.525}

SLAB = Vector((3.0, 2.1, 0.28))
SLOT_LEN, SLOT_W, SLOT_DEPTH = 1.45, 0.06, 0.16
TOP = SLAB.z


# ---------------------------------------------------------------- helpers ---

def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def material(name, color, rough, coat=0.0, spec=0.5):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes.get("Principled BSDF")
    b.inputs["Base Color"].default_value = (*color, 1.0)
    b.inputs["Roughness"].default_value = rough
    if "Coat Weight" in b.inputs:
        b.inputs["Coat Weight"].default_value = coat
    if "Specular IOR Level" in b.inputs:
        b.inputs["Specular IOR Level"].default_value = spec
    return m


def box(name, size, loc, mat=None, bevel=0.0, segments=6):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    o = bpy.context.active_object
    o.name = name
    o.scale = size
    bpy.ops.object.transform_apply(scale=True)
    if bevel > 0:
        m = o.modifiers.new("Bevel", "BEVEL")
        m.width = bevel
        m.segments = segments
        m.limit_method = "ANGLE"
    if mat:
        o.data.materials.append(mat)
    bpy.ops.object.shade_smooth()
    return o


def aim(obj, target):
    direction = Vector(target) - obj.location
    obj.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()


def area_light(name, loc, target, size, power):
    data = bpy.data.lights.new(name, "AREA")
    data.size = size
    data.energy = power
    o = bpy.data.objects.new(name, data)
    bpy.context.scene.collection.objects.link(o)
    o.location = loc
    aim(o, target)
    return o


# ------------------------------------------------------------------ scene ---

def build():
    reset()
    scene = bpy.context.scene

    white = material("Slab", (0.93, 0.93, 0.915), 0.48, coat=0.08)
    groove = material("Groove", (0.035, 0.035, 0.035), 0.7)
    cap = material("Cap", (0.004, 0.004, 0.004), 0.3, coat=0.2, spec=0.25)
    line = material("CapLine", (0.95, 0.95, 0.95), 0.4)
    ink = material("Ticks", (0.38, 0.38, 0.37), 0.6)

    slab = box("Slab", SLAB, (0, 0, SLAB.z / 2), white, bevel=0.11, segments=10)

    # Fader slots: boolean cutters; the cut faces take the groove material.
    for x in KNOBS:
        cutter = box(f"Cut{x}", (SLOT_W, SLOT_LEN, SLOT_DEPTH * 2), (x, 0, TOP), groove, bevel=0.025, segments=4)
        cutter.hide_render = True
        cutter.hide_viewport = True
        b = slab.modifiers.new(f"Slot{x}", "BOOLEAN")
        b.operation = "DIFFERENCE"
        b.object = cutter
        b.solver = "EXACT"
        if hasattr(b, "material_mode"):
            b.material_mode = "TRANSFER"
    # Bevel last so slot edges are softened too.
    bev = slab.modifiers["Bevel"]
    slab.modifiers.move(slab.modifiers.find("Bevel"), len(slab.modifiers) - 1)
    bev.width = 0.012
    outer = slab.modifiers.new("Outer", "BEVEL")  # big soft outer rounding first
    outer.width, outer.segments, outer.limit_method = 0.11, 10, "ANGLE"
    slab.modifiers.move(slab.modifiers.find("Outer"), 0)

    # Printed scale ticks to the right of each slot.
    for x in KNOBS:
        for i in range(9):
            major = i % 4 == 0
            y = -SLOT_LEN / 2 + i * SLOT_LEN / 8
            length = 0.11 if major else 0.065
            box(f"Tick{x}_{i}", (length, 0.016, 0.002), (x + 0.075 + length / 2, y, TOP + 0.001), ink)

    # Fader caps with a white indicator line.
    for x, t in KNOBS.items():
        y = -SLOT_LEN / 2 + t * SLOT_LEN
        box(f"Cap{x}", (0.42, 0.25, 0.19), (x, y, TOP + 0.085), cap, bevel=0.045, segments=8)
        box(f"Line{x}", (0.3, 0.024, 0.006), (x, y, TOP + 0.18), line, bevel=0.003, segments=2)

    # Floor that only catches shadows (transparent everywhere else).
    bpy.ops.mesh.primitive_plane_add(size=40, location=(0, 0, 0))
    floor = bpy.context.active_object
    floor.name = "Floor"
    floor.is_shadow_catcher = True

    area_light("Key", (-3.2, -2.8, 5.2), (0, 0, 0), 5.0, 1100)
    area_light("Fill", (4.5, -2.0, 3.0), (0, 0, 0), 3.5, 320)
    area_light("Rim", (0.5, 4.5, 3.4), (0, 0, 0.2), 4.0, 520)

    world = bpy.data.worlds.new("World")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (1, 1, 1, 1)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.35
    scene.world = world

    # Render settings: Cycles on the GPU (Metal), transparent film.
    scene.render.engine = "CYCLES"
    try:
        prefs = bpy.context.preferences.addons["cycles"].preferences
        prefs.compute_device_type = "METAL"
        prefs.get_devices()
        for d in prefs.devices:
            d.use = True
        scene.cycles.device = "GPU"
    except Exception as e:  # CPU fallback
        print("GPU setup failed:", e)
    scene.cycles.samples = 24 if PREVIEW else 160
    scene.cycles.use_denoising = True
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    for vt in ("Khronos PBR Neutral", "Standard"):
        try:
            scene.view_settings.view_transform = vt
            break
        except TypeError:
            continue
    return scene


def camera(name, loc, target, lens=50, ortho=None):
    data = bpy.data.cameras.new(name)
    data.lens = lens
    if ortho:
        data.type = "ORTHO"
        data.ortho_scale = ortho
    o = bpy.data.objects.new(name, data)
    bpy.context.scene.collection.objects.link(o)
    o.location = loc
    aim(o, target)
    return o


def shoot(scene, cam, name, res, shadow=True):
    if ONLY and name not in ONLY:
        return
    # Without the floor the PNG is cut exactly to the object; the site adds a CSS shadow.
    bpy.data.objects["Floor"].hide_render = not shadow
    scene.camera = cam
    scene.render.resolution_x, scene.render.resolution_y = res
    scene.render.resolution_percentage = 40 if PREVIEW else 100
    scene.render.filepath = os.path.join(OUT, f"{name}{'-preview' if PREVIEW else ''}.png")
    bpy.ops.render.render(write_still=True)
    print("wrote", scene.render.filepath)


scene = build()

# Hero: three-quarter view from the front right.
hero = camera("Hero", (4.3, -5.9, 4.1), (0, -0.05, 0.05), lens=62)
shoot(scene, hero, "hero", (2400, 1500))

# Top: straight down, orthographic, reads like the brand symbol.
top = camera("Top", (0, 0, 6), (0, 0, 0), ortho=4.0)
top.rotation_euler = (0, 0, 0)
shoot(scene, top, "top", (1600, 1200), shadow=False)

# Macro: close on the middle fader with shallow depth of field.
mid_y = -SLOT_LEN / 2 + KNOBS[0.0] * SLOT_LEN
macro = camera("Macro", (1.15, mid_y - 1.25, 1.05), (0, mid_y, TOP + 0.1), lens=105)
macro.data.dof.use_dof = True
macro.data.dof.focus_distance = (macro.location - Vector((0, mid_y, TOP + 0.1))).length
macro.data.dof.aperture_fstop = 2.2
shoot(scene, macro, "macro", (1400, 1050))
