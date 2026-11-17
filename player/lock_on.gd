extends Node
## Lock-on: trava no inimigo mais bem posicionado à frente da câmera. Tecla/botão: lock_on.

@export var max_distance := 18.0
@export var break_distance := 26.0

const MOUSE_FLICK_PIXELS := 60.0
const MOUSE_FLICK_WINDOW := 0.15

var _player: Player
var _marker: MeshInstance3D
var _stick_armed := true
var _mouse_accum := 0.0
var _mouse_timer := 0.0


func _ready() -> void:
	_player = get_parent() as Player
	_marker = MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.12
	mesh.height = 0.24
	_marker.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.2, 0.2)
	_marker.material_override = mat
	_marker.top_level = true
	_marker.visible = false
	add_child(_marker)


func _input(event: InputEvent) -> void:
	# Flick do mouse para os lados troca de alvo (a câmera ignora o yaw do mouse em lock-on).
	if event is InputEventMouseMotion and _player.has_lock() and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_mouse_accum += (event as InputEventMouseMotion).relative.x
		_mouse_timer = MOUSE_FLICK_WINDOW


func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("lock_on"):
		if _player.has_lock():
			_player.lock_target = null
		else:
			_player.lock_target = _find_target()

	# Troca de alvo: flick do analógico direito ou do mouse.
	if _player.has_lock():
		var sx := Input.get_axis("cam_left", "cam_right")
		if _stick_armed and absf(sx) > 0.7:
			_stick_armed = false
			switch_target(signf(sx))
		elif absf(sx) < 0.3:
			_stick_armed = true
		if _mouse_timer > 0.0:
			_mouse_timer -= delta
			if absf(_mouse_accum) > MOUSE_FLICK_PIXELS:
				switch_target(signf(_mouse_accum))
				_mouse_accum = 0.0
				_mouse_timer = 0.0
		if _mouse_timer <= 0.0:
			_mouse_accum = 0.0

	if _player.lock_target != null:
		var t := _player.lock_target
		if not is_instance_valid(t) or not t.is_in_group("enemy") \
				or t.global_position.distance_to(_player.global_position) > break_distance:
			_player.lock_target = null

	_marker.visible = _player.has_lock()
	if _marker.visible:
		_marker.global_position = _player.lock_target.global_position + Vector3(0, 2.3, 0)


## Troca para o inimigo mais próximo do lado indicado na tela (dir: -1 esquerda, +1 direita).
func switch_target(dir: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null or not _player.has_lock():
		return
	var current := _player.lock_target
	var cur_x := cam.unproject_position(current.global_position + Vector3.UP).x
	var best: Node3D = null
	var best_dx := INF
	for e in get_tree().get_nodes_in_group("enemy"):
		var enemy := e as Node3D
		if enemy == current:
			continue
		var pos := enemy.global_position + Vector3.UP
		if enemy.global_position.distance_to(_player.global_position) > max_distance or cam.is_position_behind(pos):
			continue
		var dx := (cam.unproject_position(pos).x - cur_x) * dir
		if dx > 10.0 and dx < best_dx:
			best_dx = dx
			best = enemy
	if best != null:
		_player.lock_target = best


func _find_target() -> Node3D:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return null
	var cam_fwd := -cam.global_transform.basis.z
	cam_fwd.y = 0.0
	cam_fwd = cam_fwd.normalized()

	var best: Node3D = null
	var best_score := INF
	for e in get_tree().get_nodes_in_group("enemy"):
		var enemy := e as Node3D
		var to := enemy.global_position - _player.global_position
		to.y = 0.0
		var dist := to.length()
		if dist > max_distance or dist < 0.01:
			continue
		var facing := cam_fwd.dot(to / dist)
		if facing < 0.2:
			continue
		var score := dist * (2.0 - facing) # perto e centralizado = menor score
		if score < best_score:
			best_score = score
			best = enemy
	return best
