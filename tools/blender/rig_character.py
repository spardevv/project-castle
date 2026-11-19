"""Prepara um personagem gerado por IA (malha em pose A, .glb) para o esqueleto do HumanoidRig do jogo.

1. Acha as articulações pela forma do corpo (quadril, joelhos, tornozelos, ombros, cotovelos, punhos):
   alturas pelas proporções do rig e posições laterais/profundidade por fatias da malha (sem o cabelo).
2. Escala e posiciona a malha no espaço do rig (quadril na altura do quadril do rig; frente = -Y no
   Blender, que vira +Z no Godot).
3. Pesos: cada vértice é ligado aos ossos mais próximos (segmentos osso→filho); o cabelo (escuro e
   neutro na textura) só segue cabeça/pescoço/peito/coluna, nunca os braços.
4. Exporta o .glb (malha + esqueleto com os nomes de ossos do jogo) e um .json com a posição de cada
   articulação no espaço do rig (o Godot usa para ligar a malha aos ossos do rig).

Uso: blender -b --factory-startup -P tools/blender/rig_character.py -- --glb in.glb --out characters/models/nome_rig.glb [--preview pasta]
"""
import argparse
import json
import math
import os
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

BONES = ["hips", "spine", "chest", "neck", "head", "clav_l", "clav_r", "sh_l", "sh_r", "el_l", "el_r",
         "th_l", "th_r", "kn_l", "kn_r", "ft_l", "ft_r",
         "wr_l", "wr_r", "toe_l", "toe_r", "hair_1", "hair_2", "hair_3"]
PARENT = {"spine": "hips", "chest": "spine", "neck": "chest", "head": "neck", "clav_l": "chest", "clav_r": "chest",
          "sh_l": "clav_l", "sh_r": "clav_r", "el_l": "sh_l", "el_r": "sh_r", "th_l": "hips", "th_r": "hips",
          "kn_l": "th_l", "kn_r": "th_r", "ft_l": "kn_l", "ft_r": "kn_r",
          "wr_l": "el_l", "wr_r": "el_r", "toe_l": "ft_l", "toe_r": "ft_r",
          "hair_1": "head", "hair_2": "hair_1", "hair_3": "hair_2"}
# Esboço de proporções (docs/vault/Animação/img/esboco_proporcoes.json, characters/body_proportions.gd):
# 8 cabeças. Alturas das articulações em cabeças a partir do chão.
HEADS = 8.0
RIG_TOP = 1.94  # altura total no espaço do rig (BodyProportions.total_height)
SKETCH = {"ankle": 0.3, "kn": 2.15, "th": 4.15, "hips": 4.35, "spine": 4.85, "chest": 5.75, "sh": 6.6,
          "neck": 6.75, "head": 7.15}
# Braço: comprimentos em cabeças (ombro -> cotovelo -> punho -> ponta dos dedos).
ARM = {"upper": 1.5, "fore": 1.25, "hand": 0.75}
FRAC = {k: v / HEADS for k, v in SKETCH.items()}
FRAC["ft"] = FRAC["ankle"] + 0.015  # fatia logo acima do tornozelo (a da altura dele pega o pé)


def log(*a):
    print("[rig]", *a, flush=True)


def import_mesh(path):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=path)
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    if len(meshes) > 1:
        bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
    for o in list(bpy.context.scene.objects):
        if o != obj:
            bpy.data.objects.remove(o)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return obj


def coords(obj):
    co = np.empty(len(obj.data.vertices) * 3, dtype=np.float64)
    obj.data.vertices.foreach_get("co", co)
    return co.reshape(-1, 3)


