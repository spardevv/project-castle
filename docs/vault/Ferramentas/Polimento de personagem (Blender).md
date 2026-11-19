---
tipo: ferramenta
tags: [ferramentas, arte, ia]
arquivos-fonte:
  - tools/blender/polish_character.py
---


# Polimento de personagem gerado por IA (Blender)

Modelos gerados por IA (TRELLIS.2, Hunyuan3D, Meshy) acertam a forma, mas borram o **rosto**: o gerador vê o
personagem inteiro numa imagem de ~1024 px, então o rosto tem poucos pixels. O script `tools/blender/polish_character.py`
conserta isso usando a imagem de conceito em alta resolução e deixa o modelo pronto para o jogo.

## O que ele faz
1. **Limpa a malha**: junta vértices duplicados, remove pedaços soltos pequenos e corrige normais.
   **Suaviza a frente do rosto** (`--face-smooth`, padrão 12 passadas): o gerador esculpe sulcos onde a textura dele tinha
   manchas (olhos borrados); esses degraus fazem sombra e esticam a pintura projetada.
2. **Projeta o conceito no rosto**: alinha a vista de frente do modelo com a imagem (topo do cabelo aos pés, centro
   horizontal), projeta a imagem só nas superfícies da **cabeça e pescoço** viradas para a frente e visíveis da frente
   (o cabelo na frente não recebe o rosto), ignora o fundo da imagem e mistura suave com a textura original nas laterais.
3. **Assa** o resultado numa textura nova (4096 por padrão) na GPU (Cycles/OptiX).
4. **Escala** para a altura do jogo (padrão 1,8 m), origem entre os pés, e **exporta** o `.glb`.

## Uso
Rodar sem abrir o Blender (Blender 5.x):
```
blender -b --factory-startup -P tools/blender/polish_character.py -- --glb entrada.glb --ref conceito_frente.png --out characters/models/nome.glb
```
Opções: `--height 1.8` (metros), `--tex 4096`, `--full-body` (projeta também no corpo; só vale se o modelo e o conceito
estão bem alinhados, senão traz o contorno do desenho para os braços/pernas), `--fit` (ajusta o encaixe pela silhueta),
`--preview pasta` (renders de frente, 3/4, costas e rosto, antes e depois).

## A imagem de conceito
Tem que ser a **mesma vista de frente que gerou o modelo** (mesma pose), corpo inteiro e fundo liso.

## Limites conhecidos
- Restam marcas leves embaixo dos olhos e manchas no pescoço (fora da área projetada: estender a projeção até o pescoço
  pega o alto dos ombros e o fundo do desenho). Retoque final: pintura de textura no Blender (modo Texture Paint).
- Testado e descartado: busca automática de encaixe do rosto por correlação (os estilos da textura gerada e da pintura
  diferem demais) e por silhueta (`--fit`, dominada pelo cabelo).
- Lateral e nuca continuam com a textura do gerador.
- Exemplo: `characters/models/elfa_base.glb` (TRELLIS.2 + polimento).


## Olhos de um busto (`--band`)
Para corrigir só uma faixa (ex.: olhos que o gerador pintou sem íris), com o modelo já gerado de um recorte em alta
resolução: `--band 0.18,0.255 --band-width 0.1 --keep-scale`. O encaixe é feito **pelos olhos**: o script renderiza a frente
do modelo com a textura, acha o centro dos dois olhos (pixels claros e neutros) no render e no conceito e alinha
escala e posição por eles.

# Troca de cabeça (`tools/blender/swap_head.py`)
Gera-se um **busto** (do peito para cima, recortado do conceito: o rosto fica ~10x maior que na imagem de corpo inteiro)
e troca-se a cabeça do corpo por ele:
```
blender -b --factory-startup -P tools/blender/swap_head.py -- --body corpo.glb --bust busto.glb --out characters/models/nome.glb --cut 0.175
```
1. **Encaixe**: largura da cabeça e topo do cabelo, depois ICP (rotação + escala + posição) só na cabeça.
2. **Pele x cabelo** (pela cor da textura: cabelo = escuro e neutro; pele em sombra é avermelhada, biquíni esverdeado):
   a pele troca no pescoço (`--cut`, fração da altura a partir do topo) e só dentro da largura do pescoço (os ombros
   do corpo ficam); o cabelo do busto continua até onde ele vai; o cabelo antigo do corpo perto do novo é removido;
   a frente do peito nunca conta como cabelo.
