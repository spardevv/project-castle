extends Node
## Ferramenta de desenvolvimento: simula golpes contra um inimigo e registra as reações.
## Uso: godot --headless --path . res://tools/combat_probe.tscn

var player: Node
var enemy: Node
var frame := 0
var _last := ""


func _ready() -> void:
	add_child(load("res://levels/test_arena.tscn").instantiate())
	EventBus.hit_landed.connect(func(_p: Vector3, d: int) -> void: print("  HIT dmg=", d, " frame=", frame))


func _physics_process(_delta: float) -> void:
	frame += 1
	if frame == 5:
		player = get_tree().get_first_node_in_group("player")
		var enemies := get_tree().get_nodes_in_group("enemy")
		enemy = enemies[0]
		for i in range(1, enemies.size()):
			enemies[i].queue_free()
		player.global_position = Vector3(0, 0.1, 0)
		player.visual.rotation.y = 0.0
		enemy.global_position = Vector3(0, 0.1, 1.7)
		enemy.attack_cd = 99.0 # deixa o inimigo parado para isolar as reações
		enemy.health.current = 500
	# Combo Y, Y, Y
	for f in [30, 44, 58]:
		if frame == f:
			Input.action_press("attack")
		if frame == f + 2:
			Input.action_release("attack")
	# Depois: Y segurado -> overhead (knockback 10 -> derrubada)
	if frame == 150:
		enemy.global_position = player.global_position + Vector3(0, 0.1, 1.7)
		Input.action_press("attack")
	if frame == 190:
		Input.action_release("attack")
	# Lock-on + trás + Y = corte ascendente (lança); depois Y no ar = cortes aéreos.
	if frame == 300:
		enemy.global_position = player.global_position + Vector3(0, 0.1, 1.7)
		enemy.attack_cd = 99.0
		Input.action_press("lock_on")
	if frame == 302:
		Input.action_release("lock_on")
		Input.action_press("move_back")
	if frame == 306:
		Input.action_press("attack")
	if frame == 308:
		Input.action_release("attack")
		Input.action_release("move_back")
	for f in [330, 346]:
		if frame == f:
			Input.action_press("attack")
		if frame == f + 2:
			Input.action_release("attack")
	# Bola de fogo: inimigo a 6 m, ainda travado no lock-on.
	if frame == 480:
		enemy.global_position = player.global_position + Vector3(0, 0.1, 6.0)
		enemy.velocity = Vector3.ZERO
		enemy.attack_cd = 99.0
		print("-- bola de fogo")
	if frame == 500:
		Input.action_press("secondary")
	if frame == 502:
		Input.action_release("secondary")
	if frame > 495 and frame < 560:
		for n in get_tree().current_scene.get_children():
			pass
		var proj := _find(get_tree().root, "Projectile")
		var ex := _find(get_tree().root, "Explosion")
		if proj:
			print(frame, "  projétil em ", proj.global_position.snappedf(0.1))
		if ex:
			print(frame, "  EXPLOSÃO em ", ex.global_position.snappedf(0.1), " monitoring=", ex.monitoring)
	if frame > 5 and enemy and is_instance_valid(enemy):
		var st: String = enemy.machine.current_name()
		var mode: String = st
		if st == "Stagger":
			mode += "/" + str(enemy.machine.current.get("_mode"))
		var line := "p=%s e=%s rig=%d hp=%d ey=%.1f py=%.1f" % [player.machine.current_name(), mode, enemy.rig._mode,
			enemy.health.current, enemy.global_position.y, player.global_position.y]
		if line != _last:
			print(frame, " ", line)
			_last = line
	if frame == 620:
		get_tree().quit()


func _find(n: Node, cls: String) -> Node3D:
	for c in n.get_children():
		if c.get_script() != null and c.get_script().get_global_name() == cls:
			return c
		var r := _find(c, cls)
		if r:
			return r
	return null
