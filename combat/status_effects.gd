class_name StatusEffects
extends Node
## Buffs e debuffs temporários de um personagem (player, inimigo, summon). Um nó filho "StatusEffects"
## é criado sob demanda por StatusEffects.apply(alvo, id).
##
## Multiplicadores consultados por: StatusEffects.mult(alvo, tipo)
##   damage_out: dano que o alvo causa | damage_in: dano que o alvo recebe | speed: velocidade de movimento

signal changed

const DEFS := {
	&"bless": {"name": "Bênção", "duration": 12.0, "color": Color(1.0, 0.85, 0.3), "damage_out": 1.3},
	&"ward": {"name": "Proteção", "duration": 10.0, "color": Color(0.4, 0.75, 1.0), "damage_in": 0.7},
	&"haste": {"name": "Pressa", "duration": 10.0, "color": Color(0.5, 1.0, 0.6), "speed": 1.25},
	&"regen": {"name": "Regeneração", "duration": 8.0, "color": Color(0.5, 1.0, 0.7), "regen": 4.0},
	&"hex": {"name": "Maldição", "duration": 8.0, "color": Color(0.7, 0.3, 0.9), "damage_in": 1.3, "damage_out": 0.8},
	&"slow": {"name": "Lentidão", "duration": 6.0, "color": Color(0.5, 0.6, 1.0), "speed": 0.5},
	# Benção passiva do sacerdote: mais dano e mais armadura por pouco tempo.
	&"blessing": {"name": "Benção", "duration": 5.0, "color": Color(1.0, 0.9, 0.45), "damage_out": 1.25, "damage_in": 0.75},
}

var active: Dictionary = {} # id -> segundos restantes
var _light: OmniLight3D


static func of(node: Node) -> StatusEffects:
	var s := node.get_node_or_null("StatusEffects") as StatusEffects
	if s == null:
		s = StatusEffects.new()
		s.name = "StatusEffects"
		node.add_child(s)
	return s


## Aplica (ou renova) o efeito e mostra o nome flutuando sobre o alvo.
static func apply(node: Node3D, id: StringName, duration := -1.0, quiet := false) -> void:
	if not DEFS.has(id):
		return
	var s := of(node)
	var d: Dictionary = DEFS[id]
	s.active[id] = duration if duration > 0.0 else float(d["duration"])
	if not quiet: # aplicações repetidas (zona arcana) não enchem a tela de texto
		Fx.damage_number(node, node.global_position + Vector3(0, 2.6, 0), 0, d["color"], d["name"])
		Sfx.play(&"debuff" if (id == &"hex" or id == &"slow") else &"buff", node.global_position + Vector3(0, 1.0, 0))
	s._refresh_light()
	s.changed.emit()


static func has(node: Node, id: StringName) -> bool:
	var s := node.get_node_or_null("StatusEffects") as StatusEffects
	return s != null and s.active.has(id)


## Produto dos multiplicadores de `kind` entre os efeitos ativos (1.0 se não houver).
static func mult(node: Node, kind: String) -> float:
	var s := node.get_node_or_null("StatusEffects") as StatusEffects
	if s == null:
		return 1.0
	var m := 1.0
	for id in s.active:
		m *= float(DEFS[id].get(kind, 1.0))
	return m


func _process(delta: float) -> void:
	if active.is_empty():
		return
	var parent := get_parent()
	var expired := false
	for id in active.keys():
		active[id] = float(active[id]) - delta
		if DEFS[id].has("regen") and parent.has_node("Health"):
			(parent.get_node("Health") as Health).heal_over_time(float(DEFS[id]["regen"]) * delta)
		if float(active[id]) <= 0.0:
			active.erase(id)
			expired = true
	if expired:
		_refresh_light()
		changed.emit()


## Luz colorida suave sobre o alvo enquanto houver efeitos (feedback visual).
func _refresh_light() -> void:
	var parent := get_parent() as Node3D
	if parent == null:
		return
	if active.is_empty():
		if _light != null:
			_light.queue_free()
			_light = null
		return
	if _light == null:
		_light = OmniLight3D.new()
		_light.omni_range = 2.8
		_light.light_energy = 0.9
		_light.position = Vector3(0, 1.0, 0)
		parent.add_child(_light)
	var newest: StringName = active.keys()[active.size() - 1]
	_light.light_color = DEFS[newest]["color"]


func _exit_tree() -> void:
	if _light != null and is_instance_valid(_light):
		_light.queue_free()
