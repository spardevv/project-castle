---
tipo: inimigo
tags: [inimigos]
arquivos-fonte:
  - enemies/archer.tscn
---

# Arqueiro

Ataque à distância.

Vida 45, velocidade 3,8, detecta a 20 m, poise 8, `engage_state = Kite`.
Mantém 4–13 m do alvo, anda de lado e atira flechas (dano 8, velocidade 24) com **antecipação** do movimento. Se o jogador chega perto, usa `jab` (6 de dano).
Parry do projétil só nega (não abre o arqueiro) — [[Guarda e parry]].

Ver [[Inimigos]] e [[IA dos inimigos]].
