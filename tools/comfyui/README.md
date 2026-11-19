# ComfyUI do Castle (modelagem de personagens por IA)

Dois workflows + um nó próprio. Tudo versionado aqui para levar a outro PC (ex.: CachyOS em casa).

| Arquivo | Para que serve |
|---|---|
| `workflows/Castle 1 - Texto para imagem.json` | Descreve o personagem em texto → folha com 3 vistas (frente, perfil, costas) com o FLUX.2 Klein 4B. **Opcional:** até 6 imagens de referência (personagem, rosto, roupa…) |
| `workflows/Castle 2 - Imagem para modelo 3D.json` | Folha (3 ou 4 vistas) **ou** frente + costas → modelo 3D **com textura** (`.glb`) com Pixal3D/TRELLIS.2. Campos opcionais "Quero / Não quero" |
| `custom_nodes/castle_nodes/` | Nós "Castle: Referências (opcional)", "1. Preparar vistas", "2. Refinar vistas com texto", "3. Vistas para 3D", "4. Pintar textura com as vistas" |
| `setup_linux.sh` | Instala o ComfyUI + links + todos os modelos (Linux) |

## Requisitos
- GPU NVIDIA (RTX 3060 12 GB serve), driver instalado, ~45 GB livres em disco.
- **RAM: 32 GB recomendado.** O Z-Image (12 GB) e o codificador de texto (8 GB) são carregados na RAM e passados à GPU conforme precisa; com menos RAM, ative swap/zram.
- O ComfyUI Desktop não existe para Linux: usa-se o ComfyUI "puro" (o script abaixo instala).

## CachyOS (Arch) — passo a passo
```bash
sudo pacman -S git curl uv                      # uv = gerenciador de Python
# driver NVIDIA (se ainda não tiver): chwd -i pci-gpu-nvidia-open   (ou: sudo pacman -S nvidia-open-dkms nvidia-utils)
git clone <seu repositório> project-castle      # ou: git pull se já tem
bash project-castle/tools/comfyui/setup_linux.sh        # instala em ~/ComfyUI (baixa ~38 GB)
cd ~/ComfyUI && source .venv/bin/activate && python main.py
```
Abra http://127.0.0.1:8188 → **Workflows** → *Castle 1* e *Castle 2*.

O script cria **links**: `~/ComfyUI/custom_nodes/castle_nodes` e os workflows apontam para o repositório. Editar/atualizar o repositório já atualiza o ComfyUI (reinicie o ComfyUI quando o nó `__init__.py` mudar).

> Não testei o script em Linux (só no Windows). Se algo falhar, a causa mais provável é a versão do PyTorch/CUDA: veja a linha `--index-url .../cu128` (para GPUs antigas use `cu126`).

## Usar
1. **Castle 1**: escreva o personagem no quadro verde → *Run* (~15 s) → `output/castle/conceito_*.png`. Para usar **referências**: nos quadros azuis *Referência 1-4* escolha a imagem e aperte **Ctrl+B** (liga o quadro); descreva no texto o que manter ("the same character as in the reference images…").
2. **Castle 2**: em *Folha* carregue essa imagem (ou *Frente* + *Costas*) → *Run* (alguns minutos) → `output/castle/personagem_*.glb`.
3. Copie o `.glb` para `characters/models/` e rode `tools/blender/rig_character.py` (veja o vault: Ferramentas › Polimento de personagem).

Dicas: mesma pose em todas as vistas. Se a cabeça sair virada ao contrário (rosto atrás), mude a *seed* do KSampler "1. Estrutura" e rode de novo.

## Modelos usados (todos em Hugging Face, `Comfy-Org`)
| Pasta em `models/` | Arquivo | Tamanho |
|---|---|---|
| diffusion_models | `pixal3d_int8_convrot.safetensors` | 5,6 GB |
| vae | `trellis_2_shape_vae_bf16.safetensors` | 1,1 GB |
| vae | `trellis_2_texture_vae_bf16.safetensors` | 0,9 GB |
| clip_vision | `dino_v3_L_naf_fp32.safetensors` | 1,2 GB |
| background_removal | `birefnet.safetensors` | 0,4 GB |
| diffusion_models | `z_image_turbo_bf16.safetensors` (refino no Castle 2) | 12,3 GB |
| text_encoders | `qwen_3_4b.safetensors` | 8,0 GB |
| vae | `ae.safetensors` | 0,3 GB |
| diffusion_models | `flux-2-klein-4b.safetensors` (Castle 1) | 7,75 GB |
| vae | `flux2-vae.safetensors` | 0,34 GB |

## Windows (onde foi feito)
Os workflows ficam em `…\ComfyUI\user\default\workflows` e o nó em `…\ComfyUI\custom_nodes\castle_nodes` (copie de `tools\comfyui`). Reinicie o ComfyUI depois de mudar o nó.
