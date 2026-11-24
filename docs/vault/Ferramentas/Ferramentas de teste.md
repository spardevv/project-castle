---
tipo: ferramenta
tags: [ferramentas]
arquivos-fonte:
  - tools/
---


# Ferramentas de teste (`tools/`)

Cenas de desenvolvimento. Rode o Godot (4.7) com `--path .`; **headless** = sem janela, imprime no log.
Dica: passe `--log-file arquivo.log` e leia o log (stdout pode não aparecer).

| Ferramenta | Modo | O que faz |
|---|---|---|
| `combat_probe` | headless | simula golpes contra um inimigo e loga estado/HP por quadro |
| `charge_probe` | headless | ataque carregado (estâncias) e arte do martelo — [[Ataque carregado]], [[Arte da arma]] |
| `feature_probe` | headless | roteiro: lock-on, arte, parry, flechas, brutamontes, skills do summon |
| `gear_probe` | headless | escudo (stance, −75%), martelo, sacerdote, buffs — [[Escudo]] |
| `summon_kit_probe` | headless (`--fixed-fps 60`) | kit inicial dos 3 summons: chegada, básicos, skill ativa e passiva, banimento × paredes secretas (64 verificações) |
| `spawn_probe` / `summon_probe` / `summon_entry_probe` | headless | posicionamento, passivas, entrada/saída do summon — [[Summons]] |
| `pose_sheet` | **janela** | folhas de pose em PNG (6 momentos × 3/4 e perfil). Filtros: `hm:` (martelo), `sh:` (escudo), `sp:` (lança; `sp_` pega os golpes da lança), folha `move_idle` — [[Poses e molas]] |
| `slide_probe` | headless | mede o deslize dos pés apoiados (m/s) em 1,5–7 m/s; ideal ≈ 0 — [[Rig humanoide]] |
| `walk_shot` | **janela** | tira de quadros do rig andando/correndo de perfil (PNG) |
| `new_gear_probe` | headless | lança (alcance/stun), besta (rajada) e mago (flanco, explosão, tempestade, meteoros, nova gélida) — [[Lança]], [[Besta automática]], [[Mago]] |
| `gear_shot` / `hud_shot` | **janela** | capturas de lança, besta e mago / da HUD com cada summon |
| `lineup` | **janela** | todos os rigs lado a lado — [[Rig humanoide]] |

Comando típico:
```
godot --headless --path . res://tools/charge_probe.tscn --quit-after 4500 --log-file out.log
godot --path . res://tools/pose_sheet.tscn --resolution 1500x720 -- pasta_saida atk_hm_smash
```

## Plugins (addons/)
- **GUT** — testes unitários: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`
- **Debug Draw 3D** — desenha linhas/esferas/caixas de debug (`DebugDraw3D.draw_sphere(...)`), útil para pés travados e hitboxes.

## Testes automatizados (`tests/`, GUT)
Rodam headless em ~1 s e falham com mensagem clara (diferente das probes, que você lê no log):
```
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
```
| Arquivo | Cobre |
|---|---|
| `test_health.gd` | dano, morte, invulnerabilidade, i-frames, `hit_filter`, cura |
| `test_movesets.gd` | grafo de combos das 3 armas, `resolve()`, sanidade dos `.tres`, poses existentes, duas mãos |
| `test_charge_profile.gd` | estâncias do [[Ataque carregado]] (`ChargeProfile`) |
| `test_enemy_poise.gd` | super armor, quebra de poise, launch, parry nos inimigos ([[Poise e super armor]]) |
| `test_player_defense.gd` | stance do jogador, escudo, guarda/parry, mitigação da carga, i-frames da esquiva ([[Guarda e parry]]) |
| `test_poses.gd` | locomoção do rig |

Ao criar golpe, arma ou inimigo novo, rode os testes: `test_movesets` pega aresta quebrada, pose inexistente e `cancel_start` fora do golpe.
