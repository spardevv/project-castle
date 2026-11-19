"""Exporta o personagem de um .blend de retoque para .glb (textura retocada embutida).

Uso: blender -b arquivo.blend -P tools/blender/export_retouch.py -- --out characters/models/nome.glb
"""
import argparse
import os
import sys

import bpy


def main():
    argv = sys.argv[sys.argv.index("--") + 1:]
    p = argparse.ArgumentParser()
    p.add_argument("--out", required=True)
    a = p.parse_args(argv)
    # Recarrega as imagens do disco: o retoque salvo no .png entra mesmo se o .blend não foi salvo depois.
    for img in bpy.data.images:
        if img.filepath and not img.packed_file:
            img.reload()
    bpy.ops.object.select_all(action="DESELECT")
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    for o in meshes:
        o.select_set(True)
    out = os.path.abspath(a.out)
    os.makedirs(os.path.dirname(out), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", use_selection=True)
    print("[retouch] exportado:", out)


main()
