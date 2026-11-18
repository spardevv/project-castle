extends CanvasLayer
## Menu de pausa (Esc / Start): continuar, equipamento, reiniciar a fase, opções e sair.
## Opções: vídeo (modo de tela, resolução, escala 3D, VSync, limite de FPS, anti-aliasing, FPS na tela),
## áudio e controles. Navegação: ↑/↓ escolhe, ←/→ ou A/Enter troca o valor, B/Esc volta.

const PAGE_MAIN := 0
const PAGE_OPTIONS := 1

var _page := PAGE_MAIN
var _main_box: VBoxContainer
var _options_box: VBoxContainer
var _main_first: Button
var _rows: Array[Dictionary] = [] # {"button": Button, "key": String}
var _hint: Label
var _fps_label: Label
## Raiz da interface do menu. A CanvasLayer fica sempre visível por causa do contador de FPS.
var _ui: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	_build()
	_build_fps_label()
	_ui.visible = false
	Settings.changed.connect(_on_settings_changed)
	_on_settings_changed()


func _process(_delta: float) -> void:
	if _fps_label.visible:
		_fps_label.text = "%d FPS" % Engine.get_frames_per_second()


func _unhandled_input(event: InputEvent) -> void:
	if not _ui.visible:
		# Só abre se nenhum outro menu já pausou o jogo (o de equipamento fecha no Esc sozinho).
		if event.is_action_pressed("pause") and not get_tree().paused:
			open()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		if _page == PAGE_OPTIONS:
			_show_page(PAGE_MAIN)
		else:
			close()
		get_viewport().set_input_as_handled()


func is_open() -> bool:
	return _ui.visible


func open() -> void:
	_ui.visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_show_page(PAGE_MAIN)


func close() -> void:
	_ui.visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func restart() -> void:
	_ui.visible = false
	get_tree().paused = false
	Engine.time_scale = 1.0
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	get_tree().reload_current_scene()


func _open_equipment() -> void:
	var menu := get_tree().current_scene.find_child("EquipmentMenu", true, false)
	if menu == null or not menu.has_method("open"):
		return
	_ui.visible = false # o jogo continua pausado; o menu de equipamento despausa ao fechar
	menu.open()


func _show_page(page: int) -> void:
	_page = page
	_main_box.visible = page == PAGE_MAIN
	_options_box.visible = page == PAGE_OPTIONS
	if page == PAGE_MAIN:
		_main_first.grab_focus()
	else:
		_refresh()
		(_rows[0]["button"] as Button).grab_focus()
	_update_hint()


# --- Construção da interface ---------------------------------------------------

func _build() -> void:
	_ui = Control.new()
	_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_ui)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(620, 0)
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	panel.add_child(margin)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	margin.add_child(vb)

	# Página principal
	_main_box = VBoxContainer.new()
	_main_box.add_theme_constant_override("separation", 10)
	vb.add_child(_main_box)
	_main_box.add_child(_title("Pausa"))
	_main_first = _menu_button(_main_box, "Continuar", close)
	_menu_button(_main_box, "Equipamento", _open_equipment)
	_menu_button(_main_box, "Reiniciar fase", restart)
	_menu_button(_main_box, "Opções", func() -> void: _show_page(PAGE_OPTIONS))
	_menu_button(_main_box, "Sair do jogo", func() -> void: get_tree().quit())

	# Página de opções
	_options_box = VBoxContainer.new()
	_options_box.add_theme_constant_override("separation", 8)
	vb.add_child(_options_box)
	_options_box.add_child(_title("Opções"))
	_options_box.add_child(_section("Vídeo"))
	_add_row("window_mode", "Modo de tela")
	_add_row("resolution", "Resolução (janela)")
	_add_row("render_scale", "Escala 3D")
	_add_row("vsync", "VSync")
	_add_row("max_fps", "Limite de FPS")
	_add_row("msaa", "Anti-aliasing")
	_add_row("show_fps", "Mostrar FPS")
	_options_box.add_child(_section("Áudio"))
	_add_row("master_volume", "Volume geral")
	_options_box.add_child(_section("Controles"))
	_add_row("camera_sensitivity", "Sensibilidade da câmera")
	_add_row("invert_y", "Inverter eixo Y")
	_add_row("screen_shake", "Tremor de tela")
	_add_row("vibration", "Vibração do controle")
	_options_box.add_child(_section("Debug"))
	_add_row("debug_hitboxes", "Mostrar hitboxes")
	_menu_button(_options_box, "Voltar", func() -> void: _show_page(PAGE_MAIN))

	_hint = Label.new()
	_hint.modulate = Color(0.7, 0.7, 0.75)
	vb.add_child(_hint)


func _build_fps_label() -> void:
	_fps_label = Label.new()
	_fps_label.position = Vector2(12, 8)
	_fps_label.add_theme_font_size_override("font_size", 18)
	_fps_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_fps_label.add_theme_constant_override("outline_size", 4)
	add_child(_fps_label)


