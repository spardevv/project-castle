class_name ArcaneOrbs
extends Node3D
## Passiva do mago: conjura 4 orbes arcanas que rodeiam o mago. Assim que um inimigo entra num raio de
## TRIGGER_RADIUS m do mago, as orbes saem uma a uma em direção ao inimigo mais próximo e explodem nele.
## As que não encontram alvo somem depois de MAX_LIFE s. Some junto com o mago.

const COUNT := 4
const TRIGGER_RADIUS := 10.0
const ORBIT_RADIUS := 1.5
const ORBIT_SPEED := 2.4
const LAUNCH_GAP := 0.3
const FLY_SPEED := 18.0
const FLY_LIFE := 3.5
const MAX_LIFE := 30.0
const DAMAGE := 14
const COLOR := Color(0.55, 0.7, 1.0)

var mage: Node3D

var _orbs: Array[Dictionary] = [] # {"node", "fly", "target", "life"}
var _angle := 0.0
var _gap := 0.0
var _age := 0.0


func _ready() -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = COLOR.lightened(0.3)
	var mesh := SphereMesh.new()
	mesh.radius = 0.2
	mesh.height = 0.4
	mesh.material = mat
	for i in COUNT:
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var light := OmniLight3D.new()
		light.light_color = COLOR
		light.light_energy = 0.8
		light.omni_range = 2.5
		mi.add_child(light)
		add_child(mi)
		_orbs.append({"i": i, "node": mi, "fly": false, "target": null, "life": 0.0})
	_place_orbiting()


func _process(delta: float) -> void:
	if not is_instance_valid(mage):
		queue_free()
		return
	_age += delta
	_angle += ORBIT_SPEED * delta
	_gap -= delta
	_place_orbiting()
	for o in _orbs:
		if o["fly"]:
			_fly(o, delta)
	if _gap <= 0.0:
		var target := _nearest_enemy(mage.global_position, TRIGGER_RADIUS)
		if target != null:
			for o in _orbs:
				if not o["fly"]:
					o["fly"] = true
					o["target"] = target
					o["life"] = FLY_LIFE
					_gap = LAUNCH_GAP
					Sfx.play(&"zap", (o["node"] as Node3D).global_position, -6.0, 1.4)
					break
	var left := 0
	for o in _orbs:
		if is_instance_valid(o["node"]):
			left += 1
	if left == 0 or _age >= MAX_LIFE:
		queue_free()


## Orbes que ainda não saíram giram em volta do mago na altura do peito.
func _place_orbiting() -> void:
	for o in _orbs:
		if o["fly"] or not is_instance_valid(o["node"]):
			continue
		var node := o["node"] as Node3D
		var idx: int = o["i"]
		var a := _angle + TAU * float(idx) / float(COUNT)
		node.global_position = mage.global_position + Vector3(cos(a) * ORBIT_RADIUS, 1.5 + sin(_angle * 2.0 + idx) * 0.12, sin(a) * ORBIT_RADIUS)


func _fly(o: Dictionary, delta: float) -> void:
	if not is_instance_valid(o["node"]):
		return
	var node := o["node"] as Node3D
	o["life"] = float(o["life"]) - delta
	var target := o["target"] as Node3D
	if not is_instance_valid(target) or (target is Enemy and (target as Enemy).health.current <= 0):
		target = _nearest_enemy(node.global_position, 14.0)
		o["target"] = target
	if target == null or float(o["life"]) <= 0.0:
		_burst(node, false)
		node.queue_free()
		return
	var aim := target.global_position + Vector3(0, 1.0, 0)
	var to := aim - node.global_position
	if to.length() < 0.8:
		_burst(node, true)
		node.queue_free()
		return
	node.global_position += to.normalized() * minf(FLY_SPEED * delta, to.length())


func _nearest_enemy(from: Vector3, radius: float) -> Node3D:
	var best: Node3D = null
	var best_d := radius
	for e in get_tree().get_nodes_in_group("enemy"):
		var d := (e as Node3D).global_position.distance_to(from)
		if d < best_d:
			best_d = d
			best = e
	return best


func _burst(node: Node3D, hit: bool) -> void:
	if not hit:
		Fx.spark(self, node.global_position, COLOR)
		return
	var ex := Explosion.new()
	ex.radius = 1.7
	ex.damage = DAMAGE
	ex.knockback = 4.0
	ex.launch = 2.5
	ex.hitstun = 0.45
	ex.color = COLOR
	ex.instigator = mage
	ex.position = node.global_position
	get_parent().add_child.call_deferred(ex)
