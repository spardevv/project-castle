---
tipo: sistema
tags: [jogador, mobilidade]
arquivos-fonte:
  - player/states/dodge.gd
  - player/states/ground.gd
---


# Movimento e esquiva

## Movimento
Direção relativa à câmera (`Player.get_move_dir`). Fora do lock-on o personagem olha para onde anda; em
lock-on ele faz *strafe* olhando o alvo ([[Lock-on e câmera]]). A locomoção do rig usa a fase do passo
acoplada à **distância andada**, então os pés não deslizam ([[Rig humanoide]]).

## Esquiva (`dodge.gd`)
| Parâmetro | Valor |
|---|---|
| Velocidade inicial | 9 m/s, decai até 20% (~2,8 m no total) |
| Duração | 0,6 s (rolamento de [[Captura de movimento]] legível) |
| **I-frames** | 0,34 s |
| Cooldown | 0,5 s |
| Cancel em ataque | a partir de 0,32 s (`attack_cancel_time`) |

- Sem direção no analógico: passo **para trás**.
- Atravessa inimigos (`contact_enabled = false`).
- Cancela a [[Ataque carregado|carga]] e é a única forma de sair dela sem soltar o golpe.

> [!tip] Design
> A esquiva é o "reset" universal: serve para sair de golpes seus durante a recuperação
> ([[Combos e movesets]]) e para evitar ataques inimigos ([[IA dos inimigos]]).
