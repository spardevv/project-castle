extends Node
## Ferramenta de desenvolvimento: testa a skill Agarrar do golem no inimigo travado pelo lock-on.
## Uso: godot --headless --path . res://tools/grab_probe.tscn

var frame := 0
var player: Player
var summon: Summon
var near: Enemy
var far: Enemy
var brute: Enemy
var _last := ""


func _ready() -> void:
	add_child(load("res://levels/test_arena.tscn").instantiate())


func _park(e: Enemy, pos: Vector3) -> void:
	e.global_position = pos
	e.velocity = Vector3.ZERO
	e.attack_cd = 99.0
	e.shoot_cd = 99.0
	e.health.current = e.health.max_health
	e.machine.change_to(&"Idle")


func _physics_process(_delta: float) -> void:
	frame += 1
	if frame == 5:
		player = get_tree().get_first_node_in_group("player")
		var grunts: Array = []
		for e in get_tree().get_nodes_in_group("enemy"):
			if e.move_set == &"brute":
				brute = e
			elif e.move_set == &"grunt":
				grunts.append(e)
			_park(e, Vector3(60 + randf() * 5, 0.1, 60))
		near = grunts[0]
		far = grunts[1]
		player.global_position = Vector3(0, 0.1, 0)
		player.toggle_summon()
		summon = player.summon
		summon.global_position = Vector3(-1, 0.1, 0)
		print("slots: ", GameState.summon_slots)

	# 1. O inimigo mais próximo do golem NÃO é o travado: o golem deve ir no travado.
	if frame == 30:
		print("== 1. agarrar o alvo travado (e não o mais próximo)")
		_park(near, Vector3(-1, 0.1, 3))
		_park(far, Vector3(4, 0.1, 9))
		player.lock_target = far
		print("  travado: %s | mais próximo do golem: %s" % [far.name, near.name])
		print("  usa agarrar: ", summon.use_skill(2))
	if frame > 30 and frame < 160:
		var line := "golem=%s travado=%s(%s) próximo=%s" % [summon.machine.current_name(), far.name, far.machine.current_name(), near.machine.current_name()]
		if line != _last:
			print("  f%d %s | hp travado=%d próximo=%d | altura travado=%.1f" % [frame, line, far.health.current, near.health.current, far.global_position.y])
			_last = line
	if frame == 170:
		print("  resultado: hp travado=%d/%d (agarrado e esmagado) | hp próximo=%d/%d (intacto)" % [
			far.health.current, far.health.max_health, near.health.current, near.health.max_health])

	# 2. Sem lock-on: agarra o mais próximo.
	if frame == 200:
		print("== 2. sem lock-on")
		player.lock_target = null
		_park(near, summon.global_position + Vector3(0, 0, 4))
		_park(far, Vector3(60, 0.1, 60))
		summon.skills[2]["timer"] = 0.0
		_last = ""
		print("  usa agarrar: ", summon.use_skill(2))
	if frame > 200 and frame < 330:
		var line2 := "golem=%s alvo=%s" % [summon.machine.current_name(), near.machine.current_name()]
		if line2 != _last:
			print("  f%d %s" % [frame, line2])
			_last = line2
	if frame == 340:
		print("  hp do alvo=%d/%d" % [near.health.current, near.health.max_health])

	# 3. Brutamontes resiste.
	if frame == 370:
		print("== 3. brutamontes")
		_park(brute, summon.global_position + Vector3(0, 0, 4))
		player.lock_target = brute
		summon.skills[2]["timer"] = 0.0
		_last = ""
		print("  usa agarrar: ", summon.use_skill(2))
	if frame > 370 and frame < 470:
		var line3 := "golem=%s brutamontes=%s" % [summon.machine.current_name(), brute.machine.current_name()]
		if line3 != _last:
			print("  f%d %s" % [frame, line3])
			_last = line3
	if frame == 480:
		print("  hp brutamontes=%d/%d (não foi erguido)" % [brute.health.current, brute.health.max_health])
		get_tree().quit()
