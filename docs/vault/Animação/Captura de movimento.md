# Captura de movimento (Mixamo → rig)

Animações básicas (parado, andar, correr, pulo, esquiva) vêm de captura de movimento do **Mixamo**, convertidas para o
esqueleto do [[Rig humanoide]]. Golpes continuam nas poses de `Poses.gd` (tempos de dano controlados).

## Baixar no Mixamo
Personagem **Y Bot** (padrão). Em cada animação: **FBX Binary**, **Without Skin**, **30 fps**, sem redução de quadros,
**In Place** marcado quando existir. Salvar em `tools/blender/mixamo_src/` com o nome do clipe:

| Arquivo | Buscar no Mixamo | Uso no jogo |
|---|---|---|
| `idle.fbx` | Breathing Idle | parado |
| `walk.fbx` | Walking | andar devagar (analógico pouco inclinado) |
| `jog.fbx` | Jogging | velocidade de andar do jogador (3,6 m/s) |
| `run.fbx` | Running | entre andar e correr |
| `sprint.fbx` | Fast Run / Sprint | correr (7 m/s) |
| `jump.fbx` | Jump | pulo (subida e descida pela velocidade vertical) |
| `fall.fbx` | Falling Idle | queda longa |
| `roll.fbx` | Sprinting Forward Roll / Stand To Roll | esquiva para frente |
| `dodge_back.fbx` | Standing Dodge Backward | esquiva para trás (sem direção) |
| `dodge_left.fbx` / `dodge_right.fbx` | Standing Dodge Left / Right | esquiva lateral (lock-on) |

Clipe que faltar usa a pose procedural antiga. A pasta tem `.gdignore` (o Godot não importa os .fbx).

## Converter
```
blender -b --factory-startup -P tools/blender/mixamo_to_clip.py -- --src tools/blender/mixamo_src --out characters/anims
```
`mixamo_to_clip.py` compara cada osso com a pose zero do rig (membros retos para baixo, frente +Z) e grava a rotação
**local** de cada junta (Euler YXZ, graus) — vale para qualquer personagem do rig, com qualquer proporção. Também:
- **frente alinhada**: golpes/esquivas do Mixamo vêm em base de luta (quadril virado 45-70°); o clipe inteiro gira
  pela direção média do quadril nos quadros em pé;
- joelhos e cotovelos em **Euler XYZ** (o rig usa `rotation_order = XYZ` neles): a dobra passa de 90° sem salto;
- giro do corpo (`pitch`) pelo **twist em X do quaternion** do quadril: contínuo no rolamento por cima do ombro;
- ciclos podem ter **vários ciclos seguidos** (o Jogging do Mixamo tem 3): `cycle_starts` marca o começo de cada um e o
  rig toca o ciclo k na volta k da fase (`AnimClip.gait_u`);
- **contato** nos ciclos em movimento = pé baixo **e** parado em relação ao chão (no In Place o chão corre para trás
  na velocidade do clipe); `touch_ahead` = quanto à frente do quadril o pé pousa (a trava de pé mira ali);
- **raiz** em alturas de quadril (o rig multiplica por `hip_y`); giro do corpo inteiro no canal `pitch` (rolamento 360°);
- **contato de cada pé** por quadro (altura do tornozelo/dedos) — a trava de pé usa isso;
- ciclos: começam no toque do pé esquerdo; **velocidade natural** e distância de um ciclo (pé de apoio indo para trás,
  ou o deslocamento do quadril se não for In Place);
- pulo: marcadores `takeoff`, `apex`, `land`; esquivas: trecho ativo `start`..`end`.

## No rig (`AnimClip`, `HumanoidRig`)
- `characters/anim_clip.gd` carrega `characters/anims/<nome>.json` (cache) e amostra por fração 0..1.
- **Locomoção**: ciclos `walk/jog/run/sprint` ordenados pela velocidade natural (convertida para o corpo); a velocidade
  atual mistura os dois vizinhos e, abaixo do primeiro, o `idle`. A fase avança pela distância andada (`cycle_dist`),
  então a cadência acompanha a velocidade e o pé não desliza. Contato dos pés vem do clipe de maior peso.
- **Braço da arma** continua na pose de carregar (o clipe não tem arma); o resto do corpo é da captura.
- **Pulo**: subida = `takeoff→apex` pela velocidade vertical; descida até perto do `land`; queda forte mistura `fall`.
- **Ferramenta** `tools/motion_strip.tscn`: roda o rig em tempo real simulado (molas, IK, cabelo) e monta uma tira de
  16 quadros de perfil (rolamento, esquivas, pulo, correr, andar). Mostra trancos que as folhas estáticas escondem.
- **Esquiva**: `set_dodge(progresso, direção)` escolhe `roll` (frente), `dodge_back`, `dodge_left/right`; o trecho
  ativo do clipe (rolamento: do mergulho até 340°; passos: enquanto o quadril se desloca) é esticado para a duração da
  esquiva do jogo (0,6 s: o rolamento roda ~2x mais rápido que no Mixamo). Mola bem firme na esquiva.
- **Trava de pé com clipes**: o pé começa a soltar **antes** de sair do chão (soltar leva um tempo; senão o corpo
  passa do alcance, a perna estica toda e pula para a pose do clipe — era o "piscar" das pernas). Tempo de prender e
  soltar proporcional ao apoio (correndo o pé fica ~0,15 s no chão). Se a trava ficar fora do alcance real da perna
  (com o quadril descendo o máximo), solta em vez de esticar. Contato = média dos clipes misturados; contato, "falta
  para tocar" e "falta para soltar" usam o mesmo quadro do clipe (nunca se contradizem). Apoio termina quando o
  **tornozelo** sobe (não os dedos).
- **Ferramenta** `tools/gait_probe.tscn` (headless): anda com a elfa como o jogador (acelera, curva 90°, corre, para)
  e conta saltos de joelho de um quadro para o outro e pernas esticadas no limite.
- Mola mais firme quando a pose vem de clipe (`_clip_driven`): segue a captura, só tira trancos de troca.
- `use_mocap = false` no rig volta tudo para o procedural.
