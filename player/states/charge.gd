extends PlayerState
## Ataque carregado: segurar o botão de ataque (depois do "hold" do combo) mantém a preparação do golpe
## e sobe de estância (3 níveis). Cada estância dá mais dano, quebra de postura e mitigação de dano
## (e resistência a cambalear). Soltar o botão executa o golpe com os multiplicadores da estância.
## Esquiva cancela a carga.

const MOVE_SPEED := 1.4

var _move: AttackData
var _t := 0.0
var _stance := 0
var _ping := 0.0


func enter(msg: Dictionary = {}) -> void:
	var p := player
	_move = p.moveset.resolve(str(msg.get("from", "")), "hold", "neutral", false)
	_t = 0.0
	_stance = 0
	_ping = 0.0
	p.armor_level = 0
	p.charge_progress = 0.01
	p.rig.set_charge(0)
	Sfx.play(&"clink", p.global_position + Vector3(0, 1.0, 0), -6.0, 0.7)


func exit() -> void:
	var p := player
	p.armor_level = -1
	p.charge_progress = 0.0
	p.rig.set_charge(-1)
	p.rig.set_glow(Color.BLACK)


func physics_update(delta: float) -> void:
	var p := player
	_t += delta
	_ping = maxf(_ping - delta * 3.0, 0.0)

	# Preparação do golpe, segurada com tremor de esforço.
	p.rig.set_attack(_move.anim_id(), _move.startup, _move.active, _move.recovery, minf(_t * 1.6, _move.startup * 0.999), _move.two_handed)

	# Sobe de estância.
	var prof := p.moveset.charge
	if _stance < ChargeProfile.MAX_STANCE and _t >= prof.times[_stance]:
		_stance += 1
		_ping = 1.0
		p.armor_level = _stance
		p.rig.set_charge(_stance)
		var col: Color = Player.CHARGE_COLORS[_stance]
		Fx.burst(p, p.global_position + Vector3(0, 0.1, 0), 1.2 + 0.5 * _stance, col, 0.45)
		Sfx.play(&"clink", p.global_position + Vector3(0, 1.0, 0), 0.0, 0.8 + 0.3 * _stance)
		if _stance == ChargeProfile.MAX_STANCE:
			Sfx.play(&"art_use", p.global_position + Vector3(0, 1.0, 0), -4.0)
		GameFeel.shake(0.05 + 0.04 * _stance)
		GameFeel.rumble(0.25, 0.1 * _stance, 0.12)
	if _stance < ChargeProfile.MAX_STANCE:
		var from_t: float = 0.0 if _stance == 0 else prof.times[_stance - 1]
		p.charge_progress = _stance + clampf((_t - from_t) / (prof.times[_stance] - from_t), 0.0, 1.0) * 0.99
	else:
		p.charge_progress = 3.0

	# Brilho do corpo: pulsa e fica mais forte/avermelhado a cada estância.
	var base: Color = Player.CHARGE_COLORS[_stance]
	var pulse := 0.5 + 0.5 * sin(_t * (8.0 + _stance * 4.0))
	p.rig.set_glow(base * (0.12 + 0.18 * _stance) * (0.6 + pulse * 0.6 + _ping * 2.0))

	# Movimento lento, virado para o alvo/direção.
	var dir := p.get_move_dir()
	p.update_facing(dir, delta)
	p.accelerate(dir.normalized() * MOVE_SPEED * minf(dir.length(), 1.0), MOVE_SPEED, 25.0, delta)
	if not p.is_on_floor():
		p.apply_gravity(delta)
	p.move_and_slide()

	if p.buffered(&"dodge") and p.can_dodge():
		p.consume(&"dodge")
		machine.change_to(&"Dodge")
		return
	if not p.is_on_floor() and p.velocity.y < -2.0:
		machine.change_to(&"Air")
		return
	if not p.is_attack_held():
		machine.change_to(&"Attack", {"move": _move, "charge": _stance})
