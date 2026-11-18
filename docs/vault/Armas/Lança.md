# Lança
Arma primária (`spear`, menu de equipamento). **Fora dos golpes fica numa mão só, segurada perto do meio da haste** (ponta à frente e para cima ao andar/correr; a haste desliza na mão — `HumanoidRig.SPEAR_REST_SHIFT`). **Nos golpes vai às duas mãos**: a haste desliza para a pegada de estocada (mão direita atrás, esquerda à frente por IK), em ~0,14 s. A guarda é de uma mão (o escudo continua no braço). O moveset é todo de **estocadas** (poses `sp_thrust1/2`, `sp_heavy`, `sp_rising`, `sp_plunge` em `characters/poses.gd`). Mais **alcance** que a espada (a ponta varre ~2,3 m do pulso) e **stun médio** (hitstun 0,55–0,65 s, contra 0,3 da espada): mantém o inimigo a distância e travado para o próximo golpe.

| Entrada | Golpe |
|---|---|
| Y / Y→Y | Estocada / Estocada dupla |
| Y→Y→Y | Estocada profunda (empurra forte) |
| segurar Y | Estocada carregada |
| Frente+Y (lock-on) | Investida |
| Trás+Y (lock-on) | Estocada ascendente (lança o inimigo) |
| Ar | 2 estocadas; Trás+Y = Mergulho (estocada para baixo) |

Arte: **Dança da Lança** (série de estocadas; a última lança o inimigo). Dados em `data/attacks/spear/`, moveset em `data/weapons/spear.gd`.
