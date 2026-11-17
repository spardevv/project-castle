---
tipo: sistema
tags: [inimigos, ia]
arquivos-fonte:
  - enemies/states/
  - enemies/enemy_moves.gd
---


# IA dos inimigos

Máquina de estados em `enemies/states/` ([[Estados do jogador]] usa a mesma base).

| Estado | Comportamento |
|---|---|
| `Idle` | espera; entra em `engage_state` (`Chase` ou `Kite`) se o alvo está a menos de `detect_range` |
| `Chase` | persegue até 80% do alcance; ataca se `dist < attack_range` e `attack_cd ≤ 0`; desiste a `detect_range × 1,8` |
| `Attack` | sorteia um golpe por **peso**, **telegrafa** (brilho crescente durante o windup, vira para o alvo) e golpeia com a [[Hitbox, Hurtbox e Health|varredura da arma]] |
| `Kite` | (arqueiro) mantém 4–13 m, anda de lado, atira entre 3–18 m, ataca de perto se encurralado |
| `Shoot` | saca 0,7 s (brilho amarelo), solta, recupera 0,4 s; mira com antecipação do movimento do alvo |
| `Stagger` | recuo (*stand*), *juggle* no ar ou derrubada (*down*); parede causa **wall splat** |
| `Held` / `Pulled` | preso/puxado pelo [[Golem]] |
| `Dead` | some em ~1,6 s, emite `enemy_killed` |

## Golpes (`enemy_moves.gd`)
| Arquétipo | Golpe | Peso | Windup | Dano | Knockback | Obs. |
|---|---|---|---|---|---|---|
| grunt | swing | 0,6 | 0,45 | 10 | 7 | glow laranja |
| grunt | smash | 0,4 | 0,75 | 16 | 10 | glow vermelho, tremor |
| brute | smash | 0,6 | 1,0 | 24 | 12 | tremor forte |
| brute | stomp | 0,4 | 0,9 | 14 | 9 | explosão raio 3,4 |
| archer | jab | 1,0 | 0,35 | 6 | 6 | defesa corpo a corpo |

> [!tip] Leitura
> O **brilho do windup** é a telegrafia: o jogador deve esquivar ([[Movimento e esquiva]]) ou dar parry ([[Guarda e parry]]) ao final dele.

**Derrubada**: knockback ≥ `knockdown_force` (9,5; brutamontes 14) derruba por 1,5 s. Arremesso a ≥ 6 m/s atropela outros inimigos.
