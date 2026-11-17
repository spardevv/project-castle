extends Node
## Ferramenta de desenvolvimento: testa as ações automáticas do summon (pulo, esquiva, passivas)
## e a cura comandada. Uso: godot --headless --path . res://tools/summon_probe.tscn

var frame := 0
var player: Player
var grunts: Array = []
var summon: Summon
var _last := ""


func _ready() -> void:
	add_child(load("res://levels/test_arena.tscn").instantiate())


func _park(e: Enemy, pos: Vector3) -> void:
	e.global_position = pos
	e.velocity = Vector3.ZERO
	e.attack_cd = 99.0
	e.shoot_cd = 99.0
	e.health.current = 500
	e.machine.change_to(&"Idle")


func _log_state(tag: String) -> void:
	var line := "%s %s" % [tag, summon.machine.current_name()]
	if line != _last:
		print("  f%d %s | summon y=%.1f" % [frame, line, summon.global_position.y])
		_last = line


func _physics_process(_delta: float) -> void:
	frame += 1
	if frame == 5:
		player = get_tree().get_first_node_in_group("player")
		for e in get_tree().get_nodes_in_group("enemy"):
			if e.move_set == &"grunt":
				grunts.append(e)
			_park(e, Vector3(60 + randf() * 5, 0.1, 60))
		player.global_position = Vector3(0, 0.1, 0)
		player.toggle_summon()
		summon = player.summon
		print("passivas: ", GameState.summon_passives, " | slots: ", GameState.summon_slots)

	# 1. Pulo: o player sobe no degrau (y=1.0); o summon deve pular para acompanhar.
	if frame == 30:
		print("== 1. pulo")
		summon.global_position = Vector3(3, 0.1, -6)
		player.global_position = Vector3(7, 2.2, -6)
	if frame > 30 and frame < 200:
		_log_state("seguindo")
	if frame == 200:
		print("  summon y final=%.1f (player y=%.1f)" % [summon.global_position.y, player.global_position.y])
		player.global_position = Vector3(0, 0.1, 0)
		summon.global_position = Vector3(1, 0.1, 1)

	# 2. Esquiva: um soldado começa a atacar o summon.
	if frame == 260:
		print("== 2. esquiva")
		_park(grunts[0], summon.global_position + Vector3(0, 0, 1.6))
		grunts[0].taunt(summon, 5.0)
		grunts[0].machine.change_to(&"Attack")
		_last = ""
	if frame > 260 and frame < 330:
		_log_state("esquiva")
	if frame == 330:
		print("  summon hp=%d (esperado 80 se esquivou)" % summon.health.current)

	# 3. Passivas: combo triplo, giro (2+ inimigos), salto (alvo distante).
	if frame == 360:
		print("== 3. passivas")
		GameState.set_summon_passive(0, &"combo")
		GameState.set_summon_passive(1, &"spin")
		print("  passivas: ", GameState.summon_passives)
		for g in grunts:
			_park(g, summon.global_position + Vector3(randf_range(-1, 1), 0, 1.5))
		_last = ""
	if frame > 360 and frame < 470:
		_log_state("combate")
	if frame == 480:
		print("  hp dos soldados: ", grunts.map(func(g): return g.health.current))
		GameState.set_summon_passive(0, &"rock")
		GameState.set_summon_passive(1, &"")
		for g in grunts:
			_park(g, summon.global_position + Vector3(0, 0, 8))
		summon.passive_timers.clear()
		_last = ""
		print("== 4. lançar pedra (alvo a 8 m)")
	if frame > 480 and frame < 600:
		_log_state("salto")
	if frame == 600:
		print("  hp dos soldados: ", grunts.map(func(g): return g.health.current))

	# 5. Skills comandadas: provocar, rajada de socos, terremoto, pedra.
	if frame == 620:
		print("== 5. skills comandadas: slots ", summon.skills.map(func(s): return s["name"]))
		for g in grunts:
			_park(g, summon.global_position + Vector3(randf_range(-2, 2), 0, 6))
		print("  provocar: ", summon.use_skill(1))
	if frame == 700:
		print("  após provocar: ", grunts.map(func(g): return "%s alvo=%s" % [g.machine.current_name(), g.get_target().name]))
		for g in grunts:
			_park(g, summon.global_position + Vector3(randf_range(-1, 1), 0, 1.6))
		print("  rajada de socos: ", summon.use_skill(2))
	if frame == 790:
		print("  hp dos soldados: ", grunts.map(func(g): return g.health.current))
		print("  terremoto: ", summon.use_skill(0))
	if frame == 860:
		print("  hp dos soldados: ", grunts.map(func(g): return g.health.current))
		get_tree().quit()
