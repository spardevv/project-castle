"""Prepara um .blend para retoque manual de textura (Texture Paint) de um personagem .glb.

Importa o modelo, salva a textura de cor base como .png ao lado do .blend (para o Blender gravar o
retoque nela) e deixa essa textura como alvo da pintura.

Uso: blender -b -P tools/blender/prepare_retouch.py -- --glb modelo.glb --out pasta/nome.blend
Depois do retoque: tools/blender/export_retouch.py exporta o .glb de volta.
"""
import argparse
import os
import sys

import bpy


def main():
    argv = sys.argv[sys.argv.index("--") + 1:]
    p = argparse.ArgumentParser()
    p.add_argument("--glb", required=True)
    p.add_argument("--out", required=True)
    a = p.parse_args(argv)
    out = os.path.abspath(a.out)
    folder = os.path.dirname(out)
    os.makedirs(folder, exist_ok=True)

    # Cena padrão (com os espaços de trabalho, inclusive "Texture Paint"), sem o cubo/câmera/luz.
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o)
    bpy.ops.import_scene.gltf(filepath=os.path.abspath(a.glb))
    obj = next(o for o in bpy.context.scene.objects if o.type == "MESH")
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)

    mat = obj.active_material
    nt = mat.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    tex = bsdf.inputs["Base Color"].links[0].from_node
    while tex.type != "TEX_IMAGE":
        tex = next(l.from_node for i in tex.inputs for l in i.links)
    img = tex.image
    png = os.path.join(folder, os.path.splitext(os.path.basename(out))[0] + "_cor.png")
    # Grava a textura embutida num .png e passa o material a usar esse arquivo (o retoque é salvo nele).
    img.save(filepath=png)
    painted = bpy.data.images.load(png, check_existing=False)
    painted.name = "cor_retoque"
    tex.image = painted
    img = painted
    # A textura de cor é o alvo do pincel.
    for n in nt.nodes:
        n.select = False
    tex.select = True
    nt.nodes.active = tex
    mat.paint_active_slot = next((i for i, s in enumerate(mat.texture_paint_images) if s == img), 0)
    obj.data.uv_layers.active_index = 0

    # Luz neutra para enxergar bem as manchas ao pintar.
    bpy.context.scene.view_settings.view_transform = "Standard"
    bpy.ops.wm.save_as_mainfile(filepath=out)
    print("[retouch] pronto:", out, "| textura:", png, img.size[:])


main()
