---
tipo: sistema
tags: [animação, equipamento]
arquivos-fonte:
  - characters/humanoid_rig.gd
  - characters/poses.gd
---


# Posicionamento das armas

## Espada e martelo ao andar/correr
Em **descanso** (movendo) a arma fica **apoiada no ombro direito**, ponta para cima e para trás — nunca para o chão.
`Poses.locomotion(..., carry_wrist)` recebe o ângulo do pulso do rig (`_carry_wrist`): espada/clava −92°/−100°, martelo −112°.
Armas que não se apoiam (golem, arco, cajado) mantêm a locomoção normal. Parado, o personagem fica em **guarda** (`READY`).

## Pegada do martelo
Pegada **no meio do cabo**: o soquete da arma é deslocado `HAMMER_GRIP = 0,5 m`. Cabo de 1,45 m, cabeça a 1,4 m do pomo.

## Balanço (acompanha o movimento)
Mola de segunda ordem ligada à aceleração/curva/passo: acelerar a deixa para trás (±14°), curvar joga para fora (±10°),
correr balança com o passo. Só em locomoção.

## Escudo
De **lado no antebraço** (face para fora) ao andar/atacar; gira **de frente** (0,15 s) na guarda com escudo e na investida (`bash`) — [[Escudo]].

## Orbe
Flutua à frente da palma esquerda, com luz pulsante; cresce ao conjurar. Guardado em golpes de [[Duas mãos]].

Ver [[Rig humanoide]].
