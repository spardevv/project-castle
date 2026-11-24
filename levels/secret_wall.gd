class_name SecretWall
extends StaticBody3D
## Parede secreta: sólida para todos (layer world), menos para quem está banido pelo mago. O estado Banished
## do jogador/inimigo chama `add_collision_exception_with` com cada parede do grupo "secret_wall" e
## `set_revealed(true)`, que a deixa translúcida com brilho verde enquanto dura o banimento.
## Pistas fora do banimento: tom levemente diferente e rachaduras nas duas faces; com o Mago invocado,
## as rachaduras pulsam um verde fraco.
## Se a cena não tiver filhos, monta sozinha a malha, as rachaduras e a colisão a partir de `size`.

const MIST := Color(0.45, 1.0, 0.6)
const CRACK_COLOR := Color(0.16, 0.15, 0.14)
## Brilho das rachaduras com o Mago invocado (mín./máx. do pulso).
const HINT_GLOW := Vector2(0.15, 0.45)

@export var size := Vector3(4.0, 6.0, 1.0)
@export var color := Color(0.5, 0.45, 0.4)
## Quantas rachaduras por face.
@export var cracks := 3

var revealed := false

var _mat: StandardMaterial3D
var _crack_mat: StandardMaterial3D
var _t := 0.0


func _ready() -> void:
	add_to_group("secret_wall")
	collision_layer = 1 << 0 # world
	collision_mask = 0
	if get_child_count() == 0:
		_build()


func _build() -> void:
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	add_child(cs)
	var mesh := BoxMesh.new()
	mesh.size = size
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = _base_color()
	mesh.material = _mat
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	add_child(mi)
	_crack_mat = StandardMaterial3D.new()
	_crack_mat.albedo_color = CRACK_COLOR
	_crack_mat.emission = MIST
	_build_cracks()


func _base_color() -> Color:
	return color.lerp(Color(0.42, 0.47, 0.4), 0.15) # um pouco mais esverdeada que as paredes comuns


## Rachaduras em zigue-zague nas duas faces largas (seed fixa pelo nome, para não mudar a cada carga).
func _build_cracks() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(String(name))
	var thin_x := size.x < size.z # a face larga olha para ±X ou ±Z?
	var width := size.z if thin_x else size.x
	var half_thin := (size.x if thin_x else size.z) * 0.5 + 0.01
	for side in [-1.0, 1.0]:
		for i in cracks:
			var p := Vector2(rng.randf_range(-0.35, 0.35) * width, rng.randf_range(-0.3, 0.3) * size.y)
			var ang := rng.randf_range(-1.2, 1.2)
			for seg in 3:
				var length := rng.randf_range(0.35, 0.8)
				var dir := Vector2(cos(ang), sin(ang))
				var mid := p + dir * length * 0.5
				var seg_mesh := BoxMesh.new()
				seg_mesh.size = Vector3(length, 0.05, 0.02)
				seg_mesh.material = _crack_mat
				var mi := MeshInstance3D.new()
				mi.mesh = seg_mesh
				if thin_x:
					mi.position = Vector3(half_thin * side, mid.y, mid.x)
					mi.rotation = Vector3(0.0, -PI * 0.5, ang) # comprimento no plano YZ, espessura em X
				else:
					mi.position = Vector3(mid.x, mid.y, half_thin * side)
					mi.rotation = Vector3(0.0, 0.0, ang)
				add_child(mi)
				p += dir * length
				ang += rng.randf_range(-0.9, 0.9)


func _process(delta: float) -> void:
	if _crack_mat == null or revealed:
		return
	_t += delta
	var hint := _mage_present()
	_crack_mat.emission_enabled = hint
	if hint:
		_crack_mat.emission_energy_multiplier = lerpf(HINT_GLOW.x, HINT_GLOW.y, 0.5 + 0.5 * sin(_t * 2.2))


func _mage_present() -> bool:
	if GameState.summon_kind != &"mage":
		return false
	var p := get_tree().get_first_node_in_group("player")
	return p != null and p.has_method("has_summon") and bool(p.call("has_summon"))


## Revela (ou esconde) a parede para quem está banido: translúcida e com brilho verde.
func set_revealed(on: bool) -> void:
	revealed = on
	if _mat == null:
		return
	if on:
		_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mat.albedo_color = Color(MIST.r, MIST.g, MIST.b, 0.35)
		_mat.emission_enabled = true
		_mat.emission = MIST
		_mat.emission_energy_multiplier = 0.6
		_crack_mat.emission_enabled = true
		_crack_mat.emission_energy_multiplier = 1.5
	else:
		_mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
		_mat.albedo_color = _base_color()
		_mat.emission_enabled = false
		_crack_mat.emission_enabled = false


## Liga/desliga a passagem de `body` por todas as paredes secretas da árvore (e o visual revelado).
static func set_passable(body: PhysicsBody3D, on: bool) -> void:
	for w in body.get_tree().get_nodes_in_group("secret_wall"):
		var wall := w as SecretWall
		if wall == null:
			continue
		if on:
			body.add_collision_exception_with(wall)
		else:
			body.remove_collision_exception_with(wall)
		if body is Player:
			wall.set_revealed(on)
