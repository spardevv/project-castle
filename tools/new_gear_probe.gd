extends Node
## Ferramenta de desenvolvimento: testa lança (alcance/stun), besta automática (rajada) e mago (flanco + magias em área).
## Uso: godot --headless --path . res://tools/new_gear_probe.tscn

var frame := 0
var player: Player
var summon: Summon
var g1: Enemy
var g2: Enemy
var g3: Enemy
var _hp0 := 0


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


func _press(action: String, at: int, hold := 2) -> void:
	if frame == at:
		Input.action_press(action)
	if frame == at + hold:
		Input.action_release(action)


func _physics_process(_delta: float) -> void:
	frame += 1
	if frame == 5:
		player = get_tree().get_first_node_in_group("player")
		var grunts: Array[Enemy] = []
		for e in get_tree().get_nodes_in_group("enemy"):
			if e.move_set == &"grunt":
				grunts.append(e)
			_park(e, Vector3(60 + randf() * 5, 0.1, 60))
		g1 = grunts[0]
		g2 = grunts[1]
		g3 = grunts[2] if grunts.size() > 2 else grunts[0]
		player.global_position = Vector3(0, 0.1, 0)

	# 1. Lança: acerta a 2,3 m (a espada não alcança) e dá stun médio.
	if frame == 10:
		print("== 1. lança")
		GameState.set_primary(&"spear")
		player.machine.change_to(&"Ground")
		player.visual.rotation.y = 0.0
		_park(g1, Vector3(0, 0.1, 2.6))
		print("  moveset=%s s1 hitstun=%.2f | espada a1 hitstun=%.2f" % [player.moveset.display_name, player.moveset.moves["s1"].hitstun, LongSword.new().moves["a1"].hitstun])
	_press("attack", 15)
	if frame >= 15 and frame <= 40 and frame % 3 == 0:
		print("   f%d tip=%s base=%s st=%s" % [frame, player.rig.sword_tip.global_position.snappedf(0.1), player.rig.sword_base.global_position.snappedf(0.1), player.machine.current_name()])
	if frame == 70:
		print("  inimigo a 2,6 m: vida %d/500 | estado=%s (esperado dano e Stagger)" % [g1.health.current, g1.machine.current_name()])
		print("  alcance da ponta: %.2f m do corpo" % (player.rig.sword_tip.global_position - player.global_position).length())

	# 2. Besta: rajada com pouco dano por virote.
	if frame == 110:
		print("== 2. besta automática")
		GameState.set_primary(&"sword")
		GameState.set_secondary(&"crossbow")
		player.machine.change_to(&"Ground")
		player.global_position = Vector3(0, 0.1, 0)
		player.visual.rotation.y = 0.0
		_park(g1, Vector3(0, 0.1, 9))
		_hp0 = g1.health.current
	if frame == 120:
		Input.action_press("secondary")
	if frame == 170: # ~0,83 s segurando
		Input.action_release("secondary")
	if frame == 200:
		var dmg := _hp0 - g1.health.current
		print("  dano total da rajada=%d (virotes ~%d) | estado=%s" % [dmg, dmg / 4, player.machine.current_name()])

	# 3. Mago: invoca, fica no flanco e conjura magias de dano em área.
	if frame == 260:
		print("== 3. mago")
		GameState.set_secondary(&"orb")
		GameState.set_summon_kind(&"mage")
		print("  slots=%s passivas=%s" % [GameState.summon_slots, GameState.summon_passives])
		_park(g1, Vector3(60, 0.1, 60))
		player.global_position = Vector3(0, 0.1, 0)
		player.visual.rotation.y = 0.0
		player.toggle_summon()
		summon = player.summon
		summon.global_position = Vector3(0, 0.1, -3)
	if frame == 400:
		var rel := summon.global_position - player.global_position
		print("  mago em %s relativo ao jogador (olhando +Z): lateral |x|=%.1f (esperado ~3,3), z=%.1f (~0,9)" % [rel.snappedf(0.1), absf(rel.x), rel.z])
		print("  (passivas desligadas para testar só as skills comandadas)")
		GameState.set_summon_passive(0, &"")
		GameState.set_summon_passive(1, &"")
		_park(g1, Vector3(0, 0.1, 8), 100)
		_park(g2, Vector3(2, 0.1, 9), 100)
		_park(g3, Vector3(-2, 0.1, 9), 100)
	if frame == 420:
		print("  explosão arcana: %s" % summon.use_skill(0))
	if frame == 520:
		print("  hp após explosão: %d / %d / %d" % [g1.health.current, g2.health.current, g3.health.current])
		print("  tempestade: %s" % summon.use_skill(2))
	if frame == 640:
		print("  hp após tempestade: %d / %d / %d" % [g1.health.current, g2.health.current, g3.health.current])
		print("  meteoros: %s" % summon.use_skill(3))
	if frame == 800:
		print("  hp após meteoros: %d / %d / %d" % [g1.health.current, g2.health.current, g3.health.current])
		_park(g1, Vector3(3, 0.1, 0.5), 100)
		_park(g2, Vector3(-3, 0.1, 2), 100)
		_park(g3, Vector3(0, 0.1, -2.5), 100)
		print("  nova gélida: %s" % summon.use_skill(1))
	if frame == 860:
		print("  lentidão: %s %s | hp %d / %d / %d" % [StatusEffects.has(g1, &"slow"), StatusEffects.has(g2, &"slow"), g1.health.current, g2.health.current, g3.health.current])
		get_tree().quit()
