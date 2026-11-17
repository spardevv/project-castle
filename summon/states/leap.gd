extends SummonState
## Salto esmagador (passiva): agacha, salta até o alvo e esmaga o chão ao pousar (explosão em área).

const WINDUP := 0.25
const MAX_SPEED := 14.0
const LAUNCH_VY := 9.0
const RECOVERY := 0.4

var _t := 0.0
var _jumped := false
var _landed := false
var _land_t := 0.0
var _dest := Vector3.ZERO


func enter(_msg: Dictionary = {}) -> void:
	_t = 0.0
	_jumped = false
	_landed = false
	_land_t = 0.0
	var target := s.find_target()
	_dest = target.global_position if target != null else s.global_position + s.forward() * 5.0


func exit() -> void:
	s.rig.set_glow(Color.BLACK)


func physics_update(delta: float) -> void:
	var c := s
	_t += delta
	c.apply_gravity(delta)
	c.rig.set_attack("overhead", WINDUP, 0.4, RECOVERY, _t if not _landed else WINDUP + 0.4 + _land_t)

	if not _jumped:
		c.accelerate(Vector3.ZERO, 0.0, 40.0, delta)
		c.rig.set_glow(Color(1.0, 0.7, 0.2) * clampf(_t / WINDUP, 0.0, 1.0))
		var to := _dest - c.global_position
		to.y = 0.0
		c.face(to.normalized(), delta, 14.0)
		if _t >= WINDUP:
			_jumped = true
			var flight := 2.0 * LAUNCH_VY / (9.81 * 2.2) # tempo de voo com a gravidade do jogo
			var v := to / maxf(flight, 0.1)
			if v.length() > MAX_SPEED:
				v = v.normalized() * MAX_SPEED
			c.velocity = Vector3(v.x, LAUNCH_VY, v.z)
			c.rig.set_glow(Color.BLACK)
	elif not _landed:
		if c.is_on_floor() and _t > WINDUP + 0.15:
			_landed = true
			_smash()
	else:
		_land_t += delta
		c.accelerate(Vector3.ZERO, 0.0, 40.0, delta)

	c.move_and_slide()
	if _landed and _land_t >= RECOVERY:
		machine.change_to(&"Chase")


func _smash() -> void:
	var c := s
	var ex := Explosion.new()
	ex.radius = 3.4
	ex.damage = 16
	ex.knockback = 7.0
	ex.launch = 5.5
	ex.color = Color(0.85, 0.6, 0.25)
	ex.instigator = c
	ex.position = c.global_position + Vector3(0, 0.3, 0)
	c.get_parent().add_child(ex)
