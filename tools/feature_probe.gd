extends Node
## Ferramenta de desenvolvimento: roteiro automático dos recursos da Fase 1 (troca de alvo, arte,
## parry, flechas, brutamontes, skills do summon). Registra os eventos relevantes.
## Uso: godot --headless --path . res://tools/feature_probe.tscn

var frame := 0
var player: Player
var grunts: Array = []
var brute: Enemy
var archers: Array = []
var _guard_armed := false
var _guard_frame := -1


func _ready() -> void:
	add_child(load("res://levels/test_arena.tscn").instantiate())
	EventBus.hit_landed.connect(func(_p: Vector3, d: int) -> void: print("    hit dmg=", d))


func _park(e: Enemy, pos: Vector3) -> void:
	e.global_position = pos
	e.velocity = Vector3.ZERO
	e.attack_cd = 99.0
	e.shoot_cd = 99.0
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
		for e in get_tree().get_nodes_in_group("enemy"):
			if e.move_set == &"brute":
				brute = e
			elif e.move_set == &"archer":
				archers.append(e)
			else:
				grunts.append(e)
			_park(e, Vector3(60 + randf() * 5, 0.1, 60))
		player.global_position = Vector3(0, 0.1, 0)
		player.visual.rotation.y = 0.0
		_park(grunts[0], Vector3(-3, 0.1, 7))
		_park(grunts[1], Vector3(3, 0.1, 7))
		print("== 1. troca de alvo")

	# 1. Lock-on e troca de alvo pelo analógico direito.
	_press("lock_on", 15)
	if frame == 25:
		print("  travado em: ", player.lock_target.name if player.has_lock() else "nada")
	_press("cam_right", 30, 4)
	if frame == 40:
		print("  após flick p/ direita: ", player.lock_target.name if player.has_lock() else "nada")
	_press("cam_left", 45, 4)
	if frame == 55:
		print("  após flick p/ esquerda: ", player.lock_target.name if player.has_lock() else "nada")

	# 2. Arte da arma com medidor cheio.
	if frame == 60:
		print("== 2. arte da arma")
		_park(grunts[0], Vector3(-0.8, 0.1, 2.5))
		_park(grunts[1], Vector3(0.8, 0.1, 3.0))
		player.art_meter = 100.0
	_press("weapon_art", 62)
	if frame in [63, 90, 120, 150]:
		print("  f%d estado=%s medidor=%.0f grunts=%s/%s" % [frame, player.machine.current_name(), player.art_meter,
			grunts[0].machine.current_name(), grunts[1].machine.current_name()])

	# 3. Parry com escudo: segura a guarda pouco antes do golpe do soldado.
	if frame == 200:
		print("== 3. parry com escudo")
		GameState.set_secondary(&"shield")
		print("  perfil de guarda: ", player.guard_profile.display_name, " offhand=", player.rig.offhand)
		player.lock_target = null
		player.global_position = Vector3(0, 0.1, 0)
		player.visual.rotation.y = 0.0
		_park(grunts[1], Vector3(60, 0.1, 60))
		_park(grunts[0], Vector3(0, 0.1, 1.8))
		grunts[0].health.current = 300
		grunts[0].machine.change_to(&"Attack")
		_guard_armed = true
	if _guard_armed and grunts[0].machine.current_name() == "Attack":
		var st: Node = grunts[0].machine.current
		# A janela de parry conta a partir do contato real da arma: aperta no início da fase ativa.
		if st._t >= float(st._m["windup"]) - 0.02:
			Input.action_press("guard")
			_guard_armed = false
			_guard_frame = frame
			print("  guarda apertada a %.2fs do golpe (%s)" % [float(st._m["windup"]) - st._t, st._m["anim"]])
	if _guard_frame > 0 and frame == _guard_frame + 20:
		print("  player hp=%d tag=%s | soldado: %s" % [player.health.current, player.health.last_tag, grunts[0].machine.current_name()])
		Input.action_release("guard")

	# 4. Flechas: uma bloqueada pelo escudo, outra acertando sem guarda.
	if frame == 300:
		print("== 4. flechas")
		_park(grunts[0], Vector3(60, 0.1, 60))
		_park(archers[0], Vector3(0, 0.1, 10))
		archers[0].shoot_cd = 0.0
		archers[0].machine.change_to(&"Kite")
		Input.action_press("guard")
	if frame == 380:
		print("  com escudo: player hp=%d" % player.health.current)
		Input.action_release("guard")
		archers[0].shoot_cd = 0.0
	if frame == 470:
		print("  sem guarda: player hp=%d" % player.health.current)
		_park(archers[0], Vector3(60, 0.1, 60))

	# 5. Brutamontes: explosão (lança) não o tira do chão; pisão contra o player.
	if frame == 480:
		print("== 5. brutamontes")
		_park(brute, Vector3(0, 0.1, 4))
		var ex := Explosion.new()
		ex.position = brute.global_position + Vector3(0, 0.5, 0)
		add_child(ex)
	if frame == 486:
		var st: Node = brute.machine.current
		print("  brutamontes após explosão: estado=%s modo=%s y=%.2f" % [brute.machine.current_name(), str(st.get("_mode")), brute.global_position.y])
	if frame == 520:
		brute.attack_cd = 0.0
		brute.machine.change_to(&"Chase")
	if frame in [600, 680]:
		print("  f%d player hp=%d estado=%s | brutamontes=%s" % [frame, player.health.current, player.machine.current_name(), brute.machine.current_name()])

	# 6. Summon: Investida e Terremoto.
	if frame == 700:
		print("== 6. skills do summon")
		_park(brute, Vector3(60, 0.1, 60))
		player.health.current = player.health.max_health
		player.global_position = Vector3(0, 0.1, 0)
		_park(grunts[0], Vector3(0, 0.1, 7))
		_park(grunts[1], Vector3(1.5, 0.1, 6))
		grunts[0].health.current = 300
		grunts[1].health.current = 300
		player.toggle_summon()
	if frame in [730, 800, 830]:
		var sp: Vector3 = player.summon.global_position
		print("  f%d distâncias do summon: grunt0=%.1f grunt1=%.1f | summon=%s" % [frame,
			sp.distance_to(grunts[0].global_position), sp.distance_to(grunts[1].global_position), player.summon.machine.current_name()])
	if frame == 730:
		print("  summon slots: ", player.summon.skills.map(func(s): return s["name"]))
		print("  investida usada: ", player.summon.use_skill(1))
	if frame == 800:
		print("  após investida: grunts=%s/%s hp=%d/%d" % [grunts[0].machine.current_name(), grunts[1].machine.current_name(),
			grunts[0].health.current, grunts[1].health.current])
		print("  terremoto usado: ", player.summon.use_skill(2))
	if frame == 860:
		print("  após terremoto: grunts=%s/%s hp=%d/%d" % [grunts[0].machine.current_name(), grunts[1].machine.current_name(),
			grunts[0].health.current, grunts[1].health.current])
	if frame == 870:
		get_tree().quit()
