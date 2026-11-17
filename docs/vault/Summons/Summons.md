---
tipo: sistema
tags: [summon]
arquivos-fonte:
  - summon/summon.gd
  - summon/states/
  - systems/game_state.gd
---


# Summons

Criatura aliada invocada com **X**. Escolha em [[Loadout e equipamento]] (golem ou sacerdote). Luta **sozinha** com passivas e recebe comandos
por **LB + botão** ([[Skills do summon]]).

| | [[Golem]] | [[Sacerdote]] |
|---|---|---|
| Papel | tanque / controle | suporte / cura |
| Vida | 200 | 90 |
| Chegada | meteoro (dano 24, lança, slow-mo) | luz sagrada (cura 40, regen 5 s) |
| Slots padrão | quake, taunt, grab, rock | heal, bless, hex, smite |

## Regras gerais
- Segue o jogador (teleporta se > 28 m), persegue inimigos a até `aggro_range` (12 m) do jogador.
- **Esquiva sozinho** a golpes inimigos (cooldown 3 s, i-frames 0,25 s).
- Cooldown de invocação: **8 s** ao dispensar, **14 s** se morre.
- Passivas escolhem o golpe pela distância e quantidade de inimigos (`pick_passive`).
- Cada summon guarda **seus próprios slots** no `GameState`; os timers das skills são preservados ao trocar o loadout.
- Chegada e saída são invulneráveis e animadas.
