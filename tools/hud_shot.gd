extends Node
## Ferramenta de desenvolvimento: abre a arena, invoca o summon e salva capturas da HUD (golem e sacerdote).
## Uso: godot --path . res://tools/hud_shot.tscn -- <prefixo>

func _ready() -> void:
	var prefix := "user://hud"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		prefix = args[0]
	var arena: Node = load("res://levels/test_arena.tscn").instantiate()
	add_child(arena)
	for k in [&"mage"]:
		GameState.set_summon_kind(k)
		await get_tree().create_timer(0.5).timeout
		var player := get_tree().get_first_node_in_group("player") as Player
		player._summon_cd = 0.0
		player.toggle_summon()
		await get_tree().create_timer(3.0).timeout
		player.summon.health.current -= 35
		player.summon.health.changed.emit(player.summon.health.current, player.summon.health.max_health)
		player.command_skill(0)
		player.health.current = 60
		player.health.changed.emit(60, player.health.max_health)
		player.art_meter = 75.0
		player.charge_progress = 1.6
		StatusEffects.apply(player, &"bless")
		StatusEffects.apply(player, &"ward", 4.0)
		StatusEffects.apply(player, &"slow")
		await get_tree().create_timer(0.8).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s_%s.png" % [prefix, k])
		print("saved ", k)
	get_tree().quit()
