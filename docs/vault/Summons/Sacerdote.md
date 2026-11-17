---
tipo: summon
tags: [summon, sacerdote]
arquivos-fonte:
  - summon/priest.tscn
  - summon/states/support.gd
---


# Sacerdote

Suporte frágil que mantém distância: fica num anel de 4–8 m do jogador, **recua 6,5 m** do lado oposto quando há ameaça e foge de inimigos a menos de 5,5 m.
Cura e dá buffs ([[Status effects]]); ataca à distância com `smite`.

## Passivas (prefixo `p_`)
| Passiva | Cooldown | Condição |
|---|---|---|
| `p_aura` | contínua | cura 2,5 PV/s num raio de 12 m (metade em si mesmo) |
| `p_heal` | 10 s | vida do jogador < 60% |
| `p_renew` | 14 s | em combate, < 85% e sem `regen` |
| `p_bless` | 25 s | em combate e sem `bless` |
| `p_ward` | 18 s | em combate, < 80% e sem `ward` |
| `p_slow` | 14 s | ≥ 2 inimigos em 10 m e algum sem `slow` |
| `p_smite` | 5 s | inimigo a > 4 m, algum em 14 m |

Skills comandadas: [[Skills do summon]].
