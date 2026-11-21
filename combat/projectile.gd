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
@export var explosion_hitstun := 0.6
@export var explosion_poise_break := false
@export var explosion_knockback := 7.0

## Alvo a perseguir (lock-on): a bola curva em direção a ele até `turn_rate` rad/s. Null = voo reto.
var homing_target: Node3D
@export var turn_rate := 7.0

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
	_steer(delta)
	global_position += direction * speed * delta
	lifetime -= delta
	if lifetime <= 0.0:
		explode()


## Gira a direção na do alvo (peito do inimigo), com limite de giro para a curva ser visível e não instantânea.
func _steer(delta: float) -> void:
	if homing_target == null:
		return
	if not is_instance_valid(homing_target) or (homing_target is Enemy and (homing_target as Enemy).health.current <= 0):
		homing_target = null
		return
	var want := (homing_target.global_position + Vector3(0, 1.0, 0) - global_position).normalized()
	var angle := direction.angle_to(want)
	if angle < 0.001:
		return
	var axis := direction.cross(want)
	if axis.length_squared() < 0.000001:
		return
	direction = direction.rotated(axis.normalized(), minf(angle, turn_rate * delta)).normalized()


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
	ex.hitstun = explosion_hitstun
	ex.poise_break = explosion_poise_break
	ex.knockback = explosion_knockback
	ex.instigator = source
	ex.position = global_position
	# Criar áreas de física durante um callback de colisão não é permitido: adiciona no fim do quadro.
	get_parent().call_deferred("add_child", ex)
	set_deferred("monitoring", false)
	queue_free()
