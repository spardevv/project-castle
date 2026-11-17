---
tipo: sistema
tags: [combate, poise]
arquivos-fonte:
  - player/player.gd
  - enemies/enemy.gd
---


# Poise e super armor

**Poise** (também "stance") é a barra invisível de postura. Todo dano soma no poise de quem apanha;
quando chega a zero, o personagem **cambaleia** (`Hurt`/`Stagger`). Enquanto houver poise, o dano entra mas o
personagem **continua agindo** — isso é a *super armor*.

## Jogador
| Fonte | Poise |
|---|---|
| Base | 9 (regenera 14/s, exceto durante Hurt) |
| Escudo equipado | 60 |
| Dano de poise de um golpe | `dano × poise_mult` |

Regras (`Player._on_damaged`):
- Golpe com `poise_break` ou `launch` **sempre** cambaleia (exceto nas estâncias do [[Ataque carregado]]).
- Estância ≥ 2: ignora `poise_break`. Estância 3: inabalável (só `launch` derruba).
- Estâncias dividem o dano de poise recebido por 1,5 / 2,5 / 4 / 8.
- Cambalear reseta o poise ao máximo.

## Ofensa
- Armas pesadas usam `poise_mult` alto (martelo 2,5×) para "parar" inimigos — [[Martelo]].
- `poise_break`: ignora a super armor do alvo — investida de [[Escudo]], golpes carregados altos, [[Arte da arma]] do martelo.

## Inimigos
Ver [[Inimigos]] e [[IA dos inimigos]] (brutamontes tem super armor; telegrafia antes de golpes).
