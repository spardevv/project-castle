---
tipo: sistema
tags: [summon]
arquivos-fonte:
  - summon/summon.gd
  - summon/states/
  - systems/game_state.gd
---


# Summons

Criatura aliada invocada com **X**. Escolha em [[Loadout e equipamento]] (golem, sacerdote ou mago). Luta **sozinha** com passivas e recebe comandos
por **LB + botão** ([[Skills do summon]]).

| | [[Golem]] | [[Sacerdote]] |
|---|---|---|
| Papel | tanque / controle | suporte / cura |
| Vida | 200 | 90 |
| Chegada | meteoro no alvo (dano 60, raio 6,5) | luz sagrada ao lado (cura 30%, regen 2 s) |
| Skill ativa | grab | heal |
| Passiva | rock | p_blessing |

## Regras gerais
- Segue o jogador (teleporta se > 28 m), persegue inimigos a até `aggro_range` (12 m) do jogador.
- **Esquiva sozinho** a golpes inimigos (cooldown 3 s, i-frames 0,25 s).
- Cooldown de invocação: **8 s** ao dispensar, **14 s** se morre.
- Passivas escolhem o golpe pela distância e quantidade de inimigos (`pick_passive`).
- Cada summon começa com **uma skill ativa, ataques básicos, skill de chegada e uma passiva** ([[Skills do summon]]; o [[Mago]] tem a sua página).
- Cada summon guarda **seus próprios slots** no `GameState`; os timers das skills são preservados ao trocar o loadout.
- Chegada e saída são invulneráveis e animadas.
