"""Nós do Project Castle para o ComfyUI.

Castle: Vistas do personagem → 3D (textura)
    Aceita UMA das entradas (escolha no "modo"):
      - "folha": uma imagem com as vistas lado a lado (frente, lado esquerdo, lado direito, costas — a ordem é
        configurável). Ela é dividida sozinha: cada figura é achada pelas pernas e os pedaços que vazam da
        vizinha (ex.: braço esticado) são apagados.
      - "frente" e (opcional) "costas": duas imagens separadas.
    Cada vista tem o fundo removido (modelo de remoção de fundo) e vai para um quadro quadrado preto na mesma
    escala (a maior medida do corpo ocupa 1/1,1 do quadro, centralizado pelas pernas) — o enquadramento que o
    Pixal3D/TRELLIS.2 espera. Sai o condicionamento multivista do Pixal3D (forma + textura, um modelo só).
"""
import math
from collections import deque

import numpy as np
import torch

MODES = ["folha com 4 vistas", "frente e costas"]
ORDERS = ["frente, lado, costas (3 vistas)", "frente, esquerda, direita, costas", "frente, direita, esquerda, costas",
          "frente, costas, esquerda, direita", "frente, esquerda, costas, direita"]
VIEW_KEYS = {"frente": "front", "esquerda": "left", "costas": "back", "direita": "right"}


# --- Divisão da folha ------------------------------------------------------------------------------

def _components(mask: np.ndarray) -> np.ndarray:
    """Rótulos de componentes ligados (vizinhança 4) — sem scipy."""
    h, w = mask.shape
    lab = np.zeros((h, w), dtype=np.int32)
    cur = 0
    ys, xs = np.nonzero(mask)
    for y0, x0 in zip(ys, xs):
        if lab[y0, x0]:
            continue
        cur += 1
        lab[y0, x0] = cur
        q = deque([(y0, x0)])
        while q:
            y, x = q.popleft()
            for ny, nx in ((y - 1, x), (y + 1, x), (y, x - 1), (y, x + 1)):
                if 0 <= ny < h and 0 <= nx < w and mask[ny, nx] and not lab[ny, nx]:
                    lab[ny, nx] = cur
                    q.append((ny, nx))
    return lab


def _dilate(mask: np.ndarray, it: int) -> np.ndarray:
    m = mask.copy()
    for _ in range(it):
        n = m.copy()
        n[1:] |= m[:-1]
        n[:-1] |= m[1:]
        n[:, 1:] |= m[:, :-1]
        n[:, :-1] |= m[:, 1:]
        m = n
    return m


def split_sheet(img: np.ndarray, views: int = 4, threshold: float = 40.0, mask: np.ndarray = None):
    """img: HxWx3 float 0..255. Devolve `views` recortes (HxWx3) com o fundo da folha no que não é da figura, da
    esquerda para a direita. mask (HxW bool, opcional): figura x fundo (ex.: remoção de fundo por IA — ignora sombra
    no chão e fundo em degradê); sem ela, compara com a cor do fundo."""
    H, W, _ = img.shape
    border = np.concatenate([img[:10].reshape(-1, 3), img[-10:].reshape(-1, 3),
                             img[:, :10].reshape(-1, 3), img[:, -10:].reshape(-1, 3)])
    bg = np.median(border, axis=0)
    fig = mask if mask is not None else np.abs(img - bg).sum(axis=2) > threshold
    # Colunas das pernas (faixa de baixo): braços esticados não juntam figuras ali.
    band = fig[int(H * 0.55):int(H * 0.97)]
    occ = band.sum(axis=0) > max(3, H * 0.002)
    runs, s = [], None
    for x in range(W):
        if occ[x] and s is None:
            s = x
        elif not occ[x] and s is not None:
            runs.append([s, x])
            s = None
    if s is not None:
        runs.append([s, W])
    runs = [r for r in runs if r[1] - r[0] > W * 0.01]
    while len(runs) > views:  # junta as duas pernas da mesma figura (vão pequeno entre elas)
        gaps = [runs[i + 1][0] - runs[i][1] for i in range(len(runs) - 1)]
        k = int(np.argmin(gaps))
        runs[k] = [runs[k][0], runs[k + 1][1]]
        del runs[k + 1]
    if len(runs) < views:  # não achou as figuras separadas: partes iguais
        runs = [[int(W * (i + 0.05) / views), int(W * (i + 0.95) / views)] for i in range(views)]
    f = max(1, int(round(max(H, W) / 700)))
    lab = _components(_dilate(fig[::f, ::f], 2))
    lab_full = np.kron(lab, np.ones((f, f), dtype=np.int32))[:H, :W]
    out = []
    for a, b in runs:
        ids = set(np.unique(lab_full[int(H * 0.85), a:b])) | set(np.unique(lab_full[int(H * 0.7), a:b]))
        ids.discard(0)
        keep = np.isin(lab_full, list(ids)) if ids else np.zeros_like(fig)
        xs = np.nonzero(keep.any(axis=0))[0]
        x0, x1 = (int(xs.min()), int(xs.max()) + 1) if len(xs) else (a, b)
        rgb = img.copy()
        rgb[~keep] = bg
        out.append(rgb[:, max(0, x0 - 10):min(W, x1 + 10)])
    return out


