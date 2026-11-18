class_name Spear
extends MoveSet
## Lança — mais alcance que a espada (a ponta varre ~2,3 m) e stun médio (hitstun ~0,55–0,65 s):
## golpes de estocada que mantêm o inimigo a distância e o deixam travado para o próximo.
##
## Neutro:   Y = Estocada | Y→Y = Estocada dupla | Y→Y→Y = Estocada profunda (empurra forte)
## Hold:     Y, segurar Y = Estocada carregada
## Lock-on:  Frente+Y = Investida | Trás+Y = Estocada ascendente (lança o inimigo)
## Ar:       Y = 2 estocadas aéreas | Trás+Y no ar = Mergulho


func _init() -> void:
	display_name = "Lança"
	for id in ["s1", "s2", "s3", "s_charge", "s_lunge", "s_rising", "s_air1", "s_air2", "s_plunge"]:
		add_move(load("res://data/attacks/spear/%s.tres" % id))

	# Arte: Dança da Lança (série de estocadas, a última lança o inimigo).
	art_name = "Dança da Lança"
	art_color = Color(0.7, 0.9, 1.0)
	for id in ["s_art_1", "s_art_2", "s_art_3"]:
		art_sequence.append(load("res://data/attacks/spear/%s.tres" % id))

	start = {"tap": "s1", "tap_fwd": "s_lunge", "tap_back": "s_rising"}
	start_air = {"tap": "s_air1", "tap_fwd": "s_air1", "tap_back": "s_plunge"}

	edges = {
		"s1": {"tap": "s2", "hold": "s_charge"},
		"s2": {"tap": "s3", "hold": "s_charge"},
		"s3": {},
		"s_charge": {},
		"s_lunge": {"tap": "s2", "hold": "s_charge"},
		"s_rising": {"tap": "s_air1", "tap_back": "s_plunge"},
		"s_air1": {"tap": "s_air2", "tap_back": "s_plunge"},
		"s_air2": {"tap_back": "s_plunge"},
	}
