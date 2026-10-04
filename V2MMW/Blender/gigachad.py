"""
V2MMW · GigaChad (personaje de prueba) — script para Blender 4.x / 5.x

Versión "galán calamar": figura de colección estilizada. Piel turquesa, cabeza alargada con nariz
caída y párpados pesados, camiseta marrón ajustada con cinturón negro y hebilla dorada, manos en la
cintura y piernas cruzadas (sin peana).
(Inspirado en un meme muy conocido: cambia el diseño antes de publicarlo en Roblox.)

Genera:
  GigaChad.blend / GigaChad.fbx / GigaChad.obj
  GigaChad_preview.png (3/4) · GigaChad_front.png (frente)

Uso:  blender --background --python gigachad.py   (o Blender → Scripting → Run Script)
Mide ~7.6 unidades de alto, con los pies en Z = 0, y mira hacia -Y.
Cada color es una malla aparte para poder colorearla en Roblox.
"""

import math
import os

import bpy
from mathutils import Vector

OUT = os.path.dirname(os.path.abspath(__file__)) if "__file__" in dir() else os.getcwd()
NAME = "GigaChad"
MAX_TRIS_PER_MESH = 9000  # Roblox admite hasta 20 000 triángulos por MeshPart
# Con umbral 0.05 y rigidez 2, la superficie visible de un metaball queda a ~0.84·radio:
# K compensa para que los tamaños del script sean (casi) los tamaños reales en pantalla.
THRESHOLD = 0.05
K = 1.18

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
X_AXIS = Vector((1, 0, 0))


