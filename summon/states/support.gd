extends SummonState
## Comportamento de suporte do sacerdote (substitui Follow e Chase).
##
## Posicionamento: fica RECUADO, num anel de 4 a 8 m do jogador, e não precisa estar nas costas dele.
##  - Com inimigos por perto: vai para o lado oposto a eles (longe da linha de frente), ~6,5 m atrás
##    do jogador em relação à ameaça, e foge dos que se aproximam.
##  - Sem inimigos: fica onde está enquanto estiver dentro do anel; se o jogador se afasta, reaproxima.
##
## Cura passiva: a "Aura de cura" (p_aura) regenera o jogador continuamente enquanto estiver perto.
## As demais passivas (p_*) são conjuradas quando a situação pede.

const RING_MIN := 4.0
const RING_MAX := 8.0
const RING_IDEAL := 5.5
const RETREAT := 6.5
const KEEP_AWAY := 5.5
const COMBAT_RANGE := 14.0
const AURA_RANGE := 12.0
const AURA_HPS := 2.5

var _aura_fx := 0.0


func physics_update(delta: float) -> void:
	var c := s
	c.apply_gravity(delta)
	var p := c.owner_player
	if not is_instance_valid(p):
		c.move_and_slide()
		return
	if c.should_dodge():
		machine.change_to(&"Dodge")
		return

	var to_player: Vector3 = p.global_position - c.global_position
	to_player.y = 0.0
	var dist_player := to_player.length()
	if dist_player > 28.0:
		c.global_position = p.global_position - (p as Player).forward() * RING_IDEAL + Vector3(0, 0.3, 0)
		return

	# Inimigos: direção média da ameaça (a partir do jogador) e o mais próximo do sacerdote.
	var threat := Vector3.ZERO
	var nearest: Node3D = null
	var nearest_d := INF
	var flee := Vector3.ZERO
	for e in c.get_tree().get_nodes_in_group("enemy"):
		var en := e as Node3D
		var from_p: Vector3 = en.global_position - p.global_position
		from_p.y = 0.0
		var dp := from_p.length()
		if dp < COMBAT_RANGE and dp > 0.01:
			threat += from_p / dp * (1.0 / maxf(dp, 2.0))
		var away: Vector3 = c.global_position - en.global_position
		away.y = 0.0
		var d := away.length()
		if d < nearest_d:
			nearest_d = d
			nearest = en
		if d < KEEP_AWAY and d > 0.01:
			flee += away / d * (1.0 - d / KEEP_AWAY) * 1.6

	# Destino desejado.
	var goal: Vector3 = c.global_position
	var want_move := false
	if threat.length() > 0.001:
		goal = p.global_position - threat.normalized() * RETREAT
		want_move = true
	elif dist_player > RING_MAX or dist_player < RING_MIN:
		var out: Vector3 = -to_player / maxf(dist_player, 0.001) # direção jogador -> sacerdote
		goal = p.global_position + out * RING_IDEAL
		want_move = true
	var move := Vector3.ZERO
	if want_move:
		var to_goal := goal - c.global_position
		to_goal.y = 0.0
		var dg := to_goal.length()
		if dg > 0.7:
			move = to_goal.normalized() * clampf(dg / 2.5, 0.25, 1.0)
	move += flee
	# Nunca encosta no jogador.
	if dist_player < RING_MIN * 0.6:
		move -= to_player / maxf(dist_player, 0.001)
	var spd := c.speed * (1.5 if dist_player > RING_MAX + 2.0 else 1.0)
	c.accelerate(move.limit_length(1.0), spd, 28.0, delta)

	# Olha para o inimigo mais próximo (em combate) ou para o jogador.
	var look := to_player
	if nearest != null and nearest_d < COMBAT_RANGE:
		look = nearest.global_position - c.global_position
		look.y = 0.0
	c.face(look.normalized(), delta, 10.0)
	c.try_jump()
	c.move_and_slide()
	c.anim_motion()

	_aura(c, p as Player, dist_player, delta)

	var pid := _pick_passive(c, p as Player, nearest, nearest_d)
	if pid != &"":
		c.passive_timers[pid] = float(SummonSkills.PASSIVES[pid]["cooldown"])
		machine.change_to(&"Skill", {"id": pid})


## Aura de cura: passiva constante (não é uma conjuração). Regenera o jogador perto do sacerdote.
func _aura(c: Summon, p: Player, dist_player: float, delta: float) -> void:
	if not GameState.summon_passives.has(&"p_aura") or dist_player > AURA_RANGE:
		return
	if p.health.current <= 0:
		return
	p.health.heal_over_time(AURA_HPS * delta)
	c.health.heal_over_time(AURA_HPS * 0.5 * delta)
	_aura_fx -= delta
	if _aura_fx <= 0.0 and p.health.current < p.health.max_health:
		_aura_fx = 1.1
		Fx.spark(c, p.global_position + Vector3(0, 1.4, 0), Color(0.5, 1.0, 0.65))


## Escolhe a primeira passiva (conjurada) equipada, pronta e cuja condição vale agora.
func _pick_passive(c: Summon, p: Player, nearest: Node3D, nearest_d: float) -> StringName:
	var hp_ratio := float(p.health.current) / float(p.health.max_health)
	var in_combat := false
	var enemies_near_player := 0
	var any_unslowed := false
	for e in c.get_tree().get_nodes_in_group("enemy"):
		var d := (e as Node3D).global_position.distance_to(p.global_position)
		if d < COMBAT_RANGE:
			in_combat = true
		if d < 10.0:
			enemies_near_player += 1
			if not StatusEffects.has(e, &"slow"):
				any_unslowed = true
	for id in GameState.summon_passives:
		if id == &"" or id == &"p_aura" or float(c.passive_timers.get(id, 0.0)) > 0.0:
			continue
		var ok := false
		match id:
			&"p_heal":
				ok = hp_ratio < 0.6
			&"p_renew":
				ok = in_combat and hp_ratio < 0.85 and not StatusEffects.has(p, &"regen")
			&"p_bless":
				ok = in_combat and not StatusEffects.has(p, &"bless")
			&"p_ward":
				ok = in_combat and hp_ratio < 0.8 and not StatusEffects.has(p, &"ward")
			&"p_slow":
				ok = enemies_near_player >= 2 and any_unslowed
			&"p_smite":
				ok = nearest != null and c.nearest_enemy_within(14.0) != null and nearest_d > 4.0
		if ok:
			return id
	return &""
