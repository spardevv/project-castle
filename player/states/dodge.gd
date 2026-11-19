extends PlayerState
## Esquiva com i-frames. Sem input, dá um passo para trás.

## Rolamento de captura de movimento (Mixamo): 0,6 s deixa o giro legível. Velocidade menor que antes
## (14 m/s em 0,38 s) para cobrir a mesma distância (~2,8 m).
@export var dodge_speed := 9.0
@export var duration := 0.6
@export var iframe_time := 0.34
## A partir de quando um ataque cancela o fim da esquiva (s).
@export var attack_cancel_time := 0.32
@export var cooldown := 0.5

var _t := 0.0
var _dir := Vector3.ZERO


func enter(_msg: Dictionary = {}) -> void:
	var p := player
	_t = 0.0
	p.dodge_cooldown = cooldown
	p.combo_memory_time = 0.0
	p.contact_enabled = false # atravessa inimigos durante a esquiva
	Sfx.play(&"whoosh", p.global_position + Vector3(0, 1.0, 0))
	p.health.invulnerable = true
	var dir := p.get_move_dir()
	if dir.length() > 0.1:
		_dir = dir.normalized()
		if not p.has_lock():
			p.snap_face(_dir)
	else:
		_dir = -p.forward()


func exit() -> void:
	player.health.invulnerable = false
	player.contact_enabled = true


func physics_update(delta: float) -> void:
	var p := player
	_t += delta
	var speed := dodge_speed * clampf(1.0 - _t / duration, 0.2, 1.0)
	p.velocity.x = _dir.x * speed
	p.velocity.z = _dir.z * speed
	if not p.is_on_floor():
		p.apply_gravity(delta)

	p.rig.set_dodge(_t / duration, _dir)
	if _t >= iframe_time:
		p.health.invulnerable = false

	# Cancel da recuperação da esquiva em ataque.
	if _t >= attack_cancel_time:
		if p.consume(&"attack"):
			p.start_attack()
			return

	p.move_and_slide()
	if _t >= duration:
		land_or_fall()
