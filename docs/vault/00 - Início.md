---
tipo: hub
tags: [hub]
arquivos-fonte:
  - project.godot
---


# Project Castle — Documentação de gameplay

Jogo de ação 3D (Godot 4.7) em 3ª pessoa, no estilo *Devil May Cry / Souls-lite*: combate com armas pesadas,
postura (poise), esquiva com i-frames e uma **criatura invocada (summon)** que luta ao seu lado.

Este vault explica **como cada sistema funciona e por quê**, com os valores reais do código.
Comece pelo [[Mapa de sistemas]] ou pela [[Visão geral do combate]].

## Por onde começar
- Quer entender uma luta de ponta a ponta? → [[Visão geral do combate]]
- Quer balancear um golpe? → [[Golpes (AttackData)]], [[Poise e super armor]], [[Espada longa]], [[Martelo]]
- Quer mexer em animação? → [[Rig humanoide]], [[Poses e molas]], [[Peso dos golpes]]
- Dúvida de termo? → [[Glossário]]
- O que falta? → [[Roadmap]]

## Pilares do jogo
1. **Peso e leitura**: cada arma tem personalidade (leve/fluida vs. lenta/brutal) — [[Peso dos golpes]].
2. **Postura como recurso**: todo mundo tem poise; quebrar o do outro é o objetivo — [[Poise e super armor]].
3. **Risco × recompensa**: carregar golpes dá mitigação mas expõe você — [[Ataque carregado]].
4. **Equipe**: o jogador comanda um summon com skills — [[Summons]].