def vertex_colors(obj):
    """Cor da textura em cada vértice (cada face usa a imagem do seu material)."""
    me = obj.data
    imgs = {}
    for i, slot in enumerate(obj.material_slots):
        mat = slot.material
        img = None
        if mat is not None and mat.use_nodes:
            for n in mat.node_tree.nodes:
                if n.type == "TEX_IMAGE" and n.image is not None:
                    links = [l for o in n.outputs for l in o.links]
                    if any(l.to_socket.name == "Base Color" or l.to_node.type in ("MIX", "MIX_RGB") for l in links):
                        img = n.image
                        break
        if img is not None:
            w, h = img.size
            px = np.empty(w * h * 4, dtype=np.float32)
            img.pixels.foreach_get(px)
            imgs[i] = px.reshape(h, w, 4)
    col = np.zeros((len(me.vertices), 3), dtype=np.float32)
    cnt = np.zeros(len(me.vertices), dtype=np.float32)
    uv = me.uv_layers[0].data
    for poly in me.polygons:
        px = imgs.get(poly.material_index)
        if px is None:
            continue
        h, w = px.shape[:2]
        for li in poly.loop_indices:
            u, v = uv[li].uv
            c = px[min(int((u % 1.0) * w), w - 1), min(int((v % 1.0) * h), h - 1)] if False else px[min(int((v % 1.0) * h), h - 1), min(int((u % 1.0) * w), w - 1)]
            vi = me.loops[li].vertex_index
            col[vi] += c[:3]
            cnt[vi] += 1
    return col / np.maximum(cnt, 1)[:, None]


def mesh_edges(obj):
    e = np.empty(len(obj.data.edges) * 2, dtype=np.int64)
    obj.data.edges.foreach_get("vertices", e)
    return e.reshape(-1, 2)


def classify_hair(obj, dark):
    """Cabelo = vértices escuros e neutros LIGADOS PELA MALHA ao topo da cabeça. Só a cor não basta: a calcinha
    e o sutiã pretos têm a mesma cor e iriam para os ossos do cabelo (balançando com a física)."""
    co = coords(obj)
    col = vertex_colors(obj)
    lum = col[:, 0] * 0.3 + col[:, 1] * 0.59 + col[:, 2] * 0.11
    sat = col.max(axis=1) - col.min(axis=1)
    z_min, z_max = co[:, 2].min(), co[:, 2].max()
    H = z_max - z_min
    cand = (lum < dark) & (sat < 0.06) & (co[:, 2] > z_min + H * 0.42)
    e = mesh_edges(obj)
    e = e[cand[e[:, 0]] & cand[e[:, 1]]]
    n = len(co)
    adj_a = np.concatenate([e[:, 0], e[:, 1]])
    adj_b = np.concatenate([e[:, 1], e[:, 0]])
    order = np.argsort(adj_a)
    adj_a, adj_b = adj_a[order], adj_b[order]
    starts = np.searchsorted(adj_a, np.arange(n + 1))
    # Pedaços (componentes ligados) da cor do cabelo: é cabelo se o pedaço sobe acima dos ombros. A calcinha
    # fica toda abaixo da cintura; mechas soltas nas costas começam na cabeça.
    comp = np.full(n, -1)
    hair = np.zeros(n, dtype=bool)
    for seed in np.nonzero(cand)[0]:
        if comp[seed] >= 0:
            continue
        comp[seed] = seed
        stack = [seed]
        members = [seed]
        while stack:
            v = stack.pop()
            for u in adj_b[starts[v]:starts[v + 1]]:
                if comp[u] < 0:
                    comp[u] = seed
                    stack.append(u)
                    members.append(u)
        if co[members, 2].max() > z_min + H * 0.80:
            hair[members] = True
    log(f"cabelo: {int(hair.sum())} vértices (cor escura: {int(cand.sum())}; o resto é roupa/sombra)")
    return co, hair


