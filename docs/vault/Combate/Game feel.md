---
tipo: sistema
tags: [combate, feedback]
arquivos-fonte:
  - systems/game_feel.gd
  - player/camera_rig.gd
---


# Game feel

Autoload `GameFeel`: o "tempero" que dá peso aos golpes.

| Efeito | Regra |
|---|---|
| **Hitstop local** | Atacante e vítima congelam (estado + rig); o resto do jogo segue. Duração = `hitstop × 1,5`, mínimo 0,07 s; vítima ×1,15 com tremor do corpo; morte ×1,6 (≥ 0,15 s). |
| **Slow-mo** | Global e curto: dano ≥ 25 (0,06 s a 20% da velocidade) ou morte (0,1 s). Também no parry e ao iniciar a [[Arte da arma]]. |
| **Screen shake** | Intensidade `0,08 + dano × 0,008` (0,12–0,4), direcional (empurra a câmera para onde o golpe vai + FOV punch) — [[Lock-on e câmera]]. |
| **Rumble** | Só com controle: forte ao ser atingido, proporcional ao dano ao acertar. |
| **Som** | `hit`, `hit_heavy` (≥ 25), `hit_kill`, `clink` (bloqueio). |

Golpes pesados ainda disparam tremor ao **sair** (`attack.gd`): peso ≥ 0,75 → 0,07; dano ≥ 30 ou `poise_break` → 0,12.
O martelo também dá um **tranco** no tronco/braço no impacto ([[Peso dos golpes]]).
