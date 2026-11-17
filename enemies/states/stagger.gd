extends EnemyState
## Reação a dano. Três variações, escolhidas pelo golpe:
##  - "stand": recuo na direção do empurrão (frente/trás/lados).
##  - "air":   juggle — gravidade reduzida, knockback menor; ao tocar o chão vira derrubada.
##  - "down":  derrubada — cai de costas, fica no chão e se levanta. Golpes nele o mantêm no chão.

const JUGGLE_GRAVITY := 0.45
const AIR_KNOCKBACK := 0.35
## Velocidade de arremesso a partir da qual atropela outros inimigos / bate na parede com impacto.
const BUMP_SPEED := 6.0
const WALL_SPEED := 6.5
## Tempo extra preso no hitstun depois de bater na parede.
const WALL_HOLD := 0.5
const DOWN_TIME := 1.5
const LAND_DOWN_TIME := 1.2

var _t := 0.0
var _duration := 0.3
var _mode := "stand"
var _push := Vector3.ZERO
# Estado no momento da saída, para saber se um novo golpe pegou o inimigo ainda no chão.
var _exit_msec := -100000
var _exit_mode := ""
var _exit_remaining := 0.0
var _bumped: Array = []
var _splatted := false


func enter(msg: Dictionary = {}) -> void:
	var en := e
	var hit: HitData = msg.get("hit")
	var was_down := _exit_mode == "down" and Time.get_ticks_msec() - _exit_msec < 50 and _exit_remaining > 0.6
	_bumped.clear()
	_splatted = false

	_push = -en.forward()
	if hit and is_instance_valid(hit.source):
		var d := en.global_position - hit.source.global_position
		d.y = 0.0
		if d.length() > 0.01:
			_push = d.normalized()
	var force := hit.knockback if hit else 4.0
	# Só vira juggle se foi lançado agora ou se já estava num juggle (não por um pulinho de recuo).
	var was_air := _exit_mode == "air" and Time.get_ticks_msec() - _exit_msec < 50
	var airborne := en.can_be_launched and ((hit != null and hit.launch > 0.0) or (was_air and not en.is_on_floor()))

	if was_down:
		_mode = "down"
		_t = 0.3
		_duration = maxf(_exit_remaining + 0.3, 1.0)
		en.velocity = Vector3(_push.x * force * 0.4, 0.0, _push.z * force * 0.4)
		en.rig.set_knockdown(_t, _duration)
		return

	_t = 0.0
	if airborne:
		_mode = "air"
		_duration = hit.hitstun if hit else 0.5
		var up := hit.launch if hit and hit.launch > 0.0 else maxf(en.velocity.y, 2.5)
		en.velocity = Vector3(_push.x * force * AIR_KNOCKBACK, up, _push.z * force * AIR_KNOCKBACK)
		en.rig.set_air_hurt(0.0)
	elif force >= en.knockdown_force:
		_mode = "down"
		_duration = DOWN_TIME
		en.velocity = Vector3(_push.x * force, 3.0, _push.z * force)
		en.rig.set_knockdown(0.0, _duration)
	else:
		_mode = "stand"
		_duration = hit.hitstun if hit else 0.3
		en.velocity = Vector3(_push.x * force, 0.0, _push.z * force)
		en.rig.set_hurt(0.0, _push) # já na pose de recuo quando o hit-stop congelar


func exit() -> void:
	_exit_msec = Time.get_ticks_msec()
	_exit_mode = _mode
	_exit_remaining = _duration - _t


## Move e trata impactos de arremesso: bater em parede ("wall splat") e atropelar outro inimigo.
func _move(en: Enemy) -> void:
	var pre := en.velocity
	var pre_h := Vector3(pre.x, 0.0, pre.z)
	var speed := pre_h.length()
	en.move_and_slide()
	if speed < BUMP_SPEED:
		return
	var dir := pre_h / speed
	# Parede: quica, segura no hitstun e treme a câmera.
	if not _splatted:
		for i in en.get_slide_collision_count():
			var c := en.get_slide_collision(i)
			var nrm := c.get_normal()
			if absf(nrm.y) < 0.5 and speed >= WALL_SPEED and nrm.dot(dir) < -0.3:
				_splatted = true
				_duration = maxf(_duration, _t + WALL_HOLD)
				en.velocity = Vector3(nrm.x, 0.0, nrm.z) * 2.5 + Vector3.UP * minf(en.velocity.y, 1.0)
				en.rig.flash(Color(1, 1, 1), 0.2)
				en.rig.kick("spine", Vector3(-250, 0, 0))
				Fx.spark(en, c.get_position() + Vector3.UP * 0.8, Color(1.0, 0.9, 0.7))
				GameFeel.shake(0.14)
				return
	# Outro inimigo no caminho: é atropelado e este perde metade da velocidade.
	for o in en.get_tree().get_nodes_in_group("enemy"):
		var other := o as Enemy
		if other == null or other == en or _bumped.has(other):
			continue
		var to := other.global_position - en.global_position
		to.y = 0.0
		if to.length() < en.contact_radius + other.contact_radius + 0.15 and to.dot(dir) > 0.0:
			_bumped.append(other)
			other.bumped(pre_h * 0.6, en)
			en.velocity.x *= 0.5
			en.velocity.z *= 0.5


func physics_update(delta: float) -> void:
	var en := e
	_t += delta
	match _mode:
		"air":
			en.apply_gravity(delta, JUGGLE_GRAVITY)
			en.accelerate(Vector3.ZERO, 0.0, 4.0, delta)
			en.rig.set_air_hurt(_t)
			_move(en)
			if en.is_on_floor() and _t > 0.12:
				# Caiu do juggle: bate no chão e precisa se levantar.
				_mode = "down"
				_t = 0.22
				_duration = LAND_DOWN_TIME
				GameFeel.shake(0.1)
		"down":
			en.apply_gravity(delta)
			en.accelerate(Vector3.ZERO, 0.0, 10.0, delta)
			en.rig.set_knockdown(_t, _duration)
			_move(en)
			if _t >= _duration:
				machine.change_to(en.engage_state)
		_:
			en.apply_gravity(delta)
			en.accelerate(Vector3.ZERO, 0.0, 12.0, delta)
			en.rig.set_hurt(_t / maxf(_duration, 0.01), _push)
			_move(en)
			if _t >= _duration and en.is_on_floor():
				machine.change_to(en.engage_state)
