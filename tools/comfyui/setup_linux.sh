#!/usr/bin/env bash
# Instala o ComfyUI com os workflows do Castle em Linux (testado em teoria para CachyOS/Arch; veja README.md).
# Uso:  bash tools/comfyui/setup_linux.sh [pasta_do_comfyui]      (padrão: ~/ComfyUI)
# Pode rodar de novo: pula o que já existe (git pull, links e downloads retomáveis).
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="${1:-$HOME/ComfyUI}"
HF="https://huggingface.co"

echo "==> Pré-requisitos"
for c in git curl; do command -v "$c" >/dev/null || { echo "Falta '$c'. No CachyOS: sudo pacman -S git curl"; exit 1; }; done
command -v uv >/dev/null || { echo "Falta 'uv'. No CachyOS: sudo pacman -S uv"; exit 1; }
command -v nvidia-smi >/dev/null || echo "AVISO: nvidia-smi não encontrado. Instale o driver NVIDIA (CachyOS: chwd -i pci-gpu-nvidia-open ou pacman -S nvidia-open-dkms nvidia-utils)."

echo "==> ComfyUI em $DEST"
if [ -d "$DEST/.git" ]; then git -C "$DEST" pull --ff-only; else git clone https://github.com/comfyanonymous/ComfyUI "$DEST"; fi

echo "==> Ambiente Python (venv) + PyTorch CUDA"
cd "$DEST"
[ -d .venv ] || uv venv --python 3.13 .venv
# shellcheck disable=SC1091
source .venv/bin/activate
uv pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu128
uv pip install -r requirements.txt

echo "==> Nó Castle e workflows (links: atualizar o repositório atualiza o ComfyUI)"
mkdir -p custom_nodes user/default/workflows
ln -sfn "$HERE/custom_nodes/castle_nodes" custom_nodes/castle_nodes
for f in "$HERE"/workflows/*.json; do ln -sf "$f" "user/default/workflows/$(basename "$f")"; done

echo "==> Modelos (~30 GB; retoma se interromper)"
get() {  # get <subpasta> <url> <arquivo>
  mkdir -p "models/$1"
  if [ -s "models/$1/$3" ]; then echo "  já existe: $1/$3"; else echo "  baixando: $1/$3"; curl -L --fail -C - -o "models/$1/$3" "$2"; fi
}
get diffusion_models "$HF/Comfy-Org/Pixal3D/resolve/main/diffusion_models/pixal3d_int8_convrot.safetensors" pixal3d_int8_convrot.safetensors
get vae              "$HF/Comfy-Org/Pixal3D/resolve/main/vae/trellis_2_shape_vae_bf16.safetensors"          trellis_2_shape_vae_bf16.safetensors
get vae              "$HF/Comfy-Org/Pixal3D/resolve/main/vae/trellis_2_texture_vae_bf16.safetensors"        trellis_2_texture_vae_bf16.safetensors
get clip_vision      "$HF/Comfy-Org/Pixal3D/resolve/main/clip_vision/dino_v3_L_naf_fp32.safetensors"        dino_v3_L_naf_fp32.safetensors
get background_removal "$HF/Comfy-Org/BiRefNet/resolve/main/background_removal/birefnet.safetensors"        birefnet.safetensors
get diffusion_models "$HF/Comfy-Org/z_image_turbo/resolve/main/split_files/diffusion_models/z_image_turbo_bf16.safetensors" z_image_turbo_bf16.safetensors
get text_encoders    "$HF/Comfy-Org/z_image_turbo/resolve/main/split_files/text_encoders/qwen_3_4b.safetensors"              qwen_3_4b.safetensors
get vae              "$HF/Comfy-Org/z_image_turbo/resolve/main/split_files/vae/ae.safetensors"                              ae.safetensors

cat <<EOF

Pronto. Para abrir:
  cd "$DEST" && source .venv/bin/activate && python main.py
Depois abra http://127.0.0.1:8188 e, em Workflows, "Castle 1" e "Castle 2".
EOF