3. **Tom de pele** do busto igualado ao do pescoço do corpo; **limpeza** de pedaços soltos (`--min-island`).
Exemplo: `characters/models/elfa_cabeca_nova.glb` (corte 0.175, `--min-island 0.012`).
4. **Emenda do pescoço**: a borda da pele do busto é encostada na superfície do corpo (sem degrau) e, até ~4 cm de cada
   lado, a cor dos dois vai para o mesmo tom de pele (assado na textura). O cabelo antigo só é removido **na frente**
   (nas costas o cabelo do busto é ralo e removê-lo abria falhas); brilhos cinza do cabelo antigo perto dos ombros saem.
Limites: podem sobrar um ou dois fragmentos pequenos de cabelo nos ombros; apagar à mão no Blender (modo Edit, L em cima
do pedaço, X).


# Esqueleto (`tools/blender/rig_character.py`)
Liga um personagem em pose A ao esqueleto do jogo:
```
blender -b --factory-startup -P tools/blender/rig_character.py -- --glb characters/models/elfa_cabeca_nova.glb --out characters/models/elfa_rig.glb --preview pasta
```
1. **Articulações**: alturas pelo esboço de 8 cabeças (`SKETCH`, igual ao `BodyProportions`); posição
   lateral/profundidade por fatias da malha (sem o cabelo).
   **Braços pela malha**: os pontos mais afastados para o lado são só uma semente; o braço é separado do tronco
   (esfera cortada no ombro, que desce/cresce até soltar — a axila costuma ficar abaixo do ombro do esboço), a ponta
   dos dedos é o vértice do braço mais longe do ombro, e cotovelo e punho ficam no centro da "casca" do braço a
   1,5 e 2,75 de 3,5 cabeças do comprimento medido (segue a dobra da pose A). O log mostra o comprimento do braço em
   cabeças contra o esboço.
   **Postura**: se as pernas vierem inclinadas para trás e o tronco para frente (comum em modelo gerado), o modelo
   inteiro gira pela média das duas inclinações antes de achar as articulações (perna reta no rig = malha sem
   esticar o bumbum). **Bumbum**: atrás da coxa e acima da dobra do glúteo, 75% do peso da coxa vai para o quadril.
   **Cabelo**: cor escura e neutra **e** o pedaço da malha (componente ligado só por vértices dessa cor) sobe acima
   dos ombros — roupa preta (calcinha) fica no corpo em vez de ir para os ossos do cabelo e balançar com a física.
   Depois o cabelo é **cortado do corpo** (arestas entre face de cabelo e face de pele), virando peça solta.
   **Bumbum subdividido** (1 corte, atrás da coxa, da dobra do glúteo até acima do quadril), triangulado sem
   triângulos degenerados e com as normais recalculadas.
2. **Escala**: altura total → 1,94 (8 cabeças no rig). Os comprimentos de membros medidos vão no `.json` e o rig os usa.
3. **Pesos**: proximidade aos segmentos dos ossos (a bacia cobre a linha entre as coxas), **suavizados pela malha**
   (transições graduais, sem rasgar); o cabelo (escuro e neutro, acima do quadril) só segue tronco/cabeça; os ossos do
   braço só pegam vértices **ligados à mão pela malha** com uma esfera cortada no ombro (a pele da cintura não vai
   junto quando o braço sobe).
4. Exporta `.glb` (malha + esqueleto com os nomes do rig) e `.json` (articulações no espaço do rig). `--preview` renderiza
   repouso e uma pose de teste.

# Ver e ajustar o esqueleto (`tools/skeleton_editor.tscn`)
Abra a cena no Godot: o modelo fica semitransparente com as juntas (amarelo = centro, azul = esquerda, vermelho =
direita) e uma linha de prumo do quadril ao chão. Selecione uma junta em **Juntas** e arraste; **Salvar no .json**
grava (o rig usa no próximo play). Os pesos da malha continuam os do Blender: ajuste fino de pivôs aqui, mudanças
grandes refaça o `rig_character.py`. Fotos de frente/lado:
`godot --path . res://tools/skeleton_editor.tscn --resolution 1400x900 -- <pasta>`
