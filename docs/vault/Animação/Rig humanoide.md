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
