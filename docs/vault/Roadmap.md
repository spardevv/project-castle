---
tipo: planejamento
tags: [roadmap]
arquivos-fonte:
  - systems/game_state.gd
---


# Roadmap (observado no código)

Itens abaixo vêm de comentários/estruturas existentes; não são promessas.

- ~~**Save/progresso** (Fase 2)~~: feito — `user://save.cfg` com progresso e loadout ([[Loadout e equipamento]]).
  Próximo: vários slots de save, checkpoints/posição do jogador e uma tela inicial (Continuar / Novo jogo).
- **Mais armas**: o `MoveSet` suporta arte, carga (`ChargeProfile`) e golpes de duas mãos por arma
  ([[Combos e movesets]], [[Arte da arma]], [[Ataque carregado]], [[Duas mãos]]); `PRIMARIES` tem espada, martelo e lança.
- **Estâncias de carga diferentes por arma**: a estrutura existe (`MoveSet.charge`), mas as três armas usam os
  mesmos valores — falta balancear com testes de jogo ([[Ataque carregado]]).
- **Mais arquétipos de inimigo** ([[Inimigos]]) e skills ([[Skills do summon]]).
- **Balanceamento do martelo e da lança** após testes de jogo ([[Martelo]], [[Lança]]).
- **Testes automatizados**: `tests/` cobre Health, movesets/AttackData, estâncias de carga e poise dos inimigos;
  o resto do combate ainda depende das probes em `tools/` ([[Ferramentas de teste]]). Também há testes de save,
  desbloqueio de skills e compilação de todos os scripts.
