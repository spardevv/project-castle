---
tipo: sistema
tags: [animação, poses]
arquivos-fonte:
  - characters/poses.gd
  - characters/humanoid_rig.gd
---


# Poses e molas

## Poses (`characters/poses.gd`)
Biblioteca de poses: **não há keyframes por tempo**. Cada golpe tem 3 poses-chave e o código interpola:

| Chave | Momento |
|---|---|
| `windup` | preparação (antes do impacto) |
| `strike` | impacto |
| `follow` | continuação (follow-through) |

A função `Poses.attack(anim, startup, active, recovery, t, from)` produz a pose para o tempo `t`:
1. **Startup**: `from → windup`. Leve = ease-out (já sai em movimento); pesado = ease-in-out + recuo além da preparação + "afundar" no fim.
2. **Ativo**: `windup → strike` em **cascata** (quadril → tronco → ombro → cotovelo → pulso — `LAG`), efeito de chicote; pesados aceleram mais (`power = 1 + peso×1,6`).
3. **Recuperação**: `strike → follow` (assenta), *hold* opcional (cravado), depois volta à guarda `READY`.

### Encadeamento fluido
`from` = pose do corpo no instante em que o golpe começou (capturada pelo rig). O próximo golpe **parte dela**, nunca da guarda —
é por isso que A1→A2→A3 da [[Espada longa]] é contínuo.

### Convenções
Personagem olha para +Z; membros pendurados: X negativo balança para frente; tronco/cabeça: X positivo inclina para frente;
yaw positivo vira à esquerda; braço direito (arma): Z negativo abre para fora. Ordem de rotação Godot = YXZ.

### Tabelas
`WEIGHT` (peso por golpe — [[Peso dos golpes]]), `HOLD` (frações cravadas), `CHARGE_SHAKE`, `ALIAS` (reuso de poses),
`TWO_HANDED` ([[Duas mãos]]). Poses de reação: `HURT_*`, `AIR_HURT`, `DOWN`, `KNEEL`, guarda, esquiva.

## Molas (rig)
Cada junta persegue a pose-alvo como uma **mola amortecida** (inércia, passa um pouco do ponto, assenta):

| Modo | Freq. (rad/s) | Amortecimento |
|---|---|---|
| Locomoção | 13 | 0,8 |
| Ataque (padrão) | 32 | 0,55 |
| Ataque com **espada** | 36 | 0,72 (firme, fluida) |
| Ataque com **martelo** | 24 | 0,46 (lenta, com folga) |
| Esquiva / Guarda / Dano | 22 / 15 / 26 | 0,7 / 0,75 / 0,42 |

Juntas "pesadas" (quadril, coluna, braço livre) respondem mais devagar (`JOINT_FREQ`).

## Ferramenta
Renderize as poses em PNG com `pose_sheet` ([[Ferramentas de teste]]).
