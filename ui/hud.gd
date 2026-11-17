extends CanvasLayer

const ART_COLOR := Color(1.0, 0.55, 0.15)
const ART_READY_COLOR := Color(1.0, 0.85, 0.3)

@onready var bar: ProgressBar = $HealthBar
@onready var summon_label: Label = $SummonLabel
@onready var controls_panel: PanelContainer = $ControlsPanel
@onready var controls_text: Label = $ControlsPanel/Margin/ControlsText
@onready var damage_flash: ColorRect = $DamageFlash

var _player: Player
var _flash_tween: Tween
var _art_bars: Array[ProgressBar] = []
var _art_fills: Array[StyleBoxFlat] = []
var _art_label: Label
var _charge_bars: Array[ProgressBar] = []
var _charge_fills: Array[StyleBoxFlat] = []
var _status_label: Label


func _ready() -> void:
	_build_art_meter()
	_build_charge_meter()
	summon_label.position.y = 78.0
	controls_panel.position.y = 190.0
	_player = get_tree().get_first_node_in_group("player") as Player
	if _player != null:
		_player.health.changed.connect(_update)
		_update(_player.health.current, _player.health.max_health)
	InputGlyphs.device_changed.connect(func(_d: String) -> void: _refresh_controls())
	EventBus.player_damaged.connect(_on_player_damaged)
	GameState.loadout_changed.connect(_refresh_controls)
	_refresh_controls()


## Medidor da arte da arma: 2 segmentos de 50 (cada um = um uso).
func _build_art_meter() -> void:
	for i in 2:
		var pb := ProgressBar.new()
		pb.show_percentage = false
		pb.max_value = Player.ART_COST
		pb.position = Vector2(24 + i * 152, 54)
		pb.size = Vector2(148, 12)
		var fill := StyleBoxFlat.new()
		fill.bg_color = ART_COLOR
		pb.add_theme_stylebox_override("fill", fill)
		add_child(pb)
		_art_bars.append(pb)
		_art_fills.append(fill)
	_art_label = Label.new()
	_art_label.position = Vector2(332, 48)
	add_child(_art_label)
	_status_label = Label.new()
	_status_label.position = Vector2(24, 128)
	add_child(_status_label)


## Estâncias do ataque carregado: 3 segmentos que enchem enquanto o botão é segurado.
func _build_charge_meter() -> void:
	for i in 3:
		var pb := ProgressBar.new()
		pb.show_percentage = false
		pb.max_value = 1.0
		pb.position = Vector2(24 + i * 100, 100)
		pb.size = Vector2(96, 9)
		var fill := StyleBoxFlat.new()
		fill.bg_color = Player.CHARGE_COLORS[i + 1]
		pb.add_theme_stylebox_override("fill", fill)
		pb.visible = false
		add_child(pb)
		_charge_bars.append(pb)
		_charge_fills.append(fill)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_controls"):
		controls_panel.visible = not controls_panel.visible


func _process(_delta: float) -> void:
	if _player == null:
		return
	var g := InputGlyphs
	# Medidor
	for i in 2:
		var v := clampf(_player.art_meter - i * Player.ART_COST, 0.0, Player.ART_COST)
		_art_bars[i].value = v
		_art_fills[i].bg_color = ART_READY_COLOR if v >= Player.ART_COST else ART_COLOR
	_art_label.text = "%s [%s]%s" % [_player.moveset.art_name, g.label(&"weapon_art"), " PRONTA" if _player.can_art() else ""]

	# Estâncias de carga
	for i in 3:
		_charge_bars[i].visible = _player.charge_progress > 0.0
		_charge_bars[i].value = clampf(_player.charge_progress - i, 0.0, 1.0)

	# Buffs e debuffs ativos no player
	var effects := StatusEffects.of(_player).active
	var parts_fx: Array[String] = []
	for id in effects:
		parts_fx.append("%s %.0fs" % [StatusEffects.DEFS[id]["name"], effects[id]])
	_status_label.text = "  ".join(parts_fx)
	_status_label.modulate = StatusEffects.DEFS[effects.keys()[0]]["color"] if not effects.is_empty() else Color.WHITE

	# Summon e seus 4 slots
	if not _player.has_summon():
		var cd := _player.summon_cooldown()
		summon_label.text = "Summon: [%s] invocar%s" % [g.label(&"summon"), "" if cd <= 0.0 else "  (recarga %.0fs)" % ceilf(cd)]
		return
	var s := _player.summon
	var slot_buttons := [&"summon", &"attack", &"secondary", &"jump"]
	var parts: Array[String] = ["Summon HP %d  [%s] dispensar" % [s.health.current, g.label(&"summon")]]
	for i in mini(s.skills.size(), 4):
		var sk: Dictionary = s.skills[i]
		if sk["id"] == &"":
			continue
		var state := "pronta" if sk["timer"] <= 0.0 else "%.1fs" % sk["timer"]
		parts.append("[%s+%s] %s: %s" % [g.label(&"summon_mod"), g.label(slot_buttons[i]), sk["name"], state])
	summon_label.text = "  |  ".join(parts)


## Monta a lista de controles a partir do Input Map, no dispositivo em uso.
func _refresh_controls() -> void:
	var g := InputGlyphs
	var secondary_name := "investida de escudo" if GameState.secondary == &"shield" else "bola de fogo"
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
		["Summon: invocar/dispensar", g.label(&"summon")],
		["Skills do summon (segurar)", "%s + botão" % g.label(&"summon_mod")],
		["Menu de equipamento", g.label(&"menu")],
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
