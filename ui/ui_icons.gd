class_name UiIcons
extends RefCounted
## Ícones vetoriais desenhados em código (sem imagens): cabeças dos summons, skills, coração e chama.
## Todos desenham em `c` (centro) com meia-largura `r`, num CanvasItem em _draw().

const SKILL_COLORS := {
	&"quake": Color(0.95, 0.6, 0.25), &"taunt": Color(0.95, 0.4, 0.3), &"punches": Color(0.95, 0.5, 0.3),
	&"rock": Color(0.75, 0.65, 0.5), &"grab": Color(0.9, 0.7, 0.35),
	&"heal": Color(0.4, 0.95, 0.5), &"renew": Color(0.5, 0.9, 0.7), &"ward": Color(0.45, 0.75, 1.0),
	&"bless": Color(1.0, 0.85, 0.35), &"haste": Color(0.5, 0.95, 0.95), &"hex": Color(0.75, 0.45, 0.95),
	&"slow": Color(0.6, 0.6, 1.0), &"smite": Color(1.0, 0.95, 0.5), &"nova": Color(1.0, 0.9, 0.6),
	&"banish": Color(0.45, 0.95, 0.6), &"blast": Color(1.0, 0.55, 0.2), &"frostnova": Color(0.55, 0.85, 1.0), &"storm": Color(0.8, 0.8, 1.0), &"meteor": Color(1.0, 0.45, 0.15),
}


static func _p(c: Vector2, r: float, pts: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(c + (p as Vector2) * r)
	return out


static func sector(ci: CanvasItem, c: Vector2, r: float, frac: float, col: Color) -> void:
	## Fatia (sentido horário a partir do topo) cobrindo `frac` do círculo.
	if frac <= 0.0:
		return
	var pts := PackedVector2Array([c])
	var n := maxi(3, int(48 * frac))
	for i in n + 1:
		var a := -PI * 0.5 + TAU * frac * float(i) / float(n)
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	ci.draw_colored_polygon(pts, col)


static func heart(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 40:
		var t := TAU * float(i) / 40.0
		var x := 16.0 * pow(sin(t), 3.0)
		var y := -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))
		pts.append(c + Vector2(x, y) / 17.0 * r)
	ci.draw_colored_polygon(pts, col)


