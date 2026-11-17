---
tipo: summon
tags: [summon, golem]
arquivos-fonte:
  - summon/summon.gd
  - summon/states/
---


# Golem de Pedra

Tanque de pedra (rig com `fist_scale` grande, sem arma). Velocidade 6,5, distância de seguir 3 m, alcance 1,8 m, massa 4, vida 200.

## Golpes básicos
`BASIC` (dano 9), `SLAM` (18, área 4,4×4,4), `SPIN` (14). O último soco do combo soma +6, knockback 9,5 e derruba.

## Passivas
| Passiva | Cooldown | Condição |
|---|---|---|
| `slam` | 7 s | alcance 0–2,6, ≥ 1 inimigo em 3,4 m |
| `combo` | 5 s | alcance 0–2,4 |
| `rock` | 7 s | alcance 4,5–14 |
| `spin` | 9 s | alcance 0–2,8, ≥ 2 inimigos em 3,6 m |

Skills comandadas: [[Skills do summon]]. Também pula degraus (`leap`) e esquiva ([[Summons]]).
Provocar (`taunt`) faz inimigos o atacarem — [[IA dos inimigos]].
