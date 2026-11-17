extends PlayerState
## Subindo ou caindo.

var _fall_speed := 0.0


func enter(_msg: Dictionary = {}) -> void:
	_fall_speed = 0.0


func physics_update(delta: float) -> void:
	var p := player
	p.apply_gravity(delta)
	_fall_speed = minf(_fall_speed, p.velocity.y)

	if p.buffered(&"jump") and p.coyote > 0.0:
		p.consume(&"jump")
		p.velocity.y = p.jump_velocity
		Sfx.play(&"jump", p.global_position)
		p.coyote = 0.0
	if Input.is_action_just_released("jump") and p.velocity.y > 0.0:
		p.velocity.y *= 0.5 # pulo variável
	if try_actions():
		return

	var dir := p.get_move_dir()
	p.accelerate(dir, p.move_speed(), p.air_acceleration, delta)
	p.update_facing(dir, delta)
	p.move_and_slide()
	p.anim_motion()

	if p.is_on_floor() and p.velocity.y <= 0.1:
		if _fall_speed < -7.0: # só pousos de queda de verdade fazem barulho
			Sfx.play(&"land", p.global_position, -3.0)
		machine.change_to(&"Ground")
