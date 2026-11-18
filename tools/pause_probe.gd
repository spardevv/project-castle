extends Node
## Ferramenta de desenvolvimento: abre o menu de pausa, tira capturas (página principal e opções),
## troca opções e reinicia a fase, conferindo que o jogo volta despausado.
## Uso (precisa de janela): godot --path . res://tools/pause_probe.tscn -- <pasta_saida>

var _out := "user://pause_probe"
var frame := 0
var _menu: Node
## A fase é filha desta cena; "Reiniciar" recarrega a cena atual, então a 2ª execução só confere o resultado.
static var _restarted := false


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	DirAccess.make_dir_recursive_absolute(_out)
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(load("res://levels/test_arena.tscn").instantiate())


func _press(action: StringName) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)


func _shot(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_out.path_join(file_name))


func _process(_delta: float) -> void:
	frame += 1
	if _restarted:
		if frame == 20:
			var player := get_tree().get_first_node_in_group("player")
			print("reiniciado: player=", player != null, " pausado=", get_tree().paused,
				" menu aberto=", find_child("PauseMenu", true, false).is_open())
			get_tree().quit()
		return
	match frame:
		30:
			_menu = find_child("PauseMenu", true, false)
			_press(&"pause")
		34:
			print("aberto=", _menu.is_open(), " pausado=", get_tree().paused)
			_shot("pause_main.png")
		38:
			_menu._show_page(1)
		42:
			_shot("pause_options.png")
			var before: float = Settings.master_volume
			_menu._cycle("master_volume", -1)
			print("volume ", before, " -> ", Settings.master_volume, " bus_db=", AudioServer.get_bus_volume_db(0))
			_menu._cycle("master_volume", 1)
			_menu._cycle("render_scale", -1)
			print("escala 3D=", get_tree().root.scaling_3d_scale)
			_menu._cycle("render_scale", 1)
		46:
			_press(&"ui_cancel") # volta para a página principal
		50:
			print("página principal visível=", _menu._main_box.visible)
			_restarted = true
			_menu.restart()
