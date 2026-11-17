extends EnemyState


func physics_update(delta: float) -> void:
	var en := e
	var to := en.to_player()
	en.apply_gravity(delta)
	if to == Vector3.ZERO:
		machine.change_to(&"Idle")
		return
	var dist := to.length()
	var dir := to / maxf(dist, 0.001)
	var sep := en.separation()
	if dist > en.attack_range * 0.8:
		en.accelerate((dir + sep).limit_length(1.0), en.move_spd(), 25.0, delta)
	else:
		en.accelerate(sep.limit_length(1.0), en.move_spd() * 0.5, 25.0, delta)
	en.face(dir, delta)
	en.move_and_slide()
	en.anim_motion()

	if dist < en.attack_range and en.attack_cd <= 0.0:
		machine.change_to(&"Attack")
	elif dist > en.detect_range * 1.8:
		machine.change_to(&"Idle")
