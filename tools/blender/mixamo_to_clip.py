"""Converte animações do Mixamo (.fbx, esqueleto "mixamorig") em clipes do HumanoidRig (.json).

Uso (Blender 5.1, sem interface):
  blender -b --factory-startup -P tools/blender/mixamo_to_clip.py -- --src tools/blender/mixamo_src --out characters/anims

Cada .fbx vira <nome>.json com o mesmo nome do arquivo (idle, walk, jog, run, jump, fall, roll, dodge_back,
dodge_left, dodge_right, ...). Nomes que começam com idle/walk/jog/run/sprint/fall/strafe são ciclos (loop).

Retarget por direção: para cada osso, o "repouso" do rig (pose zero: braços e pernas retos para baixo, frente +Z)
é comparado com a pose T do Mixamo; o clipe guarda a rotação LOCAL de cada junta do rig (Euler YXZ em graus,
como rotation_degrees no Godot), então vale para qualquer personagem do rig, com qualquer proporção.
Também grava: contato de cada pé por quadro, distância de um ciclo (pés sem deslizar), marcadores do pulo
(decolagem, ápice, pouso) e o trecho ativo das esquivas.
"""
import argparse
import json
import math
import os
import sys

import bpy
import numpy as np

# Juntas do rig <- ossos do Mixamo (sufixo depois de "mixamorig:").
MAP = {
    "hips": "Hips", "spine": "Spine2", "head": "Head",
    "sh_l": "LeftArm", "el_l": "LeftForeArm", "wr_l": "LeftHand",
    "sh_r": "RightArm", "el_r": "RightForeArm", "wr_r": "RightHand",
    "th_l": "LeftUpLeg", "kn_l": "LeftLeg", "ft_l": "LeftFoot",
    "th_r": "RightUpLeg", "kn_r": "RightLeg", "ft_r": "RightFoot",
}
# Pai de cada junta no rig (para a rotação local). spine = tronco inteiro (o rig divide entre lombar e peito);
# head = pescoço + cabeça (o rig divide também). Ombros pulam a clavícula (o rig a move sozinho).
PARENT = {"spine": "hips", "head": "spine", "sh_l": "spine", "sh_r": "spine", "el_l": "sh_l", "el_r": "sh_r",
          "wr_l": "el_l", "wr_r": "el_r", "th_l": "hips", "th_r": "hips", "kn_l": "th_l", "kn_r": "th_r",
          "ft_l": "kn_l", "ft_r": "kn_r"}
# Segmentos que no rig apontam para baixo na pose zero: osso -> osso onde termina (direção na pose T).
LIMB_END = {"sh_l": "LeftForeArm", "el_l": "LeftHand", "wr_l": "LeftHandMiddle1",
            "sh_r": "RightForeArm", "el_r": "RightHand", "wr_r": "RightHandMiddle1",
            "th_l": "LeftLeg", "kn_l": "LeftFoot", "th_r": "RightLeg", "kn_r": "RightFoot"}
LOOP_PREFIX = ("idle", "walk", "jog", "run", "sprint", "fall", "strafe", "back")
LOOP_SUFFIX = ("_idle", "_walk", "_run")
# Golpes/skills: trecho ativo "start".."end" pelo movimento das juntas (ver attack_markers), não pelo quadril.
STRIKE_CLIPS = ("kick", "swipe", "combo", "magic_attack", "jump_attack")  # pico de velocidade = impacto
MULTI_CLIPS = ("combo_melee", "jump_attack")  # vários golpes no mesmo clipe: markers["hits"] = [[início, fim, pico], ...]
HOLD_CLIPS = ("choke_lift", "heal", "block", "body_block")  # trecho parado (segurar) no meio do clipe
# Blender (Z para cima, frente -Y) -> Godot (Y para cima, frente +Z do personagem depois do alinhamento).
C = np.array([[1.0, 0, 0], [0, 0, 1.0], [0, -1.0, 0]])


def log(*a):
    print("[clip]", *a, flush=True)


def rot_between(a, b):
    """Menor rotação que leva a direção a até b."""
    a = a / np.linalg.norm(a)
    b = b / np.linalg.norm(b)
    v = np.cross(a, b)
    c = float(np.dot(a, b))
    if c < -0.9999:
        axis = np.cross(a, [1.0, 0, 0])
        if np.linalg.norm(axis) < 1e-3:
            axis = np.cross(a, [0, 0, 1.0])
        axis /= np.linalg.norm(axis)
        return 2.0 * np.outer(axis, axis) - np.eye(3)
    vx = np.array([[0, -v[2], v[1]], [v[2], 0, -v[0]], [-v[1], v[0], 0]])
    return np.eye(3) + vx + vx @ vx * (1.0 / (1.0 + c))


