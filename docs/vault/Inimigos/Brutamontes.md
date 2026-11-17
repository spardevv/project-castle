---
tipo: inimigo
tags: [inimigos]
arquivos-fonte:
  - enemies/brute.tscn
---

# Brutamontes

Inimigo pesado com super armor permanente.

Vida 180, velocidade 2,4, alcance 2,8 m, poise 80 (regenera 15/s), **`always_armored`**, **não é lançado** (`can_be_launched = false`),
massa 6 e `knockdown_force` 14.
Golpes: `smash` (24 de dano, windup de 1 s) e `stomp` (explosão raio 3,4).
**Como derrubar**: golpes de `poise_break` (investida de [[Escudo]], [[Ataque carregado]] estância ≥ 2, [[Arte da arma]] do [[Martelo]]) ou muito dano de poise
(`poise_mult` do martelo). O [[Golem]] não consegue agarrá-lo (mostra "RESISTIU").

Ver [[Inimigos]] e [[IA dos inimigos]].
