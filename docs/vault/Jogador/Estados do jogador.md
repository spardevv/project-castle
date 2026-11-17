---
tipo: sistema
tags: [jogador, estados]
arquivos-fonte:
  - player/states/
  - systems/state_machine.gd
---


# Estados do jogador

O jogador usa uma máquina de estados genérica (`systems/state_machine.gd`): cada estado é um nó filho de
`StateMachine` com `enter`, `exit` e `physics_update`. O `Player.tick()` roda antes do estado atual
(buffers, regen de poise, lock-on).

| Estado | Faz | Sai para |
|---|---|---|
| `Ground` | Idle, andar, correr | Air, Attack, Dodge, Guard, Cast, Art, Bash |
| `Air` | Subindo/caindo; golpes aéreos | Ground, Attack |
| `Attack` | Executa um `AttackData` ([[Golpes (AttackData)]]); encadeia/cancela | Attack, Charge, Art, Dodge, Ground |
| `Charge` | Segura a preparação do golpe e sobe de estância ([[Ataque carregado]]) | Attack (soltou), Dodge, Air |
| `Art` | Sequência da [[Arte da arma]] com i-frames | Ground/Air |
| `Dodge` | Esquiva com i-frames ([[Movimento e esquiva]]) | Attack, Ground, Air |
| `Guard` | LT segurado ([[Guarda e parry]]) | Ground, Air |
| `Cast` | Bola de fogo do orbe | Dodge, Attack, Ground |
| `Bash` | Investida de escudo ([[Escudo]]) | Attack, Ground |
| `Hurt` | Hitstun com knockback; pose segue a direção do golpe | Ground |
| `Dead` | Cai e recarrega a cena | — |

`try_actions()` (em `player_state.gd`) concentra as transições comuns: esquiva > arte > ataque > secundário.

## Hit-stop
`Player.hit_pause()` congela **o estado e o rig** ([[Game feel]]).

> [!info] Fonte
> `player/states/*.gd`, `systems/state_machine.gd`.
