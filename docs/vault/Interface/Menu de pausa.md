---
tipo: sistema
tags: [interface, opções]
arquivos-fonte:
  - ui/pause_menu.gd
  - systems/settings.gd
---


# Menu de pausa

**Esc** (teclado) ou **Start** (controle) pausa o jogo. Itens: **Continuar**, **Equipamento** (abre o [[Menu de equipamento]]),
**Reiniciar fase** (recarrega a cena; o loadout do `GameState` é mantido), **Opções** e **Sair do jogo**.
Navegação: ↑/↓ escolhe, ←/→ ou A/Enter troca o valor, B/Esc volta.

> [!info] Atalhos
> O menu de equipamento continua no **Tab**. No controle, o Start agora abre a pausa, e o equipamento fica em
> Start → Equipamento. Esc não solta mais o mouse: o menu de pausa faz isso.

## Opções (autoload `Settings`, salvas em `user://settings.cfg`)
| Grupo | Opção | Valores |
|---|---|---|
| Vídeo | Modo de tela | Janela, Tela cheia (sem borda), Tela cheia exclusiva |
| Vídeo | Resolução (janela) | 1280×720 a 3840×2160 (só em janela; limitada à área útil do monitor) |
| Vídeo | Escala 3D | 50–100% (renderiza o 3D menor; a interface continua nítida) |
| Vídeo | VSync, Limite de FPS, Anti-aliasing (MSAA), Mostrar FPS | |
| Áudio | Volume geral | 0–100% (bus Master) |
| Controles | Sensibilidade da câmera | 0,2–3,0× (mouse e analógico) |
| Controles | Inverter eixo Y, Tremor de tela, Vibração do controle | |

Teste: `tools/pause_probe.tscn` (precisa de janela) abre o menu, tira capturas, troca opções e reinicia.
