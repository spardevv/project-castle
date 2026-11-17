class_name PlayerState
extends State

var player: Player:
	get:
		return actor as Player


func land_or_fall() -> void:
	machine.change_to(&"Ground" if player.is_on_floor() else &"Air")


## Transições comuns (esquiva, ataque, secundário). Retorna true se mudou de estado.
func try_actions() -> bool:
	var p := player
	if p.buffered(&"dodge") and p.can_dodge():
		p.consume(&"dodge")
		machine.change_to(&"Dodge")
		return true
	if p.buffered(&"weapon_art") and p.can_art():
		p.consume(&"weapon_art")
		machine.change_to(&"Art")
		return true
	if p.consume(&"attack"):
		p.start_attack()
		return true
	if p.buffered(&"secondary") and p.secondary_cooldown <= 0.0:
		p.consume(&"secondary")
		p.use_secondary()
		return true
	# summon e skills da criatura são tratados direto no Player.tick; weapon_art ainda não existe.
	return false
