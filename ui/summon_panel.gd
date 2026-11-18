class_name SummonPanel
extends Control
## Painel do summon (canto inferior esquerdo): retrato, barra de vida e os 4 ícones de skill
## (LB + botão). Cada summon tem seu próprio visual: cor, retrato e skills.

const SLOT_BUTTONS: Array[StringName] = [&"summon", &"attack", &"secondary", &"jump"]
const THEMES := {
	&"golem": {"name": "Golem de Pedra", "color": Color(0.92, 0.6, 0.28), "bar": Color(0.85, 0.5, 0.22)},
	&"priest": {"name": "Sacerdote", "color": Color(0.98, 0.86, 0.45), "bar": Color(0.45, 0.85, 0.5)},
	&"mage": {"name": "Mago", "color": Color(0.5, 0.75, 1.0), "bar": Color(0.4, 0.55, 0.95)},
}
const SLOT := 64.0
const GAP := 14.0

var player: Player
var _hp := 0.0
var _trail := 0.0
var _pop: Array[float] = [0.0, 0.0, 0.0, 0.0] # brilho ao ficar pronta
var _was_ready: Array[bool] = [true, true, true, true]


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(440, 156)
	size = custom_minimum_size


func _process(delta: float) -> void:
	if player == null:
		return
	if player.has_summon():
		var h := player.summon.health
		var frac := float(h.current) / float(maxi(h.max_health, 1))
		_hp = lerpf(_hp, frac, 1.0 - exp(-14.0 * delta))
		_trail = move_toward(_trail, _hp, delta * 0.25) if _trail > _hp else _hp
		for i in mini(player.summon.skills.size(), 4):
			var ready: bool = player.summon.skills[i]["timer"] <= 0.0
			if ready and not _was_ready[i]:
				_pop[i] = 1.0
			_was_ready[i] = ready
			_pop[i] = maxf(_pop[i] - delta * 2.5, 0.0)
	else:
		_hp = 1.0
		_trail = 1.0
	queue_redraw()


func _draw() -> void:
	if player == null:
		return
	var g := InputGlyphs
	var kind: StringName = GameState.summon_kind
	var th: Dictionary = THEMES.get(kind, THEMES[&"golem"])
	var col: Color = th["color"]
	var active := player.has_summon()
	var font := ThemeDB.fallback_font
	var dim := 1.0 if active else 0.45

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.05, 0.05, 0.08, 0.72)
	bg.set_corner_radius_all(10)
	bg.border_color = col * Color(1, 1, 1, 0.55 * dim + 0.2)
	bg.set_border_width_all(2)
	draw_style_box(bg, Rect2(Vector2.ZERO, size))

	# Retrato
	var pc := Vector2(52, 50)
	draw_circle(pc, 38.0, Color(0.1, 0.1, 0.14))
	UiIcons.kind(self, kind, pc, 26.0, col * Color(1, 1, 1, dim))
	draw_arc(pc, 38.0, 0.0, TAU, 40, col * Color(1, 1, 1, dim), 3.0)
	if not active:
		var cd := player.summon_cooldown()
		if cd > 0.0:
			UiIcons.sector(self, pc, 38.0, clampf(cd / Player.SUMMON_COOLDOWN, 0.0, 1.0), Color(0, 0, 0, 0.6))

	# Nome + barra de vida
	draw_string(font, Vector2(104, 26), th["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, col * Color(1, 1, 1, dim + 0.2))
	var bar := Rect2(104, 34, 322, 18)
	draw_rect(bar, Color(0.12, 0.12, 0.16))
	if active:
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * _trail, bar.size.y)), Color(1, 1, 1, 0.55))
		var fcol: Color = th["bar"] if _hp > 0.3 else Color(0.9, 0.2, 0.2)
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * _hp, bar.size.y)), fcol)
		var h := player.summon.health
		draw_string(font, bar.position + Vector2(0, 14), "%d / %d" % [h.current, h.max_health], HORIZONTAL_ALIGNMENT_CENTER, bar.size.x, 13, Color.WHITE)
	else:
		var cd2 := player.summon_cooldown()
		var msg := "[%s] Invocar" % g.label(&"summon") if cd2 <= 0.0 else "Recarga %.0fs" % ceilf(cd2)
		draw_string(font, bar.position + Vector2(0, 14), msg, HORIZONTAL_ALIGNMENT_CENTER, bar.size.x, 13, Color(1, 1, 1, 0.7))
	draw_rect(bar, col * Color(1, 1, 1, 0.6 * dim), false, 1.5)

	# Skills (LB + botão)
	draw_string(font, Vector2(14, 118), "%s +" % g.label(&"summon_mod"), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.65))
	var ids: Array = GameState.summon_slots
	for i in 4:
		var id: StringName = ids[i] if i < ids.size() else &""
		var p := Vector2(104 + i * (SLOT + GAP), 60)
		var c := p + Vector2(SLOT, SLOT) * 0.5
		var slot_bg := StyleBoxFlat.new()
		slot_bg.bg_color = Color(0.1, 0.1, 0.14, 0.9)
		slot_bg.set_corner_radius_all(8)
		var ready := true
		var timer := 0.0
		var total := 1.0
		if active and i < player.summon.skills.size():
			timer = player.summon.skills[i]["timer"]
			total = maxf(player.summon.skills[i]["cooldown"], 0.01)
			ready = timer <= 0.0
		var accent: Color = UiIcons.SKILL_COLORS.get(id, col)
		slot_bg.border_color = accent * Color(1, 1, 1, 0.9 if (ready and active) else 0.35)
		slot_bg.set_border_width_all(2)
		draw_style_box(slot_bg, Rect2(p, Vector2(SLOT, SLOT)))
		if id == &"":
			draw_string(font, c + Vector2(-12, 8), "—", HORIZONTAL_ALIGNMENT_CENTER, 24, 22, Color(1, 1, 1, 0.25))
		else:
			UiIcons.skill(self, id, c, SLOT * 0.33, accent * Color(1, 1, 1, 1.0 if (ready and active) else 0.4))
			if active and not ready:
				UiIcons.sector(self, c, SLOT * 0.62, clampf(timer / total, 0.0, 1.0), Color(0, 0, 0, 0.62))
				draw_string(font, c + Vector2(-SLOT * 0.5, 7), "%.1f" % timer if timer < 10.0 else "%d" % ceili(timer), HORIZONTAL_ALIGNMENT_CENTER, SLOT, 18, Color.WHITE)
			elif active and _pop[i] > 0.0:
				draw_rect(Rect2(p, Vector2(SLOT, SLOT)), Color(1, 1, 1, 0.35 * _pop[i]))
		# Botão do slot
		var key := _short(g.label(SLOT_BUTTONS[i]))
		var tw := maxf(26.0, font.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 14.0)
		var tag := Rect2(p + Vector2(SLOT * 0.5 - tw * 0.5, SLOT + 4), Vector2(tw, 20))
		draw_style_box(_tag_box(), tag)
		draw_string(font, tag.position + Vector2(0, 15), key, HORIZONTAL_ALIGNMENT_CENTER, tag.size.x, 13, Color.WHITE)


static func _short(label: String) -> String:
	return label.replace("Mouse Esq.", "M1").replace("Mouse Dir.", "M2").replace("Space", "Spc")


func _tag_box() -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = Color(0.2, 0.2, 0.26)
	b.set_corner_radius_all(10)
	return b
