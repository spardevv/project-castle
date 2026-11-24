class_name SecretWall
extends StaticBody3D
## Parede secreta: sólida para todos (layer world), menos para quem está banido pelo mago. O estado Banished
## do jogador/inimigo chama `add_collision_exception_with` com cada parede do grupo "secret_wall" e
## `set_revealed(true)`, que a deixa translúcida com brilho verde enquanto dura o banimento.
## Se a cena não tiver filhos, monta sozinha a malha e a colisão a partir de `size`.

const MIST := Color(0.45, 1.0, 0.6)

@export var size := Vector3(4.0, 6.0, 1.0)
@export var color := Color(0.5, 0.45, 0.4)

var _mat: StandardMaterial3D


func _ready() -> void:
	add_to_group("secret_wall")
	collision_layer = 1 << 0 # world
	collision_mask = 0
	if get_child_count() == 0:
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		cs.shape = box
		add_child(cs)
		var mesh := BoxMesh.new()
		mesh.size = size
		_mat = StandardMaterial3D.new()
		_mat.albedo_color = color
		mesh.material = _mat
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		add_child(mi)


## Revela (ou esconde) a parede para quem está banido: translúcida e com brilho verde.
func set_revealed(on: bool) -> void:
	if _mat == null:
		return
	if on:
		_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mat.albedo_color = Color(MIST.r, MIST.g, MIST.b, 0.35)
		_mat.emission_enabled = true
		_mat.emission = MIST
		_mat.emission_energy_multiplier = 0.6
	else:
		_mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
		_mat.albedo_color = color
		_mat.emission_enabled = false


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
