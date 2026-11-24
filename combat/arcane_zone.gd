class_name ArcaneZone
extends Node3D
## Zona de dano arcano contínuo (chegada do mago): enquanto dura, fere (sem fazer cambalear) e deixa
## lentos os inimigos que estiverem dentro do raio. Só afeta o grupo "enemy".

@export var radius := 5.0
@export var duration := 8.0
@export var tick := 0.5
@export var damage := 4
@export var slow_time := 1.2
@export var color := Color(0.5, 0.65, 1.0)

## Quem criou a zona (origem do dano). Pode sumir antes dela.
var instigator: Node3D

var _t := 0.0
var _tick_t := 0.0
var _disc_mat: StandardMaterial3D
var _core: MeshInstance3D


func _ready() -> void:
	_disc_mat = _make_mat(Color(color.r, color.g, color.b, 0.28))
	var disc := CylinderMesh.new()
	disc.top_radius = radius
	disc.bottom_radius = radius
	disc.height = 0.04
	disc.radial_segments = 40
	var mi := MeshInstance3D.new()
	mi.mesh = disc
	mi.material_override = _disc_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

	# Anel externo e núcleo que pulsa.
	var ring := TorusMesh.new()
	ring.inner_radius = radius - 0.12
	ring.outer_radius = radius
	ring.rings = 40
	ring.ring_segments = 6
	var ring_mi := MeshInstance3D.new()
	ring_mi.mesh = ring
	ring_mi.scale = Vector3(1.0, 0.15, 1.0)
	ring_mi.material_override = _make_mat(Color(color.r, color.g, color.b, 0.85))
	ring_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring_mi)

	var core_mesh := CylinderMesh.new()
	core_mesh.top_radius = radius * 0.55
	core_mesh.bottom_radius = radius * 0.55
	core_mesh.height = 0.05
	core_mesh.radial_segments = 32
	_core = MeshInstance3D.new()
	_core.mesh = core_mesh
	_core.material_override = _make_mat(Color(color.r, color.g, color.b, 0.22))
	_core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_core.position.y = 0.02
	add_child(_core)

	var motes := CPUParticles3D.new()
	motes.amount = 40
	motes.lifetime = 1.6
	motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	motes.emission_sphere_radius = radius * 0.8
	motes.direction = Vector3.UP
	motes.spread = 12.0
	motes.initial_velocity_min = 0.6
	motes.initial_velocity_max = 1.6
	motes.gravity = Vector3.ZERO
	var mote := SphereMesh.new()
	mote.radius = 0.06
	mote.height = 0.12
	mote.material = _make_mat(Color(0.75, 0.85, 1.0, 1.0))
	motes.mesh = mote
	add_child(motes)

	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 1.6
	light.omni_range = radius * 1.4
	light.position.y = 0.8
	add_child(light)


func _make_mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = c
	return m


func _process(delta: float) -> void:
	_t += delta
	var fade := clampf((duration - _t) / 0.8, 0.0, 1.0)
	_disc_mat.albedo_color.a = 0.28 * fade
	_core.scale = Vector3.ONE * (0.9 + 0.1 * sin(_t * 5.0))
	_tick_t += delta
	if _tick_t >= tick:
		_tick_t -= tick
		_pulse()
	if _t >= duration:
		queue_free()


## Fere e atrasa quem está dentro do raio (distância horizontal; ±3 m de altura).
func _pulse() -> void:
	var src: Node3D = instigator if is_instance_valid(instigator) else null
	for e in get_tree().get_nodes_in_group("enemy"):
		var en := e as Node3D
		var d := Vector2(en.global_position.x - global_position.x, en.global_position.z - global_position.z).length()
		if d > radius or absf(en.global_position.y - global_position.y) > 3.0:
			continue
		StatusEffects.apply(en, &"slow", slow_time, true)
		Health.dot(en, damage, src, color.lightened(0.3))
