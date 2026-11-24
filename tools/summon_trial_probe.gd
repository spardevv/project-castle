extends Node
## Ferramenta de desenvolvimento: percorre levels/summon_trial.tscn usando os três summons.
## Golem abre a porta pesada, Sacerdote abre os baús (skill e cura), Mago bane o jogador através da parede
## secreta e o baú escondido libera outra skill.
## Uso: godot --headless --fixed-fps 60 --path . res://tools/summon_trial_probe.tscn

var level: Node
var player: Player
var summon: Summon
var ok := 0
var bad := 0


func _ready() -> void:
	GameState.abilities.clear()
	GameState.world_flags.clear()
	level = load("res://levels/summon_trial.tscn").instantiate()
	add_child(level)
	await _frames(5)
	player = get_tree().get_first_node_in_group("player")
	await _run()
	print("RESULTADO: %d ok, %d falhas" % [ok, bad])
	get_tree().quit(1 if bad > 0 else 0)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func check(label: String, cond: bool) -> void:
	if cond:
		ok += 1
		print("  ok   ", label)
	else:
		bad += 1
		print("  FAIL ", label)


func _summon(kind: StringName) -> void:
	if is_instance_valid(summon):
		summon.queue_free()
		player.summon = null
		await _frames(2)
	GameState.set_summon_kind(kind)
	player._summon_cd = 0.0
	player.toggle_summon()
	summon = player.summon
	await _frames(150) # chegada


## Espera até `cond` ficar verdadeira (no máximo `n` quadros).
func _wait_for(cond: Callable, n: int) -> bool:
	for i in n:
		if cond.call():
			return true
		await get_tree().physics_frame
	return bool(cond.call())


func _run() -> void:
	var door := level.get_node("HeavyDoor") as HeavyDoor
	var chest_skill := level.get_node("ChestSkill") as EnchantedChest
	var chest_heal := level.get_node("ChestHeal") as EnchantedChest
	var chest_hidden := level.get_node("ChestHidden") as EnchantedChest
	var secret := level.get_node("SecretWall") as SecretWall

	print("== início")
	check("quake e blast ainda travadas", not SummonSkills.choices_for(&"golem").has(&"quake") and not SummonSkills.choices_for(&"mage").has(&"blast"))
	check("baú sem sacerdote não abre", not chest_skill.interact(player))

	print("== sala 1: golem abre a porta pesada")
	await _summon(&"golem")
	player.global_position = Vector3(0, 0.1, -9)
	summon.skills[0]["timer"] = 0.0
	var alive := get_tree().get_nodes_in_group("enemy")
	if not alive.is_empty():
		check("com grunts por perto a porta não é alvo", summon.nearest_heavy_door() == null)
	for g in alive:
		g.queue_free() # o meteoro de chegada pode já ter matado os grunts
	check("golem chega perto da porta", await _wait_for(func() -> bool: return summon.global_position.distance_to(door.global_position) < 8.0, 300))
	check("sem inimigos, golem encontra a porta", summon.nearest_heavy_door() == door)
	check("usa Agarrar na porta", summon.use_skill(0))
	check("porta abre", await _wait_for(func() -> bool: return door.is_open and door.collision_layer == 0, 600))

	print("== sala 2: sacerdote abre os baús")
	await _summon(&"priest")
	player.global_position = Vector3(0, 0.1, -22.0)
	await _frames(5)
	check("abre o baú da skill", chest_skill.interact(player))
	check("quake liberada no menu do golem", SummonSkills.choices_for(&"golem").has(&"quake"))
	check("baú lembrado em world_flags", GameState.world_flags.get(&"trial_chest_quake", false))
	check("não abre duas vezes", not chest_skill.interact(player))
	player.health.current = 10
	check("abre o baú de cura", chest_heal.interact(player))
	check("vida restaurada", player.health.current == player.health.max_health)

	print("== sala 3: mago bane o jogador pela parede secreta")
	await _summon(&"mage")
	player.global_position = Vector3(0, 0.1, -38.0)
	await _frames(5)
	check("pista: rachaduras brilham com o mago", secret._crack_mat.emission_enabled)
	var z_normal: float = await _drive(Vector3(0, 0.1, -40.0), Vector3.FORWARD, 60)
	check("jogador comum não atravessa a parede secreta", z_normal > -43.4)
	summon.skills[0]["timer"] = 0.0
	check("usa banimento (sem inimigos, bane o jogador)", summon.use_skill(0))
	check("jogador banido", await _wait_for(func() -> bool: return player.is_banished(), 120))
	var z_banished: float = await _drive(Vector3(0, 0.1, -40.0), Vector3.FORWARD, 120)
	check("banido atravessa a parede secreta", z_banished < -46.0)
	check("sai do banimento na sala escondida", summon.use_skill(0) and not player.is_banished())

	print("== sala escondida: sacerdote abre o último baú")
	await _summon(&"priest")
	player.global_position = Vector3(0, 0.1, -48.5)
	await _frames(5)
	check("abre o baú escondido", chest_hidden.interact(player))
	check("blast liberada no menu do mago", SummonSkills.choices_for(&"mage").has(&"blast"))


## Move o jogador a partir de `start` na direção `dir` por `n` quadros e devolve o z final.
func _drive(start: Vector3, dir: Vector3, n: int) -> float:
	player.global_position = start
	player.velocity = Vector3.ZERO
	for i in n:
		player.velocity.x = dir.x * 6.0
		player.velocity.z = dir.z * 6.0
		if not player.is_banished():
			player.move_and_slide()
		await get_tree().physics_frame
	return player.global_position.z
