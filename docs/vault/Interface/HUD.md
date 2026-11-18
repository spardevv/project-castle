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

## Painel do summon (`ui/summon_panel.gd`)
Canto inferior esquerdo, com visual próprio por summon (cor, retrato e skills): **Golem** (laranja, cabeça de pedra) e **Sacerdote** (dourado/verde, capuz com cruz).
- Retrato + barra de vida (com rastro branco do dano; fica vermelha abaixo de 30%) e nome.
- 4 ícones de skill (LB + botão) com a tecla do slot, varredura de recarga com segundos e brilho ao ficar pronta; slot vazio aparece como "—".
- Sem summon: painel apagado com "[E] Invocar" ou a recarga.
- Ícones vetoriais em código (`ui/ui_icons.gd`): coração (vida), chama (arte), retratos e um glifo por skill — para adicionar uma skill nova, inclua o id no `match` de `UiIcons.skill` e a cor em `SKILL_COLORS`.
- Conferir visualmente: `tools/hud_shot` (janela) salva capturas com golem e sacerdote.

## Painel do jogador (`ui/player_panel.gd`)
Canto superior esquerdo: retrato (elmo), barra de vida com número, rastro do dano, marcas de 25% e pulso vermelho abaixo de 30%; medidor da arte da arma em 2 segmentos (pisca e mostra "PRONTA" quando há carga) com nome e tecla; 3 estâncias do ataque carregado (aparecem só enquanto carrega); buffs/debuffs como ícones com varredura e segundos restantes logo abaixo. Substitui as barras soltas antigas do `hud.gd`.