func _title(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 30)
	return l


func _section(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 18)
	l.modulate = Color(1.0, 0.75, 0.4)
	return l


func _menu_button(parent: Container, text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 44)
	b.pressed.connect(action)
	parent.add_child(b)
	return b


func _add_row(key: String, label_text: String) -> void:
	var hb := HBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(250, 0)
	hb.add_child(label)
	var button := Button.new()
	button.custom_minimum_size = Vector2(300, 0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(button)
	_options_box.add_child(hb)
	var row := {"button": button, "key": key}
	_rows.append(row)
	button.pressed.connect(func() -> void: _cycle(key, 1))
	button.gui_input.connect(func(ev: InputEvent) -> void:
		if ev.is_action_pressed("ui_left"):
			_cycle(key, -1)
			button.accept_event()
		elif ev.is_action_pressed("ui_right"):
			_cycle(key, 1)
			button.accept_event())


# --- Valores -------------------------------------------------------------------

static func _step(options: Array, current: Variant, dir: int) -> Variant:
	var i := options.find(current)
	if i < 0:
		i = 0
	return options[wrapi(i + dir, 0, options.size())]


## Índice do valor mais próximo (para floats salvos que não estão exatamente na lista).
static func _nearest(options: Array, value: float) -> float:
	var best: float = options[0]
	for o in options:
		if absf(float(o) - value) < absf(best - value):
			best = o
	return best


func _cycle(key: String, dir: int) -> void:
	var s := Settings
	match key:
		"window_mode":
			s.window_mode = wrapi(s.window_mode + dir, 0, s.WINDOW_MODES.size())
		"resolution":
			s.resolution = _step(s.RESOLUTIONS, s.resolution, dir)
		"render_scale":
			s.render_scale = _step(s.RENDER_SCALES, _nearest(s.RENDER_SCALES, s.render_scale), dir)
		"vsync":
			s.vsync = not s.vsync
		"max_fps":
			s.max_fps = _step(s.FPS_LIMITS, s.max_fps, dir)
		"msaa":
			s.msaa = wrapi(s.msaa + dir, 0, s.MSAA_LEVELS.size())
		"show_fps":
			s.show_fps = not s.show_fps
		"master_volume":
			s.master_volume = clampf(snappedf(s.master_volume + 0.1 * dir, 0.1), 0.0, 1.0)
		"camera_sensitivity":
			s.camera_sensitivity = clampf(snappedf(s.camera_sensitivity + 0.1 * dir, 0.1), 0.2, 3.0)
		"invert_y":
			s.invert_y = not s.invert_y
		"screen_shake":
			s.screen_shake = not s.screen_shake
		"vibration":
			s.vibration = not s.vibration
		"debug_hitboxes":
			s.debug_hitboxes = not s.debug_hitboxes
	s.commit()
	_refresh()


func _value_text(key: String) -> String:
	var s := Settings
	match key:
		"window_mode":
			return s.WINDOW_MODES[s.window_mode]
		"resolution":
			return "%d × %d" % [s.resolution.x, s.resolution.y]
		"render_scale":
			return "%d%%" % roundi(s.render_scale * 100.0)
		"vsync":
			return _on_off(s.vsync)
		"max_fps":
			return "Sem limite" if s.max_fps == 0 else str(s.max_fps)
		"msaa":
			return s.MSAA_LEVELS[s.msaa]
		"show_fps":
			return _on_off(s.show_fps)
		"master_volume":
			return "%d%%" % roundi(s.master_volume * 100.0)
		"camera_sensitivity":
			return "%.1f×" % s.camera_sensitivity
		"invert_y":
			return _on_off(s.invert_y)
		"screen_shake":
			return _on_off(s.screen_shake)
		"vibration":
			return _on_off(s.vibration)
		"debug_hitboxes":
			return _on_off(s.debug_hitboxes)
	return ""


static func _on_off(v: bool) -> String:
	return "Ligado" if v else "Desligado"


func _refresh() -> void:
	for row in _rows:
		var b: Button = row["button"]
		b.text = "‹  %s  ›" % _value_text(row["key"])
		# Resolução só vale em janela; em tela cheia usa a do monitor.
		if row["key"] == "resolution":
			b.disabled = Settings.window_mode != 0


func _update_hint() -> void:
	var g := InputGlyphs
	var confirm := g.label(&"jump") if g.is_gamepad() else "Enter"
	if _page == PAGE_OPTIONS:
		_hint.text = "↑/↓ escolher   ←/→ ou %s trocar   %s voltar" % [confirm, g.label(&"pause")]
	else:
		_hint.text = "↑/↓ escolher   %s confirmar   %s continuar" % [confirm, g.label(&"pause")]


func _on_settings_changed() -> void:
	_fps_label.visible = Settings.show_fps
