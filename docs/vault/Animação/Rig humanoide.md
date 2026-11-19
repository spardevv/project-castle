---
tipo: sistema
tags: [animação, rig]
arquivos-fonte:
  - characters/humanoid_rig.gd
  - characters/humanoid_rig.tscn
---


# Rig humanoide

Boneco montado com primitivas (cápsulas, caixas, esferas) em **pivôs de junta** (~1,9 m, frente = +Z). Serve para jogador,
inimigos e summons (variam cor, altura, `bulk`, equipamento). Os estados do jogo só **informam o que acontece**
(`set_motion`, `set_attack`, `set_dodge`, `set_guard`, `set_hurt`, ...) e o rig decide a pose.

## Juntas
`root` (posição do quadril), `yaw`/`pitch` (corpo todo), `hips`, `spine`, `head`, ombros/cotovelos (`sh_*`, `el_*`),
pulso da arma (`wr_r`), coxas/joelhos (`th_*`, `kn_*`). A pose é um `Dictionary` junta → `Vector3` em graus ([[Poses e molas]]).

**Juntas derivadas** (o rig calcula; as poses não as citam, então nenhuma pose precisa mudar):
- `chest`: o tronco (`spine` da pose) é dividido meio a meio entre cintura e peito (`CHEST_SHARE`), e o peito atrasa
  com uma mola própria quando o tronco gira rápido. Resultado: coluna curva em vez de bloco rígido, e efeito de chicote.
- `neck`: a cabeça (pose + olhar) é dividida entre pescoço (35%, `NECK_SHARE`) e cabeça.
- `clav_l/clav_r`: o ombro sobe (até 16°) quando o braço passa da linha do ombro ou abre para o lado.
- `toe_l/toe_r`: a ponta do pé dobra para ficar apoiada quando o calcanhar sobe ao desprender.
- **Mãos**: pulso esquerdo com arrasto (a mão livre "chicoteia" atrás do braço e assenta) e dedos com pivô próprio
  (`fingers_l/r`): abrem ao conjurar, puxar o arco, provocar e na guarda sem escudo; meio abertos caído.
- **Respiração**: peito e ombros sobem e descem (~15/min parado); depois de golpes e esquivas fica ofegante (`_exertion`) por ~3 s.
- **Estabilização da cabeça**: ao correr e curvar, a cabeça compensa 60% da inclinação do corpo (olhar nivelado).

## Malhas
**Corpo contínuo com esqueleto** (`_build_body_skin`): tronco, pescoço, braços, antebraços, coxas e canelas são uma malha
só, gerada em código como tubos de anéis elípticos (28 vértices por anel) com **pesos de osso** (Skeleton3D + Skin).
Os ossos (`SKIN_BONES`) copiam a transformação das juntas animadas a cada quadro (`_update_skin`), então nada nas poses
muda; nas articulações (cotovelo, joelho, cintura, quadril, ombro) o anel é dividido entre os dois ossos e a malha
**dobra suave, sem emendas**. Cores: roupa (tronco, braço, coxa), pele (pescoço, antebraço) e couro (canela/bota).
Peças presas a juntas continuam rígidas: armaduras (ombreiras, peitoral, joelheiras, manoplas), mãos, pés, cabeça,
tabardo e capa — `_soft_box()` (caixa de cantos arredondados) e esferas.
Este é o mesmo caminho para usar modelos .glb do Blender depois: trocar a malha gerada por uma importada no mesmo esqueleto.
Testes: `tests/test_rig.gd`.

## Modos
`LOCOMOTION, ATTACK, DODGE, GUARD, HURT, DEAD, AIR_HURT, KNOCKDOWN`. Cada modo tem sua mola (`SPRING`) e peso do olhar.

## Movimento secundário (procedural)
| Efeito | O que faz |
|---|---|
| Inclinação | acelerar inclina para frente; curvar inclina para dentro |
| Aterrissagem | tranco para baixo no quadril, mola devolve |
| Olhar | a cabeça vira para o alvo do [[Lock-on e câmera|lock-on]] (limites ±30° / ±70°) |
| Tabardo e capa | seguem o corpo com atraso e pendem para baixo no mundo |
| IK das pernas | **trava de pé**: ao andar, o pé de apoio fica preso a um ponto do mundo (sem deslizar, em qualquer direção/velocidade); o pé em balanço é guiado ao ponto de toque previsto (meio passo à frente) e o quadril desce até 18 cm para alcançar. Fora disso, pé abaixo do chão (degrau, agachado) dobra joelho/coxa. Medido com `slide_probe`. Pé com pivô próprio (`ft_l/ft_r`): chato no chão no apoio, ponta para baixo ao desprender, calcanhar primeiro ao pousar |
| Passos | fase do ciclo avança pela **distância andada** (sem deslize) |
| Balanço da arma | acelerar deixa a arma para trás; curva joga para fora; correr balança no passo — [[Posicionamento das armas]] |
| Tremor de carga | corpo treme mais a cada estância — [[Ataque carregado]] |