# --- Enquadramento ---------------------------------------------------------------------------------

def frame_view(rgb: np.ndarray, alpha: np.ndarray, size: int, fill: float = 1 / 1.1, bg: float = 0.0) -> np.ndarray:
    """Figura (rgb 0..1, alpha 0..1) num quadro size x size de fundo `bg`: a maior medida do corpo ocupa `fill`
    do quadro; centralizada na vertical e, na horizontal, pelas pernas (braço esticado não desloca o corpo)."""
    m = alpha > 0.5
    rows = np.nonzero(m.any(axis=1))[0]
    if len(rows) == 0:
        return np.full((size, size, 3), bg, dtype=np.float32)
    y0, y1 = int(rows.min()), int(rows.max()) + 1
    legs = m[y0 + int((y1 - y0) * 0.6):y0 + int((y1 - y0) * 0.95)]
    cols = np.nonzero(legs.any(axis=0))[0]
    if len(cols) == 0:
        cols = np.nonzero(m.any(axis=0))[0]
    cx = (cols.min() + cols.max()) / 2.0
    all_cols = np.nonzero(m.any(axis=0))[0]
    half_w = max(cx - all_cols.min(), all_cols.max() + 1 - cx)
    comp = rgb * alpha[..., None] + bg * (1.0 - alpha[..., None])
    scale = size * fill / max(y1 - y0, 2 * half_w)
    t = torch.from_numpy(comp.astype(np.float32)).permute(2, 0, 1)[None]
    nh, nw = max(1, int(round(rgb.shape[0] * scale))), max(1, int(round(rgb.shape[1] * scale)))
    t = torch.nn.functional.interpolate(t, size=(nh, nw), mode="bilinear", align_corners=False, antialias=True)
    small = t[0].permute(1, 2, 0).numpy()
    canvas = np.full((size, size, 3), bg, dtype=np.float32)
    top = int(round(size / 2 - (y0 + y1) / 2 * scale))
    left = int(round(size / 2 - cx * scale))
    sy0, sx0 = max(0, -top), max(0, -left)
    dy0, dx0 = max(0, top), max(0, left)
    h = min(nh - sy0, size - dy0)
    w = min(nw - sx0, size - dx0)
    if h > 0 and w > 0:
        canvas[dy0:dy0 + h, dx0:dx0 + w] = small[sy0:sy0 + h, sx0:sx0 + w]
    return canvas


def _faces_right(img: np.ndarray) -> bool:
    """Vista de perfil: os dedos do pé apontam para onde ela olha. Compara a ponta dos pés (faixa de baixo) com o
    eixo da canela (cabelo comprido não atrapalha, ao contrário de olhar a cabeça/peito)."""
    border = np.concatenate([img[:5].reshape(-1, 3), img[-5:].reshape(-1, 3)])
    bg = np.median(border, axis=0)
    fig = np.abs(img - bg).sum(axis=2) > 0.15
    rows = np.nonzero(fig.any(axis=1))[0]
    if len(rows) == 0:
        return False
    y0, y1 = rows.min(), rows.max()
    h = y1 - y0
    shin = np.nonzero(fig[y0 + int(h * 0.8):y0 + int(h * 0.88)].any(axis=0))[0]
    feet = np.nonzero(fig[y0 + int(h * 0.97):y1 + 1].any(axis=0))[0]
    if len(shin) == 0 or len(feet) == 0:
        return False
    cx = (shin.min() + shin.max()) / 2.0
    return bool(feet.max() - cx > cx - feet.min())


