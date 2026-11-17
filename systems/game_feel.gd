extends Node
## Game feel (autoload GameFeel): hit-stop local, slow-mo seletivo, screen shake direcional e vibração.
##
## Hit-stop LOCAL: só atacante e vítima congelam (StateMachine + HumanoidRig); o resto do jogo
## continua. Slow-mo global só em golpes pesados e mortes.

signal shake_requested(intensity: float, direction: Vector3)

## Multiplica o hitstop de cada golpe e garante um mínimo perceptível (em segundos).
const HITSTOP_SCALE := 1.5
const HITSTOP_MIN := 0.07

var _slow_running := false


## Chamado pelo Hitbox quando um golpe acerta. victim = dono do Hurtbox.
func on_hit(hit: HitData, victim: Node, killed: bool, blocked := false) -> void:
	var attacker := hit.source
	_hit_sound(hit, victim, killed, blocked)
	var dir := Vector3.ZERO
	if is_instance_valid(attacker) and victim is Node3D:
		dir = (victim as Node3D).global_position - attacker.global_position
		dir.y = 0.0
		dir = dir.normalized() if dir.length() > 0.01 else Vector3.ZERO

	var d := maxf(hit.hitstop * HITSTOP_SCALE, HITSTOP_MIN) if hit.hitstop > 0.0 else 0.0
	if killed:
		d = maxf(d * 1.6, 0.15)
	if hit.freeze_attacker:
		_pause(attacker, d, false)
	_pause(victim, d * 1.15, true)

	if killed or hit.damage >= 25:
		slowmo(0.2, 0.1 if killed else 0.06)

	shake(clampf(0.08 + hit.damage * 0.008, 0.12, 0.4), dir)

	if is_instance_valid(victim) and victim.is_in_group("player"):
		rumble(0.3, 0.9, 0.25)
	elif is_instance_valid(attacker) and attacker.is_in_group("player"):
		rumble(0.35, clampf(0.15 + hit.damage * 0.01, 0.0, 0.6), 0.1)


## Som do impacto: metal se bloqueado/parry, e mais grave/forte conforme o dano.
func _hit_sound(hit: HitData, victim: Node, killed: bool, blocked: bool) -> void:
	if not (victim is Node3D):
		return
	var pos := (victim as Node3D).global_position + Vector3(0, 1.0, 0)
	if blocked:
		Sfx.play(&"clink", pos)
	elif killed:
		Sfx.play(&"hit_kill", pos)
	elif hit.damage >= 25:
		Sfx.play(&"hit_heavy", pos)
	else:
		Sfx.play(&"hit", pos, 0.0, 0.85 if victim.is_in_group("player") else 1.0)


func shake(intensity: float, direction := Vector3.ZERO) -> void:
	shake_requested.emit(intensity, direction)


## Desaceleração global curta (golpe pesado / finalização).
func slowmo(time_scale: float, duration: float) -> void:
	if _slow_running:
		return
	_slow_running = true
	Engine.time_scale = time_scale
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0
	_slow_running = false


## Vibração em todos os controles conectados (só quando o último input foi de controle).
func rumble(weak: float, strong: float, duration: float) -> void:
	if not InputGlyphs.is_gamepad():
		return
	for id in Input.get_connected_joypads():
		Input.start_joy_vibration(id, clampf(weak, 0.0, 1.0), clampf(strong, 0.0, 1.0), duration)


func _pause(node: Node, duration: float, shake_body: bool) -> void:
	if duration > 0.0 and node != null and is_instance_valid(node) and node.has_method("hit_pause"):
		node.hit_pause(duration, shake_body)
