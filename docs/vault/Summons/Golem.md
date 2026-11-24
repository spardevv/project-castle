---
tipo: summon
tags: [summon, golem]
arquivos-fonte:
  - summon/summon.gd
  - summon/states/
---


# Golem de Pedra

Tanque de pedra (rig com `fist_scale` grande, sem arma). Velocidade 6,5, distância de seguir 3 m, alcance 1,8 m, massa 4, vida 200.

## Ataques básicos
Alternam em ciclo: **soco direito** (9), **soco esquerdo** (9) e **chute espartano** (14, knockback 10). A **ombrada** (12, investida) só sai a 3,2–9 m do alvo, para fechar distância (recarga 5 s).

## Skill ativa
`grab` (Agarrar): aperta o inimigo pelo pescoço por 4 s e abre portas pesadas — ver [[Skills do summon]].

## Passiva
`rock` — pedra com stun de 2 s, recarga 10 s, prioriza aéreos e longa distância.

## Ao ser invocado
Cai como **meteoro** sobre o inimigo travado (ou o mais próximo; sem inimigos, à frente do jogador): dano **60** em área de raio 6,5, lança os alvos, slow-mo e tremor.

Também pula degraus (`leap`) e esquiva ([[Summons]]). Outras skills guardadas: [[Skills do summon]].
