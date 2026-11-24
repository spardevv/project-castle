extends Node
## Ferramenta de desenvolvimento: testa o kit inicial dos summons (skill ativa, básicos, passiva e chegada)
## do Golem, Sacerdote e Mago. Uso: godot --headless --fixed-fps 60 --path . res://tools/summon_kit_probe.tscn

var player: Player
var summon: Summon
var grunts: Array[Enemy] = []
var brute: Enemy
var door: HeavyDoor
var chest: EnchantedChest
var ok := 0
var bad := 0


func _ready() -> void:
	add_child(load("res://levels/test_arena.tscn").instantiate())
	await _frames(5)
	_run()


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


func _park(e: Enemy, pos: Vector3) -> void:
	e.global_position = pos
	e.velocity = Vector3.ZERO
	e.attack_cd = 99.0
	e.shoot_cd = 99.0
	e.health.max_health = 1000
	e.health.current = 1000
	e.machine.change_to(&"Idle")


func _summon(kind: StringName) -> void:
	if is_instance_valid(summon):
		summon.queue_free()
		player.summon = null
	GameState.set_summon_kind(kind)
	player._summon_cd = 0.0
	player.toggle_summon()
	summon = player.summon


func _run() -> void:
	player = get_tree().get_first_node_in_group("player")
	for e in get_tree().get_nodes_in_group("enemy"):
		if e.move_set == &"brute":
			brute = e
		elif e.move_set == &"grunt":
			grunts.append(e)
		_park(e, Vector3(60 + randf() * 5, 0.1, 60))
	door = get_tree().get_first_node_in_group("heavy_door")
	chest = get_tree().get_first_node_in_group("interactable")
	player.global_position = Vector3(0, 0.1, 0)

	print("== dados")
	check("1 skill ativa por summon", GameState._slots[&"golem"].size() == 1 and GameState._slots[&"priest"].size() == 1 and GameState._slots[&"mage"].size() == 1)
	check("1 passiva por summon", GameState._passives[&"golem"].size() == 1 and GameState._passives[&"priest"].size() == 1 and GameState._passives[&"mage"].size() == 1)

	await _golem()
	await _priest()
	await _mage()
	print("RESULTADO: %d ok, %d falhas" % [ok, bad])
	get_tree().quit(1 if bad > 0 else 0)


func _golem() -> void:
	print("== golem: chegada (meteoro sobre o inimigo)")
	_park(grunts[0], Vector3(0, 0.1, -9))
	var before := grunts[0].health.current
	_summon(&"golem")
	await _frames(5)
	check("meteoro cai sobre o inimigo mais próximo", Vector2(summon.global_position.x, summon.global_position.z).distance_to(Vector2(0, -9)) < 3.0)
	await _frames(120)
	check("dano massivo em área", grunts[0].health.current <= before - 40)

	print("== golem: básicos")
	var seq: Array[String] = []
	var dist_near := 1.0
	for i in 4:
		seq.append(String(summon.next_basic(dist_near)["anim"]))
	check("soco D, soco E, chute, soco D", seq == ["punch_l", "kick", "punch_r", "punch_l"] or seq == ["punch_l", "kick", "punch_r", "punch_l"])
	summon.shoulder_cd = 0.0
	check("ombrada para fechar distância", summon.next_basic(6.0).get("anim", "") == "shoulder")
	check("sem ombrada em cooldown nem longe", summon.next_basic(6.0).is_empty())

	print("== golem: agarrar (inimigo)")
	_park(grunts[0], summon.global_position + Vector3(0, 0, 4))
	var hp0 := grunts[0].health.current
	summon.skills[0]["timer"] = 0.0
	check("usa agarrar", summon.use_skill(0))
	await _frames(40)
	check("golem em Grab e inimigo preso", summon.machine.current_name() == "Grab" and grunts[0].machine.current_name() == "Held")
	# o jogador ataca o preso: ele não sai
	var hit := HitData.new()
	hit.damage = 1
	grunts[0].health.take_hit(hit)
	await _frames(60)
	check("golpe do jogador não solta", grunts[0].machine.current_name() == "Held")
	await _frames(200)
	check("solta após ~4 s", grunts[0].machine.current_name() != "Held")
	check("dano baixo por segundo", grunts[0].health.current < hp0 and hp0 - grunts[0].health.current < 40)
	await _frames(60)

	print("== golem: agarrar (porta)")
	for g in grunts:
		_park(g, Vector3(60, 0.1, 60))
	summon.global_position = door.global_position + Vector3(0, -1.9, 5)
	summon.velocity = Vector3.ZERO
	await _frames(5)
	summon.skills[0]["timer"] = 0.0
	check("agarrar sem inimigo, perto da porta", summon.use_skill(0))
	await _frames(240)
	check("porta aberta", door.is_open)
	await _frames(120)
	check("porta não bloqueia mais", door.collision_layer == 0)
	summon.skills[0]["timer"] = 0.0
	summon.global_position = Vector3(0, 0.1, 20)
	check("sem inimigo nem porta: agarrar recusado", not summon.use_skill(0))

	print("== golem: pedra (passiva)")
	summon.passive_timers.clear()
	_park(grunts[0], summon.global_position + Vector3(0, 0, 6))
	_park(grunts[1], summon.global_position + Vector3(0, 0, 12))
	check("prioriza o mais distante", summon.pick_rock_target() == grunts[1])
	grunts[0].global_position.y = 4.0
	grunts[0].velocity = Vector3.ZERO
	grunts[1].velocity = Vector3.ZERO
	check("prioriza o aéreo", summon.pick_rock_target() == grunts[0])
	_park(grunts[0], summon.global_position + Vector3(0, 0, 8))
	grunts[1].global_position = Vector3(60, 0.1, 60)
	summon.start_passive(&"rock")
	await _frames(100)
	check("pedra deixa o inimigo atordoado", grunts[0].machine.current_name() == "Stagger" or grunts[0].health.current < grunts[0].health.max_health)
	check("cooldown 10 s", is_equal_approx(float(summon.passive_timers[&"rock"]), 10.0 - 100.0 / 60.0) or float(summon.passive_timers[&"rock"]) > 7.0)
	_park(grunts[0], Vector3(60, 0.1, 60))


