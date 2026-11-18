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

## Hit-stop no rig
`freeze()` encaixa a pose do impacto e segura ([[Game feel]]).
