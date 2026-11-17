extends PlayerState
## Idle + andar/correr: no chão (ou dentro do coyote time).


func physics_update(delta: float) -> void:
	var p := player
	if not p.is_on_floor():
		p.apply_gravity(delta)

	if p.buffered(&"jump") and p.coyote > 0.0:
		p.consume(&"jump")
		p.velocity.y = p.jump_velocity
		Sfx.play(&"jump", p.global_position)
		p.coyote = 0.0
		machine.change_to(&"Air")
		return
	if try_actions():
		return
	if Input.is_action_pressed("guard") and p.is_on_floor():
		machine.change_to(&"Guard")
		return

	var dir := p.get_move_dir()
	p.accelerate(dir, p.move_speed(), p.acceleration, delta)
	p.update_facing(dir, delta)
	p.move_and_slide()
	p.anim_motion()

	if not p.is_on_floor() and p.coyote <= 0.0:
		machine.change_to(&"Air")
