---
tipo: sistema
tags: [animação, ik]
arquivos-fonte:
  - characters/humanoid_rig.gd
  - characters/poses.gd
---


# Duas mãos

Alguns golpes são feitos com **as duas mãos na arma**. Nesses golpes:

1. A mão esquerda deixa de seguir a pose e passa a **seguir o cabo da arma** por **IK de dois ossos** (`_two_hand_apply`),
   misturada em ~0,14 s.
2. O que a mão esquerda segurava é **guardado** momentaneamente: o **orbe** e o **escudo** ficam invisíveis durante o golpe
   e voltam depois. ([[Loadout e equipamento]], [[Escudo]])

## Onde segura
`GRIP2` (z no soquete da arma): espada −0,14 (pomo; o cabo é longo), martelo +0,12 (perto do pomo; a mão direita está a 0,5 m do pomo).

## Golpes de duas mãos (`Poses.TWO_HANDED`)
- **Martelo**: `hm_smash`, `hm_charge`, `hm_lunge`, `hm_rising`, `hm_plunge`, `hm_spin`, `hm_art_slam`.
- **Espada**: `overhead`, `plunge`, `art_finish`.
- As varridas e golpes aéreos do [[Martelo]] e quase todos os da [[Espada longa]] são de **uma mão**.

## Como o IK funciona
Alcança o ponto de agarre (`grip`) dado o ombro, braço (0,30 m) e antebraço (0,29 m): lei dos cossenos para o ângulo do cotovelo,
"pole" fixo (cotovelo para baixo e um pouco para fora). Se o alvo está longe demais a mão fica curta (fica no máximo esticada).

Para adicionar um golpe de duas mãos: incluir a chave em `Poses.TWO_HANDED`. Ver [[Poses e molas]] e [[Posicionamento das armas]].
