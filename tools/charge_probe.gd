extends Node
## Ferramenta de desenvolvimento: testa o ataque carregado (estâncias) e a arte de cada arma.
## Uso: godot --headless --path . res://tools/charge_probe.tscn --quit-after 1500

var frame := 0
var player: Player
var enemy: Enemy
var _round := 0
var _t0 := 0


func _ready() -> void:
	add_child(load("res://levels/test_arena.tscn").instantiate())
	EventBus.hit_landed.connect(func(_p: Vector3, d: int) -> void: print("    hit dmg=", d))


func _park_all() -> void:
	var first := true
	for e in get_tree().get_nodes_in_group("enemy"):
		e.global_position = Vector3(60 + randf() * 5, 0.1, 60)
		e.attack_cd = 99.0
		e.shoot_cd = 99.0
		e.machine.change_to(&"Idle")
		if first:
			enemy = e
			e.health.max_health = 99999
			e.health.current = 99999
			first = false


func _setup(weapon: StringName) -> void:
	GameState.set_primary(weapon)
	player.global_position = Vector3(0, 0.1, 0)
	player.visual.rotation.y = 0.0
	player.art_meter = 100.0
	player.machine.change_to(&"Ground")
	enemy.global_position = Vector3(0, 0.1, 1.6)
	enemy.velocity = Vector3.ZERO
	enemy.health.current = 99999
	enemy.machine.change_to(&"Idle")


func _physics_process(_delta: float) -> void:
	frame += 1
	if frame == 5:
		player = get_tree().get_first_node_in_group("player")
		_park_all()
	# Roteiro: cada rodada = (arma, frames segurando o ataque)
	var plan := [[&"sword", -30], [&"hammer", -30], [&"hammer", 20], [&"hammer", 80]]
	var start := 20 + _round * 300
	if _round < plan.size() and frame == start:
		_setup(plan[_round][0])
		print("== rodada ", _round, " arma=", plan[_round][0], " segura ", plan[_round][1], " frames")
		Input.action_press("attack")
		_t0 = frame
	if _round < plan.size() and frame == start + 5 + int(plan[_round][1]) + 40:
		pass
	if _round < plan.size():
		var hold_frames: int = plan[_round][1]
		if frame == start + 90 + hold_frames:
			print("  libera ataque; estado=", player.machine.current_name(), " progresso=", snappedf(player.charge_progress, 0.01))
			Input.action_release("attack")
		if frame > start and (frame - start) % 20 == 0 and frame < start + 260:
			print("  f+", frame - start, " estado=", player.machine.current_name(), " armor=", player.armor_level,
				" carga=", snappedf(player.charge_progress, 0.01), " inimigo_hp=", enemy.health.current)
		if frame == start + 280:
			_round += 1
	if frame == 20 + plan.size() * 300 + 5:
		print("== arte do martelo")
		_setup(&"hammer")
		Input.action_press("weapon_art")
	if frame == 20 + plan.size() * 300 + 8:
		Input.action_release("weapon_art")
	if frame > 20 + plan.size() * 300 + 5 and frame % 15 == 0 and frame < 20 + plan.size() * 300 + 200:
		print("  art f", frame, " estado=", player.machine.current_name(), " inimigo_hp=", enemy.health.current)
