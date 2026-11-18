extends PlayerState
## Besta automática: enquanto o botão secundário estiver segurado, dispara virotes em rajada
## (pouco dano cada, cadência alta). Anda devagar enquanto atira; esquiva e golpes cancelam.

const FIRE_INTERVAL := 0.12
const MOVE_SPEED := 2.4
const MIN_TIME := 0.2 # pelo menos um disparo mesmo num toque rápido
const COOLDOWN := 0.25

var _t := 0.0
var _shot_t := 99.0


func enter(_msg: Dictionary = {}) -> void:
	_t = 0.0
	_shot_t = FIRE_INTERVAL # primeiro disparo imediato
	player.combo_memory_time = 0.0
	player.snap_face_to_intent()


func exit() -> void:
	player.secondary_cooldown = COOLDOWN
	player.rig.set_offhand_charge(0.0)


func physics_update(delta: float) -> void:
	var p := player
	_t += delta
	_shot_t += delta
	if not p.is_on_floor():
		p.apply_gravity(delta, 0.5)

	if p.buffered(&"dodge") and p.can_dodge():
		p.consume(&"dodge")
		machine.change_to(&"Dodge")
		return
	if p.consume(&"attack"):
		p.start_attack()
		return

	var dir := p.get_move_dir()
	p.accelerate(dir, MOVE_SPEED, 30.0, delta)
	if p.has_lock():
		var to := p.lock_target.global_position - p.global_position
		p.update_facing(Vector3(to.x, 0.0, to.z).normalized(), delta)
	else:
		p.update_facing(dir, delta)

	if _shot_t >= FIRE_INTERVAL:
		_shot_t = 0.0
		p.fire_bolt()
	p.rig.set_attack("cast", 0.04, 0.06, 0.1, _shot_t)
	p.rig.set_offhand_charge(1.0 - _shot_t / FIRE_INTERVAL)

	p.move_and_slide()
	if _t >= MIN_TIME and not Input.is_action_pressed("secondary"):
		land_or_fall()
