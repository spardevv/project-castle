---
tipo: sistema
tags: [jogador]
arquivos-fonte:
  - player/player.gd
  - player/player.tscn
---


# Jogador

Um `CharacterBody3D` (`player/player.gd`) que guarda **dados e utilitários**; o comportamento vive em estados
([[Estados do jogador]]). Possui vida (`Health`, ver [[Hitbox, Hurtbox e Health]]), um **moveset** da arma
equipada ([[Combos e movesets]]), medidor da arte ([[Arte da arma]]) e poise ([[Poise e super armor]]).

## Valores principais
| Parâmetro | Valor |
|---|---|
| Andar / correr | 3,6 / 7,0 m/s (L3 alterna corrida) |
| Aceleração | 45 (no ar: 18) |
| Pulo | 8,5 m/s, gravidade ×2,2, *coyote time* 0,1 s |
| Buffer de input | 0,2 s (pulo, esquiva, ataque, secundário, arte) |
| Hold do ataque | 0,25 s ([[Combos e movesets]]) |
| Memória do combo | 0,7 s (próximo toque vira "pausa") |
| Medidor da arte | máx. 100, custa 50, +0,8 por ponto de dano causado, +4 ao ser atingido |
| Poise | base 9, escudo 60, regenera 14/s |
| Cooldown do summon | 8 s ao dispensar, 14 s se ele morre |

## Entradas (resumo)
Mover, câmera, pular, **atacar** (combos), **secundário** (B: bola de fogo ou investida de escudo),
**arte da arma** (RT), **esquiva**, **guarda** (LT), **lock-on**, **invocar summon** (X) e **LB** para comandar skills
([[Summons]]).

## Ligações
[[Loadout e equipamento]] · [[Lock-on e câmera]] · [[Movimento e esquiva]] · [[Escudo]] · [[HUD]]

> [!info] Fonte
> `player/player.gd` (constantes no topo), `player/player.tscn` (nós de estado).