def separate_hair(obj, hair):
    """Corta as arestas entre cabelo e corpo: o cabelo vira uma peça solta da malha (mesma posição)."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.verts.ensure_lookup_table()
    # Face é do cabelo se a maioria dos vértices for; corta as arestas entre face de cabelo e face do corpo.
    is_hair = {f.index: sum(hair[v.index] for v in f.verts) * 2 > len(f.verts) for f in bm.faces}
    cut = [ed for ed in bm.edges if len({is_hair[f.index] for f in ed.link_faces}) > 1]
    # Arestas de fronteira: duplica os vértices do lado do cabelo.
    n0 = len(bm.verts)
    bmesh.ops.split_edges(bm, edges=cut)
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.update()
    log(f"cabelo separado do corpo: {len(cut)} arestas cortadas ({len(obj.data.vertices) - n0:+d} vértices)")


def subdivide_butt(obj, P, hair):
    """Mais polígonos no bumbum/quadril de trás (atrás da coxa, da dobra do glúteo até acima do quadril)."""
    H = P["H"][0]
    cx = P["cx"][0]
    th_y = min(P["th_l"][1], P["th_r"][1])
    th_z = 0.5 * (P["th_l"][2] + P["th_r"][2])
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.verts.ensure_lookup_table()

    def inside(v):
        c = v.co
        return (not hair[v.index] and c.y > th_y - 0.02 * H and th_z - 0.14 * H < c.z < P["hips"][2] + 0.05 * H
                and abs(c.x - cx) < 0.14 * H)

    faces = [f for f in bm.faces if all(inside(v) for v in f.verts)]
    edges = list({ed for f in faces for ed in f.edges})
    nf = len(bm.faces)
    bmesh.ops.subdivide_edges(bm, edges=edges, cuts=1, use_grid_fill=True, smooth=0.0)
    # Faces vizinhas ganharam um vértice no meio da aresta (quadrado com 3 pontos alinhados): triangula
    # tudo que não é triângulo, escolhendo a diagonal sem triângulo degenerado.
    bmesh.ops.triangulate(bm, faces=[f for f in bm.faces if len(f.verts) > 3], quad_method="BEAUTY",
                          ngon_method="BEAUTY")
    for f in bm.faces:
        f.smooth = True
    bm.to_mesh(obj.data)
    bm.free()
    # Normais personalizadas do .glb não acompanham vértices novos (pontos escuros na borda): recalcula.
    if obj.data.has_custom_normals:
        bpy.context.view_layer.objects.active = obj
        bpy.ops.mesh.customdata_custom_splitnormals_clear()
    obj.data.update()
    log(f"bumbum: {len(faces)} faces subdivididas ({nf} -> {len(obj.data.polygons)} faces na malha)")


def landmarks(co, hair):
    """Articulações no espaço do Blender (Z para cima, frente -Y)."""
    body = co[~hair]
    z0, z1 = co[:, 2].min(), co[:, 2].max()
    H = z1 - z0
    cx = np.median(body[:, 0])
    P = {}

    def slice_(frac, half=0.012):
        z = z0 + H * frac
        return body[np.abs(body[:, 2] - z) < H * half]

    def legs(frac):
        s = slice_(frac)
        s = s[np.abs(s[:, 0] - cx) < H * 0.12]
        l, r = s[s[:, 0] > cx], s[s[:, 0] <= cx]
        z = z0 + H * frac
        return (np.array([l[:, 0].mean(), l[:, 1].mean(), z]), np.array([r[:, 0].mean(), r[:, 1].mean(), z]))

    P["ft_l"], P["ft_r"] = legs(FRAC["ft"])
    for k_ in ("ft_l", "ft_r"):  # tornozelo na altura do tornozelo do rig (a fatia acima é do pé)
        P[k_][2] = z0 + H * FRAC["ankle"]
    P["kn_l"], P["kn_r"] = legs(FRAC["kn"])
    tl, tr = legs(FRAC["th"] - 0.04)  # coxas ainda separadas logo abaixo da virilha
    P["th_l"] = np.array([tl[0], tl[1], z0 + H * FRAC["th"]])
    P["th_r"] = np.array([tr[0], tr[1], z0 + H * FRAC["th"]])
    for name in ("hips", "spine", "chest", "neck", "head"):
        s = slice_(FRAC[name])
        s = s[np.abs(s[:, 0] - cx) < H * 0.08]
        P[name] = np.array([cx, s[:, 1].mean() if len(s) else 0.0, z0 + H * FRAC[name]])
    # Ombros: metade da largura do tronco na altura dos ombros, um pouco para dentro.
    s = slice_(FRAC["sh"] - 0.02, 0.015)
    s = s[np.abs(s[:, 0] - cx) < H * 0.16]
    half = np.percentile(np.abs(s[:, 0] - cx), 97)
    sh_z = z0 + H * FRAC["sh"]
    sh_y = s[:, 1].mean()
    for n, sg in (("l", 1.0), ("r", -1.0)):
        P["sh_" + n] = np.array([cx + sg * half * 0.78, sh_y, sh_z])
        P["clav_" + n] = np.array([cx + sg * half * 0.3, sh_y, sh_z])
        # Semente no braço: pontos mais afastados para o lado entre a coxa e a cintura (pose A). Pode
        # ser o cotovelo ou a mão; só serve para achar o braço pela malha (arm_landmarks).
        arm = body[(np.sign(body[:, 0] - cx) == sg) & (body[:, 2] > z0 + H * 0.3) & (body[:, 2] < sh_z - H * 0.1)]
        far = arm[np.argsort(-np.abs(arm[:, 0] - cx))[: max(20, len(arm) // 200)]]
        P["armseed_" + n] = far.mean(axis=0)
        _arm_by_line(P, n, P["armseed_" + n], H)
    for n in ("l", "r"):
        # Ponta do pé: base dos dedos à frente do tornozelo (frente = -Y), junto do chão.
        ft = P["ft_" + n]
        P["toe_" + n] = np.array([ft[0], ft[1] - H * 0.05, z0 + H * 0.012])
        P["toetip_" + n] = P["toe_" + n] + np.array([0, -H * 0.045, 0])
    P["cx"] = np.array([cx, 0, 0])
    P["H"] = np.array([H, z0, 0])
    chain = hair_chain(co, hair, P, cx, z0, H)
    if chain is not None:
        for k in range(4):
            P[f"hairpt_{k}"] = chain[k]
        for k in range(3):
            P[f"hair_{k + 1}"] = chain[k]
    return P


def _arm_by_line(P, n, tip, H):
    """Cotovelo/punho/mão numa reta ombro -> ponta dos dedos, pelos comprimentos do esboço."""
    sh = P["sh_" + n]
    total = ARM["upper"] + ARM["fore"] + ARM["hand"]
    P["el_" + n] = sh + (tip - sh) * (ARM["upper"] / total)
    wrist = sh + (tip - sh) * ((ARM["upper"] + ARM["fore"]) / total)
    P["wrist_" + n] = wrist
    P["wr_" + n] = wrist
    P["hand_" + n] = wrist + (tip - wrist) * 0.45
    P["handtip_" + n] = tip


def arm_landmarks(co, edges, P):
    """Refaz cotovelo/punho/mão pelo braço de verdade: pega os vértices do braço pela malha (ligados à
    semente), a ponta dos dedos é o vértice do braço mais longe do ombro, e cotovelo e punho ficam no
    centro da "casca" do braço à distância do esboço (1,5 e 2,75 de 3,5 cabeças até a ponta). Segue a
    dobra do cotovelo da pose A em vez de uma reta."""
    H = P["H"][0]
    total = ARM["upper"] + ARM["fore"] + ARM["hand"]
    arms = {}
    for n in ("l", "r"):
        sh = P["sh_" + n]
        # A esfera de corte desce/cresce até soltar o braço do tronco (axila abaixo do ombro do esboço).
        arm = None
        for drop, rad in ((0.0, 0.055), (0.02, 0.06), (0.035, 0.065), (0.05, 0.07), (0.035, 0.08)):
            arm = arm_component(co, edges, sh - np.array([0, 0, drop * H]), P["armseed_" + n], rad * H)
            if arm is not None:
                log(f"braço {n}: corte no ombro -{drop:.3f}H raio {rad:.3f}H")
                break
        if arm is None:
            log(f"braço {n}: separação pela malha falhou; mantendo a reta ombro -> semente")
            continue
        av = co[arm]
        dist = np.linalg.norm(av - sh, axis=1)
        tip = av[dist >= np.percentile(dist, 99.3)].mean(axis=0)
        L = np.linalg.norm(tip - sh)

        def shell(frac):
            r = L * frac
            band = av[np.abs(dist - r) < H * 0.012]
            return band.mean(axis=0) if len(band) >= 8 else sh + (tip - sh) * frac

        el = shell(ARM["upper"] / total)
        wrist = shell((ARM["upper"] + ARM["fore"]) / total)
        P["el_" + n] = el
        P["wrist_" + n] = wrist
        P["wr_" + n] = wrist
        P["hand_" + n] = wrist + (tip - wrist) * 0.45
        P["handtip_" + n] = tip
        arms[n] = arm
        log(f"braço {n}: ombro z={sh[2]:.3f} cotovelo z={el[2]:.3f} punho z={wrist[2]:.3f} ponta z={tip[2]:.3f}"
            f" (comprimento {L / H * HEADS:.2f} cabeças; esboço {total:.2f})")
    return arms


def hair_chain(co, hair, P, cx, z0, H):
    """4 pontos ao longo do cabelo das costas: nuca (atrás da cabeça) até a ponta. None se não há
    cabelo comprido atrás."""
    back = hair & (co[:, 1] > P["chest"][1] + H * 0.01) & (np.abs(co[:, 0] - cx) < H * 0.12)
    if back.sum() < 50:
        return None
    hb = co[back]
    z_end = np.percentile(hb[:, 2], 3)
    z_top = P["head"][2]
    if z_top - z_end < H * 0.15:
        return None
    pts = []
    for k in range(4):
        z = z_top + (z_end - z_top) * (k / 3.0)
        band = hb[np.abs(hb[:, 2] - z) < H * 0.03]
        if len(band) < 5:
            band = hb[np.argsort(np.abs(hb[:, 2] - z))[:20]]
        pts.append(np.array([cx, np.median(band[:, 1]), z]))
    return pts


def compute_weights(co, hair, P, edges, smooth_iters=10, arms=None):
    """Pesos por proximidade aos segmentos dos ossos, depois suavizados pela superfície da malha
    (transições graduais nas articulações, sem rasgar), e no fim os 4 maiores por vértice."""
    seg = {
        "hips": (P["hips"] - np.array([0, 0, 0.08 * P["H"][0]]), P["spine"]),
        "spine": (P["spine"], P["chest"]),
        "chest": (P["chest"], P["neck"]),
        "neck": (P["neck"], P["head"]),
        "head": (P["head"], P["head"] + np.array([0, 0, 0.12 * P["H"][0]])),
    }
    for n in ("l", "r"):
        seg["clav_" + n] = (P["clav_" + n], P["sh_" + n])
        seg["sh_" + n] = (P["sh_" + n], P["el_" + n])
        seg["el_" + n] = (P["el_" + n], P["wrist_" + n])
        seg["wr_" + n] = (P["wrist_" + n], P["handtip_" + n])
        seg["th_" + n] = (P["th_" + n], P["kn_" + n])
        seg["kn_" + n] = (P["kn_" + n], P["ft_" + n])
        seg["ft_" + n] = (P["ft_" + n], P["toe_" + n])
        seg["toe_" + n] = (P["toe_" + n], P["toetip_" + n])
    has_chain = "hairpt_0" in P
    for k in range(3):
        if has_chain:
            seg[f"hair_{k + 1}"] = (P[f"hairpt_{k}"], P[f"hairpt_{k + 1}"])
        else:
            seg[f"hair_{k + 1}"] = (P["head"], P["head"])
    # Bacia: o quadril também cobre a linha entre as duas articulações das coxas.
    extra = {"hips": [(P["th_l"], P["th_r"])]}
    names = list(seg)
    D = np.zeros((len(co), len(names)))

    def seg_dist(a, b):
        ab = b - a
        t = np.clip(((co - a) @ ab) / max(ab @ ab, 1e-9), 0, 1)
        return np.linalg.norm(co - (a + t[:, None] * ab), axis=1)

    for j, nm in enumerate(names):
        D[:, j] = seg_dist(*seg[nm])
        for a, b in extra.get(nm, []):
            D[:, j] = np.minimum(D[:, j], seg_dist(a, b))
    # Cabelo: o das costas (abaixo da cabeça) segue a cadeia do cabelo; o resto segue tronco e cabeça.
    # Pele/roupa nunca seguem ossos do cabelo.
    hair_bones = [names.index(f"hair_{k}") for k in (1, 2, 3)]
    trunk = [names.index(n) for n in ("head", "neck", "chest", "spine", "hips")]
    back_hair = hair & (co[:, 1] > P["chest"][1] + 0.01 * P["H"][0]) & (co[:, 2] < P["head"][2]) if has_chain else np.zeros(len(co), bool)
    mask_back = np.full(len(names), np.inf)
    mask_back[hair_bones + [names.index("head"), names.index("neck")]] = 0
    mask_hair = np.full(len(names), np.inf)
    mask_hair[trunk] = 0
    D[back_hair] = D[back_hair] + mask_back
    other_hair = hair & ~back_hair
    D[other_hair] = D[other_hair] + mask_hair
    D[np.ix_(~hair, hair_bones)] = np.inf
    # Braço e antebraço só pegam vértices do próprio braço: na pose A o antebraço passa perto da cintura,
    # e a pele do tronco não pode ir junto quando o braço sobe. "Braço" = o que continua ligado à mão
    # pela malha quando se corta uma esfera em volta do ombro (braço e tronco só se tocam ali).
    H = P["H"][0]
    for n in ("l", "r"):
        arm = (arms or {}).get(n)
        if arm is None:
            arm = arm_component(co, edges, P["sh_" + n], P["hand_" + n], 0.055 * H)
        if arm is None:
            log(f"braço {n}: separação pela malha falhou; usando só distância")
            continue
        for bone in ("sh_" + n, "el_" + n, "wr_" + n):
            D[~arm, names.index(bone)] = np.inf
        log(f"braço {n}: {int(arm.sum())} vértices")
    W = 1.0 / np.maximum(D, 1e-4) ** 6
    W[np.isinf(D)] = 0.0
    W /= W.sum(axis=1, keepdims=True)
    # Bumbum: atrás da articulação da coxa e acima da dobra do glúteo, a maior parte do peso fica no quadril
    # (a coxa girando no passo não arrasta o glúteo inteiro). Transição suave na dobra e para a frente.
    hi = names.index("hips")
    for n in ("l", "r"):
        th = P["th_" + n]
        ti = names.index("th_" + n)
        side = np.sign(co[:, 0] - P["hips"][0]) == (1.0 if n == "l" else -1.0)
        up = np.clip((co[:, 2] - (th[2] - 0.11 * H)) / (0.07 * H), 0.0, 1.0)  # 0 abaixo da dobra
        back = np.clip((co[:, 1] - (th[1] - 0.01 * H)) / (0.04 * H), 0.0, 1.0)  # 0 na frente da coxa
        g = up * back * side * ~hair * 0.75
        moved = W[:, ti] * g
        W[:, ti] -= moved
        W[:, hi] += moved
    # Suavização pela malha (média com os vizinhos), sem deixar o cabelo ganhar peso de braço/perna.
    allowed = np.isfinite(D)
    a_idx, b_idx = edges[:, 0], edges[:, 1]
    deg = np.zeros(len(co))
    np.add.at(deg, a_idx, 1)
    np.add.at(deg, b_idx, 1)
    for _ in range(smooth_iters):
        acc = np.zeros_like(W)
        np.add.at(acc, a_idx, W[b_idx])
        np.add.at(acc, b_idx, W[a_idx])
        W = 0.5 * W + 0.5 * acc / np.maximum(deg, 1)[:, None]
        W *= allowed
        W /= np.maximum(W.sum(axis=1, keepdims=True), 1e-9)
    top = np.argsort(-W, axis=1)[:, :4]
    Wt = np.take_along_axis(W, top, axis=1)
    Wt /= np.maximum(Wt.sum(axis=1, keepdims=True), 1e-9)
    return names, top, Wt


def arm_component(co, edges, shoulder, hand, cut_r):
    """Vértices do braço: corta uma esfera em volta do ombro e pega o que segue ligado à mão.
    A esfera entra no resultado (transição do ombro). None se o braço continuar ligado ao tronco."""
    n = len(co)
    near_sh = np.linalg.norm(co - shoulder, axis=1) < cut_r
    a, b = edges[:, 0], edges[:, 1]
    keep = ~near_sh[a] & ~near_sh[b]
    a, b = a[keep], b[keep]
    order = np.argsort(a)
    a_s, b_s = a[order], b[order]
    starts = np.searchsorted(a_s, np.arange(n + 1))
    adj_a = np.concatenate([a_s, b])
    adj_b = np.concatenate([b_s, a])
    order = np.argsort(adj_a)
    adj_a, adj_b = adj_a[order], adj_b[order]
    starts = np.searchsorted(adj_a, np.arange(n + 1))
    seed = int(np.argmin(np.linalg.norm(co - hand, axis=1)))
    seen = np.zeros(n, dtype=bool)
    seen[seed] = True
    stack = [seed]
    while stack:
        v = stack.pop()
        for u in adj_b[starts[v]:starts[v + 1]]:
            if not seen[u]:
                seen[u] = True
                stack.append(u)
    if seen.sum() > n * 0.12:  # pegou o tronco junto: a malha do braço está grudada no corpo
        return None
    return seen | near_sh


def main():
    argv = sys.argv[sys.argv.index("--") + 1:]
    p = argparse.ArgumentParser()
    p.add_argument("--glb", required=True)
    p.add_argument("--out", required=True)
    p.add_argument("--hair-dark", type=float, default=0.22)
    p.add_argument("--preview", default="")
    a = p.parse_args(argv)

    obj = import_mesh(a.glb)
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bm.to_mesh(obj.data)
    bm.free()
    co, hair = classify_hair(obj, a.hair_dark)
    P = landmarks(co, hair)
    # Postura: modelos gerados costumam vir com as pernas inclinadas para trás e o tronco para frente. O rig
    # tem pernas e tronco na vertical na pose zero; se o modelo não tiver, a malha da perna gira no quadril
    # (estica o bumbum, parece sentado). Gira o modelo inteiro em volta do eixo X pela média das duas
    # inclinações, deixando pernas e tronco quase verticais.
    def lean(a, b):  # ângulo de a->b em relação à vertical, positivo = topo mais à frente (-Y)
        d = b - a
        return math.degrees(math.atan2(-d[1], d[2]))
    ankles = (P["ft_l"] + P["ft_r"]) * 0.5
    hipj = (P["th_l"] + P["th_r"]) * 0.5
    leg_lean = lean(ankles, hipj)
    torso_lean = lean(P["hips"], P["neck"])
    fix = -(leg_lean + torso_lean) * 0.5
    log(f"postura: pernas {leg_lean:+.1f}°, tronco {torso_lean:+.1f}° -> gira {fix:+.1f}°")
    if abs(fix) > 0.5:
        obj.data.transform(Matrix.Rotation(math.radians(fix), 4, "X"))
        obj.data.update()
        co = coords(obj)
        P = landmarks(co, hair)
        ankles = (P["ft_l"] + P["ft_r"]) * 0.5
        hipj = (P["th_l"] + P["th_r"]) * 0.5
        log(f"postura corrigida: pernas {lean(ankles, hipj):+.1f}°, tronco {lean(P['hips'], P['neck']):+.1f}°")
    # Bumbum com mais polígonos (dobra melhor no passo) e cabelo solto do corpo (a física do cabelo não
    # puxa a pele/roupa que ele toca). Depois disso os índices mudam: reclassifica e refaz as articulações.
    subdivide_butt(obj, P, hair)
    co, hair = classify_hair(obj, a.hair_dark)
    separate_hair(obj, hair)
    co, hair = classify_hair(obj, a.hair_dark)
    P = landmarks(co, hair)
    H, z0 = P["H"][0], P["H"][1]
    cx = P["cx"][0]
    k = RIG_TOP / H  # altura total do esboço no rig
    log(f"altura {H:.3f}, escala para o rig x{k:.3f} (altura no rig {H * k:.2f})")

    # Malha para o espaço do rig: pés em z=0, centro em x=0, profundidade do quadril em y=0.
    y0 = P["hips"][1]
    off = np.array([cx, y0, z0])
    co_r = (co - off) * k
    obj.data.vertices.foreach_set("co", co_r.astype(np.float32).ravel())
    obj.data.update()
    Pr = {n: (v - off) * k for n, v in P.items() if n not in ("cx", "H")}
    Pr["H"] = np.array([H * k, 0, 0])

    edges = np.empty(len(obj.data.edges) * 2, dtype=np.int64)
    obj.data.edges.foreach_get("vertices", edges)
    edges = edges.reshape(-1, 2)
    arms = arm_landmarks(co_r, edges, Pr)
    names, top, Wt = compute_weights(co_r, hair, Pr, edges, arms=arms)
    # Esqueleto (nomes do rig) e pesos.
    arm_data = bpy.data.armatures.new("Esqueleto")
    arm = bpy.data.objects.new("Esqueleto", arm_data)
    bpy.context.scene.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    child_of = {"sh_l": "el_l", "sh_r": "el_r", "el_l": "wr_l", "el_r": "wr_r", "th_l": "kn_l", "th_r": "kn_r",
                "kn_l": "ft_l", "kn_r": "ft_r", "hips": "spine", "spine": "chest", "chest": "neck", "neck": "head",
                "clav_l": "sh_l", "clav_r": "sh_r", "wr_l": "handtip_l", "wr_r": "handtip_r",
                "ft_l": "toe_l", "ft_r": "toe_r", "toe_l": "toetip_l", "toe_r": "toetip_r",
                "hair_1": "hairpt_1", "hair_2": "hairpt_2", "hair_3": "hairpt_3"}
    ebs = {}
    for n in BONES:
        eb = arm_data.edit_bones.new(n)
        if n not in Pr:  # sem cadeia de cabelo: osso parado na cabeça
            Pr[n] = Pr["head"] + np.array([0, 0.02 * k * 0, 0.01])
        eb.head = Vector(Pr[n])
        tail = Pr.get(child_of.get(n, ""), None)
        if tail is None or np.linalg.norm(tail - Pr[n]) < 1e-3:
            tail = Pr[n] + (np.array([0, -0.1, 0]) if n.startswith("ft") else np.array([0, 0, 0.1]))
        eb.tail = Vector(tail)
        ebs[n] = eb
    for n, par in PARENT.items():
        ebs[n].parent = ebs[par]
    bpy.ops.object.mode_set(mode="OBJECT")
    groups = {n: obj.vertex_groups.new(name=n) for n in BONES}
    for j in range(4):
        for bi, nm in enumerate(names):
            sel = np.nonzero(top[:, j] == bi)[0]
            g = groups[nm]
            for i in sel:
                g.add([int(i)], float(Wt[i, j]), "ADD")
    mod = obj.modifiers.new("Esqueleto", "ARMATURE")
    mod.object = arm
    obj.parent = arm
    log("pesos: " + ", ".join(f"{n}={int((top[:, 0] == names.index(n)).sum())}" for n in BONES))

    # Posições das articulações no espaço do Godot (x, z, -y) para o rig.
    to_godot = lambda v: [float(v[0]), float(v[2]), float(-v[1])]
    data = {n: to_godot(Pr[n]) for n in BONES}
    for n in ("l", "r"):
        data["hand_" + n] = to_godot(Pr["hand_" + n])
        data["wrist_" + n] = to_godot(Pr["wrist_" + n])
        data["toetip_" + n] = to_godot(Pr["toetip_" + n])
    if "hairpt_0" in Pr:
        data["hair_chain"] = [to_godot(Pr[f"hairpt_{k}"]) for k in range(4)]
    data["height"] = float(H * k)
    out = os.path.abspath(a.out)
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(os.path.splitext(out)[0] + ".json", "w", encoding="utf-8") as f:
        json.dump(data, f, indent=1)
    if a.preview:
        test_pose(obj, arm, a.preview)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    arm.select_set(True)
    bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", use_selection=True, export_skins=True,
                              export_animations=False)
    log("exportado:", out)


def test_pose(obj, arm, folder):
    """Render de conferência: repouso e uma pose de teste (braços baixados, joelho dobrado, cabeça virada)."""
    os.makedirs(folder, exist_ok=True)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items] else "BLENDER_EEVEE"
    scene.world = bpy.data.worlds.new("w")
    scene.world.use_nodes = True
    scene.world.node_tree.nodes["Background"].inputs[0].default_value = (0.32, 0.33, 0.36, 1)
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sun.data.energy = 3.0
    sun.rotation_euler = (math.radians(50), 0, math.radians(30))
    scene.collection.objects.link(sun)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = 2.2
    scene.collection.objects.link(cam)
    scene.camera = cam
    scene.render.resolution_x, scene.render.resolution_y = 900, 1000
    cam.location = (2.2, -4.5, 1.0)
    cam.rotation_euler = (math.radians(90), 0, math.radians(26))

    def shot(tag):
        scene.render.filepath = os.path.join(folder, f"rig_{tag}.png")
        bpy.ops.render.render(write_still=True)

    shot("repouso")
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="POSE")
    pb = arm.pose.bones
    for b in pb:
        b.rotation_mode = "XYZ"
    pb["sh_l"].rotation_euler = (0, 0, math.radians(-40))
    pb["sh_r"].rotation_euler = (math.radians(60), 0, 0)
    pb["el_r"].rotation_euler = (math.radians(70), 0, 0)
    pb["th_l"].rotation_euler = (math.radians(50), 0, 0)
    pb["kn_l"].rotation_euler = (math.radians(-80), 0, 0)
    pb["head"].rotation_euler = (0, math.radians(35), 0)
    pb["chest"].rotation_euler = (0, math.radians(20), 0)
    bpy.ops.object.mode_set(mode="OBJECT")
    shot("pose_teste")
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="POSE")
    for b in pb:
        b.rotation_euler = (0, 0, 0)
    bpy.ops.object.mode_set(mode="OBJECT")


main()
