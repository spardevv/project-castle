---
tipo: sistema
tags: [jogador, equipamento]
arquivos-fonte:
  - systems/game_state.gd
  - player/player.gd
---


# Loadout e equipamento

O autoload `GameState` guarda o que está equipado e avisa por sinal (`loadout_changed`); o jogador aplica em
`Player.apply_loadout()`.

| Slot | Opções | Efeito |
|---|---|---|
| **Primário** (arma) | [[Espada longa]], [[Martelo]] | troca moveset, modelo no rig, raio da varredura (martelo 0,32 / espada 0,16), arte da arma |
| **Secundário** (mão esquerda) | Orbe de fogo, [[Escudo]] | B conjura bola de fogo (orbe) ou faz investida (escudo); escudo altera guarda e poise |
| **Summon** | [[Golem]], [[Sacerdote]] | muda criatura e skills ([[Skills do summon]]) |

Só **um** secundário por vez: orbe e escudo ocupam a mão esquerda. Os dois somem momentaneamente durante golpes
de [[Duas mãos]].

Troca pelo [[Menu de equipamento]] (Tab/Start), com o jogo pausado.

## Save (`user://save.cfg`)
O `GameState` grava sozinho (no fim do quadro) quando algo muda: habilidade/skill liberada (`unlock_ability`),
flag do mundo (`set_flag`: baús e portas com id — [[Exploração com summons]]) ou loadout (`loadout_changed`).
Carrega no início do jogo.

| Seção | Chaves |
|---|---|
| `meta` | `version` (`SAVE_VERSION` = 1) |
| `progress` | `abilities`, `world_flags` |
| `loadout` | `primary`, `secondary`, `summon_kind`, `slots`, `passives` (por summon) |

- Valores que não existem mais (arma, summon, skill não liberada) voltam ao padrão; as listas mantêm o tamanho padrão.
- **Headless** (probes, GUT) ou com `-- --no-save`, o arquivo não é lido nem gravado (`GameState.persistence = false`),
  para os testes não sujarem o save do jogador. `save_to(path)` / `load_from(path)` funcionam sempre (testes em `tests/test_save.gd`).
- `reset_progress()` volta ao início e apaga o save — usado por **Apagar progresso** no [[Menu de pausa]].
