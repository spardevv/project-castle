---
tipo: sistema
tags: [combate, combos]
arquivos-fonte:
  - combat/move_set.gd
  - data/weapons/
  - player/states/attack.gd
---


# Combos e movesets

Cada arma é um `MoveSet` (`combat/move_set.gd`): um **grafo** de golpes.

- `start` / `start_air`: de onde começa um golpe (chave → id).
- `edges`: para cada golpe, as saídas por tipo de input.

## Chaves de aresta
| Chave | Quando |
|---|---|
| `tap` | toque no ataque após `cancel_start` |
| `tap_fwd` / `tap_back` | só com [[Lock-on e câmera|lock-on]]: analógico para o alvo / contra o alvo |
| `hold` | segurar o ataque ≥ 0,25 s após `cancel_start` → vira [[Ataque carregado]] |
| `pause` | toque depois de terminar um golpe, dentro de 0,7 s (memória do combo) — ex.: giro da espada |

`resolve(from, kind, dir, air)` escolhe a aresta; sem aresta específica cai no início do moveset.

## Cancels (em `attack.gd`)
Depois do golpe ativo: **arte da arma**, **esquiva** e **secundário** cancelam a recuperação.
O encadeamento parte da **pose atual do corpo** ([[Poses e molas]]), então A1→A2→A3 é um gesto contínuo.

Movesets: [[Espada longa]] · [[Martelo]]. Cada moveset também define a sua [[Arte da arma]].
