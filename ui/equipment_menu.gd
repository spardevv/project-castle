extends CanvasLayer
## Menu de equipamento (Tab, ou Start → Equipamento no menu de pausa): pausa o jogo e permite trocar o equipamento secundário
## e a skill de cada slot do summon. Navegação: ↑/↓ escolhe a linha, ←/→ ou A/Enter troca o valor,
## B/Esc ou Tab/Start fecha. As mudanças vão para o GameState na hora (o jogo aplica pelo sinal).

const SLOT_BUTTONS: Array[StringName] = [&"summon", &"attack", &"secondary", &"jump"]

var _rows: Array[Dictionary] = [] # {"button": Button, "kind": "secondary"|"slot", "index": int, "label": Label}
var _desc: Label
var _hint: Label
var _close: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	_build()
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("menu"):
		toggle()
		get_viewport().set_input_as_handled()
	elif visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func open() -> void:
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh()
	(_rows[0]["button"] as Button).grab_focus()


func close() -> void:
	visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 0)
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	panel.add_child(margin)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	margin.add_child(vb)

	var title := Label.new()
	title.text = "Equipamento"
	title.add_theme_font_size_override("font_size", 28)
	vb.add_child(title)

	vb.add_child(_section("Armas"))
	_add_row(vb, "primary", 0, "Arma")
	_add_row(vb, "secondary", 0, "Secundário")

	vb.add_child(_section("Summon"))
	_add_row(vb, "summon", 0, "Summon ativo")
	vb.add_child(_section("Skills do summon (LB + botão)"))
	for i in 4:
		_add_row(vb, "slot", i, "")

	vb.add_child(_section("Skills passivas (o summon usa sozinho)"))
	for i in GameState.summon_passives.size():
		_add_row(vb, "passive", i, "Passiva %d" % (i + 1))

	_desc = Label.new()
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.custom_minimum_size = Vector2(0, 48)
	_desc.modulate = Color(0.85, 0.85, 0.9)
	vb.add_child(_desc)

	_close = Button.new()
	_close.text = "Fechar"
	_close.pressed.connect(close)
	vb.add_child(_close)

	_hint = Label.new()
	_hint.modulate = Color(0.7, 0.7, 0.75)
	vb.add_child(_hint)


func _section(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 18)
	l.modulate = Color(1.0, 0.75, 0.4)
	return l


func _add_row(parent: Container, kind: String, index: int, label_text: String) -> void:
	var hb := HBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(180, 0)
	hb.add_child(label)
	var button := Button.new()
	button.custom_minimum_size = Vector2(300, 0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(button)
	parent.add_child(hb)
	var row := {"button": button, "kind": kind, "index": index, "label": label}
	_rows.append(row)
	button.pressed.connect(func() -> void: _cycle(row, 1))
	button.focus_entered.connect(func() -> void: _update_desc(row))
	button.gui_input.connect(func(ev: InputEvent) -> void:
		if ev.is_action_pressed("ui_left"):
			_cycle(row, -1)
			button.accept_event()
		elif ev.is_action_pressed("ui_right"):
			_cycle(row, 1)
			button.accept_event())


func _cycle(row: Dictionary, dir: int) -> void:
	match row["kind"]:
		"primary":
			var options := GameState.PRIMARIES
			GameState.set_primary(options[wrapi(options.find(GameState.primary) + dir, 0, options.size())])
		"secondary":
			var options := GameState.SECONDARIES
			GameState.set_secondary(options[wrapi(options.find(GameState.secondary) + dir, 0, options.size())])
		"summon":
			var options := GameState.SUMMON_KINDS
			GameState.set_summon_kind(options[wrapi(options.find(GameState.summon_kind) + dir, 0, options.size())])
		"passive":
			var choices := SummonSkills.passive_choices_for(GameState.summon_kind)
			var slot: int = row["index"]
			var i := choices.find(GameState.summon_passives[slot])
			GameState.set_summon_passive(slot, choices[wrapi(i + dir, 0, choices.size())])
		_:
			var choices := SummonSkills.choices_for(GameState.summon_kind)
			var slot: int = row["index"]
			var i := choices.find(GameState.summon_slots[slot])
			GameState.set_summon_slot(slot, choices[wrapi(i + dir, 0, choices.size())])
	_refresh()
	_update_desc(row)


func _refresh() -> void:
	var g := InputGlyphs
	for row in _rows:
		var b: Button = row["button"]
		if row["kind"] == "primary":
			b.text = "‹  %s  ›" % GameState.PRIMARY_NAMES[GameState.primary]
		elif row["kind"] == "secondary":
			b.text = "‹  %s  ›" % GameState.SECONDARY_NAMES[GameState.secondary]
		elif row["kind"] == "summon":
			b.text = "‹  %s  ›" % GameState.SUMMON_NAMES[GameState.summon_kind]
		elif row["kind"] == "passive":
			b.text = "‹  %s  ›" % SummonSkills.passive_name(GameState.summon_passives[row["index"]])
		else:
			var slot: int = row["index"]
			(row["label"] as Label).text = "%s + %s" % [g.label(&"summon_mod"), g.label(SLOT_BUTTONS[slot])]
			b.text = "‹  %s  ›" % SummonSkills.name_of(GameState.summon_slots[slot])
	_hint.text = "↑/↓ escolher   ←/→ ou %s trocar   %s fechar" % [g.label(&"jump") if g.is_gamepad() else "Enter", g.label(&"menu") if not g.is_gamepad() else g.label(&"pause")]


func _update_desc(row: Dictionary) -> void:
	if row["kind"] == "primary":
		_desc.text = "Espada longa: rápida, combos fluidos.\nMartelo: pesado e lento, muito mais dano e golpes que quebram a defesa do inimigo (derruba).\nLança: alcance bem maior e stun médio; estocadas que mantêm o inimigo a distância."
	elif row["kind"] == "secondary":
		_desc.text = "Orbe de fogo: %s conjura uma bola de fogo que explode em área.\nEscudo: reduz 75%% de todo o dano e aumenta muito o stance (não cambaleia fácil); LT bloqueia/parry, %s é uma investida.\nBesta automática: segure %s para disparar virotes em sequência, sem parar de andar ou correr." % [
			InputGlyphs.label(&"secondary"), InputGlyphs.label(&"secondary"), InputGlyphs.label(&"secondary")]
	elif row["kind"] == "summon":
		_desc.text = "Golem de Pedra: combate corpo a corpo, provoca e agarra.\nSacerdote: fica atrás de você curando, dando buffs, aplicando debuffs e com poucas skills de dano. \nMago: fica no seu flanco lançando magias de dano em área (bola de fogo, gelo, raios, meteoros). Troque e invoque de novo com %s." % InputGlyphs.label(&"summon")
	elif row["kind"] == "passive":
		_desc.text = SummonSkills.passive_desc(GameState.summon_passives[row["index"]])
	else:
		_desc.text = SummonSkills.desc_of(GameState.summon_slots[row["index"]])
