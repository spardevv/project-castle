class_name Arrow
extends Hitbox
## Flecha dos arqueiros: voa reto, acerta o player ou o summon e some. Bloqueada pela guarda/escudo;
## o parry nega o dano, mas não faz o arqueiro cambalear (golpe à distância).

@export var speed := 24.0
@export var lifetime := 2.5
@export var damage := 8

var direction := Vector3.FORWARD


func _ready() -> void:
	super._ready()
	body_entered.connect(_on_body_entered)
	hit_landed.connect(func(_h: Hurtbox) -> void: queue_free())
	var hit := HitData.new()
	hit.damage = damage
	hit.knockback = 3.0
	hit.hitstun = 0.25
	hit.hitstop = 0.04
	hit.freeze_attacker = false
	activate(hit)


func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()


func _on_body_entered(body: Node3D) -> void:
	# Corpos de personagens são ignorados: quem resolve o acerto é o Hurtbox.
	if body.is_in_group("player") or body.is_in_group("enemy") or body.is_in_group("summon"):
		return
	queue_free()
