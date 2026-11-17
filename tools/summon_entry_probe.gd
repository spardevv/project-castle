extends Node
## Ferramenta de desenvolvimento: testa invocar/dispensar com animação, cooldown entre summons e
## gera todos os sons (confere que a síntese não falha). Uso: godot --headless --path . res://tools/summon_entry_probe.tscn

var frame := 0
var player: Player
var summon: Summon
var g1: Enemy
var _last := ""


func _ready() -> void:
	add_child(load("res://levels/test_arena.tscn").instantiate())


func _log(tag: String) -> void:
	if not is_instance_valid(summon):
		return
	var line := "%s %s" % [tag, summon.machine.current_name()]
	if line != _last:
		print("  f%d %s | y=%.1f vida=%d/%d" % [frame, line, summon.global_position.y, summon.health.current, summon.health.max_health])
		_last = line


func _physics_process(_delta: float) -> void:
	frame += 1
	if frame == 5:
		player = get_tree().get_first_node_in_group("player")
		g1 = get_tree().get_nodes_in_group("enemy")[0]
		# Sons: gera todos e confere que a síntese funciona (duração > 0).
		var ids := [&"swing", &"swing_heavy", &"whoosh", &"hit", &"hit_heavy", &"hit_kill", &"punch", &"land", &"bow", &"clink",
			&"boom", &"jump", &"fire", &"art_use", &"zap", &"debuff", &"heal", &"buff", &"summon_priest", &"dismiss_priest",
			&"meteor_fall", &"dismiss_golem", &"roar", &"denied"]
		var t0 := Time.get_ticks_msec()
		var ok := 0
		for id in ids:
			var st: AudioStreamWAV = Sfx._stream(id)
			if st != null and st.data.size() > 100:
				ok += 1
		print("sons gerados: %d/%d em %d ms" % [ok, ids.size(), Time.get_ticks_msec() - t0])

	# 1. Golem: meteoro ao invocar, com um inimigo na área de impacto.
	if frame == 20:
		print("== 1. invocar golem (meteoro)")
		g1.global_position = player.global_position + player.forward() * 4.0
		g1.velocity = Vector3.ZERO
		g1.attack_cd = 99.0
		g1.health.current = 100
		g1.machine.change_to(&"Idle")
		player.toggle_summon()
		summon = player.summon
		print("  summon %s | arrival=%s" % [GameState.summon_kind, summon.arrival])
	if frame > 20 and frame < 140:
		_log("golem")
	if frame == 140:
		print("  inimigo na área: vida %d/100 (esperado < 100 pelo impacto)" % g1.health.current)

	# 2. Dispensar golem + cooldown.
	if frame == 150:
		print("== 2. dispensar golem")
		_last = ""
		player.toggle_summon()
		print("  cooldown de summon=%.1f s" % player.summon_cooldown())
	if frame > 150 and frame < 240:
		_log("golem")
	if frame == 250:
		print("  tenta invocar com cooldown ativo: summon=%s (esperado null)" % [player.summon if player.has_summon() else null])
		player.toggle_summon()
		print("  depois de tentar: has_summon=%s (esperado false)" % player.has_summon())

	# 3. Sacerdote: explosão de cura ao surgir (player ferido).
	if frame == 260:
		print("== 3. sacerdote (explosão de cura)")
		GameState.set_summon_kind(&"priest")
		player._summon_cd = 0.0
		player.health.current = 40
		_last = ""
		player.toggle_summon()
		summon = player.summon
		print("  vida antes=%d arrival=%s" % [player.health.current, summon.arrival])
	if frame > 260 and frame < 340:
		_log("sacerdote")
	if frame == 340:
		print("  vida depois da explosão de cura=%d (esperado >= 80)" % player.health.current)
		_last = ""
		player.toggle_summon()
	if frame > 340 and frame < 440:
		_log("sacerdote")
	if frame == 450:
		print("  summon ainda existe? %s (esperado false: saiu depois da animação)" % is_instance_valid(summon))
		get_tree().quit()
