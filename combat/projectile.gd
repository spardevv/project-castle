class_name Projectile
extends Area3D
## Bola de fogo: projétil pequeno que viaja reto e, ao tocar um inimigo ou o cenário
## (ou ao fim do alcance), detona numa Explosion que causa dano em área.

@export var speed := 16.0
@export var lifetime := 1.6
@export var explosion_radius := 2.6
@export var explosion_damage := 18
@export var explosion_color := Color(1.0, 0.5, 0.12)
@export var explosion_launch := 5.0

var direction := Vector3.FORWARD
## Quem disparou (não detona nele nem em aliados).
var source: Node3D

var _exploded := false


func _ready() -> void:
	monitorable = false
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)


func _physics_process(delta: float) -> void:
	if _exploded:
		return
	global_position += direction * speed * delta
	lifetime -= delta
	if lifetime <= 0.0:
		explode()


func _is_friendly(n: Node) -> bool:
	return n == source or n.is_in_group("player") or n.is_in_group("summon")


func _on_body_entered(body: Node3D) -> void:
	if not _is_friendly(body):
		explode()


func _on_area_entered(area: Area3D) -> void:
	var hurtbox := area as Hurtbox
	if hurtbox != null and hurtbox.health != null and not _is_friendly(hurtbox.health.get_parent()):
		explode()


func explode() -> void:
	if _exploded:
		return
	_exploded = true
	var ex := Explosion.new()
	ex.radius = explosion_radius
	ex.damage = explosion_damage
	ex.color = explosion_color
	ex.launch = explosion_launch
	ex.instigator = source
	ex.position = global_position
	# Criar áreas de física durante um callback de colisão não é permitido: adiciona no fim do quadro.
	get_parent().call_deferred("add_child", ex)
	set_deferred("monitoring", false)
	queue_free()
