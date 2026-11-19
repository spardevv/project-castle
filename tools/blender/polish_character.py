"""Polimento de personagem gerado por IA (TRELLIS.2 / Hunyuan3D / Meshy) para o Project Castle.

O que faz:
  1. Limpa a malha: junta vértices duplicados, remove pedaços soltos pequenos, corrige normais.
  2. Projeta a imagem de conceito (vista de frente, alta resolução) sobre a frente do modelo e
     "assa" o resultado numa textura nova. Só onde a superfície está virada para a frente, é visível
     da frente (não escondida por cabelo/braço) e onde a imagem tem personagem (fundo é ignorado).
     Nas laterais e costas a textura original continua; a transição é suave.
     Isso conserta rosto, olhos e detalhes que o gerador 3D borra (ele vê o rosto com poucos pixels).
  3. Ajusta a escala (altura em metros), põe a origem entre os pés e exporta .glb.

Uso (sem abrir o Blender):
  blender -b --factory-startup -P tools/blender/polish_character.py -- \
      --glb modelo.glb --ref conceito_frente.png --out characters/models/nome.glb \
      [--height 1.8] [--tex 4096] [--full-body] [--fit] [--preview pasta]

Requisitos da imagem de conceito: a MESMA vista de frente que gerou o modelo (mesma pose),
corpo inteiro, fundo liso.
"""
import argparse
import math
import os
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree


def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    p = argparse.ArgumentParser()
    p.add_argument("--glb", required=True)
    p.add_argument("--ref", required=True, help="imagem de conceito de frente (mesma pose do modelo)")
    p.add_argument("--out", required=True)
    p.add_argument("--height", type=float, default=1.8, help="altura final em metros")
    p.add_argument("--tex", type=int, default=4096, help="resolução da textura assada")
    p.add_argument("--full-body", action="store_true",
                   help="projeta também no corpo (padrão: só cabeça e pescoço; o corpo gerado costuma estar bom e a projeção pode trazer o contorno do desenho)")
    p.add_argument("--min-part", type=float, default=0.002, help="fração mínima de vértices de um pedaço solto")
    p.add_argument("--preview", default="", help="pasta para renders de conferência (antes/depois)")
    p.add_argument("--face-smooth", type=int, default=12, help="passadas de suavização da frente do rosto (0 = desliga)")
    p.add_argument("--band", default="",
                   help="projeta só numa faixa horizontal: 'topo,base' em fração da altura a partir do topo (ex.: olhos de um busto '0.18,0.25'); desliga suavização, limpeza e ajuste de cor")
    p.add_argument("--band-width", type=float, default=0.1, help="meia-largura da faixa em fração da altura")
    p.add_argument("--keep-scale", action="store_true", help="não muda a escala nem a origem (ex.: busto que ainda vai ser encaixado)")
    p.add_argument("--fit", action="store_true", help="ajusta o encaixe pela silhueta (útil se o modelo saiu com proporções diferentes)")
    return p.parse_args(argv)


def log(*a):
    print("[polish]", *a, flush=True)


# --- Malha ------------------------------------------------------------------------------------

def import_mesh(path):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=path)
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    if not meshes:
        raise SystemExit("nenhuma malha no .glb")
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    if len(meshes) > 1:
        bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    # Tira o objeto de hierarquias do glTF e aplica transformações (local == mundo).
    bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return obj


def clean_mesh(obj, min_part):
    me = obj.data
    bm = bmesh.new()
    bm.from_mesh(me)
    before = len(bm.verts)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    # Pedaços soltos pequenos (respingos, pontinhos) somem.
    bm.verts.ensure_lookup_table()
    seen = set()
    islands = []
    for v in bm.verts:
        if v.index in seen:
            continue
        stack, island = [v], []
        seen.add(v.index)
        while stack:
            cur = stack.pop()
            island.append(cur)
            for e in cur.link_edges:
                o = e.other_vert(cur)
                if o.index not in seen:
                    seen.add(o.index)
                    stack.append(o)
        islands.append(island)
    total = len(bm.verts)
    small = [v for isl in islands if len(isl) < total * min_part for v in isl]
    if small:
        bmesh.ops.delete(bm, geom=small, context="VERTS")
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = True
    log(f"limpeza: {before} -> {len(me.vertices)} vértices; {len(islands)} pedaços, {len(islands) - 1 if small else len(islands)} mantidos")


def bounds(obj):
    co = np.empty(len(obj.data.vertices) * 3, dtype=np.float32)
    obj.data.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)
    return co.min(axis=0), co.max(axis=0), co


