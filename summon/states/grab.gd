extends SummonState
## Agarrar (skill ativa do golem).
##  - Com inimigo (o travado no lock-on do jogador ou o mais próximo): corre até ele, o agarra PELO PESCOÇO
##    e o segura por GRIP_TIME s, causando dano baixo por segundo. O inimigo fica preso no estado Held e
##    os golpes do jogador não o soltam. Depois de GRIP_TIME (ou se morrer), é largado no chão.
##  - Sem inimigo por perto e com uma porta pesada ("heavy_door") ao alcance: o golem vai até ela e a abre.

const APPROACH_SPEED := 11.0
const REACH_DISTANCE := 1.7
const APPROACH_TIMEOUT := 2.4
const GRIP_RAMP := 0.3 # tempo para a pose do aperto se formar
const GRIP_TIME := Summon.GRAB_HOLD_TIME
const TICK := 0.5
const TICK_DAMAGE := 3 # 6 de dano por segundo
const HOLD_HEIGHT := 0.6 # pés do inimigo ficam um pouco acima do chão: a mão do golem pega no pescoço
const RELEASE_TIME := 0.4
const DOOR_PUSH := 0.55 # momento do esforço em que a porta cede
const DOOR_TOTAL := 1.3

var _target: Enemy
var _door: Node3D
var _phase := "approach"
var _t := 0.0
var _tick := 0.0
var _grabbed := false


func enter(_msg: Dictionary = {}) -> void:
	_phase = "approach"
	_t = 0.0
	_tick = 0.0
	_grabbed = false
	_door = null
	_target = s.grab_target()
	s.hold_height = HOLD_HEIGHT
	if _target == null:
		_door = s.nearest_heavy_door()
		if _door == null:
			machine.change_to(&"Chase")


func exit() -> void:
	# Interrompido (morreu, foi esquivado...): solta quem ainda estiver preso.
	_release()
	s.rig.set_glow(Color.BLACK)


func _release() -> void:
	if _grabbed and is_instance_valid(_target) and _target.machine.current_name() == "Held":
		_target.global_position = s.global_position + s.forward() * 1.4
		_target.machine.change_to(_target.engage_state)
	_grabbed = false


func physics_update(delta: float) -> void:
	var c := s
	_t += delta
	c.apply_gravity(delta)
	if _door != null:
		_door_update(delta)
		return
	if _target == null or not is_instance_valid(_target) or _target.health.current <= 0:
		machine.change_to(&"Chase")
		return
	match _phase:
		"approach":
			_approach(delta)
		"hold":
			_hold(delta)
		"release":
			_recover(delta)


# --- Inimigo -------------------------------------------------------------------------------

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
	c.velocity = Vector3.ZERO
	_grip()


## Fecha a mão no pescoço: o inimigo vira "preso" (Held) e começa a contagem do aperto.
func _grip() -> void:
	var c := s
	_grabbed = true
	_phase = "hold"
	_t = 0.0
	_tick = 0.0
	Sfx.play(&"punch", _target.global_position + Vector3(0, 1.4, 0), 0.0, 0.8)
	_target.machine.change_to(&"Held", {"holder": c})
	GameFeel.shake(0.1)
	GameFeel.rumble(0.3, 0.3, 0.1)
	c.rig.flash(Color(1.0, 0.7, 0.3), 0.25)


func _hold(delta: float) -> void:
	var c := s
	c.accelerate(Vector3.ZERO, 0.0, 60.0, delta)
	if AnimClip.get_clip("choke_lift") != null:
		# Clipe do Mixamo: alcança (0,5 s), segura (3 s) e solta (0,5 s) = GRIP_TIME.
		c.rig.set_attack("choke_lift", 0.5, GRIP_TIME - 1.0, 0.5, _t)
	else:
		c.rig.set_attack("neck_grip", 0.2, 0.1, 5.0, minf(_t, GRIP_RAMP + 0.01))
	c.rig.set_glow(Color(1.0, 0.6, 0.2) * 0.3)
	c.move_and_slide()
	# Segurança: se o inimigo saiu do Held por outro motivo, o golem o dá por solto.
	if _target.machine.current_name() != "Held":
		_grabbed = false
		machine.change_to(&"Chase")
		return
	_tick += delta
	if _tick >= TICK:
		_tick -= TICK
		c.deal_dot(_target, TICK_DAMAGE, Color(1.0, 0.8, 0.5))
		GameFeel.shake(0.05)
	if _t >= GRIP_TIME:
		_release()
		_phase = "release"
		_t = 0.0
		c.rig.set_glow(Color.BLACK)


func _recover(delta: float) -> void:
	var c := s
	c.accelerate(Vector3.ZERO, 0.0, 40.0, delta)
	c.move_and_slide()
	if _t >= RELEASE_TIME:
		machine.change_to(&"Chase")


# --- Porta pesada --------------------------------------------------------------------------

func _door_update(delta: float) -> void:
	var c := s
	if not is_instance_valid(_door):
		machine.change_to(&"Chase")
		return
	if _phase == "approach":
		var to := _door.global_position - c.global_position
		to.y = 0.0
		var dist := to.length()
		var reach := float(_door.get("reach")) if _door.get("reach") != null else 2.6
		if dist > reach:
			var dir := to / maxf(dist, 0.001)
			c.face(dir, delta, 14.0)
			c.accelerate(dir, c.speed * 1.2, 40.0, delta)
			c.move_and_slide()
			c.anim_motion()
			if _t > 4.0:
				machine.change_to(&"Chase")
			return
		_phase = "push"
		_t = 0.0
		c.velocity = Vector3.ZERO
		return
	c.face((_door.global_position - c.global_position).normalized(), delta, 14.0)
	c.accelerate(Vector3.ZERO, 0.0, 60.0, delta)
	c.rig.set_attack("rock_throw", DOOR_PUSH, 0.1, DOOR_TOTAL - DOOR_PUSH - 0.1, _t)
	c.rig.set_glow(Color(1.0, 0.6, 0.2) * minf(_t / DOOR_PUSH, 1.0) * 0.5)
	c.move_and_slide()
	if _phase == "push" and _t >= DOOR_PUSH:
		_phase = "pushed"
		_door.call("open", c)
		GameFeel.shake(0.25)
		GameFeel.rumble(0.5, 0.6, 0.2)
	if _t >= DOOR_TOTAL:
		machine.change_to(&"Chase")
