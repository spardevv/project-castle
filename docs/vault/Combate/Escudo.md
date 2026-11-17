---
tipo: sistema
tags: [combate, equipamento]
arquivos-fonte:
  - player/states/bash.gd
  - player/player.gd
  - combat/guard_profile.gd
---


# Escudo

Equipamento secundário (mão esquerda) em vez do orbe — [[Loadout e equipamento]].

## Passivo (mesmo sem guarda)
- **−75% de todo o dano recebido** (`SHIELD_DAMAGE_MULT = 0,25`).
- Poise 60 em vez de 9 ([[Poise e super armor]]).

## Guarda
Bloqueio total + janela de parry de 0,2 s — [[Guarda e parry]].

## Investida de escudo (`Bash`, botão B)
| | |
|---|---|
| Startup / ativo / recuperação | 0,10 / 0,16 / 0,30 s |
| Avanço | 9 m/s |
| Dano | 6, knockback 8, hitstun 0,7 |
| Efeito | **quebra super armor** e faz o inimigo cambalear |
| Cooldown | 0,8 s |

Pode encadear em ataque no fim da janela ativa. A animação é `bash` ([[Poses e molas]]).

## Visual
O escudo fica **de lado, no antebraço** ao andar e atacar, e gira **de frente** só na guarda e na investida
([[Posicionamento das armas]]). Some durante golpes de [[Duas mãos]].