def smooth_face(obj, iterations):
    """Suaviza a frente do rosto (sem orelhas, cabelo e laterais). O gerador 3D esculpe sulcos onde a
    textura dele tinha manchas (olhos borrados); esses degraus fazem sombra e esticam a pintura projetada."""
    if iterations <= 0:
        return
    me = obj.data
    mn, mx, co = bounds(obj)
    height = mx[2] - mn[2]
    cx = (mn[0] + mx[0]) * 0.5
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.verts.ensure_lookup_table()
    bm.normal_update()
    top = mx[2]
    sel = [v for v in bm.verts
           if ((top - height * 0.135 < v.co.z < top - height * 0.045 and abs(v.co.x - cx) < height * 0.042)  # rosto (sem orelhas)
               or (top - height * 0.2 < v.co.z <= top - height * 0.135 and abs(v.co.x - cx) < height * 0.03))  # frente do pescoço
           and -v.normal.y > 0.2]                                     # virado para a frente
    # Bordas da região suavizam menos (sem degrau entre a parte lisa e o resto).
    for _ in range(iterations):
        bmesh.ops.smooth_vert(bm, verts=sel, factor=0.5, use_axis_x=True, use_axis_y=True, use_axis_z=True)
    bm.to_mesh(me)
    bm.free()
    me.update()
    log(f"rosto suavizado: {len(sel)} vértices, {iterations} passadas")


# --- Imagem de referência ------------------------------------------------------------------------

def load_reference(path):
    img = bpy.data.images.load(path)
    w, h = img.size
    px = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(px)
    px = px.reshape(h, w, 4)  # linhas de baixo para cima
    # Fundo = cor média dos cantos; personagem = o que difere dele.
    corners = np.concatenate([px[:20, :20, :3].reshape(-1, 3), px[:20, -20:, :3].reshape(-1, 3),
                              px[-20:, :20, :3].reshape(-1, 3), px[-20:, -20:, :3].reshape(-1, 3)])
    bg = corners.mean(axis=0)
    diff = np.abs(px[:, :, :3] - bg).max(axis=2)
    mask = diff > 0.06
    # Linhas/colunas com uma fração real de personagem (ignora ruído e pixels soltos do fundo).
    rows = np.where(mask.mean(axis=1) > 0.01)[0]
    cols = np.where(mask.mean(axis=0) > 0.01)[0]
    bbox = (cols.min(), cols.max(), rows.min(), rows.max())  # x0, x1, y0 (baixo), y1 (topo)
    # Encolhe a máscara (tira o contorno desenhado e evita pegar fundo nas bordas) e suaviza.
    m = mask.astype(np.float32)
    erode = max(3, int(min(w, h) * 0.009))
    for _ in range(erode):
        m = np.minimum.reduce([m, np.roll(m, 1, 0), np.roll(m, -1, 0), np.roll(m, 1, 1), np.roll(m, -1, 1)])
    for _ in range(3):
        m = (m + np.roll(m, 1, 0) + np.roll(m, -1, 0) + np.roll(m, 1, 1) + np.roll(m, -1, 1)) / 5.0
    px[:, :, 3] = m
    img.pixels.foreach_set(px.ravel())
    img.update()
    img.colorspace_settings.name = "sRGB"
    img.alpha_mode = "STRAIGHT"
    log(f"referência {w}x{h}, personagem em x[{bbox[0]}..{bbox[1]}] y[{bbox[2]}..{bbox[3]}], fundo={np.round(bg, 3)}")
    return img, bbox, mask


