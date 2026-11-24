---
tipo: sistema
tags: [summon, mundo, exploração]
arquivos-fonte:
  - levels/heavy_door.gd
  - levels/enchanted_chest.gd
  - levels/secret_wall.gd
  - levels/summon_trial.tscn
---


# Exploração com summons

Cada summon resolve um obstáculo do cenário. As recompensas liberam as skills guardadas ([[Skills do summon]]).

| Obstáculo | Script | Quem resolve | Como |
|---|---|---|---|
| Porta pesada (`HeavyDoor`, grupo `heavy_door`) | `levels/heavy_door.gd` | [[Golem]] | skill Agarrar perto dela (≤ 8 m do golem) e **sem inimigos a 12 m** |
| Baú encantado (`EnchantedChest`, grupo `interactable`) | `levels/enchanted_chest.gd` | [[Sacerdote]] | invocado e com a passiva Benção equipada; botão de interação **F** / D-pad ↑ |
| Parede secreta (`SecretWall`, grupo `secret_wall`) | `levels/secret_wall.gd` | [[Mago]] | Banimento no próprio jogador (sem inimigos a 15 m); só ele a atravessa |

## Baú encantado
- `reward_kind`: `"skill"` → libera `reward_skill` (`reward_is_passive` para uma passiva) e mostra "Nova skill: …"; `"heal"` → cura `heal_fraction` da vida máxima.
- `chest_id` (opcional): grava em `GameState.world_flags`; o baú nasce aberto se já foi aberto.
- Sem o sacerdote: "Selado". Sempre emite `opened(by)`.

## Parede secreta
- Sólida para todos (layer world). Banidos ganham exceção de colisão com ela; o resto do cenário continua sólido e o jogador banido sobe no máximo 2,5 m acima do chão.
- Pistas: tom mais esverdeado e rachaduras; com o Mago invocado as rachaduras pulsam; com o jogador banido a parede fica translúcida e verde.

## Cena de teste `levels/summon_trial.tscn`
Corredor de salas ao longo de −Z (jogador começa em z = 3):
1. **Golem** — 2 grunts e porta pesada em z = −14 (o meteoro de chegada costuma matar os grunts).
2. **Sacerdote** — baú `quake` (`trial_chest_quake`) e baú de cura (`trial_chest_heal`).
3. **Mago** — parede secreta em z = −44.
4. **Sala escondida** — baú `blast` (`trial_chest_blast`): invoque o Sacerdote lá dentro.

Rodar: `godot --path . res://levels/summon_trial.tscn`. Verificação automática: `summon_trial_probe` ([[Ferramentas de teste]]).