def prepare_views(mask_fn, modo, ordem_da_folha, usar_laterais, folha=None, frente=None, costas=None, size=1024,
                  drop_bad_sides=True):
    """Vistas prontas para o Pixal3D: {nome: IMAGE 1 x size x size x 3, fundo preto}."""
    views = {}
    if modo == MODES[0]:
        if folha is None:
            raise ValueError("Modo 'folha com 4 vistas': ligue a imagem da folha.")
        three = "3 vistas" in ordem_da_folha
        sheet = folha[:1, ..., :3]
        m = mask_fn(sheet)
        m = m.reshape(-1, *m.shape[-2:]).float()
        if tuple(m.shape[-2:]) != tuple(sheet.shape[1:3]):
            m = torch.nn.functional.interpolate(m[:, None], size=sheet.shape[1:3], mode="bilinear")[:, 0]
        parts = split_sheet(sheet[0].cpu().numpy() * 255.0, 3 if three else 4, mask=m[0].cpu().numpy() > 0.5)
        names = ["frente", "esquerda", "costas"] if three else [n.strip() for n in ordem_da_folha.split(",")]
        for n, p in zip(names, parts):
            views[n] = torch.from_numpy((p / 255.0).astype(np.float32))[None]
        if three:
            # Vista de lado: se ela olha para a direita da imagem, é o lado direito. O outro lado = espelho
            # (personagem simétrico).
            side = views.pop("esquerda")
            if _faces_right(side[0].numpy()):
                side = torch.flip(side, dims=[2])
            views["esquerda"] = side
            views["direita"] = torch.flip(side, dims=[2])
    else:
        if frente is None:
            raise ValueError("Modo 'frente e costas': ligue pelo menos a imagem de 'frente'.")
        views["frente"] = frente[:1]
        if costas is not None:
            views["costas"] = costas[:1]
    if not usar_laterais:
        views.pop("esquerda", None)
        views.pop("direita", None)
    out = {n: frame_with_mask(img, mask_fn, size) for n, img in views.items()}
    if drop_bad_sides and sides_need_fix(out):
        print("[Castle] vista de lado com braço esticado à frente (pose diferente da frente): laterais ignoradas")
        out.pop("esquerda", None)
        out.pop("direita", None)
    return out


def sides_need_fix(views: dict) -> bool:
    return any(n in views and _arms_forward(views[n][0].numpy()) for n in ("esquerda", "direita"))


def arm_region(view: np.ndarray) -> np.ndarray:
    """Máscara (HxW float) da região do braço esticado numa vista de perfil, para repintar: do ombro à cintura, do eixo
    do tronco até a ponta do braço (dos dois lados — o braço pode estar à frente ou atrás), com folga."""
    fig = view.max(axis=2) > 0.02
    H, W = fig.shape
    rows = np.nonzero(fig.any(axis=1))[0]
    m = np.zeros((H, W), dtype=np.float32)
    if len(rows) == 0:
        return m
    y0, y1 = rows.min(), rows.max()
    h = y1 - y0
    shin = np.nonzero(fig[y0 + int(h * 0.8):y0 + int(h * 0.88)].any(axis=0))[0]
    cx = (shin.min() + shin.max()) / 2.0 if len(shin) else W / 2
    ya, yb = y0 + int(h * 0.15), y0 + int(h * 0.58)  # do ombro (rosto fica de fora) até o quadril
    band = np.nonzero(fig[ya:yb].any(axis=0))[0]
    if len(band) == 0:
        return m
    # Lado do braço = o que mais se projeta na altura dos ombros; do outro lado só até perto do eixo do corpo
    # (o cabelo das costas fica de fora).
    sh = np.nonzero(fig[y0 + int(h * 0.14):y0 + int(h * 0.32)].any(axis=0))[0]
    right = (sh.max() - cx) > (cx - sh.min()) if len(sh) else True
    if right:
        x0, x1 = int(cx - 0.08 * h), int(band.max()) + 1
    else:
        x0, x1 = int(band.min()), int(cx + 0.08 * h)
    pad = int(0.02 * h)
    m[ya:min(H, yb + pad), max(0, x0 - pad):min(W, x1 + pad)] = 1.0
    return m


