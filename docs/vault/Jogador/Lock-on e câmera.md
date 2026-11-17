---
tipo: sistema
tags: [jogador, câmera]
arquivos-fonte:
  - player/lock_on.gd
  - player/camera_rig.gd
---


# Lock-on e câmera

## Lock-on (`lock_on.gd`)
- Trava no inimigo mais bem posicionado à frente da câmera (alcance 18 m; quebra a 26 m).
- Troca de alvo com o analógico direito (ou *flick* do mouse: 60 px em 0,15 s).
- **Habilita golpes direcionais**: com lock-on, *frente + ataque* e *trás + ataque* escolhem outros golpes
  (ex.: estocada/investida, corte ascendente/uppercut) — ver [[Combos e movesets]].
- O rig vira a cabeça para o alvo ([[Rig humanoide]]).

## Câmera (`camera_rig.gd`) — estilo Devil May Cry 5
| Parâmetro | Valor |
|---|---|
| Distância | 6,5 m (em lock-on 6,5–12 m conforme a distância do alvo) |
| FOV | 72° (lock: 66°) |
| Pitch | −50° a +25° (padrão −14°; lock −20°) |
| Auto-follow | gira para trás do jogador ao correr, após 0,5 s sem input |
| Enquadramento em lock | foco 40% no alvo, 60% no jogador |

Reage ao [[Game feel]]: tremor direcional, "chute" na direção do golpe e FOV punch no impacto.
