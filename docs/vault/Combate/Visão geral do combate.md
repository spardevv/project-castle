---
tipo: conceito
tags: [combate]
arquivos-fonte:
  - combat/
  - player/states/attack.gd
---


# Visão geral do combate

```
input ─► Combos e movesets ─► Golpes (AttackData) ─► Hitbox ─► Hurtbox ─► Health
                                                                │
                                                       Poise e super armor
                                                                │
                                                   Hurt / cambalear  ou  só dano
```

## Ciclo de um golpe
1. **Startup**: o rig arma o golpe (peso define o quanto — [[Peso dos golpes]]). O corpo pode ficar plantado (`lunge_delay`).
2. **Ativo**: a [[Hitbox, Hurtbox e Health|hitbox]] é ligada; arma varre o espaço ou uma caixa é usada.
3. **Impacto**: [[Game feel]] (hitstop, tremor, som) e o alvo recebe dano, knockback e dano de poise.
4. **Recuperação**: volta à guarda; pode ser cancelada ([[Combos e movesets]]).

## Camadas de defesa do jogador
| Camada | Efeito |
|---|---|
| [[Movimento e esquiva]] | i-frames |
| [[Guarda e parry]] | reduz dano; com escudo, nega e abre o inimigo |
| [[Escudo]] | −75% de todo o dano mesmo sem levantar a guarda |
| [[Ataque carregado]] | mitigação enquanto carrega |
| [[Poise e super armor]] | só cambaleia se o poise acabar |

## Ofensa
Combos leves, golpes pesados, [[Ataque carregado]], [[Arte da arma]], skills do [[Summons|summon]] e magia (orbe).
