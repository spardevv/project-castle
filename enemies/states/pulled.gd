extends EnemyState
## Puxado até uma posição (skill Agarrar do summon).

const MAX_TIME := 0.7
const PULL_SPEED := 16.0
const STOP_DISTANCE := 1.6

var _t := 0.0
var _pos := Vector3.ZERO


func enter(msg: Dictionary = {}) -> void:
	_t = 0.0
	_pos = msg.get("pos", e.global_position)
	e.velocity.y = 0.0


func physics_update(delta: float) -> void:
	var en := e
	_t += delta
	en.apply_gravity(delta)
	var to := _pos - en.global_position
	to.y = 0.0
	var dist := to.length()
	if dist > STOP_DISTANCE and _t < MAX_TIME:
		var dir := to / dist
		en.velocity.x = dir.x * PULL_SPEED
		en.velocity.z = dir.z * PULL_SPEED
		en.face(dir, delta)
	else:
		en.accelerate(Vector3.ZERO, 0.0, 40.0, delta)
	en.rig.set_hurt(0.2, to if dist > 0.01 else Vector3.ZERO)
	en.move_and_slide()
	if _t >= MAX_TIME or dist <= STOP_DISTANCE:
		machine.change_to(en.engage_state)
