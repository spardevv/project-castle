---
tipo: sistema
tags: [summon, skills]
arquivos-fonte:
  - summon/summon_skills.gd
  - summon/states/skill.gd
---


# Skills do summon

Comando: **LB + X / Y / B / A** → slots 1–4 do summon ativo. Os slots (e passivas) são editados no [[Menu de equipamento]].

## Golem
| Skill | Cooldown | Efeito |
|---|---|---|
| `quake` | 10 s | explosão raio 5, dano 16, lança (6,5) |
| `taunt` | 8 s | puxa e provoca inimigos a 10 m por 4 s |
| `punches` | 7 s | sequência de socos |
| `rock` | 6 s | arremessa pedra em arco (explosão) |
| `grab` | 9 s | corre, agarra o alvo do lock-on, levanta e esmaga: dano 26, knockback 10,5, **poise break** (brutamontes resiste) |

## Sacerdote
| Skill | Cooldown | Efeito |
|---|---|---|
| `heal` | 12 s | +35 de vida |
| `ward` | 15 s | −30% dano recebido, 10 s |
| `bless` | 18 s | +30% dano causado, 12 s |
| `haste` | 16 s | +25% velocidade, 10 s |
| `renew` | 16 s | regenera 4 PV/s por 8 s |
| `hex` | 14 s | maldição nos inimigos (raio 9) |
| `slow` | 12 s | lentidão nos inimigos (raio 9) |
| `smite` | 9 s | dano 22 em raio 1,9 no alvo |
| `nova` | 13 s | explosão raio 4,2, dano 14, knockback 10 |

Efeitos de status: [[Status effects]]. Quem usa: [[Golem]] e [[Sacerdote]].
