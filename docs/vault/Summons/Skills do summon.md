---
tipo: sistema
tags: [summon, skills]
arquivos-fonte:
  - summon/summon_skills.gd
  - summon/states/skill.gd
  - summon/states/grab.gd
  - levels/secret_wall.gd
  - player/states/banished.gd
  - enemies/states/banished.gd
---


# Skills do summon

No início cada summon tem **uma skill ativa**, **ataques básicos**, **uma skill de chegada** (ao ser invocado) e **uma passiva**.
A skill ativa fica no slot 1 (**LB + X**); os outros slots e as demais skills da biblioteca (`LIBRARY`) ficam guardados para serem liberados depois
(basta incluí-las em `*_CHOICES` de `summon_skills.gd`). Menu: [[Menu de equipamento]].

| | Ativa (LB+X) | Básicos | Passiva | Chegada |
|---|---|---|---|---|
| [[Golem]] | `grab` Agarrar | soco D, soco E, chute espartano, ombrada | `rock` Lançar pedra | meteoro massivo no alvo |
| [[Sacerdote]] | `heal` Cura | — (não ataca) | `p_blessing` Benção | cura 30% ao lado do jogador |
| [[Mago]] | `banish` Banimento | seta arcana | `m_orbs` Orbes arcanas | zona arcana (dano + slow) |

## Golem
- **Agarrar** (14 s): agarra pelo pescoço o inimigo **travado no lock-on** (ou o mais próximo) por **4 s**, dano baixo (6/s, sem fazê-lo cambalear). O inimigo fica no estado `Held` e **os golpes do jogador não o soltam**. Sem inimigo por perto e perto de uma **porta pesada** (`HeavyDoor`, grupo `heavy_door`), o golem a abre. Sem alvo nem porta, a skill é recusada (não gasta recarga).
- **Lançar pedra** (passiva, 10 s): dano 16 + **stun de 2 s** (quebra super armor, sem lançar). Prioriza **inimigos aéreos** e depois os **mais distantes** (4,5–16 m).

## Sacerdote
- **Cura** (1,2 s): +10% da vida máxima do jogador.
- **Benção** (passiva, 35 s — `SummonSkills.BLESSING_COOLDOWN`): ao começar um combate, +25% de dano e +25% de armadura por 5 s (efeito `blessing`). Também deixa o sacerdote **abrir baús encantados** (`EnchantedChest`, botão de interação **F** / D-pad ↑).

## Mago
- **Banimento** (alvo = travado ou mais próximo até 15 m): 20 s em plano alternativo — o inimigo não interage com nada, não é alvo nem sofre dano, fica translúcido (névoa verde) e **tem a ação cancelada**. Criaturas grandes (brutamontes: sem lançamento/armadura constante) voltam **atordoadas por 10 s** (metade). **Recarga de 30 s só conta depois que o banimento acaba.**
  - Sem inimigo à vista, bane o **próprio jogador** (sem recarga): ele flutua (pular/esquiva sobem/descem, no máximo **2,5 m acima do chão** logo abaixo) e sai apertando a skill de novo — ou ao fim dos 20 s — mas só fora de paredes secretas ("Sem espaço"). Serve para locais secretos.
  - Banido (jogador ou inimigo) continua colidindo com o cenário: **não atravessa chão, teto nem paredes comuns**. Só passa por **paredes secretas** (`SecretWall`, grupo `secret_wall`, `levels/secret_wall.gd`), que ficam translúcidas com brilho verde enquanto o jogador está banido. Na arena de teste há uma sala secreta no canto nordeste.
- **Seta arcana** (básico): projétil de alvo único, dano 9, a cada 1,2 s.
- **Orbes arcanas** (passiva, 40 s): 4 orbes giram em volta do mago; cada inimigo que entra em 10 m recebe uma orbe (dano 14, explosão pequena). Somem após 30 s sem alvo.

## Guardadas para depois
Golem: `quake`, `taunt`, `punches`, `rock` ativa, passivas `slam`/`combo`/`spin`. Sacerdote: `ward`, `bless`, `haste`, `renew`, `hex`, `slow`, `smite`, `nova` e passivas `p_aura`/`p_heal`/…
Mago: `blast`, `frostnova`, `storm`, `meteor` e passivas `m_bolt`/`m_frost`/`m_meteor`/`m_storm`.

Efeitos de status: [[Status effects]]. Quem usa: [[Golem]], [[Sacerdote]] e [[Mago]].
