class_name MoveSet
extends RefCounted
## Grafo de combos de uma arma. Cada golpe tem saídas escolhidas por:
##   tipo de input (tap / hold / pause) + direção do analógico (fwd / back, só em lock-on).
## Chaves de aresta: "tap", "tap_fwd", "tap_back", "hold", "pause", "pause_fwd"...

var display_name := ""
## Arte da arma (RT): sequência própria de cada arma e cor do rastro durante ela.
var art_name := "Arte"
var art_sequence: Array[AttackData] = []
var art_color := Color(1.0, 0.55, 0.15)
var moves: Dictionary = {} # id -> AttackData
var start: Dictionary = {} # chave -> id (a partir do neutro, no chão)
var start_air: Dictionary = {} # idem, no ar
var edges: Dictionary = {} # id -> { chave -> id }


func add_move(data: AttackData) -> void:
	moves[data.id] = data


func has_edge(from_id: String, key: String) -> bool:
	return edges.has(from_id) and edges[from_id].has(key)


## Escolhe o próximo golpe. Sem aresta específica, cai no início do moveset.
func resolve(from_id: String, kind: String, dir: String, air: bool) -> AttackData:
	var keys: Array = [kind] if dir == "neutral" else [kind + "_" + dir, kind]
	if from_id != "" and edges.has(from_id):
		for k in keys:
			if edges[from_id].has(k):
				return moves[edges[from_id][k]]
	var table: Dictionary = start_air if air else start
	var tap_keys: Array = ["tap"] if dir == "neutral" else ["tap_" + dir, "tap"]
	for k in tap_keys:
		if table.has(k):
			return moves[table[k]]
	return moves[table["tap"]]
