extends Node
## Ferramenta de desenvolvimento: liga o debug de hitboxes e tira capturas de um golpe acertando um
## inimigo (cápsulas do corpo em verde, varredura da arma em vermelho).
## Uso (precisa de janela): godot --path . res://tools/hitbox_shot.tscn -- <pasta_saida>

var _out := "user://hitbox_shot"
var frame := 0
var player: Node
var enemy: Node


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	DirAccess.make_dir_recursive_absolute(_out)
	Settings.debug_hitboxes = true
	add_child(load("res://levels/test_arena.tscn").instantiate())


func _shot(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_out.path_join(file_name))


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
		enemy.global_position = Vector3(0.3, 0.1, 1.9)
		enemy.attack_cd = 99.0
		enemy.health.current = 9999
		var cam := get_tree().get_first_node_in_group("camera_rig")
		cam.set("_yaw", deg_to_rad(-70.0))
	if frame == 40:
		Input.action_press("attack")
	if frame == 42:
		Input.action_release("attack")
	if frame in [50, 53, 56]:
		_shot("hit_%d.png" % frame)
	if frame == 120:
		get_tree().quit()
