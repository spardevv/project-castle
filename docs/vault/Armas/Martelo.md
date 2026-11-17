---
tipo: arma
tags: [arma, martelo]
arquivos-fonte:
  - data/weapons/hammer.gd
  - data/attacks/hammer/
---


# Martelo

**Lento, bruto e pesado**: mais dano e knockback, `poise_mult` alto nas varridas `h1`/`h2` (2,5×), 2,0× nos golpes aéreos, e golpes que quebram super armor.
Hitbox por varredura grossa (raio 0,32). Ver o conceito em [[Peso dos golpes]].

## Moveset
```
Neutro:    Y = h1 (varrida) → Y = h2 (volta) → Y = h3 (esmagamento, derruba)
Hold:      h1/h2/h_lunge + segurar Y = h_charge  → Ataque carregado
Lock-on:   frente+Y = h_lunge (investida) | trás+Y = h_rising (uppercut, lança)
Ar:        Y = h_air1 → h_air2 | trás+Y = h_plunge (mergulho esmagador)
```

## Golpes
| Golpe | Nome | Animação | Dano | Knockback | Hitstun | Startup / Ativo / Recuperação (s) | Poise ×| Obs. |
|---|---|---|---|---|---|---|---|---|
| `h1` | Varrida pesada | `hm_swing_r` | 16 | 8.0 | 0.5 | 0.38 / 0.14 / 0.62 | 2.5 | encadeia a partir de 0.5 s; carrega parado 50% do startup |
| `h2` | Golpe de volta | `hm_swing_l` | 18 | 9.0 | 0.5 | 0.4 / 0.14 / 0.66 | 2.5 | encadeia a partir de 0.54 s; carrega parado 50% do startup |
| `h3` | Esmagamento | `hm_smash` | 34 | 12.0 | 0.7 | 0.62 / 0.16 / 0.95 | 1.0 | quebra super armor; carrega parado 60% do startup |
| `h_charge` | Esmagamento carregado | `hm_charge` | 30 | 14.0 | 0.9 | 0.5 / 0.18 / 1.0 | 1.0 | quebra super armor; carrega parado 50% do startup |
| `h_lunge` | Investida do martelo | `hm_lunge` | 22 | 9.0 | 0.6 | 0.34 / 0.18 / 0.62 | 1.0 | quebra super armor; encadeia a partir de 0.5 s; carrega parado 45% do startup |
| `h_rising` | Uppercut | `hm_rising` | 18 | 2.0 | 1.2 | 0.3 / 0.16 / 0.6 | 1.0 | quebra super armor; lança 8.0; encadeia a partir de 0.5 s |
| `h_air1` | Pancada aérea 1 | `hm_air1` | 12 | 3.0 | 0.7 | 0.2 / 0.12 / 0.34 | 2.0 | lança 3.0; encadeia a partir de 0.3 s |
| `h_air2` | Pancada aérea 2 | `hm_air2` | 15 | 3.0 | 0.7 | 0.22 / 0.12 / 0.4 | 2.0 | lança 3.0; encadeia a partir de 0.34 s |
| `h_plunge` | Mergulho esmagador | `hm_plunge` | 30 | 10.0 | 0.6 | 0.26 / 1.2 / 0.6 | 1.0 | quebra super armor |
| `h_art_1` | Fúria: giro devastador | `hm_spin` | 20 | 10.0 | 0.7 | 0.24 / 0.32 / 0.12 | 1.0 | quebra super armor |
| `h_art_2` | Fúria: uppercut | `hm_rising` | 24 | 6.0 | 1.0 | 0.22 / 0.18 / 0.1 | 1.0 | quebra super armor; lança 9.0 |
| `h_art_3` | Fúria: impacto sísmico | `hm_art_slam` | 55 | 13.0 | 1.2 | 0.55 / 0.18 / 0.65 | 1.0 | quebra super armor; lança 7.0; onda de choque |

## Identidade de animação
- **Poses próprias** `hm_*` (base larga, preparação funda, corpo todo no golpe).
- **Cravado no chão**: depois da pancada o corpo segura a pose e puxa o martelo devagar (`HOLD`).
- **Tranco de impacto** no tronco/ombro/quadril + tremor de câmera.
- **Avanço tardio** (`lunge_delay`): carrega plantado e dá o passo junto com a pancada.
- Mola mais lenta e com folga (a massa passa um pouco do ponto).
- Pegada **no meio do cabo** (0,5 m do pomo); ao andar apoia no ombro — [[Posicionamento das armas]].
- Uma mão nas varridas e golpes aéreos; **duas mãos** em esmagamento, carregado, investida, uppercut e mergulho — [[Duas mãos]].

## Arte
**Fúria Sísmica** (`h_art_1..3`) — [[Arte da arma]].
