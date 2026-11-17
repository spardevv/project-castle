extends EnemyState
## Arqueiro: mantém distância do alvo, anda de lado e atira quando a recarga permite.
## Se o jogador encosta, recua; colado demais, dá um golpe fraco de defesa.

const TOO_CLOSE := 4.0
const TOO_FAR := 13.0
const SHOOT_MIN := 3.0
const SHOOT_MAX := 18.0

var _strafe_sign := 1.0
var _strafe_t := 0.0


func physics_update(delta: float) -> void:
	var en := e
	en.apply_gravity(delta)
	var to := en.to_player()
	if to == Vector3.ZERO:
		machine.change_to(&"Idle")
		return
	var dist := to.length()
	var dir := to / maxf(dist, 0.001)

	var move := Vector3.ZERO
	if dist < TOO_CLOSE:
		move = -dir
	elif dist > TOO_FAR:
		move = dir
	else:
		_strafe_t -= delta
		if _strafe_t <= 0.0:
			_strafe_sign = -_strafe_sign
			_strafe_t = randf_range(1.2, 2.4)
		move = Vector3(-dir.z, 0.0, dir.x) * _strafe_sign * 0.6
	move += en.separation()
	en.accelerate(move.limit_length(1.0), en.move_spd(), 20.0, delta)
	en.face(dir, delta, 10.0)
	en.move_and_slide()
	en.anim_motion()

	if dist < en.attack_range and en.attack_cd <= 0.0:
		machine.change_to(&"Attack")
	elif en.shoot_cd <= 0.0 and dist >= SHOOT_MIN and dist <= SHOOT_MAX:
		machine.change_to(&"Shoot")
	elif dist > en.detect_range * 1.8:
		machine.change_to(&"Idle")
