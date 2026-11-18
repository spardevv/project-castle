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
  - **Varredura da arma**: a cada quadro testa uma cápsula ao longo de `sword_base → sword_tip` do [[Rig humanoide]].
    Entre dois quadros a arma é **interpolada pela rotação** (segue o arco, não a corda) com subpassos proporcionais ao
    quanto a ponta andou (1 a 16; um subpasso a cada ~1,2 raio). Golpes rápidos não atravessam o alvo entre quadros.
    O golpe só acerta **onde a arma passou**. Raio: espada 0,16 / martelo 0,32 / lança 0,2.
  - Cada alvo só é acertado uma vez por ativação (lista `_already`).
  - Ponto de contato (faísca, número de dano) = ponto da arma mais próximo da **parte do corpo** atingida; `HitData.part`
    guarda qual parte foi ("head", "chest", "arm_l"...).
- **Hurtbox**: recebe o golpe e repassa ao `Health`. Com um [[Rig humanoide]] no dono, vira **16 cápsulas por parte do corpo**
  (cabeça, peito, barriga, pelve; braço, antebraço, mão, coxa, canela e pé de cada lado), reposicionadas a cada quadro
  de física pela pose do rig, com 3 cm de folga (`padding`). Agachado, caído, no ar ou inclinado, só acerta onde o corpo está
  (um corte na altura do peito passa por cima de quem está deitado). A cápsula fixa da cena fica desligada.
- **Debug**: Pausa → Opções → *Mostrar hitboxes* desenha as cápsulas do corpo (verde), a varredura das armas (vermelho)
  e as caixas de golpe (laranja). Captura: `tools/hitbox_shot.tscn`. Testes: `tests/test_hurtbox_parts.gd`.
- **Health**: `max_health`, `take_hit`, **i-frames** (`invulnerable`, `grant_iframes`), `hit_filter` (um `Callable` que
  modifica o golpe antes do dano — é por aqui que entram guarda, escudo e mitigação: ver `Player._filter_hit`),
  sinais `damaged`, `died`, `changed`.

## Pipeline de dano do jogador (`Player._filter_hit`)
1. Calcula o dano de poise (`dano × poise_mult`).
2. Mitigação de estância ([[Ataque carregado]]).
3. Se não está em guarda: escudo equipado corta 75%.
4. Em guarda: [[Guarda e parry]].
5. `Health.take_hit` → `_on_damaged` decide se cambaleia ([[Poise e super armor]]).
