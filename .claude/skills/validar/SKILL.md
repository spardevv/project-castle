---
name: validar
description: Valida mudanças no Project Castle (Godot 4.7) antes de entregar. Roda gdlint, checa node_paths em .tscn escritos à mão, carrega o projeto no editor headless para pegar erros de script/cena e executa os testes GUT; opcionalmente roda uma probe de tools/. Use sempre depois de editar .gd ou .tscn, ou quando o usuário pedir para validar/testar.
---

# Validar o Project Castle

Rode na raiz do projeto, pelo Bash (Git Bash):

```
bash .claude/skills/validar/validate.sh                 # só arquivos alterados/novos
bash .claude/skills/validar/validate.sh --all           # projeto inteiro
bash .claude/skills/validar/validate.sh --probe feature_probe   # + uma probe headless de tools/
bash .claude/skills/validar/validate.sh --probe summon_kit_probe --fixed-fps 60 --quit-after 20000
```

Leva ~15 s. Termina com `RESULTADO: OK` ou `RESULTADO: FALHOU`; os logs completos ficam na pasta indicada no fim.

## Como agir no resultado
- **gdlint**: corrija o que aparecer nos arquivos que você mexeu. Avisos em código que não é seu: só mencione.
  Problemas conhecidos e aceitos: `sfx.gd` (max-returns), `summon/states/arrive.gd` (delta não usado), `tests/test_rig.gd` (load duplicado).
- **node_paths**: sempre bug real. Adicione `node_paths=PackedStringArray("prop", ...)` ao cabeçalho do nó (antes de `instance=` em cenas instanciadas).
- **Carga no editor**: `SCRIPT ERROR`/`Parse Error` é bloqueante. "Could not resolve class X" costuma ser `:=` inferido de propriedade sem tipo: use tipo explícito.
- **GUT**: o aviso "This version of GUT may not be compatible with Godot 4.7.2" é esperado e não é falha.
  O `tests/test_scripts_load.gd` compila todo `.gd` fora de `addons/`: é ele que pega erro em `tools/`, que a carga
  no editor não abre.
- **Probe**: falha se sair com código ≠ 0, tiver linha `FAIL ` ou erro de script. As probes dos summons
  (`summon_kit_probe`, `summon_trial_probe`) precisam de `--fixed-fps 60 --quit-after 20000`.
- Escolha a probe pelo que mudou (tabela em `docs/vault/Ferramentas/Ferramentas de teste.md`): combate → `combat_probe`/`feature_probe`,
  carga/arte → `charge_probe`, escudo/martelo → `gear_probe`, summon → `summon_probe`/`summon_kit_probe`/`summon_trial_probe`, lança/besta/mago → `new_gear_probe`.
- Mudança visual: rode também a ferramenta com janela (`pose_sheet`, `*_shot`, `lineup`) e abra os PNGs com Read.
  Para ver o jogo rodando de verdade, use o MCP `godot` (`run_project` + `get_debug_output`).

Nunca entregue com `RESULTADO: FALHOU` sem dizer ao usuário o que falhou e por quê.
