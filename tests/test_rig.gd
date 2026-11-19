extends GutTest
## Rig humanoide: juntas derivadas (peito, pescoço, clavículas, ponta do pé) e malhas arredondadas.

const RIG := preload("res://characters/humanoid_rig.tscn")


func _spawn() -> HumanoidRig:
	var rig: HumanoidRig = RIG.instantiate()
	add_child_autofree(rig)
	return rig


func test_derived_joints_exist() -> void:
	var rig := _spawn()
	for j in ["chest", "neck", "clav_l", "clav_r"]:
		assert_true(rig._joints.has(j), "falta a junta %s" % j)
	assert_eq(rig._toes.size(), 2)


func test_torso_rotation_is_split_between_waist_and_chest() -> void:
	var rig := _spawn()
	rig._cur["spine"] = Vector3(20, 10, 0)
	rig._chest_lag = Vector3.ZERO
	rig._apply()
	var waist: Vector3 = rig._joints["spine"].rotation_degrees
	var chest: Vector3 = rig._joints["chest"].rotation_degrees
	assert_almost_eq((waist + chest).x, 20.0, 0.01)
	assert_almost_eq((waist + chest).y, 10.0, 0.01)


func test_head_rotation_is_split_with_neck() -> void:
	var rig := _spawn()
	rig._cur["head"] = Vector3(0, 40, 0)
	rig._head_off = Vector3.ZERO
	rig._apply()
	var total: float = rig._joints["neck"].rotation_degrees.y + rig._joints["head"].rotation_degrees.y
	assert_almost_eq(total, 40.0, 0.01)


func test_clavicle_rises_with_raised_arm() -> void:
	var rig := _spawn()
	rig._cur["sh_r"] = Vector3.ZERO
	assert_eq(rig._clav_raise("r"), 0.0, "braço baixo não levanta o ombro")
	rig._cur["sh_r"] = Vector3(-170, 0, 0)
	assert_gt(rig._clav_raise("r"), 10.0)


func test_soft_box_fits_its_size() -> void:
	var size := Vector3(0.4, 0.2, 0.3)
	var mesh := HumanoidRig._make_soft_box(size, 0.4)
	var aabb := mesh.get_aabb()
	assert_almost_eq(aabb.size.x, size.x, 0.01)
	assert_almost_eq(aabb.size.y, size.y, 0.01)
	assert_almost_eq(aabb.size.z, size.z, 0.01)
	var normals: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
	for n in normals:
		assert_almost_eq(n.length(), 1.0, 0.001)


func test_body_is_one_skinned_mesh_following_joints() -> void:
	var rig := _spawn()
	var skel: Skeleton3D = rig._skel
	assert_not_null(skel)
	assert_eq(skel.get_bone_count(), HumanoidRig.SKIN_BONES.size())
	var skinned := 0
	for child in skel.get_children():
		if child is MeshInstance3D and (child as MeshInstance3D).skin != null:
			skinned += 1
	assert_eq(skinned, 10, "tronco, pescoço e, de cada lado, braço, antebraço, coxa e canela")
	# Dobrar o cotovelo move o osso do cotovelo junto com a junta.
	rig._cur["el_r"] = Vector3(-90, 0, 0)
	rig._apply()
	rig._update_skin()
	var i := skel.find_bone("el_r")
	var joint_q: Quaternion = (skel.global_transform.affine_inverse() * rig._joints["el_r"].global_transform).basis.get_rotation_quaternion()
	assert_true(skel.get_bone_pose_rotation(i).is_equal_approx(joint_q))


func test_body_model_replaces_procedural_body() -> void:
	var rig: HumanoidRig = RIG.instantiate()
	rig.body_model = load("res://characters/models/elfa_rig.glb")
	add_child_autofree(rig)
	var joints := rig._load_model_joints()
	assert_false(joints.is_empty(), "lê o .json de articulações")
	# Ombro foi para a posição do modelo.
	var sh_rest: Transform3D = rig._skel.get_bone_rest(rig._skel.find_bone("sh_l"))
	assert_almost_eq(sh_rest.origin.x, (joints["sh_l"] as Vector3).x, 0.001)
	# A malha do modelo está no esqueleto do rig, com um osso ligado por nome para cada bind.
	var model_meshes := 0
	for child in rig._skel.get_children():
		if child is MeshInstance3D and (child as MeshInstance3D).skin != null:
			model_meshes += 1
			assert_gt((child as MeshInstance3D).skin.get_bind_count(), 10)
	assert_gt(model_meshes, 0)
	# Corpo procedural escondido; a arma continua visível.
	var visible_weapon := false
	for n in rig.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.get_parent() and String(mi.get_parent().name) == "WeaponSocket" and mi.visible:
			visible_weapon = true
	assert_true(visible_weapon, "arma continua visível")


func test_model_hair_lags_behind_when_moving() -> void:
	var rig: HumanoidRig = RIG.instantiate()
	rig.body_model = load("res://characters/models/elfa_rig.glb")
	add_child_autofree(rig)
	assert_true(rig._hair_on, "a elfa tem cadeia de cabelo")
	assert_eq(rig._skel.get_bone_count(), HumanoidRig.SKIN_BONES.size())
	rig._reset_hair()
	var rest_tip: Vector3 = rig._hair_p[3] - rig.global_position
	# Anda rápido para a frente (+Z): a ponta do cabelo fica para trás.
	for i in 10:
		rig.global_position += Vector3(0, 0, 0.08)
		rig._update_hair(1.0 / 60.0)
	var tip: Vector3 = rig._hair_p[3] - rig.global_position
	assert_lt(tip.z, rest_tip.z - 0.02, "ponta do cabelo atrasa em relação ao corpo")
	# Comprimento dos segmentos se mantém.
	for k in range(1, 4):
		assert_almost_eq(rig._hair_p[k].distance_to(rig._hair_p[k - 1]), rig._hair_len[k - 1], 0.001)
