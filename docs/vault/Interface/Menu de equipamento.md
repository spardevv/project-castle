---
tipo: sistema
tags: [interface]
arquivos-fonte:
  - ui/equipment_menu.gd
---


# Menu de equipamento

Abre com **Tab/Start** e **pausa** o jogo. Linhas: arma, secundário, summon ativo, 4 slots de skill e passivas.
↑/↓ escolhe, ←/→ ou A/Enter troca, B/Esc fecha. Cada troca chama `GameState.set_*` e o jogo aplica pelo sinal `loadout_changed`
([[Loadout e equipamento]]). Descrições vêm de `SummonSkills` ([[Skills do summon]]).
