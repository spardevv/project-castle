---
tipo: sistema
tags: [combate]
arquivos-fonte:
  - combat/hitbox.gd
  - combat/hurtbox.gd
  - combat/health.gd
---


# Hitbox, Hurtbox e Health

- **Hitbox** (`Area3D`): só ativa na janela do golpe. Dois modos:
  - **Caixa**: usa a forma da própria área (investidas, ondas, projéteis).
  - **Varredura da arma**: a cada quadro testa uma cápsula ao longo de `sword_base → sword_tip` do [[Rig humanoide]], com 3 subpassos.
    O golpe só acerta **onde a arma passou**. Raio: espada 0,16 / martelo 0,32.
  - Cada alvo só é acertado uma vez por ativação (lista `_already`).
- **Hurtbox**: recebe o golpe e repassa ao `Health`.
- **Health**: `max_health`, `take_hit`, **i-frames** (`invulnerable`, `grant_iframes`), `hit_filter` (um `Callable` que
  modifica o golpe antes do dano — é por aqui que entram guarda, escudo e mitigação: ver `Player._filter_hit`),
  sinais `damaged`, `died`, `changed`.

## Pipeline de dano do jogador (`Player._filter_hit`)
1. Calcula o dano de poise (`dano × poise_mult`).
2. Mitigação de estância ([[Ataque carregado]]).
3. Se não está em guarda: escudo equipado corta 75%.
4. Em guarda: [[Guarda e parry]].
5. `Health.take_hit` → `_on_damaged` decide se cambaleia ([[Poise e super armor]]).