def rot_x(t):
    c, s = math.cos(t), math.sin(t)
    return np.array([[1, 0, 0], [0, c, -s], [0, s, c]])


def rot_y(t):
    c, s = math.cos(t), math.sin(t)
    return np.array([[c, 0, s], [0, 1, 0], [-s, 0, c]])


def euler_yxz(R):
    """Mesma decomposição do Basis.get_euler() do Godot (ordem YXZ), em radianos."""
    m12 = R[1, 2]
    if m12 < 0.9999:
        if m12 > -0.9999:
            x = math.asin(-m12)
            y = math.atan2(R[0, 2], R[2, 2])
            z = math.atan2(R[1, 0], R[1, 1])
        else:
            x = math.pi * 0.5
            y = math.atan2(R[0, 1], R[0, 0])
            z = 0.0
    else:
        x = -math.pi * 0.5
        y = -math.atan2(R[0, 1], R[0, 0])
        z = 0.0
    return np.array([x, y, z])


def euler_xyz(R):
    """Basis.get_euler(EULER_ORDER_XYZ) do Godot (R = Rx·Ry·Rz). Joelhos e cotovelos usam esta ordem no rig:
    a dobra (X) passa de 90° sem o salto de representação da ordem YXZ."""
    y = math.asin(max(-1.0, min(1.0, R[0, 2])))
    x = math.atan2(-R[1, 2], R[2, 2])
    z = math.atan2(-R[0, 1], R[0, 0])
    return np.array([x, y, z])


HINGES = ("kn_l", "kn_r", "el_l", "el_r")


def quat(R):
    """Quaternion (w, x, y, z) de uma matriz de rotação."""
    t = np.trace(R)
    if t > 0:
        k = math.sqrt(t + 1.0) * 2
        return np.array([0.25 * k, (R[2, 1] - R[1, 2]) / k, (R[0, 2] - R[2, 0]) / k, (R[1, 0] - R[0, 1]) / k])
    i = int(np.argmax([R[0, 0], R[1, 1], R[2, 2]]))
    if i == 0:
        k = math.sqrt(1.0 + R[0, 0] - R[1, 1] - R[2, 2]) * 2
        return np.array([(R[2, 1] - R[1, 2]) / k, 0.25 * k, (R[0, 1] + R[1, 0]) / k, (R[0, 2] + R[2, 0]) / k])
    if i == 1:
        k = math.sqrt(1.0 + R[1, 1] - R[0, 0] - R[2, 2]) * 2
        return np.array([(R[0, 2] - R[2, 0]) / k, (R[0, 1] + R[1, 0]) / k, 0.25 * k, (R[1, 2] + R[2, 1]) / k])
    k = math.sqrt(1.0 + R[2, 2] - R[0, 0] - R[1, 1]) * 2
    return np.array([(R[1, 0] - R[0, 1]) / k, (R[0, 2] + R[2, 0]) / k, (R[1, 2] + R[2, 1]) / k, 0.25 * k])


def ortho(m3):
    u, _, vt = np.linalg.svd(np.array(m3))
    return u @ vt


def find_bones(arm):
    out = {}
    for b in arm.data.bones:
        short = b.name.split(":")[-1]
        out[short] = b.name
    return out


