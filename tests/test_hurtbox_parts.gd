extends GutTest
## Hurtbox por partes do corpo: cápsulas seguem o rig (em pé, caído) e acertos só onde o corpo está.

const GRUNT := preload("res://enemies/enemy.tscn")


func _spawn() -> Enemy:
	var en: Enemy = GRUNT.instantiate()
	add_child_autofree(en)
	en.attack_cd = 99.0
	return en


func _part(en: Enemy, part_name: String) -> Dictionary:
	for p in en.hurtbox.parts:
		if p["name"] == part_name:
			return p
	return {}


func test_parts_are_built_from_rig() -> void:
	var en := _spawn()
	await wait_physics_frames(2)
	assert_eq(en.hurtbox.parts.size(), 16, "cabeça, peito, barriga, pelve + 6 por lado")
	for child in en.hurtbox.get_children():
		if child is CollisionShape3D and not str(child.name).begins_with("Part_"):
			assert_true((child as CollisionShape3D).disabled, "a cápsula fixa da cena fica desligada")


func test_head_is_high_when_standing() -> void:
	var en := _spawn()
	await wait_physics_frames(2)
	var head := en.hurtbox.part_segment(_part(en, "head"))
	assert_gt(head[0].y - en.global_position.y, 1.4)


func test_parts_follow_knockdown_pose() -> void:
	var en := _spawn()
	await wait_physics_frames(2)
	en.rig.set_knockdown(0.9, 2.0) # deitado no chão
	en.rig.snap()
	en.hurtbox.update_parts()
	var head := en.hurtbox.part_segment(_part(en, "head"))
	assert_lt(head[0].y - en.global_position.y, 0.8, "caído, a cabeça fica perto do chão")


func test_closest_point_lies_on_weapon_segment() -> void:
	var en := _spawn()
	await wait_physics_frames(2)
	var a := en.global_position + Vector3(-1.0, 1.2, 0.0)
	var b := en.global_position + Vector3(1.0, 1.2, 0.0)
	var p := en.hurtbox.closest_point(a, b)
	assert_almost_eq(p.y, a.y, 0.001)
	assert_lt(absf(p.x - en.global_position.x), 0.55, "contato dentro da largura do corpo")


func test_sweep_above_lying_enemy_misses() -> void:
	var en := _spawn()
	await wait_physics_frames(2)
	en.rig.set_knockdown(0.9, 2.0)
	en.rig.snap()
	en.hurtbox.update_parts()
	await wait_physics_frames(1)
	var shape := CapsuleShape3D.new()
	shape.radius = 0.15
	shape.height = 2.3
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = shape
	params.collide_with_areas = true
	params.collide_with_bodies = false
	params.collision_mask = en.hurtbox.collision_layer
	# Corte horizontal na altura do peito de quem está em pé: passa por cima de quem está deitado.
	params.transform = Transform3D(Basis(Vector3.FORWARD, PI * 0.5), en.global_position + Vector3(0, 1.3, 0))
	var hits := en.get_world_3d().direct_space_state.intersect_shape(params, 32)
	assert_eq(hits.size(), 0)
