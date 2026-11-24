extends Node
## Ferramenta de desenvolvimento: fotografa a parede secreta da test_arena em 4 situações e salva PNGs.
##  1_normal (sem summon: rachaduras), 2_mago (Mago invocado: rachaduras pulsam), 3_banido (jogador banido
##  atravessando, no teto de 2,5 m), 4_camera_jogo (a mesma cena pela câmera do jogo).
## Uso (precisa de janela): godot --path . res://tools/secret_wall_shot.tscn --resolution 1280x720 -- <pasta>

const WALL_VIEW_FROM := Vector3(16.5, 3.2, -21.5)
const WALL_VIEW_AT := Vector3(24.0, 2.4, -27.0)

var out_dir := "user://"
var player: Player
var cam: Camera3D


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	add_child(load("res://levels/test_arena.tscn").instantiate())
	await _frames(5)
	player = get_tree().get_first_node_in_group("player")
	var i := 0
	for e in get_tree().get_nodes_in_group("enemy"):
		(e as Node3D).global_position = Vector3(-27.0 + 1.6 * i, 0.1, -27.0)
		e.process_mode = Node.PROCESS_MODE_DISABLED
		i += 1
	cam = Camera3D.new()
	add_child(cam)
	cam.global_position = WALL_VIEW_FROM
	cam.look_at(WALL_VIEW_AT)
	cam.current = true
	player.global_position = Vector3(19.0, 0.1, -25.0)
	await _frames(30)
	await _shot("1_normal")

	GameState.set_summon_kind(&"mage")
	player._summon_cd = 0.0
	player.toggle_summon()
	await _frames(200)
	await _shot("2_mago")

	player.start_banish()
	player.global_position = Vector3(21.5, 0.1, -26.5)
	for f in 60:
		player.velocity = Vector3(2.0, 4.0, 0.0)
		await get_tree().physics_frame
	player.velocity = Vector3.ZERO
	await _frames(5)
	print("jogador banido em ", player.global_position)
	await _shot("3_banido")

	var rig := get_tree().get_first_node_in_group("camera_rig")
	if rig == null:
		for n in get_tree().root.find_children("*", "CameraRig", true, false):
			rig = n
	if rig != null:
		(rig.get("camera") as Camera3D).current = true
		await _frames(30)
		await _shot("4_camera_jogo")
	get_tree().quit()


func _frames(n: int) -> void:
	for f in n:
		await get_tree().physics_frame


func _shot(label: String) -> void:
	for f in 4:
		await RenderingServer.frame_post_draw
	var path := out_dir.path_join("secret_wall_%s.png" % label)
	get_viewport().get_texture().get_image().save_png(path)
	print("saved ", path)
