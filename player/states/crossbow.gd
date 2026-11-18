extends PlayerState
## Besta automática: enquanto o botão secundário estiver segurado, dispara virotes em sequência.
## Atira andando e correndo normalmente: o braço esquerdo fica estendido mirando (camada de mira do
## rig sobre a locomoção) e não há tranco a cada disparo. Esquiva, ataque e pulo cancelam.

const FIRE_INTERVAL := 0.3 # ~3,3 disparos/s
const FIRST_SHOT_DELAY := 0.08 # tempo para o braço chegar à mira antes do 1º virote
const MIN_TIME := 0.2 # pelo menos um disparo mesmo num toque rápido
const COOLDOWN := 0.25

var _t := 0.0
var _shot_t := 0.0


func enter(_msg: Dictionary = {}) -> void:
	_t = 0.0
	_shot_t = FIRE_INTERVAL - FIRST_SHOT_DELAY
	player.combo_memory_time = 0.0
	player.snap_face_to_intent()
	player.rig.set_aim(true)


func exit() -> void:
	player.secondary_cooldown = COOLDOWN
	player.rig.set_aim(false)


func physics_update(delta: float) -> void:
	var p := player
	_t += delta
	_shot_t += delta
	if not p.is_on_floor():
		p.apply_gravity(delta)

	if p.buffered(&"dodge") and p.can_dodge():
		p.consume(&"dodge")
		machine.change_to(&"Dodge")
		return
	if p.consume(&"attack"):
		p.start_attack()
		return
	if p.buffered(&"jump") and p.coyote > 0.0:
		p.consume(&"jump")
		p.velocity.y = p.jump_velocity
		Sfx.play(&"jump", p.global_position)
		p.coyote = 0.0
		machine.change_to(&"Air")
		return

	# Movimento igual ao normal (andar/correr), virado para o alvo travado ou para onde anda.
	var dir := p.get_move_dir()
	p.accelerate(dir, p.move_speed(), p.acceleration, delta)
	if p.has_lock():
		var to := p.lock_target.global_position - p.global_position
		p.update_facing(Vector3(to.x, 0.0, to.z).normalized(), delta)
	else:
		p.update_facing(dir, delta)

	if _shot_t >= FIRE_INTERVAL:
		_shot_t = 0.0
		p.fire_bolt()

	p.move_and_slide()
	p.anim_motion()
	if _t >= MIN_TIME and not Input.is_action_pressed("secondary"):
		land_or_fall()
