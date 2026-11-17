extends EnemyState
## Arqueiro: puxa a corda (brilho amarelo de aviso), mira com antecipação e solta a flecha.

const ARROW := preload("res://combat/arrow.tscn")
const DRAW := 0.7
const RELEASE := 0.06
const RECOVER := 0.4
## Fração do movimento do alvo usada para antecipar a mira (1 = mira perfeita no ponto previsto).
const LEAD := 0.6

var _t := 0.0
var _fired := false


func enter(_msg: Dictionary = {}) -> void:
	_t = 0.0
	_fired = false


func exit() -> void:
	e.rig.set_glow(Color.BLACK)
	e.shoot_cd = randf_range(2.0, 3.0)


func physics_update(delta: float) -> void:
	var en := e
	_t += delta
	en.apply_gravity(delta)
	en.accelerate(Vector3.ZERO, 0.0, 25.0, delta)
	en.rig.set_attack("e_draw", DRAW, RELEASE, RECOVER, _t)
	var to := en.to_player()
	if to.length() > 0.01:
		en.face(to.normalized(), delta, 14.0)

	if _t < DRAW:
		en.rig.set_glow(Color(1.0, 0.85, 0.2) * (_t / DRAW) * 0.8)
	elif not _fired:
		_fired = true
		en.rig.set_glow(Color.BLACK)
		_fire()

	en.move_and_slide()
	if _t >= DRAW + RELEASE + RECOVER:
		machine.change_to(en.engage_state)


func _fire() -> void:
	var en := e
	var target := en.get_target()
	if target == null:
		return
	var origin := en.global_position + Vector3(0, 1.4, 0) + en.forward() * 0.6
	Sfx.play(&"bow", origin)
	var aim := target.global_position + Vector3(0, 1.1, 0)
	var arrow: Arrow = ARROW.instantiate()
	if target is CharacterBody3D:
		var vel := (target as CharacterBody3D).velocity
		vel.y = 0.0
		aim += vel * (origin.distance_to(aim) / arrow.speed) * LEAD
	arrow.direction = (aim - origin).normalized()
	arrow.source = en
	en.get_parent().add_child(arrow)
	arrow.global_position = origin
	arrow.look_at(origin + arrow.direction)
