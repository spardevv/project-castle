---
tipo: sistema
tags: [jogador, equipamento]
arquivos-fonte:
  - systems/game_state.gd
  - player/player.gd
---


# Loadout e equipamento

O autoload `GameState` guarda o que está equipado e avisa por sinal (`loadout_changed`); o jogador aplica em
`Player.apply_loadout()`.

| Slot | Opções | Efeito |
|---|---|---|
| **Primário** (arma) | [[Espada longa]], [[Martelo]] | troca moveset, modelo no rig, raio da varredura (martelo 0,32 / espada 0,16), arte da arma |
| **Secundário** (mão esquerda) | Orbe de fogo, [[Escudo]] | B conjura bola de fogo (orbe) ou faz investida (escudo); escudo altera guarda e poise |
| **Summon** | [[Golem]], [[Sacerdote]] | muda criatura e skills ([[Skills do summon]]) |

Só **um** secundário por vez: orbe e escudo ocupam a mão esquerda. Os dois somem momentaneamente durante golpes
de [[Duas mãos]].

Troca pelo [[Menu de equipamento]] (Tab/Start), com o jogo pausado.
