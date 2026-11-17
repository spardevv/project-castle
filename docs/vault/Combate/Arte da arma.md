---
tipo: sistema
tags: [combate, arte]
arquivos-fonte:
  - player/states/art.gd
  - combat/move_set.gd
  - data/weapons/
---


# Arte da arma (RT)

Sequência especial que **gasta 50 do medidor** (máx. 100 = 2 usos). O medidor enche ao causar dano
(+0,8 por ponto), ao ser atingido (+4) e no [[Guarda e parry|parry]] (+10). A própria arte **não** recarrega medidor.

Durante toda a sequência o jogador tem **i-frames**, o rastro troca de cor, há slow-mo curto e tremor ([[Game feel]]).

Cada arma define a sua sequência (`MoveSet.art_sequence`), nome e cor (`art_name`, `art_color`) — o HUD mostra o nome.

| Arma | Arte | Golpes |
|---|---|---|
| [[Espada longa]] | **Tempestade de Lâminas** (laranja) | investida cortando → giro em área → finalizador que lança |
| [[Martelo]] | **Fúria Sísmica** (vermelho brasa) | giro devastador (área) → uppercut que lança → **impacto sísmico** com onda de choque |

Para criar a arte de uma arma nova: 3 `.tres` em `data/attacks/<arma>/`, preencher `art_sequence` no moveset
e (se precisar) novas poses em `characters/poses.gd` ([[Poses e molas]]).
