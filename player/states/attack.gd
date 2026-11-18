extends PlayerState
## Executa um AttackData do moveset. Encadeia por tap/hold e cancela em esquiva/secundário.

var _data: AttackData
var _t := 0.0
var _hit_started := false
var _hit_ended := false
var _launched := false
var _landed := false
var _charge := -1 # estância do golpe carregado (-1 = golpe normal)
var _old_trail := Color.WHITE


func enter(msg: Dictionary = {}) -> void:
	var p := player
	_data = msg["move"]
	_charge = int(msg.get("charge", -1))
	_t = 0.0
	_hit_started = false
	_hit_ended = false
	_launched = false
	_landed = false
	p.combo_memory_time = 0.0
	_old_trail = p.rig.trail_color
	if _charge >= 0:
		# Golpe carregado: a preparação já foi feita no Charge; mantém a armadura até o fim da janela de dano.
		_t = _data.startup * 0.75
		p.armor_level = _charge
		p.rig.trail_color = Player.CHARGE_COLORS[_charge]
	if _data.turn_to_input:
		p.snap_face_to_intent()

	var box_size := _data.hitbox_size
	if _charge > 0:
		var k: float = p.moveset.charge.hitbox[_charge]
		box_size = Vector3(box_size.x * k, box_size.y, box_size.z * k)
	var shape := p.attack_hitbox.get_node("CollisionShape3D") as CollisionShape3D
	(shape.shape as BoxShape3D).size = box_size
	p.attack_hitbox.position = _data.hitbox_offset
	p.sword_arc.scale = box_size
	p.sword_arc.position = _data.hitbox_offset


func exit() -> void:
	player.armor_level = -1
	player.rig.trail_color = _old_trail
	player.attack_hitbox.deactivate()
	player.sword_arc.visible = false
	player.rig.trail_active = false


func physics_update(delta: float) -> void:
	var p := player
	var d := _data
	_t += delta
	var active_end := d.startup + d.active
	p.rig.set_attack(d.anim_id(), d.startup, d.active, d.recovery, _t, d.two_handed)
	var diving := d.dive_speed > 0.0 and _t >= d.startup and not _landed

	if diving:
		p.velocity = Vector3(0.0, -d.dive_speed, 0.0)
	else:
		if not p.is_on_floor():
			p.apply_gravity(delta, d.air_gravity)
		# Avanço do corpo durante startup + active; depois freia.
		if _t < d.startup * d.lunge_delay:
			p.accelerate(Vector3.ZERO, 0.0, 30.0, delta) # plantado, carregando o golpe
		elif _t < active_end:
			var fwd := p.forward() * d.lunge_speed
			p.velocity.x = fwd.x
			p.velocity.z = fwd.z
		else:
			p.accelerate(Vector3.ZERO, 0.0, 40.0, delta)

	# Impulso para cima (corte ascendente) só depois de a lâmina passar pela frente: corta e sobe.
	if not _launched and _t >= d.startup + d.active * 0.7:
		_launched = true
		if d.self_launch > 0.0:
			p.velocity.y = d.self_launch

	# Janela de dano.
	if not _hit_started and _t >= d.startup:
		_hit_started = true
		p.attack_hitbox.activate(_hit_data(), d.use_sweep)
		var heavy := d.poise_break or d.damage >= 28 or GameState.primary == &"hammer"
		Sfx.play(&"swing_heavy" if heavy else &"swing", p.global_position + Vector3(0, 1.2, 0), 0.0, 0.85 if heavy else 1.0)
		var weight: float = Poses.WEIGHT.get(d.anim_id(), 0.3)
		if weight >= 0.75 and not (d.poise_break or d.damage >= 30):
			GameFeel.shake(0.07)
		if weight >= 0.75: # tranco da pancada: tronco e braço "batem" e a mola assenta
			p.rig.kick("spine", Vector3(-60.0 * weight, 0.0, 0.0))
			p.rig.kick("sh_r", Vector3(-90.0 * weight, 0.0, 0.0))
			p.rig.kick("root", Vector3(0.0, -0.5 * weight, 0.0))
		if d.poise_break or d.damage >= 30:
			GameFeel.shake(0.12) # golpe pesado: sacode a câmera ao sair
		p.sword_arc.visible = p.debug_hitbox
		p.rig.trail_active = true
		if d.shockwave or _charge >= 3:
			p.slam_fx(3.0 if _charge >= 3 else 2.4, Player.CHARGE_COLORS[maxi(_charge, 3)])
	if _hit_started and not _hit_ended and _t >= active_end:
		_hit_ended = true
		p.armor_level = -1
		p.attack_hitbox.deactivate()
		p.sword_arc.visible = false
		p.rig.trail_active = false

	# Encadeamento: hold (segurando o botão) tem prioridade sobre tap.
	if _t >= d.cancel_start:
		if p.is_attack_held() and p.attack_held_time >= Player.HOLD_TIME \
				and p.moveset.has_edge(d.id, "hold") and p.is_on_floor():
			machine.change_to(&"Charge", {"from": d.id})
			return
		if p.consume(&"attack"):
			_chain("tap", p.attack_dir)
			return

	# Cancels pós-golpe: arte da arma, esquiva e secundário.
	if _t >= active_end:
		if p.buffered(&"weapon_art") and p.can_art():
			p.consume(&"weapon_art")
			machine.change_to(&"Art")
			return
		if p.buffered(&"dodge") and p.can_dodge():
			p.consume(&"dodge")
			machine.change_to(&"Dodge")
			return
		if p.buffered(&"secondary") and p.secondary_cooldown <= 0.0:
			p.consume(&"secondary")
			p.use_secondary()
			return

	p.move_and_slide()

	if diving and p.is_on_floor():
		_landed = true
		_t = maxf(_t, active_end) # encerra a janela de dano; segue para a recuperação
		GameFeel.shake(0.15)

	if _t >= d.total_time():
		# Memória do combo: o próximo toque depois disso conta como "pausa".
		p.combo_memory_id = d.id
		p.combo_memory_time = Player.COMBO_MEMORY
		land_or_fall()


func _chain(kind: String, dir: String) -> void:
	var p := player
	var move := p.moveset.resolve(_data.id, kind, dir, not p.is_on_floor())
	machine.change_to(&"Attack", {"move": move})


## Dados do golpe, com os multiplicadores da estância quando é um golpe carregado.
func _hit_data() -> HitData:
	return player.moveset.charge.apply(_data.make_hit_data(), _charge)
