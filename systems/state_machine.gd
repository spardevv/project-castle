class_name StateMachine
extends Node
## Máquina de estados genérica (player e inimigos). O dono chama start(self) no seu _ready.

@export var initial_state: StringName

var current: State
var states: Dictionary = {}
var _actor: Node
var _freeze := 0.0 # hit-stop local: o estado não avança enquanto > 0


func freeze(duration: float) -> void:
	_freeze = maxf(_freeze, duration)


func start(actor: Node) -> void:
	_actor = actor
	for child in get_children():
		if child is State:
			child.actor = actor
			child.machine = self
			states[str(child.name)] = child
	change_to(initial_state)


func change_to(state_name: StringName, msg: Dictionary = {}) -> void:
	var key := str(state_name)
	assert(states.has(key), "Estado inexistente: " + key)
	if current:
		current.exit()
	current = states[key]
	current.enter(msg)


func current_name() -> String:
	return str(current.name) if current else ""


func _physics_process(delta: float) -> void:
	if current == null:
		return
	if _actor.has_method("tick"):
		_actor.tick(delta)
	if _freeze > 0.0:
		_freeze -= delta
		return
	current.physics_update(delta)
