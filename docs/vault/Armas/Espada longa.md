---
tipo: arma
tags: [arma, espada]
arquivos-fonte:
  - data/weapons/longsword.gd
  - data/attacks/longsword/
---


# Espada longa

Arma inicial: **rápida, fluida e precisa**. Hitbox por varredura da lâmina (raio 0,16). Valores de [[Golpes (AttackData)]]:
startups curtos (0,08–0,15 s) e peso baixo na animação ([[Peso dos golpes]]).

## Moveset
```
Neutro:    Y = a1 → Y = a2 → Y = a3 (corte cruzado)
Hold:      a1/a2/stinger + segurar Y = overhead  → vira Ataque carregado
Pausa:     a1 → a2, esperar, Y = spin (giro)
Lock-on:   frente+Y = stinger (estocada) | trás+Y = rising (corte ascendente, lança)
Ar:        Y = air1 → air2 | trás+Y = plunge (mergulho)
```

## Golpes
| Golpe | Nome | Animação | Dano | Knockback | Hitstun | Startup / Ativo / Recuperação (s) | Poise ×| Obs. |
|---|---|---|---|---|---|---|---|---|
| `a1` | Corte direito | `a1` | 10 | 4.0 | 0.3 | 0.1 / 0.12 / 0.25 | 1.0 | encadeia a partir de 0.18 s |
| `a2` | Corte esquerdo | `a2` | 12 | 4.5 | 0.3 | 0.09 / 0.12 / 0.25 | 1.0 | encadeia a partir de 0.18 s |
| `a3` | Corte cruzado | `a3` | 18 | 9.0 | 0.45 | 0.12 / 0.15 / 0.4 | 1.0 | encadeia a partir de 0.5 s |
| `spin` | Giro | `spin` | 20 | 8.0 | 0.5 | 0.15 / 0.2 / 0.45 | 1.0 | encadeia a partir de 0.55 s |
| `overhead` | Overhead | `overhead` | 28 | 10.0 | 0.6 | 0.3 / 0.14 / 0.5 | 1.0 | encadeia a partir de 0.55 s |
| `stinger` | Estocada | `stinger` | 14 | 7.0 | 0.35 | 0.12 / 0.15 / 0.35 | 1.0 | encadeia a partir de 0.3 s |
| `rising` | Corte ascendente | `rising` | 12 | 1.5 | 1.1 | 0.1 / 0.15 / 0.4 | 1.0 | lança 9.0; encadeia a partir de 0.3 s |
| `air1` | Corte aéreo 1 | `air1` | 8 | 2.0 | 0.6 | 0.08 / 0.1 / 0.2 | 1.0 | lança 3.0; encadeia a partir de 0.15 s |
| `air2` | Corte aéreo 2 | `air2` | 10 | 3.0 | 0.6 | 0.08 / 0.1 / 0.25 | 1.0 | lança 3.0; encadeia a partir de 0.2 s |
| `plunge` | Mergulho | `plunge` | 22 | 8.0 | 0.5 | 0.14 / 1.2 / 0.4 | 1.0 |  |
| `art_1` | Tempestade: investida | `art_dash` | 14 | 3.0 | 0.6 | 0.08 / 0.22 / 0.06 | 1.0 |  |
| `art_2` | Tempestade: giro | `spin` | 16 | 3.0 | 0.6 | 0.06 / 0.22 / 0.06 | 1.0 |  |
| `art_3` | Tempestade: finalizador | `art_finish` | 28 | 6.0 | 1.0 | 0.14 / 0.15 / 0.45 | 1.0 | lança 8.0 |

## Animação
- Encadeia **da pose atual** (sem voltar à guarda), mola firme e bem amortecida — [[Poses e molas]].
- Golpes de [[Duas mãos]]: `overhead`, `plunge`, `art_finish`.
- Ao andar/correr a espada fica **apoiada no ombro** — [[Posicionamento das armas]].

## Arte
**Tempestade de Lâminas** (`art_1..3`) — [[Arte da arma]].
