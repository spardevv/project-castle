extends Node
## Sinais globais para desacoplar sistemas (HUD, combate, salas...).

signal player_damaged(amount: int)
signal enemy_killed(enemy: Node)
signal hit_landed(hit_position: Vector3, damage: int)
signal ability_unlocked(ability: StringName)