# ---------------------------------------------------------------- helpers
def material(name, rgb, roughness=0.55, metallic=0.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = (*rgb, 1)
        bsdf.inputs["Roughness"].default_value = roughness
        bsdf.inputs["Metallic"].default_value = metallic
    mat.diffuse_color = (*rgb, 1)  # color que usa la vista Workbench
    return mat


def metaball(family, resolution=0.05):
    mb = bpy.data.metaballs.new(family)
    mb.resolution = resolution
    mb.render_resolution = resolution
    mb.threshold = THRESHOLD
    obj = bpy.data.objects.new(family, mb)
    scene.collection.objects.link(obj)
    return mb, obj


def ball(mb, co, r, stiff=2.0):
    el = mb.elements.new()
    el.type = "BALL"
    el.co = co
    el.radius = r * K
    el.stiffness = stiff
    return el


def ellipsoid(mb, co, size, r=1.0, stiff=2.0, rot=None):
    el = mb.elements.new()
    el.type = "ELLIPSOID"
    el.co = co
    el.radius = r * K
    el.size_x, el.size_y, el.size_z = size
    el.stiffness = stiff
    if rot is not None:
        el.rotation = rot
    return el


def limb(mb, a, b, r, stiff=2.0):
    """cápsula que va del punto a al punto b"""
    a, b = Vector(a), Vector(b)
    d = b - a
    el = mb.elements.new()
    el.type = "CAPSULE"
    el.co = (a + b) / 2
    el.radius = r * K
    el.size_x = d.length / 2
    el.stiffness = stiff
    el.rotation = X_AXIS.rotation_difference(d.normalized())
    return el


def lerp(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


# ---------------------------------------------------------------- medidas del cuerpo
BASE_TOP = 0.43
SIDES = (-1, 1)
SHOULDER = {s: (s * 1.02, 0.02, 4.85) for s in SIDES}
ELBOW = {s: (s * 1.62, 0.22, 3.85) for s in SIDES}
HAND = {s: (s * 0.74, 0.02, 3.12) for s in SIDES}
HIP = {s: (s * 0.24, 0.0, 2.78) for s in SIDES}
# piernas cruzadas: la izquierda pasa por delante de la derecha
KNEE = {-1: (0.02, -0.18, 1.68), 1: (0.24, 0.05, 1.66)}
FOOT = {-1: (0.42, -0.3, BASE_TOP + 0.12), 1: (0.14, 0.12, BASE_TOP + 0.12)}

# ---------------------------------------------------------------- PIEL
skin, skin_obj = metaball("Skin")
for s in SIDES:
    # brazos en jarra (manos en la cintura)
    limb(skin, SHOULDER[s], ELBOW[s], 0.34)
    ball(skin, lerp(SHOULDER[s], ELBOW[s], 0.55), 0.38, stiff=1.6)             # bíceps
    limb(skin, ELBOW[s], HAND[s], 0.25)
    ball(skin, lerp(ELBOW[s], HAND[s], 0.3), 0.3, stiff=1.5)                    # antebrazo
    ellipsoid(skin, HAND[s], (0.18, 0.22, 0.24), stiff=2.2)                     # mano
    # piernas finas y largas
    limb(skin, HIP[s], KNEE[s], 0.27)
    limb(skin, KNEE[s], FOOT[s], 0.19)
    ball(skin, lerp(KNEE[s], FOOT[s], 0.3), 0.21, stiff=1.4)                    # gemelo
# cuello con nuez
limb(skin, (0, 0.05, 5.0), (0, 0.0, 5.4), 0.4)
ball(skin, (0, -0.33, 5.25), 0.1, stiff=1.1)
# cabeza alargada: cráneo alto, mandíbula cuadrada, nariz larga caída
ellipsoid(skin, (0, 0.08, 6.60), (0.56, 0.56, 0.78))                       # cráneo
ellipsoid(skin, (0, -0.04, 5.80), (0.5, 0.45, 0.38), stiff=2.3)           # mandíbula
ellipsoid(skin, (0, -0.33, 5.57), (0.28, 0.18, 0.2), stiff=2.2)          # mentón
for s in SIDES:
    ball(skin, (s * 0.28, -0.32, 6.10), 0.12, stiff=0.9)                  # pómulos
    ellipsoid(skin, (s * 0.42, -0.08, 5.75), (0.1, 0.25, 0.22), stiff=1.2)  # ángulo mandíbula
ellipsoid(skin, (0, -0.42, 6.50), (0.42, 0.1, 0.07), stiff=1.8)            # arco de las cejas
limb(skin, (0, -0.5, 6.38), (0, -0.66, 5.90), 0.12, stiff=1.8)             # nariz
ball(skin, (0, -0.66, 5.84), 0.15, stiff=2.0)                             # punta de la nariz

# ---------------------------------------------------------------- CAMISETA (ajustada, con mangas cortas)
shirt, shirt_obj = metaball("Shirt")
ellipsoid(shirt, (0, 0.06, 4.45), (1.02, 0.55, 0.68))                     # pecho/espalda en V
for s in SIDES:
    ellipsoid(shirt, (s * 0.42, -0.2, 4.55), (0.5, 0.38, 0.38), stiff=2.2)  # pectorales
    ellipsoid(shirt, (s * 0.78, 0.15, 4.05), (0.3, 0.36, 0.6), stiff=1.4)   # dorsales
    ball(shirt, SHOULDER[s], 0.45)                                         # hombros
    limb(shirt, SHOULDER[s], lerp(SHOULDER[s], ELBOW[s], 0.45), 0.42)      # manga corta
ellipsoid(shirt, (0, 0.04, 5.12), (0.55, 0.34, 0.25))                     # trapecios
ellipsoid(shirt, (0, 0.02, 3.45), (0.54, 0.35, 0.55))                      # abdomen
for row, z in enumerate((3.4, 3.72)):
    for s in SIDES:
        ellipsoid(shirt, (s * 0.14, -0.31, z), (0.12, 0.06, 0.12), stiff=0.7)  # abdominales marcados
ellipsoid(shirt, (0, 0, 2.86), (0.55, 0.4, 0.3))                          # parte baja (tipo malla)

# ---------------------------------------------------------------- PIES
feet, feet_obj = metaball("Feet")
for s in SIDES:
    f = FOOT[s]
    ellipsoid(feet, (f[0], f[1] - 0.12, f[2] - 0.02), (0.17, 0.32, 0.11))

# ---------------------------------------------------------------- OJOS (párpados pesados), boca
eyes, eyes_obj = metaball("Eyes", resolution=0.02)
lids, lids_obj = metaball("Eyelids", resolution=0.025)
pupils, pupils_obj = metaball("Pupils", resolution=0.015)
lips, lips_obj = metaball("Lips", resolution=0.02)
for s in SIDES:
    ellipsoid(eyes, (s * 0.2, -0.47, 6.32), (0.13, 0.06, 0.1), stiff=3)
    ellipsoid(lids, (s * 0.2, -0.5, 6.38), (0.15, 0.06, 0.065), stiff=3)   # cubren la mitad superior
    ellipsoid(pupils, (s * 0.19, -0.53, 6.29), (0.035, 0.015, 0.035), stiff=3)
ellipsoid(lips, (0, -0.47, 5.63), (0.17, 0.045, 0.035), stiff=3)


# ---------------------------------------------------------------- metaballs → mallas
def finish_mesh(mesh_obj, name, mat):
    mesh_obj.name = f"{NAME}_{name}"
    mesh_obj.data.name = mesh_obj.name
    mesh_obj.data.materials.clear()
    mesh_obj.data.materials.append(mat)
    tris = sum(len(p.vertices) - 2 for p in mesh_obj.data.polygons)
    if tris > MAX_TRIS_PER_MESH:
        bpy.ops.object.select_all(action="DESELECT")
        bpy.context.view_layer.objects.active = mesh_obj
        mesh_obj.select_set(True)
        dec = mesh_obj.modifiers.new("Decimate", "DECIMATE")
        dec.ratio = MAX_TRIS_PER_MESH / tris
        bpy.ops.object.modifier_apply(modifier=dec.name)
    return mesh_obj


def to_mesh(obj, name, mat):
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.convert(target="MESH")
    m = bpy.context.view_layer.objects.active
    for p in m.data.polygons:
        p.use_smooth = True
    return finish_mesh(m, name, mat)


meshes = []
for obj, name, mat in (
    (skin_obj, "Skin", material("Skin", (0.46, 0.68, 0.68))),
    (shirt_obj, "Shirt", material("Shirt", (0.42, 0.3, 0.18), 0.8)),
    (feet_obj, "Feet", material("Feet", (0.52, 0.52, 0.72))),
    (eyes_obj, "Eyes", material("Eyes", (0.95, 0.92, 0.72), 0.3)),
    (lids_obj, "Eyelids", material("Eyelids", (0.38, 0.56, 0.58))),
    (pupils_obj, "Pupils", material("Pupils", (0.45, 0.12, 0.15), 0.2)),
    (lips_obj, "Lips", material("Lips", (0.58, 0.48, 0.64))),
):
    meshes.append(to_mesh(obj, name, mat))

for o in list(scene.objects):
    if o.type == "META":
        bpy.data.objects.remove(o, do_unlink=True)


# ---------------------------------------------------------------- cinturón y hebilla (mallas simples)
def cylinder(name, mat, radius, depth, loc, scale=(1, 1, 1), verts=48):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=radius, depth=depth, location=loc)
    o = bpy.context.active_object
    o.scale = scale
    bpy.ops.object.transform_apply(scale=True)
    return finish_mesh(o, name, mat)


def box(name, mat, size, loc, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=rot)
    o = bpy.context.active_object
    o.scale = size
    bpy.ops.object.transform_apply(scale=True)
    return finish_mesh(o, name, mat)


def pebble(name, mat, loc, size):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=8, radius=1, location=loc)
    o = bpy.context.active_object
    o.scale = size
    bpy.ops.object.transform_apply(scale=True)
    for p in o.data.polygons:
        p.use_smooth = True
    return finish_mesh(o, name, mat)


