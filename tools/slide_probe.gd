extends Node3D
## Mede o deslize dos pés: move o rig em velocidade constante e acumula a velocidade (no mundo)
## dos pés que estão apoiados no chão. Ideal = 0 m/s.
## Uso: godot --headless --path . res://tools/slide_probe.tscn

const SPEEDS := [1.5, 3.0, 4.5, 6.0, 7.0]
const DT := 1.0 / 60.0

var _rig: HumanoidRig
var _mover: Node3D
var _si := 0
var _t := 0.0
var _prev := {}
var _sum := 0.0
var _n := 0
var _worst := 0.0


func _ready() -> void:
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(400, 1, 400)
	cs.shape = box
	cs.position.y = -0.5
	floor_body.add_child(cs)
	add_child(floor_body)
	_mover = Node3D.new()
	add_child(_mover)
	_rig = HumanoidRig.new()
	_mover.add_child(_rig)
	_start()


func _start() -> void:
	_mover.position = Vector3.ZERO
	_t = 0.0
	_prev.clear()
	_sum = 0.0
	_n = 0
	_worst = 0.0


func _process(_delta: float) -> void:
	var v: float = SPEEDS[_si]
	_t += DT
	_mover.position.z += v * DT
	_rig.set_motion(v, true, 0.0)
	if _t > 1.0: # deixa a mola assentar
		for n in ["l", "r"]:
			var kn: Node3D = _rig._joints["kn_" + n]
			var ankle := kn.global_transform * Vector3(0, -HumanoidRig.SHIN_LEN, 0)
			var c := cos(_rig._phase)
			var stance: bool = (c < -0.25) if n == "l" else (c > 0.25)
			if _prev.has(n) and stance:
				var d := Vector2(ankle.x - _prev[n].x, ankle.z - _prev[n].z).length() / DT
				_sum += d
				_n += 1
				_worst = maxf(_worst, d)
			_prev[n] = ankle
	if _t > 6.0:
		print("v=%.1f m/s  deslize médio=%.3f m/s  pior=%.3f m/s  (amostras=%d)" % [v, _sum / maxf(_n, 1), _worst, _n])
		_si += 1
		if _si >= SPEEDS.size():
			get_tree().quit()
			return
		_start()
