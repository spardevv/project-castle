---
tipo: planejamento
tags: [roadmap]
arquivos-fonte:
  - systems/game_state.gd
---


# Roadmap (observado no código)

Itens abaixo vêm de comentários/estruturas existentes; não são promessas.

- **Save/progresso** (Fase 2): `GameState.abilities` e `world_flags` já existem ([[Loadout e equipamento]]).
- **Mais armas**: o `MoveSet` suporta arte, carga (`ChargeProfile`) e golpes de duas mãos por arma
  ([[Combos e movesets]], [[Arte da arma]], [[Ataque carregado]], [[Duas mãos]]); `PRIMARIES` tem espada, martelo e lança.
- **Estâncias de carga diferentes por arma**: a estrutura existe (`MoveSet.charge`), mas as três armas usam os
  mesmos valores — falta balancear com testes de jogo ([[Ataque carregado]]).
- **Mais arquétipos de inimigo** ([[Inimigos]]) e skills ([[Skills do summon]]).
- **Balanceamento do martelo e da lança** após testes de jogo ([[Martelo]], [[Lança]]).
- **Testes automatizados**: `tests/` cobre Health, movesets/AttackData, estâncias de carga e poise dos inimigos;
  o resto do combate ainda depende das probes em `tools/` ([[Ferramentas de teste]]).
