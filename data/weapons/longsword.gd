class_name LongSword
extends MoveSet
## Espada longa — moveset inicial.
##
## Neutro:   Y = A1 | Y→Y = A2 | Y→Y→Y = A3 (corte cruzado)
## Hold:     Y, segurar Y = Overhead (golpe carregado)
## Pausa:    Y→Y, esperar, Y = Giro
## Lock-on:  Frente+Y = Estocada | Trás+Y = Corte ascendente (lança o inimigo)
## Ar:       Y = 2 cortes aéreos | Trás+Y no ar = Mergulho


func _init() -> void:
	display_name = "Espada longa"
	for id in ["a1", "a2", "a3", "spin", "overhead", "stinger", "rising", "air1", "air2", "plunge"]:
		add_move(load("res://data/attacks/longsword/%s.tres" % id))

	start = {"tap": "a1", "tap_fwd": "stinger", "tap_back": "rising"}
	start_air = {"tap": "air1", "tap_fwd": "air1", "tap_back": "plunge"}

	edges = {
		"a1": {"tap": "a2", "hold": "overhead"},
		"a2": {"tap": "a3", "hold": "overhead", "pause": "spin"},
		"a3": {},
		"stinger": {"tap": "a2", "hold": "overhead"},
		"rising": {"tap": "air1", "tap_back": "plunge"},
		"air1": {"tap": "air2", "tap_back": "plunge"},
		"air2": {"tap_back": "plunge"},
	}
