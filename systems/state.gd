class_name State
extends Node
## Estado base. Preenchido pelo StateMachine em start().

var actor: Node
var machine: StateMachine


func enter(_msg: Dictionary = {}) -> void:
	pass


func exit() -> void:
	pass


func physics_update(_delta: float) -> void:
	pass
