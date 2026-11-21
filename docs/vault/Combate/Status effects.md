---
tipo: sistema
tags: [combate, buffs]
arquivos-fonte:
  - combat/status_effects.gd
---


# Status effects

Buffs e debuffs temporários em qualquer personagem (jogador, inimigo, summon). Um nó filho `StatusEffects` é criado sob demanda.
Mostram o nome flutuando sobre o alvo e uma luz colorida; o HUD lista os ativos do jogador ([[HUD]]).

| Id | Nome | Duração | Efeito |
|---|---|---|---|
| `bless` | Bênção | 12 s | dano causado ×1,3 |
| `ward` | Proteção | 10 s | dano recebido ×0,7 |
| `haste` | Pressa | 10 s | velocidade ×1,25 |
| `regen` | Regeneração | 8 s | cura 4/s |
| `hex` | Maldição | 8 s | dano recebido ×1,3 e causado ×0,8 |
| `slow` | Lentidão | 6 s | velocidade ×0,5 |
| `blessing` | Benção (passiva do sacerdote) | 5 s | dano causado ×1,25 e dano recebido ×0,75 |

Consultas: `StatusEffects.mult(alvo, "damage_out" | "damage_in" | "speed")` (produto dos efeitos ativos).
Aplicados principalmente pelas skills do [[Sacerdote]] ([[Skills do summon]]).
