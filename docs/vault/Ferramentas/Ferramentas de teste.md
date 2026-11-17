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
| `grab_probe` | headless | skill Agarrar (alvo perto/longe, brutamontes) |
| `spawn_probe` / `summon_probe` / `summon_entry_probe` | headless | posicionamento, passivas, entrada/saída do summon — [[Summons]] |
| `pose_sheet` | **janela** | folhas de pose em PNG (6 momentos × 3/4 e perfil). Filtros: `hm:` (martelo), `sh:` (escudo) — [[Poses e molas]] |
| `lineup` | **janela** | todos os rigs lado a lado — [[Rig humanoide]] |

Comando típico:
```
godot --headless --path . res://tools/charge_probe.tscn --quit-after 4500 --log-file out.log
godot --path . res://tools/pose_sheet.tscn --resolution 1500x720 -- pasta_saida atk_hm_smash
```
