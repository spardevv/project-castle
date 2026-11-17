---
tipo: sistema
tags: [combate, dados]
arquivos-fonte:
  - combat/attack_data.gd
  - combat/hit_data.gd
  - data/attacks/
---


# Golpes (`AttackData`)

Todo golpe é um *Resource* (`.tres`) em `data/attacks/<arma>/`. Editável no Inspector.

## Campos
**Dano**: `damage`, `knockback`, `hitstun`, `hitstop`, `launch` (velocidade vertical dada ao alvo — juggle),
`poise_break` (ignora super armor), `poise_mult` (multiplica o dano no poise do alvo).

**Timing** (s): `startup`, `active`, `recovery`, `cancel_start` (a partir daqui pode encadear/cancelar),
`lunge_speed` (avanço do corpo) e `lunge_delay` (fração do startup parado antes de avançar — golpes pesados).

**Movimento**: `self_launch` (sobe ao cortar), `dive_speed` (mergulho), `air_gravity`, `turn_to_input`.

**Hitbox**: `use_sweep` (acerta onde a lâmina passa) ou caixa (`hitbox_size`/`hitbox_offset`).
`shockwave`: onda de choque visual + tremor ([[Game feel]]).

`anim` aponta a chave da animação em `characters/poses.gd` ([[Poses e molas]]); vazio = usa o `id`.

## `HitData`
Cópia criada a cada acerto, com `source`. Carrega dano, knockback, hitstun, hitstop, launch, `poise_break`,
`poise_mult` e `freeze_attacker` (falso em projéteis).

## Onde estão os valores
Tabelas completas: [[Espada longa]] e [[Martelo]]. Multiplicadores do carregamento: [[Ataque carregado]].
