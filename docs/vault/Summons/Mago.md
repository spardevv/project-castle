# Mago
Summon de **controle e dano arcano** (80 de vida). Fica no **flanco** do jogador (~3,3 m ao lado e um pouco à frente), no lado com menos inimigos (troca só depois de 3 s); foge de inimigos colados (`summon/states/caster.gd`).

- **Skill ativa (LB + X):** Banimento — bane o alvo por 20 s (ou o próprio jogador, que atravessa só paredes secretas). Detalhes em [[Skills do summon]].
- **Ataque básico:** seta arcana de alvo único.
- **Passiva:** Orbes arcanas (4 orbes, 40 s de recarga).
- **Ao ser invocado:** zona de dano arcano contínuo que deixa os inimigos lentos (raio 5, 8 s, 4 de dano a cada 0,5 s).

Dados em `summon/summon_skills.gd`, efeitos em `summon/states/skill.gd`, banimento em `enemies/states/banished.gd` e `player/states/banished.gd`, zona e orbes em `combat/arcane_zone.gd` / `combat/arcane_orbs.gd`, cena `summon/mage.tscn`.
