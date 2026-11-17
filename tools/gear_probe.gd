extends Node
## Ferramenta de desenvolvimento: testa escudo (stance + 75%), martelo, sacerdote, buffs e debuffs.
## Uso: godot --headless --path . res://tools/gear_probe.tscn

var frame := 0
var player: Player
var summon: Summon
var g1: Enemy
var g2: Enemy
var brute: Enemy


func _ready() -> void:
	add_child(load("res://levels/test_arena.tscn").instantiate())


func _park(e: Enemy, pos: Vector3, hp := 500) -> void:
	e.global_position = pos
	e.velocity = Vector3.ZERO
	e.attack_cd = 99.0
	e.shoot_cd = 99.0
	e.health.max_health = maxi(e.health.max_health, hp)
	e.health.current = hp
	e.machine.change_to(&"Idle")


func _hit_player(dmg: int, poise_break := false) -> void:
	var h := HitData.new()
	h.damage = dmg
	h.knockback = 3.0
	h.hitstun = 0.3
	h.poise_break = poise_break
	h.source = g1
	player.health.take_hit(h)


func _press(action: String, at: int, hold := 2) -> void:
	if frame == at:
		Input.action_press(action)
	if frame == at + hold:
		Input.action_release(action)


func _physics_process(_delta: float) -> void:
	frame += 1
	if frame == 5:
		player = get_tree().get_first_node_in_group("player")
		for e in get_tree().get_nodes_in_group("enemy"):
			if e.move_set == &"brute":
				brute = e
			elif e.move_set == &"grunt":
				if g1 == null:
					g1 = e
				else:
					g2 = e
			_park(e, Vector3(60 + randf() * 5, 0.1, 60))
		player.global_position = Vector3(0, 0.1, 0)

	# 1. Escudo: -75% de dano sempre e stance alto; sem escudo, dano cheio e stance baixo.
	if frame == 10:
		print("== 1. escudo")
		GameState.set_secondary(&"orb")
		player.health.invulnerable = false
		player.health._iframes = 0.0
		player.health.current = 100
		player.poise = player.poise_max()
		_hit_player(20)
		print("  sem escudo: vida 100 -> %d (dano 20) | estado=%s" % [player.health.current, player.machine.current_name()])
	if frame == 60:
		player.health._iframes = 0.0
		player.health.current = 100
		GameState.set_secondary(&"shield")
		player.poise = player.poise_max()
		print("  poise máx com escudo=%.0f (sem escudo=%.0f)" % [player.poise_max(), Player.POISE_BASE])
		_hit_player(20)
		print("  com escudo: vida 100 -> %d (esperado 95) | estado=%s (esperado Ground, não cambaleia)" % [player.health.current, player.machine.current_name()])
	if frame == 62:
		player.health._iframes = 0.0
		_hit_player(20, true)
	if frame == 64:
		print("  golpe que quebra poise: estado=%s (esperado Hurt)" % player.machine.current_name())

	# 2. Martelo: golpes mais lentos/fortes que quebram a super armor do inimigo.
	if frame == 120:
		print("== 2. martelo")
		GameState.set_secondary(&"orb")
		GameState.set_primary(&"hammer")
		player.health._iframes = 0.0
		player.health.current = 100
		player.machine.change_to(&"Ground")
		player.global_position = Vector3(0, 0.1, 0)
		player.visual.rotation.y = 0.0
		player.velocity = Vector3.ZERO
		_park(g1, Vector3(0, 0.1, 1.7))
		g1.machine.change_to(&"Attack") # inimigo em ataque = super armor
		print("  arma=%s moveset=%s | golpe 1: startup=%.2f dano=%d" % [GameState.primary, player.moveset.display_name,
			player.moveset.moves["h1"].startup, player.moveset.moves["h1"].damage])
	for f in [125, 150, 175]:
		_press("attack", f)
	if frame >= 138 and frame <= 156 and player.rig.sword_tip != null:
		var st = player.machine.current
		print("   f%d tip=%s base=%s player=%s inimigo=%s sweep=%s mon=%s mask=%d t=%s" % [frame,
			player.rig.sword_tip.global_position.snappedf(0.1), player.rig.sword_base.global_position.snappedf(0.1),
			player.global_position.snappedf(0.1), g1.global_position.snappedf(0.1), player.attack_hitbox._sweeping,
			player.attack_hitbox.monitoring, player.attack_hitbox.collision_mask, str(st.get("_t"))])
	if frame in [140, 166, 200]:
		print("  f%d jogador=%s inimigo=%s hp=%d poise=%.0f" % [frame, player.machine.current_name(), g1.machine.current_name(), g1.health.current, g1.poise])

	# 3. Sacerdote: troca, fica atrás, cura, buff, debuff, dano.
	if frame == 260:
		print("== 3. sacerdote")
		GameState.set_primary(&"sword")
		GameState.set_summon_kind(&"priest")
		print("  slots do sacerdote: ", GameState.summon_slots, " passivas: ", GameState.summon_passives)
		_park(g1, Vector3(60, 0.1, 60))
		player.global_position = Vector3(0, 0.1, 0)
		player.visual.rotation.y = 0.0
		player.toggle_summon()
		summon = player.summon
		summon.global_position = Vector3(0, 0.1, 1)
	if frame == 330:
		print("  posição do sacerdote=%s (player em 0,0,0 olhando +Z: deve estar atrás, z<0)" % summon.global_position.snappedf(0.1))
		player.health.current = 30
		print("  vida antes=%d | cura: %s" % [player.health.current, summon.use_skill(0)])
	if frame == 400:
		print("  vida depois=%d (esperado 65)" % player.health.current)
		print("  bênção: %s" % summon.use_skill(1))
	if frame == 450:
		print("  jogador abençoado=%s | mult dano=%.2f" % [StatusEffects.has(player, &"bless"), StatusEffects.mult(player, "damage_out")])
		_park(g1, Vector3(0, 0.1, 6), 100)
		_park(g2, Vector3(2, 0.1, 6), 100)
	if frame == 480:
		print("  maldição: %s" % summon.use_skill(2))
	if frame == 545:
		print("  inimigo amaldiçoado=%s | mult dano recebido=%.2f | mult dano causado=%.2f" % [StatusEffects.has(g1, &"hex"),
			StatusEffects.mult(g1, "damage_in"), StatusEffects.mult(g1, "damage_out")])
		print("  julgamento: %s" % summon.use_skill(3))
	if frame == 630:
		print("  hp inimigos após julgamento (amaldiçoados: +30%% dano): %d / %d" % [g1.health.current, g2.health.current])
		get_tree().quit()
