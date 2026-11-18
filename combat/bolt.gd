class_name Bolt
extends Hitbox
## Virote da besta do jogador: voa reto e rápido, causa pouco dano e some ao acertar um inimigo
## ou o cenário. O dano é por acerto direto (sem área).

@export var speed := 42.0
@export var lifetime := 0.9
@export var damage := 4

var direction := Vector3.FORWARD
var instigator: Node3D


func _ready() -> void:
	super._ready()
	collision_layer = 1 << 3 # player_hitbox
	collision_mask = (1 << 0) | (1 << 2) # cenário + hurtbox de inimigos
	monitorable = false
	var cs := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.14
	cs.shape = shape
	add_child(cs)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.05, 0.05, 0.5)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.9, 0.5)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.8, 0.3)
	mat.emission_energy_multiplier = 2.0
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	add_child(mi)
	if direction.length() > 0.01:
		look_at(global_position + direction, Vector3.UP)

	source = instigator
	if instigator != null and instigator.has_method("_on_hit_landed"):
		hit_landed.connect(Callable(instigator, "_on_hit_landed"))
	body_entered.connect(_on_body_entered)
	hit_landed.connect(func(_h: Hurtbox) -> void: queue_free())
	var hit := HitData.new()
	hit.damage = damage
	hit.knockback = 1.2
	hit.hitstun = 0.1
	hit.hitstop = 0.0
	hit.poise_mult = 0.35
	hit.freeze_attacker = false
	activate(hit)


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	global_position += direction * speed * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") or body.is_in_group("enemy") or body.is_in_group("summon"):
		return
	queue_free()