def attack_markers(ch, n, name):
    """(início, fim, impacto) do trecho ativo de um golpe/skill pela velocidade angular das juntas.
    Golpes: pico de velocidade = impacto; ativo = em volta do pico enquanto > 25% dele.
    Segurar (agarrar, cura, bloqueio): ativo = a janela mais longa de pouco movimento depois do pico."""
    joints = ("hips", "spine", "sh_l", "sh_r", "el_l", "el_r", "th_l", "th_r")
    d = np.zeros(n)
    for j in joints:
        d[1:] += np.abs(np.diff(np.degrees(ch[j]), axis=0)).sum(axis=1)
    d = np.convolve(d, np.ones(3) / 3.0, mode="same")
    peak = int(np.argmax(d))
    if any(k in name for k in HOLD_CLIPS):
        # Janelas de pouco movimento (>= 4 quadros). Vale a que está mais longe da pose de repouso (quadro 0)
        # vezes o tamanho: segurar o pescoço / erguer as mãos, e não o repouso do começo ou do fim do clipe.
        quiet = d < max(d.max() * 0.2, 0.5)
        rest = {j: np.degrees(ch[j][0]) for j in ("sh_l", "sh_r", "el_l", "el_r", "spine")}
        far = np.zeros(n)
        for j in rest:
            far += np.abs(np.degrees(ch[j]) - rest[j]).sum(axis=1)
        runs, cur = [], None
        for i in range(n):
            if quiet[i] and cur is None:
                cur = i
            if (not quiet[i] or i == n - 1) and cur is not None:
                if i - cur >= 4:
                    runs.append((cur, i))
                cur = None
        if not runs:
            return int(n * 0.3), int(n * 0.7), n // 2
        best = max(runs, key=lambda r: (r[1] - r[0]) * float(far[r[0]:r[1]].mean()))
        return best[0], best[1], (best[0] + best[1]) // 2
    thr = d[peak] * 0.25
    s_i = peak
    while s_i > 0 and d[s_i - 1] > thr:
        s_i -= 1
    e_i = peak
    while e_i < n - 1 and d[e_i + 1] > thr:
        e_i += 1
    return max(s_i - 1, 0), min(e_i + 1, n - 1), peak


def multi_hits(ch, n, fps):
    """Golpes de um clipe com vários (combo): cada pico de velocidade das juntas vira [início, fim, pico]
    (frações 0..1), com o trecho ativo em volta do pico enquanto > 25% dele."""
    joints = ("hips", "spine", "sh_l", "sh_r", "el_l", "el_r", "th_l", "th_r")
    d = np.zeros(n)
    for j in joints:
        d[1:] += np.abs(np.diff(np.degrees(ch[j]), axis=0)).sum(axis=1)
    d = np.convolve(d, np.ones(5) / 5.0, mode="same")
    gap = max(int(0.3 * fps), 3)
    peaks = [i for i in range(2, n - 2) if d[i] == d[max(0, i - gap):i + gap + 1].max() and d[i] > d.max() * 0.35]
    hits = []
    for p in peaks:
        thr = d[p] * 0.5
        s_i, e_i = p, p
        lim = int(0.25 * fps)  # no máximo 0,25 s para cada lado do pico
        while s_i > 0 and d[s_i - 1] > thr and p - s_i < lim:
            s_i -= 1
        while e_i < n - 1 and d[e_i + 1] > thr and e_i - p < lim:
            e_i += 1
        hits.append([max(s_i - 1, 0) / (n - 1), min(e_i + 1, n - 1) / (n - 1), p / (n - 1)])
    return hits


