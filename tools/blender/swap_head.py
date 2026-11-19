"""Troca a cabeça de um personagem pela de um busto gerado em alta resolução.

O busto (cabeça + ombros, gerado a partir de um recorte do conceito do peito para cima) tem muito mais
detalhe no rosto. O script:
  1. Encaixa o busto no corpo: escala e posição iniciais pela altura do topo do cabelo e pela cabeça,
     depois refina por ICP (aproxima a superfície da cabeça do busto da cabeça do corpo).
  2. Corta o corpo acima do pescoço e o busto abaixo dele (com uma pequena sobreposição para não
     abrir buraco) e junta tudo num objeto só (cada parte mantém seu material).
  3. Exporta o .glb e, se pedido, renders de conferência.

Uso:
  blender -b --factory-startup -P tools/blender/swap_head.py -- --body corpo.glb --bust busto.glb \
      --out characters/models/nome.glb [--cut 0.16] [--preview pasta]
--cut: altura do corte medida do topo, em fração da altura do corpo (0.16 ≈ meio do pescoço).
"""
import argparse
import math
import os
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree


def log(*a):
    print("[head]", *a, flush=True)


def import_glb(path, name):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    new = [o for o in bpy.data.objects if o not in before and o.type == "MESH"]
    bpy.ops.object.select_all(action="DESELECT")
    for o in new:
        o.select_set(True)
    bpy.context.view_layer.objects.active = new[0]
    if len(new) > 1:
        bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    obj.name = name
    return obj


def coords(obj):
    co = np.empty(len(obj.data.vertices) * 3, dtype=np.float64)
    obj.data.vertices.foreach_get("co", co)
    return co.reshape(-1, 3)


def set_coords(obj, co):
    obj.data.vertices.foreach_set("co", co.astype(np.float32).ravel())
    obj.data.update()


def head_points(co, top, height, frac):
    return co[co[:, 2] > top - height * frac]


