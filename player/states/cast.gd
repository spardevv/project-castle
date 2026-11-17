extends PlayerState
## Conjurar com o equipamento secundário (orbe): recolhe, projeta o braço e solta a bola de fogo
## no instante em que o braço estica. Depois de soltar, pode cancelar em esquiva ou ataque.

const STARTUP := 0.16 # até soltar o projétil
const ACTIVE := 0.08
const RECOVERY := 0.24
const COOLDOWN := 0.6
const AIR_GRAVITY := 0.3 # conjurar no ar "segura" o corpo um pouco

var _t := 0.0
var _fired := false


func enter(_msg: Dictionary = {}) -> void:
	var p := player
	_t = 0.0
	_fired = false
	p.secondary_cooldown = COOLDOWN
	p.combo_memory_time = 0.0
	p.snap_face_to_intent()
	if not p.is_on_floor() and p.velocity.y < 0.0:
		p.velocity.y *= 0.3


func exit() -> void:
	player.rig.set_offhand_charge(0.0)


func physics_update(delta: float) -> void:
	var p := player
	_t += delta
	p.rig.set_attack("cast", STARTUP, ACTIVE, RECOVERY, _t)
	if not p.is_on_floor():
		p.apply_gravity(delta, AIR_GRAVITY)
	p.accelerate(Vector3.ZERO, 0.0, 30.0, delta)

	if not _fired:
		p.rig.set_offhand_charge(_t / STARTUP)
		if _t >= STARTUP:
			_fired = true
			p.fire_projectile()
	else:
		p.rig.set_offhand_charge(maxf(0.0, 1.0 - (_t - STARTUP) / 0.15))
		if p.buffered(&"dodge") and p.can_dodge():
			p.consume(&"dodge")
			machine.change_to(&"Dodge")
			return
		if _t >= STARTUP + ACTIVE and p.consume(&"attack"):
			p.start_attack()
			return

	p.move_and_slide()
	if _t >= STARTUP + ACTIVE + RECOVERY:
		land_or_fall()