static func flame(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	ci.draw_colored_polygon(_p(c, r, [Vector2(0, -1), Vector2(0.55, -0.35), Vector2(0.7, 0.3), Vector2(0.35, 0.9), Vector2(-0.35, 0.9),
		Vector2(-0.7, 0.3), Vector2(-0.45, -0.2), Vector2(-0.15, -0.05)]), col)
	ci.draw_colored_polygon(_p(c, r, [Vector2(0.05, 0.1), Vector2(0.35, 0.5), Vector2(0.15, 0.85), Vector2(-0.2, 0.8), Vector2(-0.3, 0.45)]), col.lightened(0.5))


## Retrato do summon: golem (cabeça de pedra com runas) ou sacerdote (capuz com cruz).
static func kind(ci: CanvasItem, k: StringName, c: Vector2, r: float, col: Color) -> void:
	var dark := Color(0.08, 0.08, 0.1)
	if k == &"mage":
		ci.draw_colored_polygon(_p(c, r, [Vector2(0, -1.05), Vector2(0.35, -0.3), Vector2(0.95, -0.15), Vector2(-0.95, -0.15), Vector2(-0.35, -0.3)]), col.darkened(0.2))
		ci.draw_circle(c + Vector2(0, 0.35) * r, r * 0.5, Color(0.92, 0.78, 0.65))
		ci.draw_rect(Rect2(c + Vector2(-0.5, -0.15) * r, Vector2(1.0, 0.16) * r), col)
		for ex in [-0.18, 0.18]:
			ci.draw_circle(c + Vector2(ex, 0.3) * r, r * 0.07, dark)
		ci.draw_colored_polygon(_p(c, r, [Vector2(-0.4, 0.55), Vector2(0.4, 0.55), Vector2(0.0, 1.0)]), Color(0.9, 0.9, 0.95))
	elif k == &"priest":
		ci.draw_colored_polygon(_p(c, r, [Vector2(0, -1), Vector2(0.75, -0.3), Vector2(0.85, 0.9), Vector2(-0.85, 0.9), Vector2(-0.75, -0.3)]), col.darkened(0.15))
		ci.draw_colored_polygon(_p(c, r, [Vector2(0, -0.55), Vector2(0.42, -0.1), Vector2(0.4, 0.55), Vector2(-0.4, 0.55), Vector2(-0.42, -0.1)]), dark)
		ci.draw_rect(Rect2(c + Vector2(-0.05, -0.35) * r, Vector2(0.1, 0.55) * r), col.lightened(0.3))
		ci.draw_rect(Rect2(c + Vector2(-0.22, -0.18) * r, Vector2(0.44, 0.1) * r), col.lightened(0.3))
	else:
		ci.draw_rect(Rect2(c + Vector2(-0.8, -0.8) * r, Vector2(1.6, 1.6) * r), col.darkened(0.25))
		ci.draw_rect(Rect2(c + Vector2(-0.8, -0.8) * r, Vector2(1.6, 0.3) * r), col)
		ci.draw_rect(Rect2(c + Vector2(-0.5, 0.35) * r, Vector2(1.0, 0.35) * r), col)
		for ex in [-0.38, 0.38]:
			ci.draw_rect(Rect2(c + Vector2(ex - 0.16, -0.25) * r, Vector2(0.32, 0.2) * r), Color(0.4, 0.95, 1.0))
		ci.draw_rect(Rect2(c + Vector2(-0.08, 0.05) * r, Vector2(0.16, 0.25) * r), dark)


## Ícone da skill `id` (silhueta cheia com detalhes).
static func skill(ci: CanvasItem, id: StringName, c: Vector2, r: float, col: Color) -> void:
	var w := maxf(2.0, r * 0.14)
	var hi := col.lightened(0.45)
	match id:
		&"quake":
			ci.draw_line(c + Vector2(-1, 0.55) * r, c + Vector2(1, 0.55) * r, col, w * 1.6)
			ci.draw_polyline(_p(c, r, [Vector2(-0.1, -0.9), Vector2(0.2, -0.4), Vector2(-0.15, -0.05), Vector2(0.2, 0.55)]), hi, w)
			ci.draw_arc(c + Vector2(0, 0.55) * r, r * 0.8, PI * 1.1, PI * 1.9, 16, col, w)
		&"taunt":
			ci.draw_rect(Rect2(c + Vector2(-0.13, -0.85) * r, Vector2(0.26, 1.05) * r), col)
			ci.draw_circle(c + Vector2(0, 0.62) * r, r * 0.16, col)
			ci.draw_arc(c, r * 0.8, -PI * 0.25, PI * 0.25, 10, hi, w)
			ci.draw_arc(c, r * 0.8, PI * 0.75, PI * 1.25, 10, hi, w)
		&"punches":
			ci.draw_colored_polygon(_p(c, r, [Vector2(-0.6, -0.15), Vector2(0.6, -0.15), Vector2(0.6, 0.55), Vector2(0.3, 0.85), Vector2(-0.45, 0.85), Vector2(-0.6, 0.55)]), col)
			for i in 4:
				ci.draw_circle(c + Vector2(-0.45 + i * 0.3, -0.2) * r, r * 0.17, hi)
			ci.draw_line(c + Vector2(-0.2, 0.2) * r, c + Vector2(0.4, 0.2) * r, hi.darkened(0.4), w * 0.7)
			ci.draw_line(c + Vector2(-1.0, -0.5) * r, c + Vector2(-0.75, -0.5) * r, hi, w)
			ci.draw_line(c + Vector2(-1.0, 0.0) * r, c + Vector2(-0.75, 0.0) * r, hi, w)
		&"rock":
			ci.draw_colored_polygon(_p(c, r, [Vector2(-0.8, 0.5), Vector2(-0.6, -0.3), Vector2(-0.1, -0.8), Vector2(0.5, -0.5), Vector2(0.85, 0.1), Vector2(0.6, 0.65), Vector2(-0.1, 0.8)]), col)
			ci.draw_polyline(_p(c, r, [Vector2(-0.4, -0.2), Vector2(0.0, -0.45), Vector2(0.4, -0.2)]), hi, w)
		&"grab":
			ci.draw_circle(c + Vector2(0, 0.35) * r, r * 0.5, col)
			for i in 4:
				var x := -0.42 + i * 0.28
				ci.draw_polyline(_p(c, r, [Vector2(x, 0.1), Vector2(x, -0.65), Vector2(x + 0.1, -0.85)]), hi, w * 1.5)
			ci.draw_line(c + Vector2(0.5, 0.35) * r, c + Vector2(0.85, 0.05) * r, hi, w * 1.5)
		&"heal":
			ci.draw_rect(Rect2(c + Vector2(-0.22, -0.8) * r, Vector2(0.44, 1.6) * r), col)
			ci.draw_rect(Rect2(c + Vector2(-0.8, -0.22) * r, Vector2(1.6, 0.44) * r), col)
			ci.draw_circle(c + Vector2(0.65, -0.65) * r, r * 0.1, hi)
		&"renew":
			ci.draw_arc(c, r * 0.72, -PI * 0.3, PI * 1.3, 24, col, w * 1.4)
			ci.draw_colored_polygon(_p(c, r, [Vector2(0.62, -0.5), Vector2(0.95, -0.05), Vector2(0.3, -0.1)]), col)
			ci.draw_rect(Rect2(c + Vector2(-0.08, -0.3) * r, Vector2(0.16, 0.6) * r), hi)
			ci.draw_rect(Rect2(c + Vector2(-0.3, -0.08) * r, Vector2(0.6, 0.16) * r), hi)
		&"ward":
			ci.draw_colored_polygon(_p(c, r, [Vector2(-0.75, -0.75), Vector2(0.75, -0.75), Vector2(0.75, 0.05), Vector2(0, 0.95), Vector2(-0.75, 0.05)]), col)
			ci.draw_polyline(_p(c, r, [Vector2(0, -0.6), Vector2(0, 0.6)]), hi, w)
			ci.draw_polyline(_p(c, r, [Vector2(-0.5, -0.1), Vector2(0.5, -0.1)]), hi, w)
		&"bless":
			ci.draw_line(c + Vector2(0, -0.9) * r, c + Vector2(0, 0.45) * r, col, w * 2.0)
			ci.draw_line(c + Vector2(-0.4, 0.45) * r, c + Vector2(0.4, 0.45) * r, col, w * 1.6)
			ci.draw_line(c + Vector2(0, 0.45) * r, c + Vector2(0, 0.95) * r, col.darkened(0.3), w * 1.6)
			ci.draw_colored_polygon(_p(c, r, [Vector2(0.6, -0.95), Vector2(0.68, -0.68), Vector2(0.95, -0.6), Vector2(0.68, -0.52), Vector2(0.6, -0.25), Vector2(0.52, -0.52), Vector2(0.25, -0.6), Vector2(0.52, -0.68)]), hi)
		&"haste":
			ci.draw_polyline(_p(c, r, [Vector2(-0.8, -0.65), Vector2(-0.15, 0.0), Vector2(-0.8, 0.65)]), col, w * 1.8)
			ci.draw_polyline(_p(c, r, [Vector2(-0.05, -0.65), Vector2(0.6, 0.0), Vector2(-0.05, 0.65)]), hi, w * 1.8)
		&"hex":
			ci.draw_circle(c + Vector2(0, -0.15) * r, r * 0.62, col)
			ci.draw_rect(Rect2(c + Vector2(-0.35, 0.3) * r, Vector2(0.7, 0.5) * r), col)
			for ex in [-0.26, 0.26]:
				ci.draw_circle(c + Vector2(ex, -0.15) * r, r * 0.17, Color(0.08, 0.05, 0.12))
			ci.draw_rect(Rect2(c + Vector2(-0.14, 0.45) * r, Vector2(0.28, 0.35) * r), Color(0.08, 0.05, 0.12))
		&"slow":
			ci.draw_colored_polygon(_p(c, r, [Vector2(-0.6, -0.85), Vector2(0.6, -0.85), Vector2(0.0, 0.0)]), col)
			ci.draw_colored_polygon(_p(c, r, [Vector2(-0.6, 0.85), Vector2(0.6, 0.85), Vector2(0.0, 0.0)]), hi)
			ci.draw_line(c + Vector2(-0.75, -0.88) * r, c + Vector2(0.75, -0.88) * r, col, w)
			ci.draw_line(c + Vector2(-0.75, 0.88) * r, c + Vector2(0.75, 0.88) * r, col, w)
		&"smite":
			ci.draw_colored_polygon(_p(c, r, [Vector2(0.25, -1.0), Vector2(-0.55, 0.1), Vector2(-0.05, 0.1), Vector2(-0.3, 1.0), Vector2(0.6, -0.15), Vector2(0.1, -0.15)]), col)
		&"nova":
			var pts: Array = []
			for i in 16:
				var a := TAU * float(i) / 16.0 - PI * 0.5
				pts.append(Vector2(cos(a), sin(a)) * (1.0 if i % 2 == 0 else 0.45))
			ci.draw_colored_polygon(_p(c, r, pts), col)
			ci.draw_circle(c, r * 0.28, hi)
		&"banish":
			ci.draw_arc(c, r * 0.8, 0.0, TAU, 24, col, w * 1.3)
			ci.draw_colored_polygon(_p(c, r, [Vector2(-0.4, 0.7), Vector2(-0.4, -0.2), Vector2(-0.2, -0.65), Vector2(0.2, -0.65), Vector2(0.4, -0.2), Vector2(0.4, 0.7), Vector2(0.2, 0.45), Vector2(0.0, 0.7), Vector2(-0.2, 0.45)]), col.darkened(0.15))
			for ex in [-0.16, 0.16]:
				ci.draw_circle(c + Vector2(ex, -0.25) * r, r * 0.09, Color(0.05, 0.12, 0.08))
		&"blast":
			ci.draw_circle(c + Vector2(0.15, 0.15) * r, r * 0.55, col)
			ci.draw_circle(c + Vector2(0.15, 0.15) * r, r * 0.28, hi)
			ci.draw_line(c + Vector2(-0.9, -0.85) * r, c + Vector2(-0.3, -0.25) * r, hi, w * 1.4)
			ci.draw_line(c + Vector2(-0.9, -0.3) * r, c + Vector2(-0.4, 0.1) * r, col, w)
			ci.draw_line(c + Vector2(-0.5, -0.9) * r, c + Vector2(-0.05, -0.45) * r, col, w)
		&"frostnova":
			for i in 3:
				var a := PI * float(i) / 3.0
				var d := Vector2(cos(a), sin(a)) * r * 0.95
				ci.draw_line(c - d, c + d, col, w * 1.3)
				var e := Vector2(cos(a + PI * 0.5), sin(a + PI * 0.5)) * r * 0.28
				ci.draw_line(c + d * 0.7 - e, c + d * 0.7 + e, hi, w)
				ci.draw_line(c - d * 0.7 - e, c - d * 0.7 + e, hi, w)
			ci.draw_circle(c, r * 0.18, hi)
		&"storm":
			ci.draw_circle(c + Vector2(0, -0.45) * r, r * 0.42, col.darkened(0.3))
			ci.draw_circle(c + Vector2(-0.45, -0.3) * r, r * 0.3, col.darkened(0.3))
			ci.draw_circle(c + Vector2(0.45, -0.3) * r, r * 0.3, col.darkened(0.3))
			ci.draw_colored_polygon(_p(c, r, [Vector2(0.15, -0.3), Vector2(-0.3, 0.3), Vector2(0.0, 0.3), Vector2(-0.2, 0.95), Vector2(0.35, 0.15), Vector2(0.05, 0.15)]), Color(1.0, 0.95, 0.4))
		&"meteor":
			ci.draw_circle(c + Vector2(0.25, 0.2) * r, r * 0.5, col)
			ci.draw_circle(c + Vector2(0.25, 0.2) * r, r * 0.25, hi)
			ci.draw_colored_polygon(_p(c, r, [Vector2(-0.1, -0.1), Vector2(-0.95, -0.85), Vector2(-0.6, -0.95), Vector2(0.1, -0.3)]), col.darkened(0.2))
			ci.draw_colored_polygon(_p(c, r, [Vector2(-0.3, 0.2), Vector2(-1.0, -0.2), Vector2(-0.85, 0.05), Vector2(-0.2, 0.45)]), col.darkened(0.3))
		_:
			ci.draw_arc(c, r * 0.6, 0.0, TAU, 20, col.darkened(0.4), w)


## Retrato do jogador: elmo com viseira e crista.
static func knight(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	var dark := Color(0.06, 0.06, 0.09)
	ci.draw_colored_polygon(_p(c, r, [Vector2(-0.12, -1.0), Vector2(0.12, -1.0), Vector2(0.1, -0.75), Vector2(-0.1, -0.75)]), Color(0.75, 0.15, 0.2))
	ci.draw_colored_polygon(_p(c, r, [Vector2(-0.7, -0.65), Vector2(0, -0.8), Vector2(0.7, -0.65), Vector2(0.75, 0.3), Vector2(0.5, 0.95), Vector2(-0.5, 0.95), Vector2(-0.75, 0.3)]), col)
	ci.draw_rect(Rect2(c + Vector2(-0.58, -0.1) * r, Vector2(1.16, 0.2) * r), dark)
	ci.draw_rect(Rect2(c + Vector2(-0.05, 0.1) * r, Vector2(0.1, 0.65) * r), dark)
	ci.draw_line(c + Vector2(-0.4, -0.5) * r, c + Vector2(-0.1, -0.6) * r, col.lightened(0.5), maxf(2.0, r * 0.1))