def convert(path, out_dir):
    name = os.path.splitext(os.path.basename(path))[0].lower()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=path)
    arms = [o for o in bpy.context.scene.objects if o.type == "ARMATURE"]
    if not arms:
        log(name, ": sem esqueleto, pulando")
        return
    arm = arms[0]
    bones = find_bones(arm)
    missing = [m for m in set(MAP.values()) | {"LeftToeBase", "RightToeBase"} if m not in bones]
    if missing:
        log(name, ": faltam ossos", missing)
        return
    act = arm.animation_data.action if arm.animation_data else None
    if act is None:
        log(name, ": sem animação")
        return
    f0, f1 = int(act.frame_range[0]), int(act.frame_range[1])
    scene = bpy.context.scene
    fps = scene.render.fps / scene.render.fps_base
    mw = np.array(arm.matrix_world)

    def world_rest(bname):
        b = arm.data.bones[bones[bname]]
        m = mw @ np.array(b.matrix_local)
        return C @ ortho(m[:3, :3]) @ C.T, C @ (m[:3, 3])

    # Alinhamento: frente do personagem -> +Z do Godot (esquerda +X).
    _, lhip = world_rest("LeftUpLeg")
    _, rhip = world_rest("RightUpLeg")
    left = lhip - rhip
    left[1] = 0.0
    front = np.cross(left, [0, 1.0, 0])
    yaw = math.atan2(front[0], front[2])
    A = rot_y(-yaw)
    log(f"{name}: frente girada {math.degrees(yaw):+.0f}°, quadros {f0}..{f1} a {fps:.0f} fps")

    rest_R, rest_p = {}, {}
    for short in set(MAP.values()) | set(LIMB_END.values()) | {"LeftToeBase", "RightToeBase"}:
        if short not in bones:
            continue
        R, p = world_rest(short)
        rest_R[short], rest_p[short] = A @ R, A @ p
    hips_h = rest_p["Hips"][1]  # origem do Mixamo fica no chão
    # Correção por osso: ours(t) = M(t) @ corr. Repouso do rig na pose T: tronco/pés identidade; membros
    # giram de "para baixo" até a direção do osso na pose T.
    corr = {}
    for j, short in MAP.items():
        O = np.eye(3)
        if j in LIMB_END and LIMB_END[j] in rest_p:
            O = rot_between(np.array([0, -1.0, 0]), rest_p[LIMB_END[j]] - rest_p[short])
        corr[j] = rest_R[short].T @ O

    # Golpes/esquivas do Mixamo vêm em base de luta (quadril virado 45-70°): gira o clipe inteiro pela
    # direção média do quadril nos quadros em pé, para o corpo ficar de frente como no resto do jogo.
    sx, sz = 0.0, 0.0
    for f in range(f0, f1 + 1):
        scene.frame_set(f)
        m = mw @ np.array(arm.pose.bones[bones["Hips"]].matrix)
        Wh = A @ C @ ortho(m[:3, :3]) @ C.T @ corr["hips"]
        if (Wh @ np.array([0, 1.0, 0]))[1] < 0.7:
            continue
        fw = Wh @ np.array([0, 0, 1.0])
        sx, sz = sx + fw[0], sz + fw[2]
    ym = math.atan2(sx, sz) if abs(sx) + abs(sz) > 1e-6 else 0.0
    if abs(math.degrees(ym)) > 3.0:
        log(f"{name}: quadril virado {math.degrees(ym):+.0f}° em média -> corrigido")
        A = rot_y(-ym) @ A

    n = f1 - f0 + 1
    ch = {j: np.zeros((n, 3)) for j in MAP}
    pitch = np.zeros(n)
    hips_pos = np.zeros((n, 3))
    feet = {s: np.zeros((n, 3)) for s in ("LeftFoot", "RightFoot", "LeftToeBase", "RightToeBase")}
    prev_q = np.array([1.0, 0, 0, 0])
    for i, f in enumerate(range(f0, f1 + 1)):
        scene.frame_set(f)
        W = {}
        for j, short in MAP.items():
            pb = arm.pose.bones[bones[short]]
            m = mw @ np.array(pb.matrix)
            W[j] = A @ C @ ortho(m[:3, :3]) @ C.T @ corr[j]
            if short == "Hips":
                hips_pos[i] = A @ C @ m[:3, 3]
        for s in feet:
            m = mw @ np.array(arm.pose.bones[bones[s]].matrix)
            feet[s][i] = A @ C @ m[:3, 3]
        # Giro do corpo em volta de X (rolamento) = "twist" do quaternion do quadril em X: contínuo mesmo
        # no rolamento por cima do ombro (o vetor "para cima" do corpo passa pelo lado).
        q = quat(W["hips"])
        if i > 0 and np.dot(q, prev_q) < 0:
            q = -q
        prev_q = q
        pitch[i] = 2.0 * math.atan2(q[1], q[0])
        hips_local = rot_x(pitch[i]).T @ W["hips"]
        ch["hips"][i] = euler_yxz(hips_local)
        for j, par in PARENT.items():
            loc = W[par].T @ W[j]
            ch[j][i] = euler_xyz(loc) if j in HINGES else euler_yxz(loc)
    pitch = np.unwrap(pitch)
    for j in ch:
        ch[j] = np.unwrap(ch[j], axis=0)

    loop = name.startswith(LOOP_PREFIX) or name.endswith(LOOP_SUFFIX)
    # Pés: altura acima do chão do clipe -> contato.
    floor_a = min(feet["LeftFoot"][:, 1].min(), feet["RightFoot"][:, 1].min())
    floor_t = min(feet["LeftToeBase"][:, 1].min(), feet["RightToeBase"][:, 1].min())
    contact = {}
    for side, a_, t_ in (("l", "LeftFoot", "LeftToeBase"), ("r", "RightFoot", "RightToeBase")):
        ha = feet[a_][:, 1] - floor_a
        ht = feet[t_][:, 1] - floor_t
        contact[side] = ((ha < 0.05 * hips_h) | (ht < 0.025 * hips_h)).astype(float)
    # Deslocamento do quadril: com movimento (sem "In Place") vira velocidade e sai da raiz.
    t = np.arange(n) / fps
    disp = hips_pos[-1] - hips_pos[0]
    horiz = math.hypot(disp[0], disp[2])
    root_motion = horiz > 0.3 * hips_h
    pos = hips_pos.copy()
    if loop:
        if root_motion:
            vel = disp / max(t[-1], 1e-3)
            pos[:, 0] -= vel[0] * t
            pos[:, 2] -= vel[2] * t
        pos[:, 0] -= pos[:, 0].mean()
        pos[:, 2] -= pos[:, 2].mean()
    else:
        pos[:, 0] = 0.0  # físico do jogo move o corpo; o clipe só sobe/desce e gira
        pos[:, 2] = 0.0
    root = np.zeros((n, 3))
    for i in range(n):
        p = pos[i]
        root[i] = rot_x(pitch[i]).T @ p / hips_h - np.array([0, 1.0, 0])

    data = {"name": name, "fps": fps, "loop": loop}
    if loop:
        # Ciclo fechado: tira o último quadro se repetir o primeiro e começa no toque do pé esquerdo.
        if n > 2 and np.abs(ch["hips"][-1] - ch["hips"][0]).max() < math.radians(2.0) and \
                np.abs(ch["th_l"][-1] - ch["th_l"][0]).max() < math.radians(2.0):
            n -= 1
            for d in (ch, contact):
                for k in d:
                    d[k] = d[k][:n]
            pitch, root = pitch[:n], root[:n]
            t = t[:n]
        # Contato refinado (ciclos em movimento): pé baixo E parado em relação ao chão. Num clipe "In Place"
        # o chão corre para trás na velocidade do clipe; com deslocamento, o chão está parado.
        est = []
        for side, a_ in (("l", "LeftFoot"), ("r", "RightFoot")):
            z = feet[a_][:n, 2]
            dz = -(np.roll(z, -1) - z) * fps
            est.extend(dz[contact[side][:n] > 0.5].tolist())
        v_est = horiz / max(t[-1], 1e-3) if root_motion else max(float(np.median(est)) if est else 0.0, 0.0)
        if v_est > 0.3:
            ground = 0.0 if root_motion else -v_est
            for side, a_, t_ in (("l", "LeftFoot", "LeftToeBase"), ("r", "RightFoot", "RightToeBase")):
                z = feet[a_][:n, 2]
                vz = (np.roll(z, -1) - z) * fps
                vz[-1] = vz[-2]  # emenda do ciclo
                # Só o tornozelo: na saída o calcanhar sobe com os dedos ainda no chão, e a trava (que segura o
                # tornozelo) esticaria a perna. Esse trecho fica para o clipe.
                low = (feet[a_][:n, 1] - floor_a) < 0.06 * hips_h
                still = np.abs(vz - ground) < 0.35 * max(v_est, 0.6)
                c = (low & still).astype(float)
                c = ((np.roll(c, 1) + c + np.roll(c, -1)) >= 2.0).astype(float)  # tira piscadas de 1 quadro
                contact[side] = c
        # Onde o pé pousa: distância à frente do quadril no instante do toque (média dos toques).
        ahead = []
        for side, a_ in (("l", "LeftFoot"), ("r", "RightFoot")):
            cs = contact[side]
            for i in range(n):
                if cs[i] > 0.5 and cs[i - 1] < 0.5:
                    ahead.append(feet[a_][i, 2] - hips_pos[i, 2])
        data["touch_ahead"] = float(np.mean(ahead)) / hips_h if ahead else 0.0
        cl = contact["l"]
        starts = [i for i in range(n) if cl[i] > 0.5 and cl[i - 1] < 0.5]
        s0 = starts[0] if starts else 0
        for d in (ch, contact):
            for k in d:
                d[k] = np.roll(d[k], -s0, axis=0)
        pitch = np.roll(pitch, -s0)
        root = np.roll(root, -s0, axis=0)
        for k in ch:  # emenda contínua no fim do ciclo (sem salto de 360°)
            ch[k] = np.unwrap(ch[k], axis=0)
        pitch = np.unwrap(pitch)
        # Velocidade natural do ciclo: com movimento, a do quadril; no lugar, a do pé de apoio indo para trás.
        if root_motion:
            speed = horiz / max(t[-1], 1e-3)
        else:
            vs = []
            for side, a_ in (("l", "LeftFoot"), ("r", "RightFoot")):
                z = np.roll(feet[a_][:n, 2], -s0)
                dz = -(np.roll(z, -1) - z) * fps
                c = contact[side] > 0.5
                c &= np.roll(contact[side], -1) > 0.5
                vs.extend(dz[c].tolist())
            speed = float(np.median(vs)) if vs else 0.0
            speed = max(speed, 0.0)
        duration = n / fps
        # Clipes do Mixamo podem ter vários ciclos seguidos: cada um começa num toque do pé esquerdo.
        cl2 = contact["l"]
        cyc = [i for i in range(n) if cl2[i] > 0.5 and cl2[i - 1] < 0.5] or [0]
        if cyc[0] != 0:
            cyc = [0] + cyc
        data["cycle_starts"] = [i / n for i in cyc]
        data["speed"] = speed / hips_h  # em alturas de quadril por segundo
        data["cycle_dist"] = speed * duration / len(cyc) / hips_h  # de UM ciclo (2 passos)
        log(f"{name}: pé pousa {data['touch_ahead'] * hips_h:.2f} m à frente do quadril {np.round(ahead, 2).tolist()}")
        log(f"{name}: {len(cyc)} ciclo(s) em {duration:.2f}s, velocidade {speed:.2f} m/s ({speed / hips_h:.2f} quadris/s), "
            f"apoio esq {contact['l'].mean() * 100:.0f}% dir {contact['r'].mean() * 100:.0f}%")
    else:
        both_off = (contact["l"] < 0.5) & (contact["r"] < 0.5)
        markers = {}
        if both_off.any() and "jump" in name and "attack" not in name:
            tk = int(np.argmax(both_off))
            after = np.nonzero(~both_off[tk:])[0]
            ld = tk + int(after[0]) if len(after) else n - 1
            ap = tk + int(np.argmax(hips_pos[tk:ld + 1, 1]))
            markers = {"takeoff": tk / (n - 1), "apex": ap / (n - 1), "land": ld / (n - 1)}
        # Trecho ativo (esquivas): rolamento = do começo do giro até completar 340°; outros = enquanto o
        # quadril se desloca (> 25% da velocidade máxima). O resto (preparar/levantar) fica de fora.
        dp = np.degrees(pitch - pitch[0])
        if np.abs(dp).max() > 180.0:
            s_i = int(np.argmax(np.abs(dp) > 20.0))  # já mergulhando (agachar antes fica de fora)
            e_i = int(np.argmax(np.abs(dp) >= 340.0))
            s_i, e_i = max(s_i - 1, 0), min(e_i + 2, n - 1)
        else:
            hv = np.zeros(n)
            hv[1:] = np.hypot(np.diff(hips_pos[:, 0]), np.diff(hips_pos[:, 2])) * fps
            hv = np.convolve(hv, np.ones(5) / 5.0, mode="same")
            act = np.nonzero(hv > hv.max() * 0.25)[0] if hv.max() > 0.05 else np.arange(n)
            s_i, e_i = max(int(act[0]) - 2, 0), min(int(act[-1]) + 3, n - 1)
        if any(k in name for k in STRIKE_CLIPS + HOLD_CLIPS):
            s_i, e_i, imp = attack_markers(ch, n, name)
            markers["impact"] = imp / (n - 1)
            if any(k in name for k in MULTI_CLIPS):
                markers["hits"] = multi_hits(ch, n, fps)
        markers["start"] = s_i / (n - 1)
        markers["end"] = e_i / (n - 1)
        log(f"{name}: trecho ativo {(e_i - s_i) / fps:.2f}s")
        data["markers"] = markers
        log(f"{name}: {n / fps:.2f}s, marcadores {', '.join(f'{k}={v:.2f}' for k, v in markers.items() if not isinstance(v, list)) + f", {len(markers.get('hits', []))} golpes"}")

    deg = lambda a: np.round(np.degrees(a), 2).tolist()
    data["frames"] = n
    data["channels"] = {j: deg(ch[j]) for j in ch}
    data["pitch"] = np.round(np.degrees(pitch), 2).tolist()
    data["root"] = np.round(root, 4).tolist()
    data["contact_l"] = contact["l"].astype(int).tolist()
    data["contact_r"] = contact["r"].astype(int).tolist()
    os.makedirs(out_dir, exist_ok=True)
    with open(os.path.join(out_dir, name + ".json"), "w", encoding="utf-8") as f:
        json.dump(data, f, separators=(",", ":"))
    log(f"{name}: salvo")


def main():
    argv = sys.argv[sys.argv.index("--") + 1:]
    p = argparse.ArgumentParser()
    p.add_argument("--src", required=True)
    p.add_argument("--out", required=True)
    a = p.parse_args(argv)
    files = sorted(f for f in os.listdir(a.src) if f.lower().endswith(".fbx"))
    if not files:
        log("nenhum .fbx em", a.src)
    for f in files:
        convert(os.path.join(a.src, f), os.path.abspath(a.out))


main()
