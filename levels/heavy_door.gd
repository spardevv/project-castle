class_name HeavyDoor
extends StaticBody3D
## Porta pesada: o jogador não consegue abri-la. Só o golem, com a skill Agarrar usada perto dela e sem
## inimigos por perto (Summon.nearest_heavy_door), a levanta. Fica no grupo "heavy_door".
## Se a cena não tiver filhos, monta sozinha a malha e a colisão a partir de `size`.

signal opened(by: Node3D)

@export var size := Vector3(4.0, 4.0, 0.8)
@export var open_time := 1.4
## Distância (m) a que o golem se posiciona para abri-la.
@export var reach := 2.8

var is_open := false


func _ready() -> void:
	add_to_group("heavy_door")
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
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.32, 0.27, 0.24)
		mat.roughness = 0.95
		mesh.material = mat
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		add_child(mi)
		# Faixas de ferro para parecer "pesada".
		var iron := StandardMaterial3D.new()
		iron.albedo_color = Color(0.14, 0.14, 0.16)
		iron.metallic = 0.6
		iron.roughness = 0.5
		for y in [-size.y * 0.3, size.y * 0.3]:
			var band := BoxMesh.new()
			band.size = Vector3(size.x * 1.02, 0.25, size.z * 1.1)
			band.material = iron
			var bi := MeshInstance3D.new()
			bi.mesh = band
			bi.position.y = y
			add_child(bi)


## Chamado pelo golem: a porta sobe (ou cede) e deixa de bloquear a passagem.
func open(by: Node3D = null) -> void:
	if is_open:
		return
	is_open = true
	Sfx.play(&"boom", global_position, 0.0, 0.5)
	var tw := create_tween()
	tw.tween_property(self, "global_position:y", global_position.y + size.y + 0.3, open_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(func() -> void: collision_layer = 0)
	opened.emit(by)