func _priest() -> void:
	print("== sacerdote: chegada (cura ao lado)")
	player.health.current = 30
	_summon(&"priest")
	await _frames(5)
	var rel := summon.global_position - player.global_position
	check("chega ao lado do jogador", absf(rel.dot(player.forward().cross(Vector3.UP))) > 1.0)
	await _frames(40)
	check("cura 30% da vida máxima", player.health.current >= 30 + int(player.health.max_health * 0.3) - 1)
	check("regen de 2 s", StatusEffects.has(player, &"regen"))
	await _frames(200)
	player.health.current = 50

	print("== sacerdote: cura ativa")
	summon.skills[0]["timer"] = 0.0
	check("usa heal", summon.use_skill(0))
	await _frames(60)
	check("cura 10% da vida máxima", player.health.current == 50 + int(ceili(player.health.max_health * 0.1)))
	check("recarga 1,2 s", is_equal_approx(float(summon.skills[0]["cooldown"]), 1.2))

	print("== sacerdote: sem ataque básico")
	_park(grunts[0], summon.global_position + Vector3(0, 0, 2))
	await _frames(60)
	check("não ataca (nunca entra em Strike)", summon.machine.current_name() != "Strike")
	check("benção ao começar o combate, próxima só em ~35 s", float(summon.passive_timers.get(&"p_blessing", 0.0)) > 30.0)
	print("== sacerdote: benção passiva em combate")
	await _frames(30)
	check("benção ativa no jogador", StatusEffects.has(player, &"blessing"))
	check("benção: dano ×1,25 e armadura", is_equal_approx(StatusEffects.mult(player, "damage_out"), 1.25) and is_equal_approx(StatusEffects.mult(player, "damage_in"), 0.75))
	_park(grunts[0], Vector3(60, 0.1, 60))

	print("== sacerdote: baú encantado")
	player.global_position = chest.global_position + Vector3(0, 0.1, 2)
	GameState.set_summon_kind(&"golem")
	await _frames(5)
	player.try_interact()
	check("baú selado sem sacerdote", not chest.is_open)
	player._summon_cd = 0.0
	GameState.set_summon_kind(&"priest")
	player._summon_cd = 0.0
	player.toggle_summon()
	summon = player.summon
	await _frames(60)
	player.global_position = chest.global_position + Vector3(0, 0.1, 2)
	player.try_interact()
	check("baú abre com sacerdote + interagir", chest.is_open)
	player.global_position = Vector3(0, 0.1, 0)