## Armas e equipamentos no rig
`set_weapon` (espada, clava, martelo, cajado, arco), `set_offhand` (orbe, escudo). Marcadores `sword_base`/`sword_tip` alimentam a
varredura da [[Hitbox, Hurtbox e Health|hitbox]] e o rastro (`WeaponTrail`).

## Proporções (esboço de 8 cabeças)
O esqueleto sai do esboço ![[esboco_proporcoes.svg]] via `BodyProportions` (`characters/body_proportions.gd`):
alturas, comprimentos e larguras em **cabeças** (1 cabeça = 1,94 ÷ 8 = 0,2425 no rig). `HumanoidRig.proportions`
(vazio = padrão) e `feminine` (ombros 0,78 e quadril 0,42 cabeça do centro; masculino 0,95 e 0,45).

| Junta | Altura (cabeças) | | Segmento | Comprimento (cabeças) |
|---|---|---|---|---|
| pivô da cabeça | 7,15 | | braço | 1,5 |
| pescoço | 6,75 | | antebraço | 1,25 |
| ombro | 6,6 | | mão | 0,75 |
| peito | 5,75 | | coxa | 2,0 |
| lombar | 4,85 | | canela | 1,85 |
| quadril / fêmur | 4,35 / 4,15 | | folga do joelho | 0,12 |
| tornozelo | 0,3 | | | |

`_apply_proportions()` converte para as medidas usadas no rig (`hip_y`, `upper_arm`, `forearm`, `thigh_len`, `shin_len`,
`foot_h`…): construção, IK das pernas e das duas mãos, tubos do corpo, hitboxes e capa. A perna do rig é a do esboço
menos `knee_slack` (o joelho fica levemente dobrado em pé e o IK tem margem no passo). O desenho da cabeça procedural
desce `HEAD_GEO_Y` para o centro ficar a meia cabeça do topo.

## Hit-stop no rig
`freeze()` encaixa a pose do impacto e segura ([[Game feel]]).


## Corpo de um modelo 3D (`body_model`)
O rig pode usar um **modelo .glb** (ex.: gerado por IA) no lugar do corpo procedural: `HumanoidRig.body_model` + o
`.json` de articulações com o mesmo nome. Preparação no Blender: `tools/blender/rig_character.py`
([[Polimento de personagem (Blender)]]).
- As articulações do **tronco, ombros e quadris** vão para as posições do modelo (`MODEL_PLACED`); os **comprimentos de
  braço e perna** e a altura do tornozelo vêm do `.json` (`_fit_lengths_to_model`), para a malha não esticar até o
  cotovelo/joelho do esboço. O quadril desce a folga do joelho (`knee_slack`) para a perna não ficar travada reta.
- Cada osso do modelo tem repouso = articulação do modelo, com os **membros girados da pose A para "reto para baixo"**
  (a pose zero do rig). Por isso as mesmas poses e golpes valem para o modelo sem mudar nada.
- O corpo procedural (pele, roupa, armadura, cabeça, mãos, pés, capa) fica escondido.
- Ver nas folhas de pose: filtro `elfa:` no `pose_sheet` (ex.: `elfa:move_walk`). Teste: `tests/test_rig.gd`.

### Ossos extras do modelo
Além do tronco e membros, o esqueleto tem **punhos** (`wr_r` segue o pulso da arma: a mão dobra com o ângulo do golpe;
`wr_l` balança com o arrasto da mão livre), **pontas dos pés** (`toe_l/r`: dobram ao desprender do chão) e uma
**cadeia de cabelo** (`hair_1..3`).

### Cabelo com física
Quando o modelo traz `hair_chain` no `.json` (4 pontos da nuca à ponta, achados pelo `rig_character.py` no cabelo das
costas), o rig simula a cadeia (Verlet, `_update_hair`):
- **Inércia**: corre e o cabelo vai para trás; para e ele balança para frente e volta.
- **Gravidade** e **mola** para a forma de repouso presa ao peito (raiz firme, ponta solta: `HAIR_STIFF`).
- **Comprimento fixo** dos segmentos, **colisão com as costas** (eixo do tronco) e **limite de balanço** por segmento
  (`HAIR_MAX_SWING`: 25°/40°/55°; sem isso, numa parada brusca o cabelo passava por cima dos ombros).
Pesos: cabelo das costas segue a cadeia; mechas da frente seguem tronco e cabeça. Teste: `tests/test_rig.gd`.