def icp_similarity(src, dst_bvh, iters=30):
    """Alinha pontos src à superfície dst (BVH) com rotação + escala uniforme + translação."""
    total = Matrix.Identity(4)
    pts = src.copy()
    for it in range(iters):
        pairs = []
        for p in pts[:: max(1, len(pts) // 3000)]:
            hit = dst_bvh.find_nearest(Vector(p))
            if hit[0] is not None:
                pairs.append((p, np.array(hit[0])))
        if len(pairs) < 20:
            break
        a = np.array([p[0] for p in pairs])
        b = np.array([p[1] for p in pairs])
        d = np.linalg.norm(a - b, axis=1)
        keep = d < np.percentile(d, 80)  # ignora os piores pares (cabelo que não bate)
        a, b = a[keep], b[keep]
        ca, cb = a.mean(axis=0), b.mean(axis=0)
        A, B = a - ca, b - cb
        U, S, Vt = np.linalg.svd(A.T @ B)
        R = (U @ Vt).T
        if np.linalg.det(R) < 0:
            Vt[-1] *= -1
            R = (U @ Vt).T
        scale = S.sum() / (A ** 2).sum()
        t = cb - scale * (R @ ca)
        pts = (scale * (R @ pts.T)).T + t
        M = Matrix.Identity(4)
        for i in range(3):
            for j in range(3):
                M[i][j] = scale * R[i, j]
            M[i][3] = t[i]
        total = M @ total
        if it > 3 and abs(scale - 1.0) < 1e-4 and np.linalg.norm(t) < 1e-5:
            break
    return total


def cut(obj, keep_above, z, overlap):
    """Remove a parte da malha abaixo (keep_above=True) ou acima de z (com sobreposição)."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    if keep_above:
        dead = [v for v in bm.verts if v.co.z < z - overlap]
    else:
        dead = [v for v in bm.verts if v.co.z > z + overlap]
    bmesh.ops.delete(bm, geom=dead, context="VERTS")
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.update()


# --- Cabelo x pele ---------------------------------------------------------------------------------

def base_image(obj):
    for slot in obj.material_slots:
        mat = slot.material
        if mat is None or not mat.use_nodes:
            continue
        bsdf = next((n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
        if bsdf is None or not bsdf.inputs["Base Color"].links:
            continue
        stack = [bsdf.inputs["Base Color"].links[0].from_node]
        while stack:
            n = stack.pop()
            if n.type == "TEX_IMAGE" and n.image is not None:
                return n.image
            stack += [l.from_node for i in n.inputs for l in i.links]
    return None


def image_array(img):
    w, h = img.size
    px = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(px)
    return px.reshape(h, w, 4)


def vertex_colors(obj):
    """Cor da textura (como armazenada) em cada vértice, pela média das UVs dos cantos."""
    me = obj.data
    img = base_image(obj)
    if img is None:
        return None
    px = image_array(img)
    h, w = px.shape[:2]
    loop_v = np.empty(len(me.loops), dtype=np.int32)
    me.loops.foreach_get("vertex_index", loop_v)
    luv = np.empty(len(me.loops) * 2, dtype=np.float32)
    me.uv_layers[0].data.foreach_get("uv", luv)
    luv = luv.reshape(-1, 2)
    vuv = np.zeros((len(me.vertices), 2), dtype=np.float32)
    cnt = np.zeros(len(me.vertices), dtype=np.float32)
    np.add.at(vuv, loop_v, luv)
    np.add.at(cnt, loop_v, 1.0)
    vuv /= np.maximum(cnt, 1.0)[:, None]
    xi = np.clip((np.mod(vuv[:, 0], 1.0) * w).astype(int), 0, w - 1)
    yi = np.clip((np.mod(vuv[:, 1], 1.0) * h).astype(int), 0, h - 1)
    return px[yi, xi, :3]


def delete_verts(obj, mask):
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.verts.ensure_lookup_table()
    dead = [bm.verts[i] for i in np.nonzero(mask)[0]]
    bmesh.ops.delete(bm, geom=dead, context="VERTS")
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.update()


def split_hair_and_skin(body, bust, z, ov, top, height, dark):
    """Pele: troca no pescoço (z). Cabelo: o do busto continua até onde ele vai (abaixo do pescoço) e
    o cabelo antigo do corpo que fica perto dele é removido. O tom de pele do busto é igualado ao corpo."""
    bco, uco = coords(body), coords(bust)
    bcol, ucol = vertex_colors(body), vertex_colors(bust)
    lum = lambda c: c[:, 0] * 0.3 + c[:, 1] * 0.59 + c[:, 2] * 0.11
    sat = lambda c: c.max(axis=1) - c.min(axis=1)
    # Cabelo = escuro E neutro. Pele em sombra é avermelhada e o biquíni esverdeado (têm cor).
    is_hair = lambda c: (lum(c) < dark) & (sat(c) < 0.06)

    def normals(obj):
        n = np.empty(len(obj.data.vertices) * 3, dtype=np.float32)
        obj.data.vertices.foreach_get("normal", n)
        return n.reshape(-1, 3)

    cx = (bco[:, 0].min() + bco[:, 0].max()) * 0.5
    # Frente do peito (onde fica o biquíni): nunca é cabelo.
    chest_front = lambda co, n: (-n[:, 1] > 0.3) & (np.abs(co[:, 0] - cx) < height * 0.12) & (co[:, 2] < z) & (co[:, 2] > top - height * 0.36)

    # Busto: pele só do pescoço para cima e dentro da largura do pescoço/cabeça (sem os ombros, que no
    # busto saem mais altos e largos); abaixo disso, só cabelo.
    unrm = normals(bust)
    head_zone = uco[:, 2] > top - height * 0.13  # cabeça inteira, com orelhas
    neck_zone = (uco[:, 2] > z - ov) & (np.abs(uco[:, 0] - cx) < height * 0.05)
    u_hair = is_hair(ucol) & ~chest_front(uco, unrm)
    keep_u = head_zone | neck_zone | u_hair
    delete_verts(bust, ~keep_u)
    uco = coords(bust)
    ucol = vertex_colors(bust)
    u_hair = is_hair(ucol)

    # Corpo: some tudo acima do pescoço, e o cabelo antigo (escuro) que está perto do cabelo novo.
    hair_faces = []
    hv = set(np.nonzero(u_hair)[0].tolist())
    for poly in bust.data.polygons:
        if all(v in hv for v in poly.vertices):
            hair_faces.append(tuple(poly.vertices))
    bvh = BVHTree.FromPolygons([tuple(v) for v in uco], hair_faces) if hair_faces else None
    near_new_hair = np.zeros(len(bco), dtype=bool)
    # Só na metade da frente: nas costas o cabelo do busto (gerado de uma vista de frente) é ralo, e
    # tirar o antigo ali abre falhas.
    shoulders = (bco[:, 2] < z) & (bco[:, 2] > z - height * 0.08)
    y_mid = np.median(bco[shoulders, 1]) if shoulders.any() else np.median(bco[:, 1])
    b_hair = is_hair(bcol) & ~chest_front(bco, normals(body)) & (bco[:, 1] < y_mid)
    if bvh is not None:
        lim = height * 0.04
        for i in np.nonzero(b_hair & (bco[:, 2] <= z + ov))[0]:
            hit = bvh.find_nearest(Vector(bco[i]), lim)
            if hit[0] is not None:
                near_new_hair[i] = True
    # Some do corpo: a cabeça/pescoço (acima do corte, dentro da largura da cabeça; os ombros ficam) e o
    # cabelo antigo perto do novo.
    body_head = (bco[:, 2] > z + ov) & ((np.abs(bco[:, 0] - cx) < height * 0.07) | (bco[:, 2] > top - height * 0.13) | is_hair(bcol))
    # Brilho do cabelo antigo (cinza: claro demais para "cabelo", mas sem cor de pele) perto dos ombros.
    old_shine = ((sat(bcol) < 0.06) & (lum(bcol) >= dark) & (lum(bcol) < 0.65)
                 & (bco[:, 2] > z - height * 0.1) & ~chest_front(bco, normals(body)))
    delete_verts(body, body_head | near_new_hair | old_shine)
    log(f"cabelo: {int(u_hair.sum())} vértices do busto mantidos abaixo/acima do pescoço; "
        f"{int(near_new_hair.sum())} vértices de cabelo antigo removidos do corpo")

    # Tom de pele: pescoço do busto (logo acima do corte) x pescoço do corpo (logo abaixo).
    bco, bcol = coords(body), vertex_colors(body)
    uco, ucol = coords(bust), vertex_colors(bust)
    b_s = (bco[:, 2] > z - height * 0.05) & (bco[:, 2] < z) & (lum(bcol) > 0.3)
    u_s = (uco[:, 2] > z) & (uco[:, 2] < z + height * 0.04) & (lum(ucol) > 0.3)
    img = base_image(bust)
    if b_s.sum() > 10 and u_s.sum() > 10 and img is not None:
        bm_ = np.median(bcol[b_s], axis=0)
        um_ = np.median(ucol[u_s], axis=0)
        gain = np.clip((bm_ ** 2.2) / np.maximum(um_ ** 2.2, 1e-4), 0.7, 1.5)
        px = image_array(img)
        px[..., :3] = np.clip((np.clip(px[..., :3], 0, 1) ** 2.2 * gain) ** (1 / 2.2), 0, 1)
        img.pixels.foreach_set(px.ravel())
        img.update()
        img.pack()
        log(f"tom de pele: corpo {np.round(bm_, 3)}, busto {np.round(um_, 3)}, ganho {np.round(gain, 3)}")
        seam_blend(body, bust, z, ov, height, cx, bm_, is_hair)


def seam_blend(body, bust, z, ov, height, cx, skin_srgb, is_hair):
    """Some com a linha na base do pescoço: a borda da pele do busto é encostada na superfície do corpo
    (sem degrau) e, dos dois lados da emenda, a cor vai para o mesmo tom de pele (sem contraste)."""
    zone = height * 0.03
    body_bvh = BVHTree.FromObject(body, bpy.context.evaluated_depsgraph_get())
    uco, ucol = coords(bust), vertex_colors(bust)
    near = (uco[:, 2] < z + zone) & (np.abs(uco[:, 0] - cx) < height * 0.08) & ~is_hair(ucol)
    moved = 0
    for i in np.nonzero(near)[0]:
        hit = body_bvh.find_nearest(Vector(uco[i]), height * 0.03)
        if hit[0] is None:
            continue
        w = np.clip(1.0 - (uco[i, 2] - (z - ov)) / (zone + ov), 0.0, 1.0)
        uco[i] = uco[i] * (1 - w) + np.array(hit[0]) * w
        moved += 1
    set_coords(bust, uco)
    # Pesos de cor: 1 na emenda, 0 a ~4 cm dela.
    blend = height * 0.045
    ucol = vertex_colors(bust)
    wu = np.where(~is_hair(ucol) & (np.abs(uco[:, 0] - cx) < height * 0.08),
                  np.clip(1.0 - (uco[:, 2] - (z - ov)) / blend, 0.0, 1.0), 0.0)
    bco, bcol = coords(body), vertex_colors(body)
    wb = np.where(~is_hair(bcol) & (np.abs(bco[:, 0] - cx) < height * 0.09),
                  np.clip(1.0 - (z + ov - bco[:, 2]) / blend, 0.0, 1.0) * (bco[:, 2] <= z + ov), 0.0)
    target = tuple(float(c) ** 2.2 for c in skin_srgb)
    bake_tint(bust, wu, target)
    bake_tint(body, wb, target)
    log(f"emenda do pescoço: {moved} vértices encostados no corpo; cor misturada em {int((wu > 0).sum())} + {int((wb > 0).sum())} vértices")


def bake_tint(obj, weights, color_lin):
    """Assa na textura de cor do objeto: cor = mistura(textura, color_lin, peso do vértice)."""
    img = base_image(obj)
    if img is None or not np.any(weights > 0):
        return
    me = obj.data
    attr = me.color_attributes.new(name="tint_w", type="FLOAT_COLOR", domain="POINT")
    cols = np.zeros((len(weights), 4), dtype=np.float32)
    cols[:, 0] = weights
    cols[:, 3] = 1.0
    attr.data.foreach_set("color", cols.ravel())
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 1
    try:
        prefs = bpy.context.preferences.addons["cycles"].preferences
        prefs.compute_device_type = "OPTIX"
        prefs.get_devices()
        for d in prefs.devices:
            d.use = d.type == "OPTIX"
        scene.cycles.device = "GPU"
    except Exception:
        pass
    w, h = img.size
    target = bpy.data.images.new(obj.name + "_cor", w, h, alpha=False)
    target.colorspace_settings.name = "sRGB"
    temp_nodes, restores = [], []
    for slot in obj.material_slots:
        mat = slot.material
        if mat is None:
            continue
        nt = mat.node_tree
        out = next(n for n in nt.nodes if n.type == "OUTPUT_MATERIAL")
        old = out.inputs["Surface"].links[0].from_socket if out.inputs["Surface"].links else None
        tex = next((n for n in nt.nodes if n.type == "TEX_IMAGE" and n.image == img), None)
        if tex is None:
            continue
        uvn = nt.nodes.new("ShaderNodeUVMap"); uvn.uv_map = me.uv_layers[0].name
        src = nt.nodes.new("ShaderNodeTexImage"); src.image = img
        nt.links.new(uvn.outputs["UV"], src.inputs["Vector"])
        vc = nt.nodes.new("ShaderNodeVertexColor"); vc.layer_name = "tint_w"
        sep = nt.nodes.new("ShaderNodeSeparateColor"); nt.links.new(vc.outputs["Color"], sep.inputs["Color"])
        rgb = nt.nodes.new("ShaderNodeRGB"); rgb.outputs[0].default_value = (*color_lin, 1.0)
        mix = nt.nodes.new("ShaderNodeMix"); mix.data_type = "RGBA"
        nt.links.new(sep.outputs[0], mix.inputs["Factor"])
        nt.links.new(src.outputs["Color"], mix.inputs["A"])
        nt.links.new(rgb.outputs[0], mix.inputs["B"])
        emit = nt.nodes.new("ShaderNodeEmission"); nt.links.new(mix.outputs["Result"], emit.inputs["Color"])
        nt.links.new(emit.outputs["Emission"], out.inputs["Surface"])
        tgt = nt.nodes.new("ShaderNodeTexImage"); tgt.image = target
        nt.links.new(uvn.outputs["UV"], tgt.inputs["Vector"])
        for n in nt.nodes:
            n.select = False
        tgt.select = True
        nt.nodes.active = tgt
        temp_nodes.append((nt, [uvn, src, vc, sep, rgb, mix, emit, tgt]))
        restores.append((nt, out, old, tex))
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.bake(type="EMIT", margin=16, use_clear=True)
    target.pack()
    for nt, out, old, tex in restores:
        if old is not None:
            nt.links.new(old, out.inputs["Surface"])
        tex.image = target
    for nt, nodes in temp_nodes:
        for n in nodes:
            nt.nodes.remove(n)
    me.color_attributes.remove(me.color_attributes["tint_w"])


def remove_small_islands(obj, min_frac):
    """Remove pedaços soltos pequenos (restos picotados do cabelo antigo, respingos)."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    # O glTF separa vértices nas costuras da textura; junta os coincidentes antes de achar os pedaços.
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bm.verts.ensure_lookup_table()
    seen = np.zeros(len(bm.verts), dtype=bool)
    small = []
    total = len(bm.verts)
    for v in bm.verts:
        if seen[v.index]:
            continue
        stack, island = [v], []
        seen[v.index] = True
        while stack:
            cur = stack.pop()
            island.append(cur)
            for e in cur.link_edges:
                o = e.other_vert(cur)
                if not seen[o.index]:
                    seen[o.index] = True
                    stack.append(o)
        if len(island) < total * min_frac:
            small.extend(island)
    if small:
        bmesh.ops.delete(bm, geom=small, context="VERTS")
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.update()
    log(f"limpeza final: {len(small)} vértices em pedaços soltos removidos")


def render_preview(objs, folder, tag):
    import importlib.util
    here = os.path.dirname(os.path.abspath(__file__))
    spec = importlib.util.spec_from_file_location("polish", os.path.join(here, "polish_character.py"))
    # Reaproveita o render de conferência do polimento sem rodar o main dele.
    src = open(os.path.join(here, "polish_character.py"), encoding="utf-8").read().replace("\nmain()\n", "\n")
    ns = {"__name__": "polish_lib"}
    exec(compile(src, "polish_character.py", "exec"), ns)
    ns["render_preview"](objs, folder, tag)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:]
    p = argparse.ArgumentParser()
    p.add_argument("--body", required=True)
    p.add_argument("--bust", required=True)
    p.add_argument("--out", required=True)
    p.add_argument("--cut", type=float, default=0.16)
    p.add_argument("--overlap", type=float, default=0.006, help="sobreposição no corte (fração da altura)")
    p.add_argument("--preview", default="")
    p.add_argument("--min-island", type=float, default=0.004, help="fração mínima de vértices de um pedaço solto")
    p.add_argument("--no-hair-split", action="store_true", help="corte reto em z, sem separar cabelo e pele")
    p.add_argument("--hair-dark", type=float, default=0.22, help="luminância abaixo da qual a textura conta como cabelo")
    a = p.parse_args(argv)

    bpy.ops.wm.read_factory_settings(use_empty=True)
    body = import_glb(a.body, "Corpo")
    bust = import_glb(a.bust, "Busto")
    bco, uco = coords(body), coords(bust)
    b_top, b_h = bco[:, 2].max(), bco[:, 2].max() - bco[:, 2].min()

    # Encaixe inicial: largura da cabeça (região do topo, 12% da altura do corpo) e topo do cabelo.
    def head_width(co, top, span):
        h = co[co[:, 2] > top - span]
        return np.percentile(h[:, 0], 95) - np.percentile(h[:, 0], 5), h.mean(axis=0)
    u_top = uco[:, 2].max()
    bw, bc = head_width(bco, b_top, b_h * 0.12)
    # No busto a cabeça é uma fração maior; procura a faixa do topo com a mesma proporção de altura.
    u_span = (uco[:, 2].max() - uco[:, 2].min()) * 0.12 * (b_h * 0.12) / max((uco[:, 2].max() - uco[:, 2].min()) * 0.12, 1e-6)
    # Escala aproximada: compara larguras da cabeça (topo do busto até ~ queixo).
    for _ in range(3):
        uw, uc = head_width(uco, u_top, u_span)
        k = bw / max(uw, 1e-6)
        u_span = b_h * 0.12 / k
    uco = (uco - np.array([uc[0], uc[1], u_top])) * k + np.array([bc[0], bc[1], b_top])
    set_coords(bust, uco)
    log(f"encaixe inicial: escala x{k:.3f}")

    # Refino por ICP: só a cabeça (sem o cabelo comprido de baixo), contra a cabeça do corpo.
    body_head = bmesh.new()
    body_head.from_mesh(body.data)
    dead = [v for v in body_head.verts if v.co.z < b_top - b_h * 0.15]
    bmesh.ops.delete(body_head, geom=dead, context="VERTS")
    bvh = BVHTree.FromBMesh(body_head)
    src = uco[uco[:, 2] > b_top - b_h * 0.15]
    M = icp_similarity(src, bvh)
    bust.data.transform(M)
    bust.data.update()
    sx = M.to_scale()[0]
    log(f"refino ICP: escala x{sx:.3f}, deslocamento {tuple(round(x, 4) for x in M.to_translation())}")

    # Corte e junção.
    z = b_top - b_h * a.cut
    ov = b_h * a.overlap
    if a.no_hair_split:
        cut(body, keep_above=False, z=z, overlap=ov)
        cut(bust, keep_above=True, z=z, overlap=ov)
    else:
        split_hair_and_skin(body, bust, z, ov, b_top, b_h, a.hair_dark)
    bpy.ops.object.select_all(action="DESELECT")
    body.select_set(True)
    bust.select_set(True)
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    obj.name = "Personagem"
    remove_small_islands(obj, a.min_island)
    for poly in obj.data.polygons:
        poly.use_smooth = True
    log(f"corte em {a.cut:.2f} da altura a partir do topo; {len(obj.data.vertices)} vértices no total")

    if a.preview:
        render_preview(obj, a.preview, "cabeca_nova")
    out = os.path.abspath(a.out)
    os.makedirs(os.path.dirname(out), exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", use_selection=True)
    log("exportado:", out)


main()
