---
tipo: sistema
tags: [combate, defesa]
arquivos-fonte:
  - combat/guard_profile.gd
  - player/states/guard.gd
---


# Guarda e parry

LT segurado entra em `Guard`. O comportamento vem do `GuardProfile` (`combat/guard_profile.gd`):

| | Postura defensiva (sem escudo) | Escudo |
|---|---|---|
| Dano recebido | ×0,75 | ×0 (bloqueia tudo) |
| Knockback | ×1,0 | ×0,3 |
| Cancela hitstun | não (ainda cambaleia) | sim |
| **Janela de parry** | — | 0,2 s no início da guarda |
| Velocidade | ×0,6 | ×0,75 |

## Parry
Nos primeiros 0,2 s da guarda com escudo o golpe é **negado** (dano 0) e, se for corpo a corpo, o atacante
cambaleia aberto (`parried()`). Recompensa: +10 de medidor da [[Arte da arma]], slow-mo e tremor ([[Game feel]]).
Projéteis só são negados.

Ver também [[Escudo]] e [[Poise e super armor]].
