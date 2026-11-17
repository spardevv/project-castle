class_name Hurtbox
extends Area3D

@export var health: Health


func _ready() -> void:
	# Rede de segurança: se a referência não veio da cena, usa o nó "Health" irmão.
	if health == null:
		health = get_parent().get_node_or_null("Health") as Health
	if health == null:
		push_error("Hurtbox sem Health: %s" % get_path())


func receive_hit(hit: HitData) -> bool:
	return health != null and health.take_hit(hit)
