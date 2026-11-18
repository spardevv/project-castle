extends SummonState
## Comportamento do mago (substitui Follow e Chase): fica no FLANCO do jogador — ao lado e um pouco
## à frente — e conjura magias de dano em área sozinho enquanto o jogador luta.
##
## O lado (direito/esquerdo) é o que tem menos inimigos; só troca depois de alguns segundos para não
## ficar "dançando". Mantém distância de inimigos colados e olha para o alvo mais próximo.

const FLANK_DIST := 3.3
const FLANK_FORWARD := 0.9
const KEEP_AWAY := 4.0
const COMBAT_RANGE := 15.0
const SIDE_HOLD := 3.0

var _side := 1.0 # +1 direita do jogador, -1 esquerda
var _side_timer := 0.0


func enter(_msg: Dictionary = {}) -> void:
	_side_timer = 0.0


func physics_update(delta: float) -> void:
	var c := s
	c.apply_gravity(delta)
	var p := c.owner_player as Player
	if not is_instance_valid(p):
		c.move_and_slide()
		return
	if c.should_dodge():
		machine.change_to(&"Dodge")
		return

	var fwd := p.forward()
	var right := fwd.cross(Vector3.UP).normalized() # direita do personagem
	var to_player: Vector3 = p.global_position - c.global_position
	to_player.y = 0.0
	var dist_player := to_player.length()
	if dist_player > 28.0:
		c.global_position = p.global_position + right * _side * FLANK_DIST + Vector3(0, 0.3, 0)
		return

	# Inimigos: contagem por lado do jogador, mais próximo do mago e repulsão dos colados.
	var side_count := [0, 0] # [direita, esquerda]
	var nearest: Node3D = null
	var nearest_d := INF
	var flee := Vector3.ZERO
	for e in c.get_tree().get_nodes_in_group("enemy"):
		var en := e as Node3D
		var rel: Vector3 = en.global_position - p.global_position
		rel.y = 0.0
		if rel.length() < COMBAT_RANGE:
			side_count[0 if rel.dot(right) >= 0.0 else 1] += 1
		var away: Vector3 = c.global_position - en.global_position
		away.y = 0.0
		var d := away.length()
		if d < nearest_d:
			nearest_d = d
			nearest = en
		if d < KEEP_AWAY and d > 0.01:
			flee += away / d * (1.0 - d / KEEP_AWAY) * 1.8

	_side_timer -= delta
	if _side_timer <= 0.0:
		var want := -1.0 if side_count[0] > side_count[1] + 1 else (1.0 if side_count[1] > side_count[0] + 1 else _side)
		if want != _side:
			_side = want
			_side_timer = SIDE_HOLD

	var goal: Vector3 = p.global_position + right * _side * FLANK_DIST + fwd * FLANK_FORWARD
	var to_goal := goal - c.global_position
	to_goal.y = 0.0
	var dg := to_goal.length()
	var move := Vector3.ZERO
	if dg > 0.6:
		move = to_goal.normalized() * clampf(dg / 2.0, 0.2, 1.0)
	move += flee
	var spd := c.speed * (1.6 if dg > 8.0 else 1.0)
	c.accelerate(move.limit_length(1.0), spd, 28.0, delta)

	var look := to_player
	if nearest != null and nearest_d < COMBAT_RANGE:
		look = nearest.global_position - c.global_position
		look.y = 0.0
	c.face(look.normalized(), delta, 10.0)
	c.try_jump()
	c.move_and_slide()
	c.anim_motion()

	var pid := _pick_passive(c, p, nearest, nearest_d)
	if pid != &"":
		c.passive_timers[pid] = float(SummonSkills.PASSIVES[pid]["cooldown"])
		machine.change_to(&"Skill", {"id": pid})


## Primeira passiva equipada, pronta e cuja condição vale agora.
func _pick_passive(c: Summon, p: Player, nearest: Node3D, nearest_d: float) -> StringName:
	var near_mage := 0
	var near_player := 0
	var wide := 0
	for e in c.get_tree().get_nodes_in_group("enemy"):
		var en := e as Node3D
		if en.global_position.distance_to(c.global_position) < 4.8:
			near_mage += 1
		var dp := en.global_position.distance_to(p.global_position)
		if dp < 12.0:
			near_player += 1
		if dp < 11.0:
			wide += 1
	for id in GameState.summon_passives:
		if id == &"" or float(c.passive_timers.get(id, 0.0)) > 0.0:
			continue
		var ok := false
		match id:
			&"m_bolt":
				ok = nearest != null and nearest_d > 3.0 and nearest_d < 16.0
			&"m_frost":
				ok = near_mage >= 2 or (near_mage >= 1 and nearest_d < 2.6)
			&"m_meteor":
				ok = near_player >= 3
			&"m_storm":
				ok = wide >= 2
		if ok:
			return id
	return &""
