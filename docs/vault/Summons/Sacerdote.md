---
tipo: summon
tags: [summon, sacerdote]
arquivos-fonte:
  - summon/priest.tscn
  - summon/states/support.gd
  - levels/enchanted_chest.gd
---


# Sacerdote

Suporte frágil que mantém distância: fica num anel de 4–8 m do jogador, **recua 6,5 m** do lado oposto quando há ameaça e foge de inimigos a menos de 5,5 m.
Cura e dá buffs ([[Status effects]]); ataca à distância com `smite`.

## Skill ativa
`heal` — cura 10% da vida máxima do jogador (recarga 1,2 s). **Não tem ataque básico.**

## Passiva
`p_blessing` — Benção em combate (+25% dano e armadura por 5 s), recarga 35 s. Permite abrir **baús encantados** com o botão de interação (recompensa configurável: libera uma skill guardada ou cura — ver [[Exploração com summons]]).

## Ao ser invocado
Surge **ao lado (e um pouco atrás)** do jogador e explode em cura: **+30% da vida máxima** e regeneração por 2 s.

Outras skills/passivas (aura, cura divina, escudo de luz…) estão guardadas: [[Skills do summon]].
