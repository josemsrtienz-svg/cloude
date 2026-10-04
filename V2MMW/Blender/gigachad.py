"""
V2MMW · GigaChad (personaje de prueba) — script para Blender 4.x / 5.x

Genera desde cero un GigaChad estilizado (diseño propio, low-poly, en blanco y negro como el meme):
  GigaChad.blend          archivo editable de Blender
  GigaChad.fbx            para importar en Roblox Studio (Importador 3D)
  GigaChad.obj            alternativa
  GigaChad_preview.png    vista previa 3/4
  GigaChad_front.png      vista previa de frente

Uso:  blender --background --python gigachad.py
      (o ábrelo en Blender → Scripting → Run Script)
Mide unas 7 unidades de alto (≈ 7 studs) con los pies en Z = 0 y mira hacia -Y.
Cada color es una malla aparte (Skin, Hair, Shorts, Eyes) para poder colorearla en Roblox.
"""

import math
import os

import bpy
from mathutils import Quaternion, Vector

OUT = os.path.dirname(os.path.abspath(__file__)) if "__file__" in dir() else os.getcwd()
NAME = "GigaChad"
MAX_TRIS_PER_MESH = 9000  # Roblox admite hasta 20 000 triángulos por MeshPart
# Con umbral 0.05 y rigidez 2, la superficie visible de un metaball queda a ~0.84·radio:
# K compensa para que los tamaños del script sean (casi) los tamaños reales en pantalla.
THRESHOLD = 0.05
K = 1.18

# ---------------------------------------------------------------- escena vacía
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene

VERTICAL = Quaternion((0, 1, 0), math.radians(90))  # cápsula con el eje X girado a vertical


def material(name, rgb, roughness=0.55):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = (*rgb, 1)
        bsdf.inputs["Roughness"].default_value = roughness
    mat.diffuse_color = (*rgb, 1)  # color que usa la vista Workbench
    return mat


def metaball(family, resolution=0.055):
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


def capsule(mb, co, half_len, r, stiff=2.0, rot=VERTICAL):
    el = mb.elements.new()
    el.type = "CAPSULE"
    el.co = co
    el.radius = r * K
    el.size_x = half_len
    el.stiffness = stiff
    el.rotation = rot
    return el


def tilt(axis, deg):
    """rotación vertical de la cápsula + inclinación extra"""
    return Quaternion(axis, math.radians(deg)) @ VERTICAL


# ---------------------------------------------------------------- PIEL (cuerpo + cabeza)
skin, skin_obj = metaball("Skin")
# piernas
for s in (-1, 1):
    capsule(skin, (s * 0.46, 0, 2.25), 0.55, 0.43)            # muslo
    capsule(skin, (s * 0.46, 0.02, 1.0), 0.5, 0.33)           # pantorrilla
    ellipsoid(skin, (s * 0.46, 0.05, 1.35), (0.3, 0.3, 0.42), stiff=1.5)  # gemelo
# cadera y abdomen
ellipsoid(skin, (0, 0, 3.15), (0.85, 0.5, 0.45))
ellipsoid(skin, (0, 0, 3.6), (0.72, 0.46, 0.55))
for row, z in enumerate((3.35, 3.7, 4.05)):
    for s in (-1, 1):
        ball(skin, (s * 0.17, -0.37, z), 0.13, stiff=1.1)  # abdominales
for s in (-1, 1):
    ellipsoid(skin, (s * 0.62, -0.2, 3.55), (0.22, 0.3, 0.5), stiff=1.4)  # oblicuos
# torso en V
ellipsoid(skin, (0, 0.08, 4.5), (1.12, 0.55, 0.72))
for s in (-1, 1):
    ellipsoid(skin, (s * 0.46, -0.2, 4.55), (0.56, 0.42, 0.42), stiff=2.2)  # pectorales
    ellipsoid(skin, (s * 0.85, 0.18, 4.1), (0.35, 0.4, 0.7), stiff=1.5)     # dorsales
# trapecios y cuello
ellipsoid(skin, (0, 0.08, 5.22), (0.62, 0.36, 0.32))
capsule(skin, (0, 0.05, 5.42), 0.18, 0.44)
# hombros y brazos
for s in (-1, 1):
    ball(skin, (s * 1.18, 0.02, 4.86), 0.54)                                   # deltoides
    capsule(skin, (s * 1.36, 0.02, 4.12), 0.42, 0.37, rot=tilt((0, 1, 0), s * 6))  # brazo
    ball(skin, (s * 1.34, -0.17, 4.18), 0.36, stiff=1.8)                       # bíceps
    ball(skin, (s * 1.42, 0.2, 4.2), 0.32, stiff=1.6)                          # tríceps
    capsule(skin, (s * 1.48, 0.0, 3.2), 0.42, 0.3, rot=tilt((0, 1, 0), s * 4))  # antebrazo
    ellipsoid(skin, (s * 1.52, 0.0, 2.55), (0.22, 0.2, 0.28))                   # mano
    ellipsoid(skin, (s * 0.46, -0.12, 0.13), (0.26, 0.46, 0.14))                # pie
# cabeza: mandíbula cuadrada enorme, pómulos, nariz, cejas
ellipsoid(skin, (0, -0.08, 5.85), (0.6, 0.5, 0.34), stiff=2.4)   # mandíbula
ellipsoid(skin, (0, -0.4, 5.72), (0.34, 0.2, 0.2), stiff=2.2)    # mentón
for s in (-1, 1):
    ellipsoid(skin, (s * 0.48, -0.12, 5.85), (0.16, 0.34, 0.24), stiff=2.0)  # ángulo de la mandíbula
    ball(skin, (s * 0.32, -0.36, 6.2), 0.14, stiff=1.2)                    # pómulos
    ball(skin, (s * 0.53, 0.05, 6.25), 0.12, stiff=1.2)                    # orejas
