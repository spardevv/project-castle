extends Node
## Ferramenta de desenvolvimento: confirma que o player nasce longe dos inimigos (nenhum persegue no
## início) e que o sacerdote se posiciona recuado, com a aura de cura funcionando.
## Uso: godot --headless --path . res://tools/spawn_probe.tscn

var frame := 0
var player: Player
var summon: Summon
var g1: Enemy


func _ready() -> void:
	add_child(load("res://levels/test_arena.tscn").instantiate())


func _physics_process(_delta: float) -> void:
	frame += 1
	if frame == 5:
		player = get_tree().get_first_node_in_group("player")
		print("player nasce em ", player.global_position.snappedf(0.1), " olhando ", player.forward().snappedf(0.1))
		var min_d := INF
		for e in get_tree().get_nodes_in_group("enemy"):
			min_d = minf(min_d, e.global_position.distance_to(player.global_position))
		print("inimigo mais próximo do spawn: %.1f m" % min_d)
	if frame == 240:
		var chasing := 0
		for e in get_tree().get_nodes_in_group("enemy"):
			if e.machine.current_name() != "Idle":
				chasing += 1
		print("após 4 s parado: inimigos ativos=%d (esperado 0)" % chasing)
		var cam := get_tree().get_first_node_in_group("camera_rig") as Camera3D
		GameState.set_summon_kind(&"priest")
		player.toggle_summon()
		summon = player.summon
		summon.global_position = player.global_position + Vector3(2, 0, 1)
		g1 = get_tree().get_nodes_in_group("enemy")[0]
		print("passivas do sacerdote: ", GameState.summon_passives)
	# Sacerdote com inimigo à frente: deve recuar para longe do inimigo, não necessariamente para as costas.
	if frame == 260:
		g1.global_position = player.global_position + Vector3(8, 0.1, -6)
		g1.velocity = Vector3.ZERO
		g1.attack_cd = 99.0
		player.health.current = 50
		print("== inimigo a nordeste do player")
	if frame in [380, 520]:
		var to_priest := summon.global_position - player.global_position
		var to_enemy := g1.global_position - player.global_position
		print("  f%d sacerdote a %.1f m do player (anel 4-8) | ângulo entre sacerdote e inimigo=%.0f° (esperado perto de 180) | vida do player=%d" % [
			frame, Vector2(to_priest.x, to_priest.z).length(),
			rad_to_deg(Vector2(to_priest.x, to_priest.z).angle_to(Vector2(to_enemy.x, to_enemy.z))), player.health.current])
	if frame == 530:
		get_tree().quit()
