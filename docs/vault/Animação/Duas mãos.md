---
tipo: sistema
tags: [animação, ik]
arquivos-fonte:
  - characters/humanoid_rig.gd
  - combat/attack_data.gd
---


# Duas mãos

Alguns golpes são feitos com **as duas mãos na arma**. Nesses golpes:

1. A mão esquerda deixa de seguir a pose e passa a **seguir o cabo da arma** por **IK de dois ossos** (`_two_hand_apply`),
   misturada em ~0,14 s.
2. O que a mão esquerda segurava é **guardado** momentaneamente: o **orbe** e o **escudo** ficam invisíveis durante o golpe
   e voltam depois. ([[Loadout e equipamento]], [[Escudo]])

## Onde segura
`GRIP2` (z no soquete da arma): espada −0,14 (pomo; o cabo é longo), martelo +0,12 (perto do pomo; a mão direita está a 0,5 m do pomo).

## Golpes de duas mãos (`AttackData.two_handed`)
É um atributo de cada golpe (`.tres` em `data/attacks/`), passado ao rig em `set_attack(..., two_handed)`.
- **Martelo**: `h3`, `h_charge`, `h_lunge`, `h_rising`, `h_plunge` e a arte inteira (`h_art_1..3`).
- **Espada**: `overhead`, `plunge`, `art_3` (`art_finish`).
- **Lança**: todos os golpes. Fora deles (andar, guarda, secundário) fica numa mão, pegada no meio da haste ([[Lança]]).
- As varridas e golpes aéreos do [[Martelo]] e quase todos os da [[Espada longa]] são de **uma mão**.
- Ações da mão esquerda (bola de fogo, investida de escudo, besta) são sempre de uma mão, mesmo com a lança.

## Como o IK funciona
Alcança o ponto de agarre (`grip`) dado o ombro, braço (0,30 m) e antebraço (0,29 m): lei dos cossenos para o ângulo do cotovelo,
"pole" fixo (cotovelo para baixo e um pouco para fora). Se o alvo está longe demais a mão fica curta (fica no máximo esticada).

Para adicionar um golpe de duas mãos: marcar `two_handed = true` no `.tres` do golpe. Ferramentas que tocam poses pela chave (`pose_sheet`) usam `AttackData.two_handed_anims()`. Ver [[Poses e molas]] e [[Posicionamento das armas]].
