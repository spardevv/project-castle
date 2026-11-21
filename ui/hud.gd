extends CanvasLayer

@onready var bar: ProgressBar = $HealthBar
@onready var summon_label: Label = $SummonLabel
@onready var controls_panel: PanelContainer = $ControlsPanel
@onready var controls_text: Label = $ControlsPanel/Margin/ControlsText
@onready var damage_flash: ColorRect = $DamageFlash

var _player: Player
var _flash_tween: Tween
var _summon_panel: SummonPanel
var _player_panel: PlayerPanel


func _ready() -> void:
	summon_label.visible = false
	bar.visible = false
	_player_panel = PlayerPanel.new()
	add_child(_player_panel)
	_player_panel.position = Vector2(24, 24)
	_summon_panel = SummonPanel.new()
	add_child(_summon_panel)
	_summon_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_summon_panel.position = Vector2(24, get_viewport().get_visible_rect().size.y - 156 - 24)
	get_viewport().size_changed.connect(func() -> void:
		_summon_panel.position = Vector2(24, get_viewport().get_visible_rect().size.y - 156 - 24))
	controls_panel.position.y = 220.0
	_player = get_tree().get_first_node_in_group("player") as Player
	if _player != null:
		_player.health.changed.connect(_update)
		_update(_player.health.current, _player.health.max_health)
		_summon_panel.player = _player
		_player_panel.player = _player
	InputGlyphs.device_changed.connect(func(_d: String) -> void: _refresh_controls())
	EventBus.player_damaged.connect(_on_player_damaged)
	GameState.loadout_changed.connect(_refresh_controls)
	_refresh_controls()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_controls"):
		controls_panel.visible = not controls_panel.visible




## Monta a lista de controles a partir do Input Map, no dispositivo em uso.
func _refresh_controls() -> void:
	var g := InputGlyphs
	var secondary_name: String = {&"shield": "investida de escudo", &"crossbow": "besta, segurar"}.get(GameState.secondary, "bola de fogo")
	var guard_name := "Guarda com escudo / parry (segurar)" if GameState.secondary == &"shield" else "Guarda (segurar)"
	var rows: Array = [
		["Mover", g.move_label()],
		["Câmera", g.camera_label()],
		["Pular", g.label(&"jump")],
		["Ataque (combos)", g.label(&"attack")],
		["Secundário (%s)" % secondary_name, g.label(&"secondary")],
		["Arte da arma (gasta 1 barra)", g.label(&"weapon_art")],
		["Esquiva", g.label(&"dodge")],
		[guard_name, g.label(&"guard")],
		["Alternar corrida", g.label(&"run_toggle")],
		["Lock-on / trocar alvo", "%s / %s para os lados" % [g.label(&"lock_on"), g.camera_label()]],
		["Interagir (baús, etc.)", g.label(&"interact")],
		["Summon: invocar/dispensar", g.label(&"summon")],
		["Skills do summon (segurar)", "%s + botão" % g.label(&"summon_mod")],
		["Menu de equipamento", g.label(&"menu") if not g.is_gamepad() else "%s → Equipamento" % g.label(&"pause")],
		["Pausa / opções / reiniciar", g.label(&"pause")],
		["Mostrar/ocultar controles", g.label(&"toggle_controls")],
	]
	var lines: Array[String] = ["— %s —" % g.device_name()]
	for r in rows:
		lines.append("%-30s %s" % [r[0], r[1]])
	lines.append("")
	lines.append("Combos (com lock-on): frente+%s estocada | trás+%s ascendente" % [g.label(&"attack"), g.label(&"attack")])
	lines.append("Segurar %s após o 1º golpe: overhead | pausa no 2º golpe: giro" % g.label(&"attack"))
	controls_text.text = "\n".join(lines)


## Tela pisca em vermelho ao levar dano (mais forte quanto maior o dano).
func _on_player_damaged(amount: int) -> void:
	if amount <= 0:
		return
	if _flash_tween:
		_flash_tween.kill()
	damage_flash.color.a = clampf(0.12 + amount * 0.01, 0.12, 0.35)
	_flash_tween = create_tween()
	_flash_tween.tween_property(damage_flash, "color:a", 0.0, 0.35)


func _update(current: int, maximum: int) -> void:
	bar.max_value = maximum
	bar.value = current
