---
tipo: sistema
tags: [inimigos]
arquivos-fonte:
  - enemies/enemy.gd
  - enemies/enemy_moves.gd
  - enemies/*.tscn
---


# Inimigos

`Enemy` (`CharacterBody3D`) configurado por exports da cena. Arquétipos: [[Grunt]], [[Brutamontes]], [[Arqueiro]].
Comportamento em [[IA dos inimigos]]. Têm [[Hitbox, Hurtbox e Health|Health]], **poise** próprio e [[Status effects]].

## Poise do inimigo
- `poise_max` (padrão 30), regenera `poise_regen`/s fora do `Stagger`.
- **Armored** durante `Attack` (ou sempre, se `always_armored`): o golpe só faz o inimigo piscar laranja.
- Quebra o poise: `hit.poise_break`, `hit.launch > 0` (se `can_be_launched`) ou dano de poise (`dano × poise_mult`) até zero.
- **Parry**: `parried()` reseta o poise e dá 1,1 s de `Stagger` ([[Guarda e parry]]).
- `bumped()`: arremessado contra outro inimigo → dano 4, hitstun 0,45.
- `taunt(alvo, tempo)`: o summon vira o alvo dele ([[Skills do summon]]).

| Arquétipo | Vida | Velocidade | Poise | Particularidade |
|---|---|---|---|---|
| [[Grunt]] | 60 | 3,5 | 30 | soldado básico |
| [[Brutamontes]] | 180 | 2,4 | 80, sempre armored | não é lançado; massa 6 |
| [[Arqueiro]] | 45 | 3,8 | 8 | mantém distância e atira |

## Mundo
Arena de teste: chão 60×60, 3 degraus, 1 pilar, 2 grunts, 1 brutamontes e 2 arqueiros (`levels/test_arena.tscn`).
Contato entre personagens (empurrões por massa) em `systems/body_contacts.gd`.