def frame_with_mask(img, mask_fn, size=1024):
    """IMAGE 1xHxWx3 -> IMAGE 1 x size x size x 3: figura recortada pela máscara de fundo e enquadrada (fundo preto)."""
    img = img[..., :3]
    mask = mask_fn(img)
    mask = mask.reshape(-1, *mask.shape[-2:]).float()
    if tuple(mask.shape[-2:]) != tuple(img.shape[1:3]):
        mask = torch.nn.functional.interpolate(mask[:, None], size=img.shape[1:3], mode="bilinear")[:, 0]
    return torch.from_numpy(frame_view(img[0].cpu().numpy(), mask[0].cpu().numpy(), size))[None]


def _arms_forward(view: np.ndarray) -> bool:
    """Vista de perfil (fundo preto): algo sai muito à frente/atrás do corpo na altura do peito/barriga = braço
    esticado (pose diferente da vista de frente)."""
    fig = view.max(axis=2) > 0.02
    rows = np.nonzero(fig.any(axis=1))[0]
    if len(rows) == 0:
        return False
    y0, y1 = rows.min(), rows.max()
    h = y1 - y0
    shin = np.nonzero(fig[y0 + int(h * 0.8):y0 + int(h * 0.88)].any(axis=0))[0]
    if len(shin) == 0:
        return False
    cx = (shin.min() + shin.max()) / 2.0
    band = np.nonzero(fig[y0 + int(h * 0.12):y0 + int(h * 0.5)].any(axis=0))[0]
    reach = max(band.max() - cx, cx - band.min()) if len(band) else 0.0
    return bool(reach > 0.18 * h)


class CastleViewsTo3D:
    @classmethod
    def INPUT_TYPES(cls):
        return {
            "required": {
                "clip_vision": ("CLIP_VISION", {"tooltip": "Load CLIP Vision: dino_v3_L_naf_fp32."}),
                "bg_removal_model": ("BACKGROUND_REMOVAL", {"tooltip": "Load Background Removal Model (birefnet)."}),
                "modo": (MODES, {"default": MODES[0], "tooltip":
                         "'folha com 4 vistas' usa a imagem 'folha'; 'frente e costas' usa as imagens 'frente' e 'costas'."}),
                "ordem_da_folha": (ORDERS, {"default": ORDERS[0], "tooltip":
                                   "Ordem das figuras na folha, da esquerda para a direita. 'esquerda' = a vista em que "
                                   "aparece o lado ESQUERDO dela (ela olha para a esquerda da imagem)."}),
                "usar_laterais": ("BOOLEAN", {"default": True, "tooltip":
                                  "Desligue se as vistas de lado têm pose diferente da frente (ex.: braço esticado)."}),
                "fov": ("FLOAT", {"default": 20.0, "min": 1.0, "max": 90.0, "step": 0.5, "tooltip":
                        "Abertura da câmera das vistas: 20 para desenhos/folhas (quase sem perspectiva); "
                        "fotos com perspectiva forte: 40-50."}),
            },
            "optional": {
                "folha": ("IMAGE", {"tooltip": "Uma imagem com as 4 vistas lado a lado."}),
                "frente": ("IMAGE", {"tooltip": "Imagem de frente (modo 'frente e costas')."}),
                "costas": ("IMAGE", {"tooltip": "Imagem de costas (opcional)."}),
            },
        }

    RETURN_TYPES = ("CONDITIONING", "CONDITIONING", "IMAGE")
    RETURN_NAMES = ("positive", "negative", "vistas")
    FUNCTION = "run"
    CATEGORY = "Castle"
    DESCRIPTION = ("Folha de personagem (4 vistas) OU frente + costas → fundo removido, mesma escala → "
                   "condicionamento multivista do Pixal3D (um modelo, com textura).")

    def run(self, clip_vision, bg_removal_model, modo, ordem_da_folha, usar_laterais, fov, folha=None, frente=None,
            costas=None):
        vistas = drop_bad_sides(CastlePrepareViews().run(bg_removal_model, modo, ordem_da_folha, usar_laterais, folha,
                                                         frente, costas)[0])
        pos, neg = CastleConditioning3D().run(clip_vision, vistas, fov)
        return (pos, neg, vistas)


