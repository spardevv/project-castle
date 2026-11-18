class_name Hurtbox
extends Area3D
## Área que recebe golpes. Se o dono tem um HumanoidRig (Visual/Rig), a área vira um conjunto de
## cápsulas por parte do corpo (cabeça, tronco, braços, pernas...) que seguem o esqueleto a cada
## quadro de física: o golpe só acerta onde o corpo realmente está (agachado, caído, no ar).
## Sem rig, usa a forma fixa da cena (CollisionShape3D).

@export var health: Health
## Cápsulas por parte do corpo seguindo o rig. Falso = forma fixa da cena.
@export var body_parts := true
## Folga (m) somada ao raio de cada parte: um pouco de tolerância para o golpe "pegar".
@export var padding := 0.03

var rig: HumanoidRig
## Uma entrada por parte: {"name", "node", "a", "b", "r", "shape": CollisionShape3D}.
var parts: Array[Dictionary] = []


func _ready() -> void:
	# Rede de segurança: se a referência não veio da cena, usa o nó "Health" irmão.
	if health == null:
		health = get_parent().get_node_or_null("Health") as Health
	if health == null:
		push_error("Hurtbox sem Health: %s" % get_path())
	if body_parts:
		rig = get_parent().get_node_or_null("Visual/Rig") as HumanoidRig
	if rig != null:
		_build_parts.call_deferred() # o rig monta o corpo no _ready dele


func receive_hit(hit: HitData) -> bool:
	return health != null and health.take_hit(hit)


func _build_parts() -> void:
	if rig == null or not is_instance_valid(rig):
		return
	for child in get_children():
		if child is CollisionShape3D:
			(child as CollisionShape3D).disabled = true
	for def in rig.hurt_parts():
		var cs := CollisionShape3D.new()
		cs.name = "Part_" + str(def["name"])
		var r: float = float(def["r"]) * rig.height + padding
		if (def["a"] as Vector3).is_equal_approx(def["b"]):
			var sphere := SphereShape3D.new()
			sphere.radius = r
			cs.shape = sphere
		else:
			var capsule := CapsuleShape3D.new()
			capsule.radius = r
			cs.shape = capsule
		add_child(cs)
		var entry: Dictionary = def.duplicate()
		entry["r"] = r
		entry["shape"] = cs
		parts.append(entry)
	update_parts()


func _physics_process(_delta: float) -> void:
	if not parts.is_empty():
		update_parts()
		if Settings.debug_hitboxes:
			for p in parts:
				var seg := part_segment(p)
				DebugDraw3D.draw_capsule_ab(seg[0], seg[1], float(p["r"]), Color(0.3, 1.0, 0.4), 0.0)


## Reposiciona cada cápsula na pose atual do rig.
func update_parts() -> void:
	for p in parts:
		var seg := part_segment(p)
		var cs: CollisionShape3D = p["shape"]
		var a: Vector3 = seg[0]
		var b: Vector3 = seg[1]
		var length := a.distance_to(b)
		if cs.shape is CapsuleShape3D:
			var capsule := cs.shape as CapsuleShape3D
			capsule.height = length + capsule.radius * 2.0
			var y := (b - a) / maxf(length, 0.0001)
			var ref := Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.95 else Vector3.RIGHT
			var x := y.cross(ref).normalized()
			cs.global_transform = Transform3D(Basis(x, y, x.cross(y)), (a + b) * 0.5)
		else:
			cs.global_transform = Transform3D(Basis.IDENTITY, a)


## Pontas da parte no mundo: [a, b] (iguais numa esfera).
func part_segment(p: Dictionary) -> PackedVector3Array:
	var node: Node3D = p["node"]
	var xf := node.global_transform
	return PackedVector3Array([xf * (p["a"] as Vector3), xf * (p["b"] as Vector3)])


## Parte correspondente ao índice de forma devolvido por consultas de física (ou {} se for outra forma).
func part_for_shape(shape_index: int) -> Dictionary:
	var owner_id := shape_find_owner(shape_index)
	var node := shape_owner_get_owner(owner_id)
	for p in parts:
		if p["shape"] == node:
			return p
	return {}


## Ponto do corpo mais próximo de um segmento (arma) ou ponto (projétil). Sem partes, o centro do corpo.
func closest_point(a: Vector3, b: Vector3) -> Vector3:
	if parts.is_empty():
		return Geometry3D.get_closest_point_to_segment(global_position + Vector3.UP, a, b)
	var best := Vector3.ZERO
	var best_d := INF
	for p in parts:
		var seg := part_segment(p)
		var pts := Geometry3D.get_closest_points_between_segments(a, b, seg[0], seg[1])
		var d := (pts[0] as Vector3).distance_to(pts[1])
		if d < best_d:
			best_d = d
			best = pts[0]
	return best
