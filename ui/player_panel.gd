class_name PlayerPanel
extends Control
## Painel do jogador (canto superior esquerdo): retrato, barra de vida, medidor da arte da arma
## (2 usos), estâncias do ataque carregado e os buffs/debuffs ativos como ícones com tempo.

const HP_COLOR := Color(0.85, 0.2, 0.25)
const ART_COLOR := Color(1.0, 0.55, 0.15)
const ART_READY_COLOR := Color(1.0, 0.88, 0.35)
const FX_ICON := {&"bless": &"bless", &"ward": &"ward", &"haste": &"haste", &"regen": &"renew", &"hex": &"hex", &"slow": &"slow"}

var player: Player
var _hp := 1.0
var _trail := 1.0
var _flash := 0.0 # brilho no último ponto de vida ao curar/levar dano
var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(420, 124)


func _process(delta: float) -> void:
	if player == null:
		return
	_t += delta
	var h := player.health
	var frac := float(h.current) / float(maxi(h.max_health, 1))
	if frac < _hp - 0.001:
		_flash = 1.0
	_hp = lerpf(_hp, frac, 1.0 - exp(-16.0 * delta))
	_trail = move_toward(_trail, _hp, delta * 0.3) if _trail > _hp else _hp
	_flash = maxf(_flash - delta * 3.0, 0.0)
	queue_redraw()


func _draw() -> void:
	if player == null:
		return
	var g := InputGlyphs
	var font := ThemeDB.fallback_font
	var h := player.health
	var low := _hp < 0.3

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.05, 0.05, 0.08, 0.72)
	bg.set_corner_radius_all(10)
	bg.border_color = Color(0.8, 0.75, 0.65, 0.5)
	bg.set_border_width_all(2)
	draw_style_box(bg, Rect2(Vector2.ZERO, size))

	# Retrato
	var pc := Vector2(52, 52)
	draw_circle(pc, 36.0, Color(0.1, 0.1, 0.14))
	UiIcons.knight(self, pc, 24.0, Color(0.72, 0.74, 0.8))
	var ring := HP_COLOR.lerp(Color.WHITE, _flash * 0.6) if low or _flash > 0.0 else Color(0.8, 0.75, 0.65)
	draw_arc(pc, 36.0, 0.0, TAU, 40, ring, 3.0)

	# Vida
	UiIcons.heart(self, Vector2(112, 31), 8.0, HP_COLOR)
	var bar := Rect2(128, 20, 276, 22)
	draw_rect(bar, Color(0.12, 0.12, 0.16))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * _trail, bar.size.y)), Color(1, 1, 1, 0.55))
	var pulse := 0.5 + 0.5 * sin(_t * 8.0) if low else 0.0
	var fcol := HP_COLOR.lerp(Color(1, 0.5, 0.5), pulse * 0.6).lerp(Color.WHITE, _flash * 0.5)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * _hp, bar.size.y)), fcol)
	for i in range(1, 4): # marcas de 25%
		var x := bar.position.x + bar.size.x * i / 4.0
		draw_line(Vector2(x, bar.position.y + 15), Vector2(x, bar.end.y), Color(0, 0, 0, 0.35), 1.0)
	draw_string(font, bar.position + Vector2(0, 16), "%d / %d" % [h.current, h.max_health], HORIZONTAL_ALIGNMENT_CENTER, bar.size.x, 14, Color.WHITE)
	draw_rect(bar, Color(0.8, 0.75, 0.65, 0.6), false, 1.5)

	# Arte da arma: 2 segmentos de ART_COST
	UiIcons.flame(self, Vector2(112, 62), 8.0, ART_COLOR if not player.can_art() else ART_READY_COLOR)
	for i in 2:
		var seg := Rect2(128 + i * 140, 54, 136, 14)
		var v := clampf(player.art_meter - i * Player.ART_COST, 0.0, Player.ART_COST) / Player.ART_COST
		draw_rect(seg, Color(0.12, 0.12, 0.16))
		var ready := v >= 1.0
		draw_rect(Rect2(seg.position, Vector2(seg.size.x * v, seg.size.y)), ART_READY_COLOR.lerp(Color.WHITE, 0.3 * (0.5 + 0.5 * sin(_t * 6.0))) if ready else ART_COLOR)
		draw_rect(seg, Color(0.8, 0.75, 0.65, 0.5), false, 1.0)
	var art_txt := "%s  [%s]" % [player.moveset.art_name, g.label(&"weapon_art")]
	draw_string(font, Vector2(128, 90), art_txt, HORIZONTAL_ALIGNMENT_LEFT, 240, 14, Color(1, 1, 1, 0.85))
	if player.can_art():
		draw_string(font, Vector2(128, 90), "PRONTA", HORIZONTAL_ALIGNMENT_RIGHT, 276, 14, ART_READY_COLOR)

	# Estâncias do ataque carregado (só enquanto carrega)
	if player.charge_progress > 0.0:
		for i in 3:
			var cs := Rect2(128 + i * 94, 100, 90, 9)
			draw_rect(cs, Color(0.12, 0.12, 0.16))
			draw_rect(Rect2(cs.position, Vector2(cs.size.x * clampf(player.charge_progress - i, 0.0, 1.0), cs.size.y)), Player.CHARGE_COLORS[i + 1])
			draw_rect(cs, Color(0.8, 0.75, 0.65, 0.4), false, 1.0)

	# Buffs/debuffs: ícones logo abaixo do painel
	var effects := StatusEffects.of(player).active
	var x := 0.0
	for id in effects:
		var d: Dictionary = StatusEffects.DEFS[id]
		var col: Color = d["color"]
		var left: float = effects[id]
		var p := Vector2(x, size.y + 8)
		var cc := p + Vector2(16, 16)
		var b := StyleBoxFlat.new()
		b.bg_color = Color(0.08, 0.08, 0.12, 0.85)
		b.set_corner_radius_all(6)
		b.border_color = col
		b.set_border_width_all(2)
		draw_style_box(b, Rect2(p, Vector2(32, 32)))
		UiIcons.skill(self, FX_ICON.get(id, id), cc, 10.0, col)
		UiIcons.sector(self, cc, 20.0, clampf(1.0 - left / float(d["duration"]), 0.0, 1.0), Color(0, 0, 0, 0.5))
		draw_string(font, p + Vector2(0, 46), "%ds" % ceili(left), HORIZONTAL_ALIGNMENT_CENTER, 32, 12, Color.WHITE)
		x += 40.0
