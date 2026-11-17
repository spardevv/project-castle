extends EnemyState


func physics_update(delta: float) -> void:
	var en := e
	en.apply_gravity(delta)
	en.accelerate(Vector3.ZERO, 0.0, 20.0, delta)
	en.move_and_slide()
	en.anim_motion()
	var to := en.to_player()
	if to != Vector3.ZERO and to.length() < en.detect_range:
		machine.change_to(en.engage_state)