belt_mat = material("Belt", (0.03, 0.03, 0.03), 0.4)
gold = material("Buckle", (0.85, 0.66, 0.2), 0.3, 0.8)
meshes.append(cylinder("Belt", belt_mat, 1, 0.2, (0, 0.0, 3.08), scale=(0.66, 0.47, 1)))
meshes.append(box("Buckle", gold, (0.32, 0.06, 0.24), (0, -0.5, 3.08)))
meshes.append(box("BuckleHole", belt_mat, (0.18, 0.07, 0.11), (0, -0.505, 3.08)))

# sin peana: se baja todo para que los pies queden apoyados en Z = 0
for m in meshes:
    m.location.z -= BASE_TOP
bpy.ops.object.select_all(action="DESELECT")
for m in meshes:
    m.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]
bpy.ops.object.transform_apply(location=True, rotation=False, scale=False)

total = sum(sum(len(p.vertices) - 2 for p in m.data.polygons) for m in meshes)
print(f"[GigaChad] mallas: {len(meshes)}  triángulos totales: {total}")

# ---------------------------------------------------------------- cámara, luces y render de vista previa
target = bpy.data.objects.new("Target", None)
scene.collection.objects.link(target)
target.location = (0, 0, 3.5)
cam = bpy.data.objects.new("Camera", bpy.data.cameras.new("Camera"))
cam.data.lens = 50
scene.collection.objects.link(cam)
track = cam.constraints.new("TRACK_TO")
track.target = target
track.track_axis = "TRACK_NEGATIVE_Z"
track.up_axis = "UP_Y"
scene.camera = cam

scene.render.engine = "BLENDER_WORKBENCH"
shading = scene.display.shading
shading.light = "STUDIO"
shading.color_type = "MATERIAL"
shading.show_cavity = True
shading.cavity_type = "BOTH"
shading.show_shadows = True
scene.render.resolution_x = 900
scene.render.resolution_y = 1200
scene.world = bpy.data.worlds.new("World")
scene.world.color = (0.12, 0.12, 0.13)


def render(path, loc):
    cam.location = loc
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    print("[GigaChad] render:", path)


try:
    render(os.path.join(OUT, f"{NAME}_preview.png"), (6.0, -12.5, 6.2))
    render(os.path.join(OUT, f"{NAME}_front.png"), (0, -14, 4.6))
except Exception as e:
    print("[GigaChad] no se pudo renderizar la vista previa:", e)

# ---------------------------------------------------------------- exportar
bpy.ops.object.select_all(action="DESELECT")
for m in meshes:
    m.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]
bpy.ops.export_scene.fbx(
    filepath=os.path.join(OUT, f"{NAME}.fbx"),
    use_selection=True,
    object_types={"MESH"},
    apply_scale_options="FBX_SCALE_ALL",
    mesh_smooth_type="FACE",
    add_leaf_bones=False,
    bake_anim=False,
)
print("[GigaChad] exportado FBX")
try:
    bpy.ops.wm.obj_export(filepath=os.path.join(OUT, f"{NAME}.obj"), export_selected_objects=True, export_materials=True)
    print("[GigaChad] exportado OBJ")
except Exception as e:
    print("[GigaChad] OBJ no exportado:", e)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, f"{NAME}.blend"))
print("[GigaChad] guardado .blend · LISTO")
