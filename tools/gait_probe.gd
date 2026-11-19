extends Node3D
## Ferramenta de desenvolvimento: anda com a elfa como o jogador (aceleração, curva de 90°, correr, parar)
## a 60 quadros/s e registra trancos nas pernas: joelho mudando muito de um quadro para o outro e perna
## esticada até o limite (trava do pé longe demais do quadril).
## Uso: godot --headless --path . res://tools/gait_probe.tscn

const RIG := preload("res://characters/humanoid_rig.tscn")
const MODEL := preload("res://characters/models/elfa_rig.glb")
const DT := 1.0 / 60.0
const ACCEL := 45.0
const TURN := 14.0
## Segundos: [fim, velocidade alvo, direção (graus, 0 = +Z)]
const PLAN := [[0.5, 0.0, 0.0], [3.0, 3.6, 0.0], [4.5, 3.6, 90.0], [6.5, 7.0, 90.0], [7.0, 7.0, 0.0], [8.5, 0.0, 0.0]]

var _rig: HumanoidRig
var _mover: Node3D
var _vel := Vector3.ZERO
var _t := 0.0
var _prev_knee := {}
var _events: Array[String] = []
var _jumps := 0
var _overext := 0
var _frames := 0


func _ready() -> void:
	var floor_body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(400, 1, 400)
	cs.shape = box
	cs.position.y = -0.5
	floor_body.add_child(cs)
	add_child(floor_body)
	_mover = Node3D.new()
	add_child(_mover)
	_rig = RIG.instantiate()
	_rig.body_model = MODEL
	_rig.feminine = true
	_mover.add_child(_rig)
	_rig.set_process(false)


func _physics_process(_delta: float) -> void:
	if _t > PLAN[-1][0]:
		print("quadros=%d  saltos de joelho=%d  perna no limite=%d" % [_frames, _jumps, _overext])
		for e in _events.slice(0, 40):
			print(e)
		get_tree().quit()
		return
	var step: Array = PLAN[0]
	for p in PLAN:
		if _t <= p[0]:
			step = p
			break
	var dir := Vector3(sin(deg_to_rad(step[2])), 0, cos(deg_to_rad(step[2])))
	var target: Vector3 = dir * float(step[1])
	_vel.x = move_toward(_vel.x, target.x, ACCEL * DT)
	_vel.z = move_toward(_vel.z, target.z, ACCEL * DT)
	_mover.position += _vel * DT
	if _vel.length() > 0.2:
		var yaw := atan2(_vel.x, _vel.z)
		_mover.rotation.y = lerp_angle(_mover.rotation.y, yaw, 1.0 - exp(-TURN * DT))
	_rig.set_motion(Vector2(_vel.x, _vel.z).length(), true, 0.0)
	_rig._process(DT)
	_t += DT
	_frames += 1
	var main := _rig._loco_main.name if _rig._loco_main != null else "-"
	for i in 2:
		var n: String = "l" if i == 0 else "r"
		var kn: Node3D = _rig._joints["kn_" + n]
		var th: Node3D = _rig._joints["th_" + n]
		var knee := kn.rotation_degrees.x
		var ankle := kn.global_transform * Vector3(0, -_rig.shin_len, 0)
		var ext := th.global_position.distance_to(ankle) / ((_rig.thigh_len + _rig.shin_len) * _rig.height)
		if _prev_knee.has(n) and absf(knee - float(_prev_knee[n])) > 20.0:
			_jumps += 1
			_events.append("t=%.2f %s joelho %+.0f -> %+.0f  v=%.1f clipe=%s w=%.2f apoio=%s ext=%.2f" % [
				_t, n, _prev_knee[n], knee, _vel.length(), main, _rig._foot_w[i], _rig.foot_stance(i), ext])
		if ext > 0.985 and _rig._foot_w[i] > 0.5:
			_overext += 1
			if _overext % 6 == 1:
				_events.append("t=%.2f %s PERNA ESTICADA ext=%.3f v=%.1f clipe=%s w=%.2f" % [_t, n, ext, _vel.length(), main, _rig._foot_w[i]])
		_prev_knee[n] = knee
