extends PlayerState
## Investida de escudo (B com escudo equipado): avanço curto com o escudo à frente.
## Pouco dano, mas quebra a super armor e faz o inimigo cambalear — abre a guarda dele.

const STARTUP := 0.1
const ACTIVE := 0.16
const RECOVERY := 0.3
const COOLDOWN := 0.8
const LUNGE := 9.0
const HITBOX_SIZE := Vector3(1.8, 1.8, 1.4)
const HITBOX_OFFSET := Vector3(0, 1.0, 1.0)

var _t := 0.0
var _hit_started := false
var _hit_ended := false


func enter(_msg: Dictionary = {}) -> void:
	var p := player
	_t = 0.0
	_hit_started = false
	_hit_ended = false
	p.secondary_cooldown = COOLDOWN
	p.combo_memory_time = 0.0
	p.snap_face_to_intent()
	var shape := p.attack_hitbox.get_node("CollisionShape3D") as CollisionShape3D
	(shape.shape as BoxShape3D).size = HITBOX_SIZE
	p.attack_hitbox.position = HITBOX_OFFSET


func exit() -> void:
	player.attack_hitbox.deactivate()


func physics_update(delta: float) -> void:
	var p := player
	_t += delta
	p.rig.set_attack("bash", STARTUP, ACTIVE, RECOVERY, _t)
	if not p.is_on_floor():
		p.apply_gravity(delta)

	if _t < STARTUP + ACTIVE:
		var fwd := p.forward() * (LUNGE if _t >= STARTUP * 0.5 else 2.0)
		p.velocity.x = fwd.x
		p.velocity.z = fwd.z
	else:
		p.accelerate(Vector3.ZERO, 0.0, 40.0, delta)

	if not _hit_started and _t >= STARTUP:
		_hit_started = true
		var hit := HitData.new()
		hit.damage = 6
		hit.knockback = 8.0
		hit.hitstun = 0.7
		hit.hitstop = 0.08
		hit.poise_break = true
		Sfx.play(&"swing_heavy", p.global_position + Vector3(0, 1.0, 0), 0.0, 0.8)
		p.attack_hitbox.activate(hit)
	if _hit_started and not _hit_ended and _t >= STARTUP + ACTIVE:
		_hit_ended = true
		p.attack_hitbox.deactivate()
		if p.buffered(&"attack"):
			p.consume(&"attack")
			p.start_attack()
			return

	p.move_and_slide()
	if _t >= STARTUP + ACTIVE + RECOVERY:
		land_or_fall()
