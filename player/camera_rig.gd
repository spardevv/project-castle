class_name CameraRig
extends Node3D
## Câmera de 3ª pessoa estilo Devil May Cry 5: afastada e elevada, órbita livre,
## e em lock-on enquadra jogador + alvo juntos, afastando-se conforme a distância.

@export var target: Node3D
@export var follow_offset := Vector3(0, 1.7, 0)
@export var follow_speed := 12.0
@export var follow_speed_vertical := 5.0 # Y mais suave: pulos não "chicoteiam" a câmera
@export var mouse_sensitivity := 0.0025
@export var stick_sensitivity := 3.0
@export var min_pitch := deg_to_rad(-50.0)
@export var max_pitch := deg_to_rad(25.0)
@export var default_pitch := deg_to_rad(-14.0)

@export_group("Distância")
@export var distance := 6.5
@export var lock_min_distance := 6.5
@export var lock_max_distance := 12.0
@export var fov_normal := 72.0
@export var fov_lock := 66.0

@export_group("Impacto")
## Quanto a câmera é empurrada na direção do golpe (multiplica a intensidade do shake).
@export var kick_strength := 1.2
## Graus de FOV que fecham no impacto (multiplica a intensidade).
@export var fov_punch := 14.0

@export_group("Auto-follow")
## A câmera gira suavemente para ficar atrás do jogador enquanto ele corre
## (só sem input de câmera e sem lock-on; ignora movimento de volta à câmera).
@export var auto_follow := true
@export var auto_follow_delay := 0.5
@export var auto_follow_speed := 2.0

@export_group("Lock-on")
## 0 = foca no jogador, 1 = foca no alvo. 0.4 mantém os dois no enquadramento.
@export_range(0.0, 1.0) var lock_focus_bias := 0.4
@export var lock_pitch := deg_to_rad(-20.0)

@onready var pivot: Node3D = $Pivot
@onready var arm: SpringArm3D = $Pivot/SpringArm3D
@onready var camera: Camera3D = $Pivot/SpringArm3D/Camera3D

var _yaw := 0.0
var _pitch := deg_to_rad(-14.0)
var _shake := 0.0
var _kick := Vector3.ZERO
var _fov_kick := 0.0
var _fov_base := 72.0
var _idle_time := 0.0


func _ready() -> void:
	add_to_group("camera_rig")
	GameFeel.shake_requested.connect(_on_shake_requested)
	top_level = true
	_pitch = default_pitch
	arm.spring_length = distance
	_fov_base = fov_normal
	camera.fov = fov_normal
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if target == null:
		target = get_tree().get_first_node_in_group("player") as Node3D
	if target:
		global_position = target.global_position + follow_offset
		_yaw = target.get_node("Visual").global_rotation.y + PI if target.has_node("Visual") else 0.0


func _has_lock() -> bool:
	return target != null and target.get("lock_target") != null \
		and is_instance_valid(target.get("lock_target"))


## intensity: tremor aleatório. direction (mundo): empurrão da câmera na direção do golpe + FOV punch.
func _on_shake_requested(intensity: float, direction: Vector3) -> void:
	_shake = maxf(_shake, intensity)
	if direction.length() > 0.01:
		_kick = direction.normalized() * intensity * kick_strength
	_fov_kick = maxf(_fov_kick, intensity * fov_punch)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_idle_time = 0.0
		if not _has_lock():
			_yaw -= event.relative.x * mouse_sensitivity
		_pitch -= event.relative.y * mouse_sensitivity
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	var look := Input.get_vector("cam_left", "cam_right", "cam_up", "cam_down")
	_pitch -= look.y * stick_sensitivity * delta

	var locked := _has_lock()
	var goal_distance := distance
	var goal_fov := fov_normal
	var focus := Vector3.ZERO
	if target:
		focus = target.global_position

	if locked:
		var lt: Node3D = target.get("lock_target")
		var to := lt.global_position - target.global_position
		var flat := Vector2(to.x, to.z)
		# Gira para manter o alvo à frente do jogador.
		if flat.length() > 0.5:
			_yaw = lerp_angle(_yaw, atan2(-to.x, -to.z), 1.0 - exp(-8.0 * delta))
		_pitch = lerpf(_pitch, lock_pitch, 1.0 - exp(-4.0 * delta))
		# Enquadra os dois e afasta conforme o alvo se distancia.
		focus = target.global_position.lerp(lt.global_position, lock_focus_bias)
		goal_distance = clampf(lock_min_distance + flat.length() * 0.45, lock_min_distance, lock_max_distance)
		goal_fov = fov_lock
	else:
		_yaw -= look.x * stick_sensitivity * delta
		if look.length() > 0.1:
			_idle_time = 0.0
		else:
			_idle_time += delta
		if auto_follow and _idle_time > auto_follow_delay and target:
			var vel: Vector3 = target.get("velocity")
			var flat_vel := Vector2(vel.x, vel.z)
			if flat_vel.length() > 2.0:
				var heading := atan2(-vel.x, -vel.z)
				var diff := angle_difference(_yaw, heading)
				# Só corrige se o jogador não estiver vindo em direção à câmera.
				if absf(diff) < deg_to_rad(120.0):
					_yaw += diff * (1.0 - exp(-auto_follow_speed * delta))

	_pitch = clampf(_pitch, min_pitch, max_pitch)

	arm.spring_length = lerpf(arm.spring_length, goal_distance, 1.0 - exp(-5.0 * delta))
	_fov_base = lerpf(_fov_base, goal_fov, 1.0 - exp(-5.0 * delta))
	_fov_kick = lerpf(_fov_kick, 0.0, 1.0 - exp(-12.0 * delta))
	camera.fov = _fov_base - _fov_kick # fecha o FOV um instante: "soco" no impacto

	# Screen shake (tremor aleatório) + kick direcional (empurra na direção do golpe).
	var offset := Vector2.ZERO
	if _shake > 0.001:
		offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake
		_shake = lerpf(_shake, 0.0, 1.0 - exp(-18.0 * delta))
	else:
		_shake = 0.0
	if _kick.length() > 0.001:
		var local := camera.global_transform.basis.inverse() * _kick
		offset += Vector2(local.x, -_kick.length() * 0.4)
		_kick = _kick.lerp(Vector3.ZERO, 1.0 - exp(-14.0 * delta))
	camera.h_offset = offset.x
	camera.v_offset = offset.y

	rotation.y = _yaw
	pivot.rotation.x = _pitch

	if target:
		var goal := focus + follow_offset
		var pos := global_position
		var t_h := 1.0 - exp(-follow_speed * delta)
		var t_v := 1.0 - exp(-follow_speed_vertical * delta)
		pos.x = lerpf(pos.x, goal.x, t_h)
		pos.z = lerpf(pos.z, goal.z, t_h)
		pos.y = lerpf(pos.y, goal.y, t_v)
		global_position = pos
