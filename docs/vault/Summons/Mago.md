# Mago
Summon de **dano em área** (80 de vida). Fica no **flanco** do jogador (~3,3 m ao lado e um pouco à frente), no lado com menos inimigos (troca só depois de 3 s); foge de inimigos colados e conjura sozinho (`summon/states/caster.gd`). Chegada: clarão arcano que fere e empurra.

**Skills (LB + botão):** Explosão arcana (bola de fogo, 22 em área) · Nova gélida (12 + lentidão) · Tempestade (até 5 raios, 15 cada) · Chuva de meteoros (3 meteoros, 26 cada, com marca no chão e atraso de 0,8 s).
**Passivas:** Orbe arcano, Geada, Chuva ardente, Tempestade elétrica (escolhidas no menu).
Dados em `summon/summon_skills.gd`, efeitos em `summon/states/skill.gd`, cena `summon/mage.tscn`.