VIEW_ORDER = ["frente", "esquerda", "costas", "direita"]
VIEW_PHRASE = {"frente": "front view, facing the viewer", "esquerda": "side profile view, looking to the left",
               "costas": "back view, seen from behind, face not visible", "direita": "side profile view, looking to the right"}


class CastlePrepareViews:
    @classmethod
    def INPUT_TYPES(cls):
        return {
            "required": {
                "bg_removal_model": ("BACKGROUND_REMOVAL", {"tooltip": "Load Background Removal Model (birefnet)."}),
                "modo": (MODES, {"default": MODES[0], "tooltip":
                         "'folha com 4 vistas' usa a imagem 'folha' (3 ou 4 vistas lado a lado); 'frente e costas' usa "
                         "as imagens 'frente' e 'costas'."}),
                "ordem_da_folha": (ORDERS, {"default": ORDERS[0], "tooltip":
                                   "Ordem das figuras na folha, da esquerda para a direita. 'esquerda' = a vista em que "
                                   "aparece o lado ESQUERDO dela (ela olha para a esquerda da imagem)."}),
                "usar_laterais": ("BOOLEAN", {"default": True, "tooltip":
                                  "Usa as vistas de lado. Se o braço estiver esticado nelas (pose diferente da frente), o "
                                  "passo 2 repinta o braço para baixo; se não der, elas são ignoradas."}),
            },
            "optional": {
                "folha": ("IMAGE", {"tooltip": "Uma imagem com as vistas lado a lado."}),
                "frente": ("IMAGE", {"tooltip": "Imagem de frente (modo 'frente e costas')."}),
                "costas": ("IMAGE", {"tooltip": "Imagem de costas (opcional)."}),
            },
        }

    RETURN_TYPES = ("IMAGE", "BOOLEAN")
    RETURN_NAMES = ("vistas", "laterais_a_corrigir")
    FUNCTION = "run"
    CATEGORY = "Castle"
    DESCRIPTION = ("Divide a folha (ou usa frente/costas), tira o fundo e enquadra cada vista na mesma escala (fundo "
                   "preto). Avisa (laterais_a_corrigir) se as vistas de lado estão com o braço esticado.")

    def run(self, bg_removal_model, modo, ordem_da_folha, usar_laterais, folha=None, frente=None, costas=None):
        views = prepare_views(bg_removal_model.encode_image, modo, ordem_da_folha, usar_laterais, folha, frente, costas,
                              drop_bad_sides=False)
        bad = sides_need_fix(views)
        if bad:
            print("[Castle] vistas de lado com braço esticado: o passo 2 vai repintar o braço para baixo")
        return (torch.cat([views[n] for n in VIEW_ORDER if n in views], dim=0), bad)


def views_dict(vistas: torch.Tensor) -> dict:
    names = VIEWS_BY_COUNT.get(int(vistas.shape[0]), VIEW_ORDER[:int(vistas.shape[0])])
    return {n: vistas[k:k + 1, ..., :3] for k, n in enumerate(names)}


def drop_bad_sides(vistas: torch.Tensor) -> torch.Tensor:
    """Se ainda houver vista de lado com braço esticado, fica só frente/costas (evita braço aberto no modelo)."""
    v = views_dict(vistas)
    if sides_need_fix(v):
        print("[Castle] vistas de lado ainda com braço esticado: usando só frente e costas")
        v.pop("esquerda", None)
        v.pop("direita", None)
        return torch.cat([v[n] for n in VIEW_ORDER if n in v], dim=0)
    return vistas


