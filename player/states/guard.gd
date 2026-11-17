extends PlayerState
## Guarda (LT segurado). O comportamento vem do GuardProfile do player:
## sem escudo reduz pouco o dano e ainda sofre colisão; escudos podem dar parry ou bloquear sem colisão.

var time := 0.0


func enter(_msg: Dictionary = {}) -> void:
	time = 0.0


func physics_update(delta: float) -> void:
	var p := player
	time += delta
	if not p.is_on_floor():
		p.apply_gravity(delta)

	if not Input.is_action_pressed("guard"):
		machine.change_to(&"Ground")
		return
	if p.buffered(&"jump") and p.coyote > 0.0:
		p.consume(&"jump")
		p.velocity.y = p.jump_velocity
		p.coyote = 0.0
		machine.change_to(&"Air")
		return
	if try_actions():
		return

	var dir := p.get_move_dir()
	p.accelerate(dir, p.walk_speed * p.guard_profile.move_speed_multiplier, p.acceleration, delta)
	p.update_facing(dir, delta)
	p.move_and_slide()
	p.rig.set_guard(p.guard_profile.uses_shield)

	if not p.is_on_floor() and p.coyote <= 0.0:
		machine.change_to(&"Air")
