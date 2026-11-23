# Project Castle

Jogo de ação 3D em 3ª pessoa (Godot **4.7.2**, GDScript, Forward+, física **Jolt**), estilo Souls-lite/DMC:
armas pesadas, poise, esquiva com i-frames e um summon aliado. A documentação de gameplay (o "porquê" e os
valores reais) fica no vault do Obsidian em `docs/vault/`. Comece por `00 - Início.md` e `Mapa de sistemas.md`.

## Idioma
Código (identificadores) em inglês; **comentários, docstrings `##`, docs, mensagens de commit e conversa em português**.

## Ferramentas nesta máquina
- Godot: `C:\Users\gabriel.ramos\Documents\Godot_v4.7.2-stable_win64.exe` (fora do PATH; use `$GODOT_PATH` se definido).
- Blender 5.1: `C:\Program Files\Blender Foundation\Blender 5.1\blender.exe` (scripts em `tools/blender/`, rodar com `-b --factory-startup -P`).
- gdtoolkit: `gdlint`/`gdformat` em `%APPDATA%\Python\Python313\Scripts\` (config em `gdlintrc`).
- MCP `godot` (`.mcp.json`): roda o projeto **com janela** e captura a saída de debug (`run_project`, `get_debug_output`, `stop_project`).
- Validação completa: skill `/validar` (lint + carga no editor + testes GUT + checagem de `.tscn`).

## Estrutura
| Pasta | Conteúdo |
|---|---|
| `systems/` | autoloads (`EventBus`, `GameState`, `GameFeel`, `InputGlyphs`, `BodyContacts`, `Sfx`, `Settings`) + `State`/`StateMachine` |
| `player/`, `player/states/` | `Player` e seus estados (um `State` por arquivo: ground, air, attack, dodge, guard, charge...) |
| `enemies/`, `summon/` | inimigos e summons, também por máquina de estados |
| `combat/` | `Hitbox`, `Hurtbox`, `Health`, `HitData`, `AttackData`, `MoveSet`, projéteis, efeitos |
| `data/attacks/<arma>/*.tres`, `data/weapons/` | golpes (AttackData) e definição das armas |
| `characters/` | rig humanoide procedural (`humanoid_rig.gd`), poses (`poses.gd`), modelos `.glb` e clipes |
| `ui/` | HUD, menus de pausa e equipamento, ícones vetoriais |
| `tools/` | probes de desenvolvimento (`*_probe.tscn` headless, `*_shot.tscn`/`pose_sheet`/`lineup` com janela), scripts Blender e ComfyUI |
| `tests/` | testes GUT |
| `addons/` | GUT e Debug Draw 3D (terceiros, não editar) |

Camadas de física: 1 world · 2 player · 3 enemy · 4 player_hitbox · 5 enemy_hitbox · 6 interactable.

## Convenções
- Classes com `class_name` e docstring `##` logo abaixo do `extends`. Tipagem estática (`: int`, `-> void`, `:=`).
- Comunicação global via sinais do `EventBus`; não buscar nós por caminho entre sistemas.
- Golpes novos = `.tres` de `AttackData` + aresta no `MoveSet` + pose em `characters/poses.gd`.
- **`.tscn` escrito à mão**: todo `@export` do tipo Node atribuído com `NodePath(...)` precisa de
  `node_paths=PackedStringArray("prop")` no cabeçalho do nó, senão carrega `null` **sem erro**.
- Inferência `:=` a partir de propriedade sem tipo já quebrou a resolução de classes. Prefira tipo explícito nesses casos.
- Ao mudar um sistema, atualize a nota correspondente em `docs/vault/` (o frontmatter `arquivos-fonte` diz qual).

## Validar antes de entregar
1. `/validar` (ou os comandos abaixo). Não confie em `--check-only --script`: ele não carrega autoloads e acusa
   "Identifier not found" falso para `EventBus`/`GameFeel` etc.
2. Stdout do Godot não é capturado no Windows: **sempre** `--log-file <arquivo>` e leia o log.
```
godot --headless --editor --path . --quit-after 300 --log-file out.log      # erros de script/cena
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit --log-file gut.log
godot --headless --path . res://tools/feature_probe.tscn --quit-after 4500 --log-file probe.log
godot --path . res://tools/pose_sheet.tscn --resolution 1500x720 -- <saida> [filtro]   # precisa de janela
```
3. Mudança visual (pose, rig, HUD): gere a captura com a ferramenta `*_shot`/`pose_sheet` e **olhe o PNG** antes de entregar.
4. Se o editor do usuário estiver aberto, ele pode manter o arquivo antigo em memória: peça para recarregar, não salvar por cima.