class CastleRefineViews:
    @classmethod
    def INPUT_TYPES(cls):
        return {
            "required": {
                "vistas": ("IMAGE",),
                "model": ("MODEL", {"lazy": True, "tooltip": "Z-Image Turbo (depois do ModelSamplingAuraFlow). Só é "
                                                              "carregado se houver texto ou lateral a corrigir."}),
                "clip": ("CLIP", {"lazy": True, "tooltip": "qwen_3_4b (CLIPLoader tipo lumina2)."}),
                "vae": ("VAE", {"lazy": True, "tooltip": "ae.safetensors"}),
                "bg_removal_model": ("BACKGROUND_REMOVAL",),
                "quero": ("STRING", {"multiline": True, "default": "", "tooltip":
                          "O que você quer no modelo (opcional, inglês funciona melhor). Ex.: 'smooth skin, detailed "
                          "face, dark green bikini'. Com 'quero' e 'não quero' vazios as vistas passam sem mudança."}),
                "nao_quero": ("STRING", {"multiline": True, "default": "", "tooltip":
                              "O que você NÃO quer (opcional). Ex.: 'black outline, line art, harsh shadows, tattoos'."}),
                "forca": ("FLOAT", {"default": 0.4, "min": 0.05, "max": 0.9, "step": 0.05, "tooltip":
                          "Quanto cada vista pode mudar com o texto: 0,2-0,3 só limpa; 0,4-0,5 muda detalhes; acima de "
                          "0,6 muda a pose e pode perder a cara do personagem."}),
                "corrigir_braco_lateral": ("BOOLEAN", {"default": False, "tooltip":
                                           "Experimental: repinta o braço esticado das vistas de lado para baixo em vez de "
                                           "descartá-las. Pode duplicar braços no modelo (a pose do lado não bate com a "
                                           "da frente); desligado = laterais com braço esticado são ignoradas."}),
                "forca_braco": ("FLOAT", {"default": 0.9, "min": 0.5, "max": 1.0, "step": 0.05, "tooltip":
                                "Repintura do braço nas vistas de lado (só a região do braço muda). Mais alto = mais "
                                "liberdade para baixar o braço."}),
                "seed": ("INT", {"default": 0, "min": 0, "max": 0xffffffffffffffff, "control_after_generate": True}),
                "passos": ("INT", {"default": 9, "min": 4, "max": 30}),
            },
            "optional": {
                "laterais_a_corrigir": ("BOOLEAN", {"forceInput": True, "tooltip": "Do passo 1."}),
            },
        }

    RETURN_TYPES = ("IMAGE",)
    RETURN_NAMES = ("vistas",)
    FUNCTION = "run"
    CATEGORY = "Castle"
    DESCRIPTION = ("Opcional: refaz cada vista com o Z-Image seguindo o que você quer / não quer, e repinta o braço "
                   "esticado das vistas de lado para baixo. Sem texto e sem lateral a corrigir, não faz nada.")

    def check_lazy_status(self, quero, nao_quero, corrigir_braco_lateral=False, model=None, clip=None, vae=None,
                          laterais_a_corrigir=False, **kwargs):
        if not quero.strip() and not nao_quero.strip() and not (laterais_a_corrigir and corrigir_braco_lateral):
            return []  # nada a fazer: não carrega o Z-Image
        return [n for n, v in (("model", model), ("clip", clip), ("vae", vae)) if v is None]

    def _sample(self, nodes, model, clip, vae, img, text, nao_quero, denoise, seed, passos, noise_mask=None):
        pos = nodes.CLIPTextEncode().encode(clip, text)[0]
        if nao_quero:
            neg = nodes.CLIPTextEncode().encode(clip, nao_quero)[0]
            cfg = 2.0  # Z-Image Turbo: o negativo só age com cfg > 1
        else:
            neg = nodes.ConditioningZeroOut().zero_out(pos)[0]
            cfg = 1.0
        lat = {"samples": vae.encode(img[..., :3])}
        if noise_mask is not None:
            lat["noise_mask"] = noise_mask
        res = nodes.common_ksampler(model, seed, passos, cfg, "res_multistep", "simple", pos, neg, lat, denoise=denoise)[0]
        dec = vae.decode(res["samples"])
        return dec.reshape(-1, *dec.shape[-3:])[:1, ..., :3].float().clamp(0, 1)

    def run(self, vistas, bg_removal_model, quero, nao_quero, forca, corrigir_braco_lateral, forca_braco, seed, passos,
            model=None, clip=None, vae=None, laterais_a_corrigir=False):
        quero, nao_quero = quero.strip(), nao_quero.strip()
        laterais_a_corrigir = bool(laterais_a_corrigir and corrigir_braco_lateral)
        if not quero and not nao_quero and not laterais_a_corrigir:
            return (drop_bad_sides(vistas),)
        import nodes
        size = int(vistas.shape[1])
        views = views_dict(vistas)
        out = {}
        for k, (n, img) in enumerate(views.items()):
            if laterais_a_corrigir and n in ("esquerda", "direita") and _arms_forward(img[0].cpu().numpy()):
                # Repinta só a região do braço: braços para baixo, ao lado do corpo.
                region = torch.from_numpy(arm_region(img[0].cpu().numpy()))[None]
                text = ("High quality 3D game character render, " + VIEW_PHRASE[n] + ", full body, standing straight "
                        "with both arms hanging straight down along the sides of the body, hands next to the thighs, "
                        "arms not raised, plain pure black background. " + quero)
                img = self._sample(nodes, model, clip, vae, img, text, nao_quero, forca_braco, seed + 100 + k, passos,
                                   noise_mask=region)
                img = frame_with_mask(img, bg_removal_model.encode_image, size)
            if quero or nao_quero:
                text = ("High quality 3D game character render, clean smooth shading, " + VIEW_PHRASE[n] + ", full body, "
                        "standing in a relaxed A-pose with arms down, plain pure black background. " + quero)
                img = self._sample(nodes, model, clip, vae, img, text, nao_quero, forca, seed + k, passos)
                img = frame_with_mask(img, bg_removal_model.encode_image, size)  # mesma escala das outras
            out[n] = img
        return (drop_bad_sides(torch.cat([out[n] for n in VIEW_ORDER if n in out], dim=0)),)


