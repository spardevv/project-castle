class_name Hammer
extends MoveSet
## Martelo — mais pesado e lento que a espada: mais dano, mais knockback e golpes que quebram a
## super armor do inimigo (poise_break / poise_mult). Mesmo esquema de input da espada.
##
## Neutro:   Y = Varrida | Y→Y = Golpe de volta | Y→Y→Y = Esmagamento (derruba)
## Hold:     Y, segurar Y = Esmagamento carregado
## Lock-on:  Frente+Y = Investida | Trás+Y = Uppercut (lança)
## Ar:       Y = 2 pancadas aéreas | Trás+Y no ar = Mergulho esmagador


func _init() -> void:
	display_name = "Martelo"
	for id in ["h1", "h2", "h3", "h_charge", "h_lunge", "h_rising", "h_air1", "h_air2", "h_plunge"]:
		add_move(load("res://data/attacks/hammer/%s.tres" % id))

	start = {"tap": "h1", "tap_fwd": "h_lunge", "tap_back": "h_rising"}
	start_air = {"tap": "h_air1", "tap_fwd": "h_air1", "tap_back": "h_plunge"}

	edges = {
		"h1": {"tap": "h2", "hold": "h_charge"},
		"h2": {"tap": "h3", "hold": "h_charge"},
		"h3": {},
		"h_charge": {},
		"h_lunge": {"tap": "h3", "hold": "h_charge"},
		"h_rising": {"tap": "h_air1", "tap_back": "h_plunge"},
		"h_air1": {"tap": "h_air2", "tap_back": "h_plunge"},
		"h_air2": {"tap_back": "h_plunge"},
	}
