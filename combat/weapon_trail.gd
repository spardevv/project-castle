class_name WeaponTrail
extends MeshInstance3D
## Rastro de lâmina: fita entre a base e a ponta da arma enquanto rig.trail_active estiver ligado.

@export var rig: HumanoidRig
@export var lifetime := 0.2
@export var max_samples := 24

var _samples: Array = [] # cada item: [base: Vector3, tip: Vector3, age: float]
var _mesh := ImmediateMesh.new()


func _ready() -> void:
	if rig == null:
		rig = get_parent().get_node_or_null("Visual/Rig") as HumanoidRig
	top_level = true
	global_transform = Transform3D.IDENTITY
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh = _mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	material_override = mat


func _process(delta: float) -> void:
	for s in _samples:
		s[2] += delta
	while not _samples.is_empty() and _samples[0][2] > lifetime:
		_samples.pop_front()

	if rig != null and rig.trail_active and rig.sword_tip != null and delta > 0.0:
		_samples.append([rig.sword_base.global_position, rig.sword_tip.global_position, 0.0])
		if _samples.size() > max_samples:
			_samples.pop_front()

	_mesh.clear_surfaces()
	if _samples.size() < 2:
		return
	var col := rig.trail_color if rig != null else Color.WHITE
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for s in _samples:
		var a := clampf(1.0 - float(s[2]) / lifetime, 0.0, 1.0) * 0.75
		_mesh.surface_set_color(Color(col.r, col.g, col.b, a))
		_mesh.surface_add_vertex(s[0])
		_mesh.surface_set_color(Color(col.r, col.g, col.b, 0.0))
		_mesh.surface_add_vertex(s[1])
	_mesh.surface_end()
