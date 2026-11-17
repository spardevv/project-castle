extends SummonState
## Agarrar: o golem corre até o inimigo travado no lock-on do jogador (ou o mais próximo), o agarra,
## ergue sobre a cabeça e o esmaga no chão. Inimigos que não podem ser erguidos (brutamontes) resistem.

const APPROACH_SPEED := 11.0
const REACH_DISTANCE := 2.0
const APPROACH_TIMEOUT := 2.2
const GRAB_AT := 0.22 # segundos depois de chegar: momento em que as mãos fecham
const LIFT := 0.8 # chegada -> topo da elevação (início do golpe)
const SLAM_ACTIVE := 0.12
const RECOVERY := 0.55
const DAMAGE := 26

var _target: Enemy
var _phase := "approach"
var _t := 0.0
var _grabbed := false


func enter(_msg: Dictionary = {}) -> void:
	_phase = "approach"
	_t = 0.0
	_grabbed = false
	_target = _pick_target()
	s.hold_height = 1.2
	if _target == null:
		machine.change_to(&"Chase")


func exit() -> void:
	# Interrompido (morreu, foi esquivado...): solta quem ainda estiver preso.
	_release()
	s.rig.set_glow(Color.BLACK)


func _pick_target() -> Enemy:
	var c := s
	if is_instance_valid(c.owner_player):
		var locked = c.owner_player.get("lock_target")
		if locked is Enemy and is_instance_valid(locked) and (locked as Enemy).health.current > 0:
			return locked
	return c.nearest_enemy_within(15.0) as Enemy


func _release() -> void:
	if _grabbed and is_instance_valid(_target) and _target.machine.current_name() == "Held":
		_target.machine.change_to(_target.engage_state)
	_grabbed = false


func physics_update(delta: float) -> void:
	var c := s
	_t += delta
	c.apply_gravity(delta)
	if _target == null or not is_instance_valid(_target) or _target.health.current <= 0:
		machine.change_to(&"Chase")
		return

	match _phase:
		"approach":
			_approach(delta)
		"lift":
			_lift(delta)
		"slam":
			_slam(delta)


func _approach(delta: float) -> void:
	var c := s
	var to := _target.global_position - c.global_position
	to.y = 0.0
	var dist := to.length()
	var dir := to / maxf(dist, 0.001)
	c.rig.set_glow(Color(1.0, 0.6, 0.2) * 0.35)
	c.face(dir, delta, 18.0)
	if dist > REACH_DISTANCE:
		c.accelerate(dir, APPROACH_SPEED, 60.0, delta)
		c.move_and_slide()
		c.anim_motion()
		if _t > APPROACH_TIMEOUT:
			machine.change_to(&"Chase")
		return
	_phase = "lift"
	_t = 0.0
	c.velocity = Vector3.ZERO


func _lift(delta: float) -> void:
	var c := s
	c.accelerate(Vector3.ZERO, 0.0, 60.0, delta)
	c.rig.set_attack("rock_throw", LIFT, SLAM_ACTIVE, RECOVERY, _t)
	c.move_and_slide()
	if not _grabbed and _t >= GRAB_AT:
		if not _try_grab():
			return
	if _grabbed:
		c.hold_height = lerpf(1.2, 2.6, clampf((_t - GRAB_AT) / (LIFT - GRAB_AT), 0.0, 1.0))
	if _t >= LIFT:
		_phase = "slam"
		_t = 0.0
		_slam_do()


## Fecha as mãos: o inimigo vira "preso". Brutamontes (não erguíveis) resistem e o golem desiste.
func _try_grab() -> bool:
	var c := s
	if not _target.can_be_launched:
		Fx.damage_number(c, _target.global_position + Vector3(0, 2.4, 0), 0, Color(1.0, 0.7, 0.3), "RESISTIU")
		_target.rig.flash(Color(1.0, 0.6, 0.2), 0.3)
		GameFeel.shake(0.08)
		machine.change_to(&"Chase")
		return false
	_grabbed = true
	Sfx.play(&"punch", _target.global_position + Vector3(0, 1.0, 0), 0.0, 0.8)
	_target.machine.change_to(&"Held", {"holder": c})
	GameFeel.shake(0.1)
	GameFeel.rumble(0.3, 0.3, 0.1)
	c.rig.flash(Color(1.0, 0.7, 0.3), 0.25)
	return true


## Esmaga: solta o inimigo no chão à frente e aplica o golpe (derruba).
func _slam_do() -> void:
	var c := s
	if not _grabbed or not is_instance_valid(_target) or _target.machine.current_name() != "Held":
		return
	_target.global_position = c.global_position + c.forward() * 1.4
	_target.machine.change_to(_target.engage_state)
	_grabbed = false
	var hit := HitData.new()
	hit.damage = DAMAGE
	hit.knockback = 10.5
	hit.hitstun = 0.7
	hit.hitstop = 0.12
	hit.poise_break = true
	hit.source = c
	if _target.health.take_hit(hit):
		var pos := _target.global_position + Vector3.UP
		Fx.spark(c, pos, Color(0.9, 0.7, 0.4))
		Fx.damage_number(c, pos + Vector3(0, 0.8, 0), _target.health.last_damage, Color.WHITE)
		GameFeel.on_hit(hit, _target, _target.health.current <= 0)
	GameFeel.shake(0.3)
	GameFeel.rumble(0.5, 0.6, 0.2)


func _slam(delta: float) -> void:
	var c := s
	c.accelerate(Vector3.ZERO, 0.0, 60.0, delta)
	c.rig.set_attack("rock_throw", LIFT, SLAM_ACTIVE, RECOVERY, LIFT + _t)
	c.move_and_slide()
	if _t >= SLAM_ACTIVE + RECOVERY:
		machine.change_to(&"Chase")
