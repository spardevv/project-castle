class_name Explosion
extends Hitbox
## Esfera de dano em área: expande rápido, acerta cada inimigo dentro do raio uma vez e
## empurra para fora a partir do centro (o knockback usa a posição da própria explosão).
## Criada pelo Projectile; pode ser reutilizada por outras magias/itens.

const ACTIVE_TIME := 0.12
const LIFETIME := 0.6

@export var radius := 2.6
@export var damage := 18
@export var color := Color(1.0, 0.5, 0.12)

## Quem causou a explosão. Não recebe dano; se tiver _on_hit_landed (player), ganha medidor.
var instigator: Node3D
## Falso: acerta inimigos (magia do player/summon). Verdadeiro: acerta player e summon (inimigos).
@export var hits_player := false
@export var knockback := 7.0
@export var launch := 5.0


func _ready() -> void:
	super._ready()
	if hits_player:
		collision_layer = 1 << 4 # enemy_hitbox
		collision_mask = 1 << 1 # hurtbox do player e do summon
	else:
		collision_layer = 1 << 3 # player_hitbox
		collision_mask = 1 << 2 # hurtbox de inimigos
	if instigator != null and instigator.has_method("_on_hit_landed"):
		hit_landed.connect(Callable(instigator, "_on_hit_landed"))
	monitorable = false
	monitoring = false
	var cs := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = radius
	cs.shape = shape
	add_child(cs)

	source = self # knockback radial a partir do centro
	var hit := HitData.new()
	hit.damage = damage
	hit.knockback = knockback
	hit.launch = launch # levanta os alvos: viram juggle e caem derrubados
	hit.hitstun = 0.6
	hit.hitstop = 0.07
	hit.freeze_attacker = false
	activate(hit)
	get_tree().create_timer(ACTIVE_TIME).timeout.connect(deactivate)

	_build_visuals()
	# Explosões maiores soam mais graves e mais altas.
	Sfx.play(&"boom", global_position, clampf(radius * 0.8 - 4.0, -5.0, 2.0), clampf(1.5 - radius * 0.15, 0.6, 1.3))
	GameFeel.shake(0.25)
	GameFeel.rumble(0.45, 0.55, 0.18)
	get_tree().create_timer(LIFETIME).timeout.connect(queue_free)


func _build_visuals() -> void:
	# Núcleo brilhante + casca externa, expandindo e sumindo.
	var layers := [[1.0, 0.85], [0.7, 1.0]] # [escala relativa ao raio, alpha inicial]
	for l in layers:
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		var c := color if l[0] >= 1.0 else Color(1.0, 0.9, 0.5)
		mat.albedo_color = Color(c.r, c.g, c.b, l[1])
		var mesh := SphereMesh.new()
		mesh.radius = 1.0
		mesh.height = 2.0
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.scale = Vector3.ONE * 0.15
		add_child(mi)
		var target_scale: float = radius * float(l[0])
		var tw := mi.create_tween()
		tw.set_parallel(true)
		tw.tween_property(mi, "scale", Vector3.ONE * target_scale, 0.16).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tw.tween_property(mat, "albedo_color:a", 0.0, 0.4).set_delay(0.08)

	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 8.0
	light.omni_range = radius * 2.5
	add_child(light)
	light.create_tween().tween_property(light, "light_energy", 0.0, 0.4)

	Fx.spark(self, global_position, color)
	Fx.spark(self, global_position + Vector3(0, 0.3, 0), Color(1.0, 0.85, 0.4))