ellipsoid(skin, (0, 0.05, 6.4), (0.5, 0.54, 0.56))                # cráneo
ellipsoid(skin, (0, -0.55, 6.2), (0.07, 0.1, 0.14), stiff=1.4)    # nariz
ellipsoid(skin, (0, -0.47, 6.43), (0.44, 0.1, 0.08), stiff=1.6)   # arco de las cejas

# ---------------------------------------------------------------- PELO (peinado hacia atrás)
hair, hair_obj = metaball("Hair", resolution=0.05)
ellipsoid(hair, (0, 0.06, 6.85), (0.54, 0.6, 0.26))
ellipsoid(hair, (0, -0.3, 6.9), (0.46, 0.22, 0.2), rot=Quaternion((1, 0, 0), math.radians(-20)))  # tupé
ellipsoid(hair, (0, 0.45, 6.5), (0.48, 0.22, 0.36))  # nuca
for s in (-1, 1):
    ellipsoid(hair, (s * 0.48, 0.1, 6.55), (0.08, 0.38, 0.24))  # laterales cortos
for s in (-1, 1):
    ellipsoid(hair, (s * 0.2, -0.56, 6.47), (0.15, 0.04, 0.035), stiff=2.5, rot=Quaternion((0, 1, 0), math.radians(s * -10)))  # cejas

# ---------------------------------------------------------------- SHORTS
shorts, shorts_obj = metaball("Shorts")
ellipsoid(shorts, (0, 0, 2.98), (0.92, 0.58, 0.42))
for s in (-1, 1):
    capsule(shorts, (s * 0.47, 0, 2.45), 0.32, 0.49)

# ---------------------------------------------------------------- OJOS (mirada intensa)
eyes, eyes_obj = metaball("Eyes", resolution=0.02)
for s in (-1, 1):
    ellipsoid(eyes, (s * 0.19, -0.53, 6.31), (0.1, 0.03, 0.035), stiff=3)


# ---------------------------------------------------------------- metaballs → mallas
def to_mesh(obj, mat):
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.convert(target="MESH")
    mesh_obj = bpy.context.view_layer.objects.active
    mesh_obj.data.materials.clear()
    mesh_obj.data.materials.append(mat)
    tris = sum(len(p.vertices) - 2 for p in mesh_obj.data.polygons)
    if tris > MAX_TRIS_PER_MESH:
        dec = mesh_obj.modifiers.new("Decimate", "DECIMATE")
        dec.ratio = MAX_TRIS_PER_MESH / tris
        bpy.ops.object.modifier_apply(modifier=dec.name)
    for p in mesh_obj.data.polygons:
        p.use_smooth = True
    return mesh_obj


meshes = []
for obj, name, mat in (
    (skin_obj, "Skin", material("ChadSkin", (0.78, 0.77, 0.76))),
    (hair_obj, "Hair", material("ChadHair", (0.06, 0.06, 0.06), 0.4)),
    (shorts_obj, "Shorts", material("ChadShorts", (0.04, 0.04, 0.045), 0.8)),
    (eyes_obj, "Eyes", material("ChadEyes", (0.02, 0.02, 0.02), 0.2)),
):
    m = to_mesh(obj, mat)
    m.name = f"{NAME}_{name}"
    m.data.name = m.name
    meshes.append(m)

# limpiar los metaballs originales que hayan quedado
for o in list(scene.objects):
    if o.type == "META":
        bpy.data.objects.remove(o, do_unlink=True)

total = sum(sum(len(p.vertices) - 2 for p in m.data.polygons) for m in meshes)
print(f"[GigaChad] mallas: {[m.name for m in meshes]}  triángulos totales: {total}")

# ---------------------------------------------------------------- cámara, luces y render de vista previa
target = bpy.data.objects.new("Target", None)
scene.collection.objects.link(target)
target.location = (0, 0, 3.7)

cam_data = bpy.data.cameras.new("Camera")
cam_data.lens = 50
cam = bpy.data.objects.new("Camera", cam_data)
scene.collection.objects.link(cam)
track = cam.constraints.new("TRACK_TO")
track.target = target
track.track_axis = "TRACK_NEGATIVE_Z"
track.up_axis = "UP_Y"
scene.camera = cam

sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
sun.data.energy = 3
sun.rotation_euler = (math.radians(50), math.radians(10), math.radians(-30))
scene.collection.objects.link(sun)

scene.render.engine = "BLENDER_WORKBENCH"
shading = scene.display.shading
shading.light = "STUDIO"
shading.color_type = "MATERIAL"
shading.show_cavity = True
shading.cavity_type = "BOTH"
shading.show_shadows = True
scene.render.resolution_x = 900
scene.render.resolution_y = 1200
scene.render.film_transparent = False
try:
    scene.world = bpy.data.worlds.new("World")
    scene.world.color = (0.16, 0.12, 0.3)
except Exception:
    pass


def render(path, loc):
    cam.location = loc
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    print("[GigaChad] render:", path)


try:
    render(os.path.join(OUT, f"{NAME}_preview.png"), (6.5, -11.5, 6.0))
    render(os.path.join(OUT, f"{NAME}_front.png"), (0, -13, 4.6))
except Exception as e:  # sin GPU en modo background: el modelo se exporta igual
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