class CastleConditioning3D:
    @classmethod
    def INPUT_TYPES(cls):
        return {
            "required": {
                "clip_vision": ("CLIP_VISION", {"tooltip": "Load CLIP Vision: dino_v3_L_naf_fp32."}),
                "vistas": ("IMAGE",),
                "fov": ("FLOAT", {"default": 20.0, "min": 1.0, "max": 90.0, "step": 0.5, "tooltip":
                        "Abertura da câmera das vistas: 20 para desenhos/folhas; fotos com perspectiva forte: 40-50."}),
            }
        }

    RETURN_TYPES = ("CONDITIONING", "CONDITIONING")
    RETURN_NAMES = ("positive", "negative")
    FUNCTION = "run"
    CATEGORY = "Castle"
    DESCRIPTION = "Condicionamento multivista do Pixal3D/TRELLIS.2 a partir das vistas (um modelo só)."

    def run(self, clip_vision, vistas, fov):
        from comfy_extras.nodes_trellis2 import Pixal3DMultiViewConditioning
        v = views_dict(drop_bad_sides(vistas))
        out = Pixal3DMultiViewConditioning.execute(clip_vision, fov, **{VIEW_KEYS[n]: img for n, img in v.items()})
        return (out.result[0], out.result[1])


# --- Projeção das vistas na textura -----------------------------------------------------------------

# Vistas do lote "vistas" do nó acima, pela quantidade: sempre na ordem frente, esquerda, costas, direita.
VIEWS_BY_COUNT = {1: ["frente"], 2: ["frente", "costas"], 3: ["frente", "esquerda", "costas"],
                  4: ["frente", "esquerda", "costas", "direita"]}
# Direção da câmera de cada vista (espaço da malha = glTF: Y para cima, personagem olhando para +Z,
# esquerda dela em +X).
VIEW_DIRS = {"frente": (0.0, 0.0, 1.0), "esquerda": (1.0, 0.0, 0.0), "costas": (0.0, 0.0, -1.0), "direita": (-1.0, 0.0, 0.0)}