def fit_alignment(co, mn, mx, img_size, bbox, mask):
    """Ajusta escala e deslocamento da projeção comparando a silhueta do modelo (vista de frente)
    com a do personagem na imagem. Começa pelo encaixe das caixas e refina por busca em grade."""
    w, h = img_size
    x0, x1, y0, y1 = bbox
    f = 6  # trabalha em 1/6 da resolução
    small = mask[::f, ::f]
    sh, sw = small.shape
    base_s = (y1 - y0) / max(mx[2] - mn[2], 1e-6)
    base_cx = (x0 + x1) * 0.5
    mesh_cx = (mn[0] + mx[0]) * 0.5
    pts = co[:: max(1, len(co) // 40000)]

    def silhouette(s_mul, dx, dy):
        s = base_s * s_mul
        u = (base_cx + dx + (pts[:, 0] - mesh_cx) * s) / f
        v = (y0 + dy + (pts[:, 2] - mn[2]) * s) / f
        sil = np.zeros((sh, sw), dtype=bool)
        ui = np.clip(u.astype(int), 0, sw - 1)
        vi = np.clip(v.astype(int), 0, sh - 1)
        sil[vi, ui] = True
        for _ in range(2):  # fecha os buracos entre pontos
            sil = sil | np.roll(sil, 1, 0) | np.roll(sil, -1, 0) | np.roll(sil, 1, 1) | np.roll(sil, -1, 1)
        return sil

    def score(params):
        sil = silhouette(*params)
        inter = np.logical_and(sil, small).sum()
        union = np.logical_or(sil, small).sum()
        return inter / max(union, 1)

    best = (1.0, 0.0, 0.0)
    best_score = score(best)
    for step_s, step_px in ((0.02, 12.0), (0.008, 4.0), (0.003, 1.5)):
        improved = True
        while improved:
            improved = False
            for ds in (-step_s, 0.0, step_s):
                for ddx in (-step_px, 0.0, step_px):
                    for ddy in (-step_px, 0.0, step_px):
                        cand = (best[0] + ds, best[1] + ddx, best[2] + ddy)
                        sc = score(cand)
                        if sc > best_score + 1e-5:
                            best, best_score, improved = cand, sc, True
    log(f"encaixe: escala x{best[0]:.3f}, desloc. ({best[1]:.1f}, {best[2]:.1f}) px, IoU silhueta {best_score:.3f}")
    return base_s * best[0], base_cx + best[1], y0 + best[2]


# --- Projeção ----------------------------------------------------------------------------------------

def make_projection(obj, ref_img, bbox, mask, front_only_head, fit=False, band=None, band_width=0.1):
    """UV "proj" (vista de frente ortográfica alinhada à imagem) e peso por vértice "proj_w"."""
    me = obj.data
    mn, mx, co = bounds(obj)
    w, h = ref_img.size
    x0, x1, y0, y1 = bbox
    if fit:
        s, img_cx, img_y0 = fit_alignment(co, mn, mx, (w, h), bbox, mask)
    else:
        # Encaixe pelas extremidades: altura total (topo do cabelo aos pés) e centro horizontal.
        s = (y1 - y0) / max(mx[2] - mn[2], 1e-6)
        img_cx, img_y0 = (x0 + x1) * 0.5, y0
    mesh_cx = (mn[0] + mx[0]) * 0.5
    u = (img_cx + (co[:, 0] - mesh_cx) * s) / w
    v = (img_y0 + (co[:, 2] - mn[2]) * s) / h

    uv = me.uv_layers.new(name="proj")
    loop_v = np.empty(len(me.loops), dtype=np.int32)
    me.loops.foreach_get("vertex_index", loop_v)
    uvs = np.stack([u[loop_v], v[loop_v]], axis=1).astype(np.float32)
    uv.data.foreach_set("uv", uvs.ravel())

    # Peso: virado para a frente (-Y no Blender) e visível da frente (raio vindo de -Y).
    nrm = np.empty(len(me.vertices) * 3, dtype=np.float32)
    me.vertices.foreach_get("normal", nrm)
    nrm = nrm.reshape(-1, 3)
    # Corpo: só superfícies bem de frente (as bordas ficam com a textura original, sem o contorno
    # desenhado). Cabeça: tudo que olha para a frente, inclusive as cavidades dos olhos.
    height = mx[2] - mn[2]
    head = np.clip((co[:, 2] - (mx[2] - height * 0.16)) / (height * 0.02), 0.0, 1.0)  # cabeça
    body_f = np.clip((-nrm[:, 1] - 0.45) / 0.35, 0.0, 1.0)
    # Na cabeça vale tudo que é visível de frente, até superfícies quase de lado (cavidade dos olhos,
    # abaixo do nariz e da boca): senão a mancha do olho antigo aparece por baixo do olho novo.
    head_f = np.clip((-nrm[:, 1] + 0.45) / 0.3, 0.0, 1.0)
    facing = body_f * (1.0 - head) + head_f * head
    facing = facing * facing * (3 - 2 * facing)
    bvh = BVHTree.FromObject(obj, bpy.context.evaluated_depsgraph_get())
    # Visível de frente = o raio vindo da frente bate (quase) no próprio vértice. Na cabeça a tolerância
    # é maior: o gerador esculpe sulcos fundos em volta dos olhos, e o fundo deles fica milímetros atrás
    # da pálpebra; sem isso a mancha do olho antigo sobrevive ali.
    eps_body = (mx[2] - mn[2]) * 0.006
    eps_head = (mx[2] - mn[2]) * 0.03
    start_y = mn[1] - 1.0
    vis = np.zeros(len(co), dtype=np.float32)
    for i, p in enumerate(co):
        if facing[i] <= 0.0:
            continue
        hit, _n, _idx, dist = bvh.ray_cast(Vector((p[0], start_y, p[2])), Vector((0.0, 1.0, 0.0)))
        eps = eps_body + (eps_head - eps_body) * head[i]
        if hit is not None and (hit - Vector(p)).length < eps:
            vis[i] = 1.0
    if band is not None:
        # Só a faixa pedida (ex.: olhos), com a regra permissiva da cabeça e borda suave.
        z_top, z_bot = mx[2] - height * band[0], mx[2] - height * band[1]
        # Encaixe pelos olhos: centro de cada olho (branco do olho) na textura gerada e no conceito.
        fix = eye_alignment(obj, ref_img, s, img_cx, img_y0, mesh_cx, mn[2],
                            z_top + height * 0.02, z_bot - height * 0.02, height * band_width)
        if fix is not None:
            k, (mcx, mcy), (rcx, rcy) = fix
            u = (rcx + k * (u * w - mcx)) / w
            v = (rcy + k * (v * h - mcy)) / h
            uvs = np.stack([u[loop_v], v[loop_v]], axis=1).astype(np.float32)
            uv.data.foreach_set("uv", uvs.ravel())
        soft = height * 0.008
        in_band = (np.clip((z_top - co[:, 2]) / soft, 0, 1) * np.clip((co[:, 2] - z_bot) / soft, 0, 1)
                   * np.clip((height * band_width - np.abs(co[:, 0] - mesh_cx)) / soft, 0, 1))
        fw = np.clip((-nrm[:, 1] + 0.45) / 0.3, 0.0, 1.0)
        vis_band = np.zeros(len(co), dtype=np.float32)
        eps = height * 0.03
        for i in np.nonzero(in_band > 0)[0]:
            p = co[i]
            hit, _n, _idx, _d = bvh.ray_cast(Vector((p[0], start_y, p[2])), Vector((0.0, 1.0, 0.0)))
            if hit is not None and (hit - Vector(p)).length < eps:
                vis_band[i] = 1.0
        weight = in_band * fw * vis_band
        attr = me.color_attributes.new(name="proj_w", type="FLOAT_COLOR", domain="POINT")
        cols = np.zeros((len(co), 4), dtype=np.float32)
        cols[:, 0] = weight
        cols[:, 3] = 1.0
        attr.data.foreach_set("color", cols.ravel())
        log(f"projeção na faixa {band}: {int((weight > 0.5).sum())} vértices")
        return
    weight = facing * vis
    # Corpo: onde a imagem projetada discorda muito da textura gerada (ex.: o traço de contorno do
    # desenho caindo sobre a pele porque o braço ficou um pouco mais aberto), mantém a original.
    # Na cabeça não: lá a discordância (olhos borrados x olhos do conceito) é o que se quer corrigir.
    orig_img = base_color_image(obj)
    if orig_img is not None:
        base_uv = next(l for l in me.uv_layers if l.name != "proj")
        luv = np.empty(len(me.loops) * 2, dtype=np.float32)
        base_uv.data.foreach_get("uv", luv)
        luv = luv.reshape(-1, 2)
        vuv = np.zeros((len(co), 2), dtype=np.float32)
        cnt = np.zeros(len(co), dtype=np.float32)
        np.add.at(vuv, loop_v, luv)
        np.add.at(cnt, loop_v, 1.0)
        vuv /= np.maximum(cnt, 1.0)[:, None]
        orig_rgb = sample_image(orig_img, vuv[:, 0], vuv[:, 1])
        ref_rgb = sample_image(ref_img, u, v)
        diff = np.abs(orig_rgb - ref_rgb).mean(axis=1)
        agree = np.clip(1.0 - (diff - 0.07) / 0.12, 0.0, 1.0)
        weight = weight * (head + (1.0 - head) * agree)
    if front_only_head:
        head_start = mx[2] - height * 0.19  # cabeça e começo do pescoço (abaixo disso pega ombros e fundo)
        weight *= np.clip((co[:, 2] - head_start) / (height * 0.03), 0.0, 1.0)
    # Cor: a pintura do conceito tem outro tom de pele (mais escuro/esverdeado) que o corpo gerado.
    # Ajusta a imagem projetada para o tom da pele do corpo (ganho por canal, medido em linear).
    # Limpeza: na frente da cabeça e do pescoço a textura antiga (olhos borrados, riscos) é trocada
    # por pele lisa no tom do corpo antes da mistura; assim nada antigo aparece "por baixo" do rosto novo.
    clean = np.zeros(len(co), dtype=np.float32)
    if orig_img is not None:
        lum = lambda c: c[:, 0] * 0.3 + c[:, 1] * 0.59 + c[:, 2] * 0.11
        top = mx[2]
        fwd = -nrm[:, 1]
        chest = (co[:, 2] > top - height * 0.32) & (co[:, 2] < top - height * 0.22) & (fwd > 0.3) & (lum(orig_rgb) > 0.3)
        face_skin = (head > 0.5) & (weight > 0.7) & (lum(ref_rgb) > 0.35) & (lum(ref_rgb) < 0.85)
        if chest.sum() > 20 and face_skin.sum() > 20:
            body = np.median(orig_rgb[chest], axis=0)
            face = np.median(ref_rgb[face_skin], axis=0)
            COLOR_FIX["gain"] = tuple(float(x) for x in np.clip((body ** 2.2) / np.maximum(face ** 2.2, 1e-4), 0.3, 3.0))
            COLOR_FIX["skin"] = tuple(float(x) for x in body ** 2.2)
            log(f"tom de pele: corpo {np.round(body, 3)}, rosto do conceito {np.round(face, 3)}, ganho {np.round(COLOR_FIX['gain'], 3)}")
        region = (np.clip((co[:, 2] - (top - height * 0.26)) / (height * 0.02), 0.0, 1.0)
                  * np.clip((fwd + 0.2) / 0.3, 0.0, 1.0)
                  * np.clip((height * 0.06 - np.abs(co[:, 0] - mesh_cx)) / (height * 0.01), 0.0, 1.0))  # sem as mechas laterais
        face_core = (head > 0.5) & (np.abs(co[:, 0] - mesh_cx) < height * 0.045) & (fwd > 0.1)
        skinlike = np.where(face_core, 1.0, np.clip((lum(orig_rgb) - 0.22) / 0.1, 0.0, 1.0))  # cabelo (escuro) fica
        clean = region * skinlike
    attr = me.color_attributes.new(name="proj_w", type="FLOAT_COLOR", domain="POINT")
    cols = np.zeros((len(co), 4), dtype=np.float32)
    cols[:, 0] = weight
    cols[:, 1] = clean
    cols[:, 3] = 1.0
    attr.data.foreach_set("color", cols.ravel())
    log(f"projeção: {int((weight > 0.5).sum())}/{len(co)} vértices recebem a imagem de frente")


def render_front_albedo(obj, s, img_cx, img_y0, mesh_cx, mn_z, w, h):
    """Cor da textura do modelo, de frente e sem luz, no MESMO enquadramento em pixels do conceito.
    Devolve (h, w, 4), linhas de baixo para cima (como Image.pixels)."""
    scene = bpy.context.scene
    old_engine = scene.render.engine
    scene.render.engine = "BLENDER_WORKBENCH"
    sh = scene.display.shading
    sh.light = "FLAT"
    sh.color_type = "TEXTURE"
    scene.view_settings.view_transform = "Standard"
    scene.render.film_transparent = True
    scene.render.resolution_x, scene.render.resolution_y = w, h
    scene.render.resolution_percentage = 100
    cam = bpy.data.objects.new("eye_cam", bpy.data.cameras.new("eye_cam"))
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = max(w, h) / s
    cam.location = (mesh_cx + (w * 0.5 - img_cx) / s, -10.0, mn_z + (h * 0.5 - img_y0) / s)
    cam.rotation_euler = (math.radians(90), 0, 0)
    scene.collection.objects.link(cam)
    old_cam = scene.camera
    scene.camera = cam
    import tempfile
    path = os.path.join(tempfile.gettempdir(), "polish_eye_front.png")
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    img = bpy.data.images.load(path, check_existing=False)
    px = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(px)
    bpy.data.images.remove(img)
    scene.camera = old_cam
    bpy.data.objects.remove(cam)
    scene.render.engine = old_engine
    scene.render.film_transparent = False
    return px.reshape(h, w, 4)


def _eye_centers(rgb, alpha=None):
    """Centros (x, y) dos dois olhos numa janela: pixels mais claros e pouco saturados, separados
    pela mediana horizontal."""
    lum = rgb.mean(axis=2)
    sat = rgb.max(axis=2) - rgb.min(axis=2)
    ok = sat < 0.25
    if alpha is not None:
        ok &= alpha > 0.5
    if ok.sum() < 20:
        return None
    thr = np.percentile(lum[ok], 97)
    ys, xs = np.nonzero(ok & (lum >= thr))
    if len(xs) < 10:
        return None
    mid = np.median(xs)
    l, r = xs < mid, xs >= mid
    if l.sum() < 3 or r.sum() < 3:
        return None
    return (np.array([np.median(xs[l]), np.median(ys[l])]), np.array([np.median(xs[r]), np.median(ys[r])]))


def eye_alignment(obj, ref_img, s, img_cx, img_y0, mesh_cx, mn_z, z_top, z_bot, half_w):
    """Encaixe pelos olhos: compara o centro dos dois olhos no render da textura gerada e no conceito
    (mesma janela). Devolve (escala, centro_malha, centro_conceito) em pixels ou None."""
    w, h = ref_img.size
    ren = render_front_albedo(obj, s, img_cx, img_y0, mesh_cx, mn_z, w, h)
    ref = np.empty(w * h * 4, dtype=np.float32)
    ref_img.pixels.foreach_get(ref)
    ref = ref.reshape(h, w, 4)
    y0 = int(max(img_y0 + (z_bot - mn_z) * s, 0))
    y1 = int(min(img_y0 + (z_top - mn_z) * s, h))
    x0 = int(max(img_cx - half_w * s, 0))
    x1 = int(min(img_cx + half_w * s, w))
    m = _eye_centers(ren[y0:y1, x0:x1, :3], ren[y0:y1, x0:x1, 3])
    r = _eye_centers(ref[y0:y1, x0:x1, :3])
    if m is None or r is None:
        log("encaixe pelos olhos: olhos não encontrados", "(malha)" if m is None else "(conceito)")
        return None
    off = np.array([x0, y0])
    m_l, m_r = m[0] + off, m[1] + off
    r_l, r_r = r[0] + off, r[1] + off
    k = np.linalg.norm(r_r - r_l) / max(np.linalg.norm(m_r - m_l), 1e-6)
    log(f"encaixe pelos olhos: malha {np.round(m_l)} / {np.round(m_r)}, conceito {np.round(r_l)} / {np.round(r_r)} px, escala x{k:.3f}")
    if not 0.75 < k < 1.33:
        log("encaixe pelos olhos: escala fora do esperado, ignorado")
        return None
    return k, tuple((m_l + m_r) / 2), tuple((r_l + r_r) / 2)


COLOR_FIX = {"gain": (1.0, 1.0, 1.0), "skin": None}


def base_color_image(obj):
    for slot in obj.material_slots:
        if slot.material is not None:
            _b, tex = find_base_color_node(slot.material)
            if tex is not None and tex.image is not None:
                return tex.image
    return None


def sample_image(img, u, v):
    """Cor RGB (linear como armazenada) nas coordenadas UV, vizinho mais próximo."""
    w, h = img.size
    px = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(px)
    px = px.reshape(h, w, 4)
    xi = np.clip((np.mod(u, 1.0) * w).astype(int), 0, w - 1)
    yi = np.clip((np.mod(v, 1.0) * h).astype(int), 0, h - 1)
    return px[yi, xi, :3]


def find_base_color_node(mat):
    nt = mat.node_tree
    bsdf = next((n for n in nt.nodes if n.type == "BSDF_PRINCIPLED"), None)
    if bsdf is None:
        return None, None
    inp = bsdf.inputs["Base Color"]
    if not inp.links:
        return bsdf, None
    node = inp.links[0].from_node
    # Pode haver nós no meio (ex.: multiplicar cor de vértice); procura a textura para trás.
    stack, seen = [node], set()
    while stack:
        n = stack.pop()
        if n.name in seen:
            continue
        seen.add(n.name)
        if n.type == "TEX_IMAGE":
            return bsdf, n
        for i in n.inputs:
            for l in i.links:
                stack.append(l.from_node)
    return bsdf, None


def bake_projection(obj, ref_img, tex_size):
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    try:
        prefs = bpy.context.preferences.addons["cycles"].preferences
        for kind in ("OPTIX", "CUDA"):
            try:
                prefs.compute_device_type = kind
                prefs.get_devices()
                if any(d.type == kind for d in prefs.devices):
                    for d in prefs.devices:
                        d.use = d.type == kind
                    scene.cycles.device = "GPU"
                    log("bake na GPU:", kind)
                    break
            except Exception:
                continue
    except Exception:
        pass
    scene.cycles.samples = 1
    me = obj.data
    base_uv = next(l.name for l in me.uv_layers if l.name != "proj")
    target = bpy.data.images.new("baked_basecolor", tex_size, tex_size, alpha=False)
    target.colorspace_settings.name = "sRGB"
    restores = []
    for slot in obj.material_slots:
        mat = slot.material
        if mat is None:
            continue
        nt = mat.node_tree
        bsdf, tex = find_base_color_node(mat)
        out = next(n for n in nt.nodes if n.type == "OUTPUT_MATERIAL")
        old_link_src = out.inputs["Surface"].links[0].from_socket if out.inputs["Surface"].links else None
        uv_base = nt.nodes.new("ShaderNodeUVMap"); uv_base.uv_map = base_uv
        uv_proj = nt.nodes.new("ShaderNodeUVMap"); uv_proj.uv_map = "proj"
        ref = nt.nodes.new("ShaderNodeTexImage"); ref.image = ref_img; ref.extension = "CLIP"; ref.interpolation = "Cubic"
        nt.links.new(uv_proj.outputs["UV"], ref.inputs["Vector"])
        wattr = nt.nodes.new("ShaderNodeVertexColor"); wattr.layer_name = "proj_w"
        sep = nt.nodes.new("ShaderNodeSeparateColor")
        nt.links.new(wattr.outputs["Color"], sep.inputs["Color"])
        mul = nt.nodes.new("ShaderNodeMath"); mul.operation = "MULTIPLY"
        nt.links.new(sep.outputs[0], mul.inputs[0])
        nt.links.new(ref.outputs["Alpha"], mul.inputs[1])
        mix = nt.nodes.new("ShaderNodeMix"); mix.data_type = "RGBA"
        nt.links.new(mul.outputs[0], mix.inputs["Factor"])
        base_out = None
        if tex is not None:
            orig = nt.nodes.new("ShaderNodeTexImage"); orig.image = tex.image
            nt.links.new(uv_base.outputs["UV"], orig.inputs["Vector"])
            base_out = orig.outputs["Color"]
        else:
            mix.inputs["A"].default_value = bsdf.inputs["Base Color"].default_value if bsdf else (0.8, 0.8, 0.8, 1)
        if base_out is not None and COLOR_FIX["skin"] is not None:
            # Pele lisa no tom do corpo onde a textura antiga é limpa (canal G de proj_w).
            skin = nt.nodes.new("ShaderNodeRGB"); skin.outputs[0].default_value = (*COLOR_FIX["skin"], 1.0)
            cleanmix = nt.nodes.new("ShaderNodeMix"); cleanmix.data_type = "RGBA"
            nt.links.new(sep.outputs[1], cleanmix.inputs["Factor"])
            nt.links.new(base_out, cleanmix.inputs["A"])
            nt.links.new(skin.outputs[0], cleanmix.inputs["B"])
            base_out = cleanmix.outputs["Result"]
        if base_out is not None:
            nt.links.new(base_out, mix.inputs["A"])
        # Referência no tom de pele do corpo.
        gain = nt.nodes.new("ShaderNodeRGB"); gain.outputs[0].default_value = (*COLOR_FIX["gain"], 1.0)
        mul_c = nt.nodes.new("ShaderNodeMix"); mul_c.data_type = "RGBA"; mul_c.blend_type = "MULTIPLY"
        mul_c.inputs["Factor"].default_value = 1.0
        nt.links.new(ref.outputs["Color"], mul_c.inputs["A"])
        nt.links.new(gain.outputs[0], mul_c.inputs["B"])
        nt.links.new(mul_c.outputs["Result"], mix.inputs["B"])
        emit = nt.nodes.new("ShaderNodeEmission")
        nt.links.new(mix.outputs["Result"], emit.inputs["Color"])
        nt.links.new(emit.outputs["Emission"], out.inputs["Surface"])
        tgt = nt.nodes.new("ShaderNodeTexImage"); tgt.image = target
        nt.links.new(uv_base.outputs["UV"], tgt.inputs["Vector"])
        for n in nt.nodes:
            n.select = False
        tgt.select = True
        nt.nodes.active = tgt
        restores.append((mat, out, old_link_src, tex, bsdf))
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    me.uv_layers.active = me.uv_layers[base_uv]
    log(f"assando textura {tex_size}x{tex_size}...")
    bpy.ops.object.bake(type="EMIT", margin=16, use_clear=True)
    target.pack()
    # Volta o material: BSDF original, cor base = textura assada.
    for mat, out, old_src, tex, bsdf in restores:
        nt = mat.node_tree
        if old_src is not None:
            nt.links.new(old_src, out.inputs["Surface"])
        if tex is not None:
            tex.image = target
        elif bsdf is not None:
            t = nt.nodes.new("ShaderNodeTexImage"); t.image = target
            nt.links.new(t.outputs["Color"], bsdf.inputs["Base Color"])
        for n in list(nt.nodes):
            if n.type in ("UVMAP", "VERTEX_COLOR", "SEPARATE_COLOR", "MATH", "MIX", "EMISSION", "RGB") or (n.type == "TEX_IMAGE" and n.image in (ref_img,) ) or (n.type == "TEX_IMAGE" and n.image == target and n != tex and not n.outputs["Color"].links):
                nt.nodes.remove(n)
    me.uv_layers.remove(me.uv_layers["proj"])
    me.color_attributes.remove(me.color_attributes["proj_w"])
    return target


# --- Escala, exportação e prévia -------------------------------------------------------------------

def normalize_scale(obj, height):
    mn, mx, _ = bounds(obj)
    k = height / max(mx[2] - mn[2], 1e-6)
    obj.scale = (k, k, k)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    mn, mx, _ = bounds(obj)
    obj.location = (-(mn[0] + mx[0]) * 0.5, -(mn[1] + mx[1]) * 0.5, -mn[2])
    bpy.ops.object.transform_apply(location=True, rotation=False, scale=False)
    log(f"altura final {height:.2f} m (escala x{k:.3f})")


def render_preview(obj, folder, tag):
    os.makedirs(folder, exist_ok=True)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items] else "BLENDER_EEVEE"
    if scene.world is None:
        scene.world = bpy.data.worlds.new("w")
        scene.world.use_nodes = True
        bg = scene.world.node_tree.nodes["Background"]
        bg.inputs[0].default_value = (0.32, 0.33, 0.36, 1)
        sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
        sun.data.energy = 3.0
        sun.rotation_euler = (math.radians(50), 0, math.radians(30))
        scene.collection.objects.link(sun)
        cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
        cam.data.type = "ORTHO"
        scene.collection.objects.link(cam)
        scene.camera = cam
    cam = scene.camera
    mn, mx, _ = bounds(obj)
    c = Vector(((mn[0] + mx[0]) / 2, (mn[1] + mx[1]) / 2, (mn[2] + mx[2]) / 2))
    hgt = mx[2] - mn[2]
    shots = {
        "frente": (Vector((0, -1, 0)), c, hgt * 1.1, 900, 1200),
        "tres_quartos": (Vector((0.7, -0.7, 0)).normalized(), c, hgt * 1.1, 900, 1200),
        "costas": (Vector((0, 1, 0)), c, hgt * 1.1, 900, 1200),
        "rosto": (Vector((0, -1, 0)), Vector((c.x, c.y, mx[2] - hgt * 0.09)), hgt * 0.2, 900, 900),
    }
    for name, (d, target, ortho, rx, ry) in shots.items():
        cam.location = target + d * (hgt * 3)
        cam.rotation_euler = (math.radians(90), 0, math.atan2(d.x, -d.y))
        cam.data.ortho_scale = ortho
        scene.render.resolution_x, scene.render.resolution_y = rx, ry
        scene.render.filepath = os.path.join(folder, f"{tag}_{name}.png")
        bpy.ops.render.render(write_still=True)


def main():
    a = parse_args()
    obj = import_mesh(a.glb)
    if a.preview:
        render_preview(obj, a.preview, "antes")
    band = tuple(float(x) for x in a.band.split(",")) if a.band else None
    clean_mesh(obj, a.min_part)
    if band is None:
        smooth_face(obj, a.face_smooth)
    ref_img, bbox, mask = load_reference(a.ref)
    make_projection(obj, ref_img, bbox, mask, not a.full_body, a.fit, band, a.band_width)
    bake_projection(obj, ref_img, a.tex)
    if not a.keep_scale:
        normalize_scale(obj, a.height)
    if a.preview:
        render_preview(obj, a.preview, "depois")
    os.makedirs(os.path.dirname(os.path.abspath(a.out)), exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.ops.export_scene.gltf(filepath=os.path.abspath(a.out), export_format="GLB", use_selection=True)
    log("exportado:", os.path.abspath(a.out))


main()
