---
tipo: sistema
tags: [combate, carga]
arquivos-fonte:
  - player/states/charge.gd
  - player/states/attack.gd
  - player/player.gd
---


# Ataque carregado (3 estâncias)

Depois de um golpe do combo, **segurar o ataque** (≥ 0,25 s após `cancel_start`) entra no estado `Charge`:
o personagem mantém a preparação do golpe pesado da arma e **sobe de estância** enquanto segura. **Soltar** executa
o golpe com os multiplicadores da estância. Só no chão.

- Espada → `overhead` ([[Espada longa]]) · Martelo → esmagamento carregado `h_charge` ([[Martelo]]).

## Estâncias
| Estância | Tempo segurando | Dano | Poise (alvo) | Knockback | Hitbox | **Mitigação** ao carregar | Poise próprio ÷ |
|---|---|---|---|---|---|---|---|
| 0 | 0 s | ×1,0 | ×1,0 | ×1,0 | ×1,0 | −15% | 1,5 |
| 1 | 0,45 s | ×1,4 | ×1,4 | ×1,2 | ×1,1 | −30% | 2,5 |
| 2 | 0,95 s | ×1,9 | ×2,0 | ×1,5 | ×1,25 | −45% | 4 |
| 3 | 1,55 s | ×2,6 | ×3,0 | ×1,9 | ×1,5 | −60% | 8 (inabalável) |

Regras extras:
- **Estância ≥ 2**: o golpe vira `poise_break` (quebra super armor) e o jogador ignora `poise_break` recebido.
- **Estância 3**: lança o inimigo (`launch ≥ 5`), hitstun ≥ 1 s, **onda de choque** no chão e tremor de câmera; o jogador não cambaleia (só `launch` derruba).
- A **mitigação continua durante a startup e a janela ativa** do golpe liberado.
- Soltar antes da estância 1 faz o golpe com multiplicadores ×1,0.
- Durante a carga: anda a 1,4 m/s; **esquiva cancela**; ao tomar hit forte o estado é interrompido.

## Feedback
- Corpo brilha e treme mais a cada estância; anel de energia (`Fx.burst`) com cor própria:
  branco → amarelo → laranja → vermelho (`Player.CHARGE_COLORS`).
- Rastro da arma muda de cor ao golpear.
- **HUD**: 3 barras que enchem ([[HUD]]).
- Som: `clink` com tom crescente; `art_use` na estância 3.

> [!info] Fonte
> Constantes `CHARGE_*` em `player/player.gd`; lógica em `player/states/charge.gd` e `_hit_data()` em `attack.gd`.
> Teste: [[Ferramentas de teste]] (`charge_probe`).