def view_cameras(verts: torch.Tensor, names, fill: float = 1 / 1.1):
    """Câmeras ortográficas que enquadram a malha como frame_view enquadra as imagens: centro vertical no meio da
    altura, centro horizontal no eixo das pernas, e a maior medida (altura ou meia largura x2 a partir das pernas)
    ocupando `fill` do quadro."""
    v = verts.float()
    ymin, ymax = float(v[:, 1].min()), float(v[:, 1].max())
    h = ymax - ymin
    legs = v[(v[:, 1] > ymin + 0.05 * h) & (v[:, 1] < ymin + 0.40 * h)]
    if legs.shape[0] == 0:
        legs = v
    cx = float(legs[:, 0].min() + legs[:, 0].max()) * 0.5
    cz = float(legs[:, 2].min() + legs[:, 2].max()) * 0.5
    cy = (ymin + ymax) * 0.5
    cams = []
    for n in names:
        d = VIEW_DIRS[n]
        horiz = v[:, 2] - cz if d[0] != 0.0 else v[:, 0] - cx
        size = max(h, 2.0 * float(horiz.abs().max()))
        half = size / fill * 0.5
        dist = 3.0 * size
        fov = math.degrees(2.0 * math.atan(half / dist))
        cams.append({"position": {"x": cx + d[0] * dist, "y": cy, "z": cz + d[2] * dist},
                     "target": {"x": cx, "y": cy, "z": cz}, "up": {"x": 0.0, "y": 1.0, "z": 0.0},
                     "fov": fov, "zoom": 1.0, "cameraType": "orthographic"})
    return cams


class CastleProjectViews:
    @classmethod
    def INPUT_TYPES(cls):
        return {
            "required": {
                "mesh": ("MESH", {"tooltip": "Malha com UV e textura (saída do Apply Texture to Mesh)."}),
                "vistas": ("IMAGE", {"tooltip": "Saída 'vistas' do nó Castle: Vistas do personagem."}),
                "resolucao": ("INT", {"default": 2048, "min": 512, "max": 8192, "step": 256}),
                "nitidez": ("FLOAT", {"default": 6.0, "min": 0.0, "max": 32.0, "step": 0.5, "tooltip":
                            "Mais alto = cada ponto usa a vista mais de frente para ele (mais nítido, emendas mais "
                            "duras); mais baixo = mistura as vistas (mais suave)."}),
                "recuo_da_borda": ("INT", {"default": 10, "min": 0, "max": 32, "tooltip":
                                   "Pixels ignorados na borda da figura de cada vista (evita trazer o fundo preto)."}),
            }
        }

    RETURN_TYPES = ("IMAGE", "MASK")
    RETURN_NAMES = ("base_color", "confianca")
    FUNCTION = "run"
    CATEGORY = "Castle"
    DESCRIPTION = ("Pinta a textura com as cores das próprias vistas (frente, lados, costas), projetadas na malha. "
                   "O que nenhuma vista vê fica com a textura gerada.")

    def run(self, mesh, vistas, resolucao, nitidez, recuo_da_borda):
        from comfy_extras.nodes_mesh_postprocess import BakeTextureFromViews
        vistas = drop_bad_sides(vistas)
        names = VIEWS_BY_COUNT.get(int(vistas.shape[0]))
        if names is None:
            raise ValueError(f"Esperava 1, 2, 3 ou 4 vistas; recebi {int(vistas.shape[0])}.")
        cams = view_cameras(mesh.vertices[0], names)
        img = vistas[..., :3].float()
        mask = (img.max(dim=-1).values > 0.02).float()  # fundo preto = fora da figura
        if recuo_da_borda > 0:
            k = 2 * recuo_da_borda + 1
            mask = 1.0 - torch.nn.functional.max_pool2d((1.0 - mask)[:, None], k, stride=1, padding=recuo_da_borda)[:, 0]
        out = BakeTextureFromViews.execute(mesh, img, resolucao, nitidez, fill_unseen=False, camera_info=cams, mask=mask)
        return (out.result[0], out.result[1])


NODE_CLASS_MAPPINGS = {"CastlePrepareViews": CastlePrepareViews, "CastleRefineViews": CastleRefineViews,
                       "CastleConditioning3D": CastleConditioning3D, "CastleProjectViews": CastleProjectViews,
                       "CastleViewsTo3D": CastleViewsTo3D}
NODE_DISPLAY_NAME_MAPPINGS = {"CastlePrepareViews": "Castle: 1. Preparar vistas",
                              "CastleRefineViews": "Castle: 2. Refinar vistas com texto (opcional)",
                              "CastleConditioning3D": "Castle: 3. Vistas para 3D",
                              "CastleProjectViews": "Castle: 4. Pintar textura com as vistas",
                              "CastleViewsTo3D": "Castle: Vistas do personagem para 3D (antigo)"}
