extends PlayerState
## Arte da arma (RT) — "Tempestade de Lâminas": investida cortando, giro em área e finalizador
## que lança. Gasta medidor; o player fica com i-frames e super armor durante toda a sequência.


var _i := 0
var _seq: Array[AttackData] = []
var _data: AttackData
var _t := 0.0
var _hit_started := false
var _hit_ended := false
var _old_trail := Color.WHITE


func enter(_msg: Dictionary = {}) -> void:
	var p := player
	p.art_meter -= Player.ART_COST
	p.combo_memory_time = 0.0
	p.health.invulnerable = true
	_old_trail = p.rig.trail_color
	_seq = p.moveset.art_sequence # cada arma tem a sua arte
	p.rig.trail_color = p.moveset.art_color
	p.rig.flash(p.moveset.art_color.lightened(0.2), 0.35)
	Sfx.play(&"art_use", p.global_position + Vector3(0, 1.0, 0))
	GameFeel.slowmo(0.25, 0.12)
	GameFeel.shake(0.2)
	GameFeel.rumble(0.5, 0.3, 0.2)
	_i = 0
	_begin()


func exit() -> void:
	var p := player
	p.health.invulnerable = false
	p.rig.trail_color = _old_trail
	p.rig.trail_active = false
	p.attack_hitbox.deactivate()
	p.sword_arc.visible = false


func _begin() -> void:
	var p := player
	_data = _seq[_i]
	_t = 0.0
	_hit_started = false
	_hit_ended = false
	if _data.turn_to_input:
		p.snap_face_to_intent()
	var shape := p.attack_hitbox.get_node("CollisionShape3D") as CollisionShape3D
	(shape.shape as BoxShape3D).size = _data.hitbox_size
	p.attack_hitbox.position = _data.hitbox_offset
	p.sword_arc.scale = _data.hitbox_size
	p.sword_arc.position = _data.hitbox_offset


func physics_update(delta: float) -> void:
	var p := player
	var d := _data
	_t += delta
	var active_end := d.startup + d.active
	p.rig.set_attack(d.anim_id(), d.startup, d.active, d.recovery, _t)

	if not p.is_on_floor():
		p.apply_gravity(delta, 0.4)
	if _t < active_end:
		var fwd := p.forward() * d.lunge_speed
		p.velocity.x = fwd.x
		p.velocity.z = fwd.z
	else:
		p.accelerate(Vector3.ZERO, 0.0, 50.0, delta)

	if not _hit_started and _t >= d.startup:
		_hit_started = true
		p.attack_hitbox.activate(d.make_hit_data(), d.use_sweep) # activate limpa a lista: cada golpe acerta de novo
		p.sword_arc.visible = p.debug_hitbox
		p.rig.trail_active = true
		Sfx.play(&"swing_heavy", p.global_position + Vector3(0, 1.2, 0), 0.0, 1.0 + 0.1 * _i)
		if d.shockwave:
			p.slam_fx(3.4, p.moveset.art_color)
	if _hit_started and not _hit_ended and _t >= active_end:
		_hit_ended = true
		p.attack_hitbox.deactivate()
		p.sword_arc.visible = false
		if _i == _seq.size() - 1:
			p.rig.trail_active = false

	p.move_and_slide()

	if _t >= d.total_time():
		_i += 1
		if _i < _seq.size():
			_begin()
		else:
			land_or_fall()