func _mage() -> void:
	print("== mago: chegada (zona arcana)")
	_summon(&"mage")
	var zone_found := false
	for i in 80:
		await _frames(1)
		for c in get_children():
			pass
		if not get_tree().root.find_children("*", "ArcaneZone", true, false).is_empty():
			zone_found = true
			break
	check("zona arcana criada", zone_found)
	var zone: ArcaneZone = get_tree().root.find_children("*", "ArcaneZone", true, false)[0]
	_park(grunts[0], zone.global_position + Vector3(1.5, 0.1, 0))
	var hp := grunts[0].health.current
	await _frames(120)
	check("zona causa dano contínuo", grunts[0].health.current < hp)
	check("zona causa lentidão", StatusEffects.has(grunts[0], &"slow"))
	_park(grunts[0], Vector3(60, 0.1, 60))
	check("dano contínuo não faz cambalear", Health.dot(grunts[0], 3, null) and grunts[0].machine.current_name() == "Idle")
	_park(grunts[0], Vector3(60, 0.1, 60))
	zone.queue_free()
	await _frames(5)

	print("== mago: seta arcana (básico)")
	_park(grunts[0], summon.global_position + Vector3(0, 0, -8))
	grunts[0].health.current = 900
	var arrows := 0
	var seen_skill := false
	for i in 200:
		await _frames(1)
		if summon.machine.current_name() == "Skill":
			seen_skill = true
	check("dispara seta arcana", seen_skill and grunts[0].health.current < 900)
	_park(grunts[0], Vector3(60, 0.1, 60))

	print("== mago: banimento em inimigo")
	_park(grunts[0], player.global_position + Vector3(0, 0, -6))
	_park(brute, player.global_position + Vector3(6, 0, -8))
	grunts[0].machine.change_to(&"Chase")
	summon.skills[0]["timer"] = 0.0
	player.lock_target = grunts[0]
	print("   estado=", summon.machine.current_name(), " hp=", summon.health.current, " skills=", summon.skills)
	check("usa banimento", summon.use_skill(0))
	await _frames(40)
	check("inimigo banido", grunts[0].is_banished() and not grunts[0].is_in_group("enemy"))
	check("recarga travada enquanto banido", float(summon.skills[0]["timer"]) > 1000.0)
	check("translúcido", (grunts[0].rig.find_children("*", "MeshInstance3D", true, false)[0] as GeometryInstance3D).transparency > 0.3)
	check("sem colisão (atravessa paredes)", grunts[0].collision_mask == 0)
	var hp_b := grunts[0].health.current
	var hit := HitData.new()
	hit.damage = 20
	var hb: Hurtbox = grunts[0].hurtbox
	check("não pode ser atingido", not hb.monitorable)
	await _frames(1200)
	check("volta após 20 s", not grunts[0].is_banished() and grunts[0].is_in_group("enemy"))
	check("recarga de 30 s começa só agora", float(summon.skills[0]["timer"]) > 28.0 and float(summon.skills[0]["timer"]) <= 30.0)
	check("inimigo comum não fica atordoado", grunts[0].machine.current_name() != "Stagger")
	print("== mago: banimento em criatura grande")
	summon.skills[0]["timer"] = 0.0
	_park(grunts[0], Vector3(60, 0.1, 60))
	player.lock_target = brute
	check("usa banimento no brutamontes", summon.use_skill(0))
	await _frames(1240)
	check("brutamontes volta atordoado", brute.machine.current_name() == "Stagger")
	_park(brute, Vector3(60, 0.1, 60))
	player.lock_target = null

	print("== mago: banimento no jogador")
	for g in grunts:
		_park(g, Vector3(60, 0.1, 60))
	await _frames(90)
	summon.skills[0]["timer"] = 0.0
	player.global_position = Vector3(0, 0.1, 0)
	print("   estado=", summon.machine.current_name(), " hp=", summon.health.current, " passivas=", summon.passive_timers)
	check("usa banimento sem inimigos", summon.use_skill(0))
	await _frames(40)
	check("jogador banido", player.is_banished())
	check("sem recarga no jogador", float(summon.skills[0]["timer"]) == 0.0)
	check("não leva dano", not player.health.take_hit(HitData.new()))
	player.velocity = Vector3(8, 0, 0)
	player.global_position = Vector3(29.0, 0.5, 0)
	await _frames(60)
	check("atravessa a parede", player.global_position.x > 29.5 or player.is_banished())
	player.global_position = Vector3(0, 0.0, 0)
	await _frames(5)
	check("sai apertando a skill de novo (pés no chão)", summon.use_skill(0) and not player.is_banished())
	await _frames(20)

	print("== mago: orbes (passiva)")
	summon.passive_timers.clear()
	_park(grunts[0], player.global_position + Vector3(0, 0, -7))
	grunts[0].health.current = 900
	var orbs_seen := false
	for i in 200:
		await _frames(1)
		if not get_tree().root.find_children("*", "ArcaneOrbs", true, false).is_empty():
			orbs_seen = true
	check("conjura orbes", orbs_seen)
	check("cooldown de 40 s", float(summon.passive_timers[&"m_orbs"]) > 30.0)
	check("orbes ferem o inimigo", grunts[0].health.current < 900)
