---
tipo: sistema
tags: [interface]
arquivos-fonte:
  - ui/hud.gd
  - ui/hud.tscn
---


# HUD

`CanvasLayer` com:
- **Barra de vida** do jogador e flash vermelho ao ser atingido.
- **Medidor da arte**: 2 segmentos de 50 (cada um = um uso); vira amarelo quando cheio. Mostra o nome da [[Arte da arma]] equipada.
- **Estâncias de carga**: 3 barras que enchem enquanto o ataque é segurado — [[Ataque carregado]].
- **Status** ativos com tempo restante — [[Status effects]].
- **Summon**: vida e os 4 slots com cooldown (`pronta` / segundos) — [[Skills do summon]].
- **Painel de controles** (alterna com `toggle_controls`), montado do Input Map no dispositivo em uso (`InputGlyphs`).
