---
tipo: conceito
tags: [animação, design]
arquivos-fonte:
  - characters/poses.gd
  - player/states/attack.gd
---


# Peso dos golpes

`Poses.WEIGHT[anim]` vai de **0 (seco e leve)** a **1 (brutal)** e controla a *sensação* de peso:

| Peso baixo (espada) | Peso alto (martelo) |
|---|---|
| sai já em movimento (ease-out) | acelera devagar, vence o peso |
| preparação curta | recua além da preparação (carga) |
| cascata curta, mola firme | cascata acelerada (`power` até 2,6), mola com folga |
| volta à guarda suave, encadeia | assenta rápido, **cravado** (`HOLD`), levanta devagar |
| sem tranco | **tranco** de tronco/ombro/quadril + tremor de câmera (peso ≥ 0,75) |

## Tabela de pesos (principais)
| Golpe | Peso |
|---|---|
| `a1`, `a2` | 0,2 |
| `a3` | 0,6 |
| `spin` | 0,4 |
| `overhead` | 1,0 |
| `hm_swing_r` / `hm_swing_l` | 0,85 / 0,9 |
| `hm_smash`, `hm_charge`, `hm_art_slam` | 1,0 |
| `hm_lunge`, `hm_rising`, `hm_spin` | 0,9 |
| `hm_plunge` | 0,95 |

## Ferramentas de peso no código
- `lunge_delay` (carrega plantado, [[Golpes (AttackData)]]).
- `HOLD` e `CHARGE_SHAKE` em [[Poses e molas]].
- Mola mais lenta e menos amortecida para o martelo.
- `GameFeel.shake` e `rig.kick` em `attack.gd` ([[Game feel]]).
Ver [[Martelo]] e [[Espada longa]].
