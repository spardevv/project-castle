extends SceneTree
## Ferramenta: imprime a pose de repouso dos ossos do corpo do HumanoidRig (espaço do rig, sem escala),
## em JSON, para montar no Blender um esqueleto idêntico ao do jogo.
## Uso: godot --headless --path . -s tools/print_rig_rest.gd


func _initialize() -> void:
	var rig: HumanoidRig = load("res://characters/humanoid_rig.tscn").instantiate()
	root.add_child(rig)
	await process_frame
	var out := {}
	for i in rig._skel.get_bone_count():
		var rest := rig._skel.get_bone_rest(i)
		out[rig._skel.get_bone_name(i)] = [rest.origin.x, rest.origin.y, rest.origin.z]
	# Pontos extras úteis: punho (mão), ponta do pé.
	var inv := rig._skel.global_transform.affine_inverse()
	for n in ["l", "r"]:
		out["hand_" + n] = _v(inv * (rig._hands[n] as Node3D).global_position)
		out["toe_" + n] = _v(inv * (rig._toes[n] as Node3D).global_position)
	print("RIG_REST ", JSON.stringify(out))
	quit()


func _v(p: Vector3) -> Array:
	return [p.x, p.y, p.z]
