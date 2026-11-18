extends GutTest
## Estâncias do ataque carregado (ChargeProfile).

var prof: ChargeProfile


func before_each() -> void:
	prof = ChargeProfile.new()


func _base_hit() -> HitData:
	var h := HitData.new()
	h.damage = 20
	h.knockback = 10.0
	h.hitstun = 0.3
	h.hitstop = 0.1
	return h


func test_array_sizes() -> void:
	assert_eq(prof.times.size(), ChargeProfile.MAX_STANCE)
	for arr in [prof.damage, prof.poise, prof.knockback, prof.hitbox, prof.armor_damage, prof.armor_poise]:
		assert_eq(arr.size(), ChargeProfile.MAX_STANCE + 1)


func test_stances_scale_monotonically() -> void:
	for i in range(1, prof.times.size()):
		assert_gt(prof.times[i], prof.times[i - 1], "times")
	for i in range(1, ChargeProfile.MAX_STANCE + 1):
		assert_gt(prof.damage[i], prof.damage[i - 1], "damage")
		assert_gt(prof.poise[i], prof.poise[i - 1], "poise")
		assert_lt(prof.armor_damage[i], prof.armor_damage[i - 1], "mais estância = menos dano recebido")
		assert_gt(prof.armor_poise[i], prof.armor_poise[i - 1], "armor_poise")


func test_stance_at() -> void:
	assert_eq(prof.stance_at(0.0), 0)
	assert_eq(prof.stance_at(prof.times[0]), 1)
	assert_eq(prof.stance_at(prof.times[1] + 0.01), 2)
	assert_eq(prof.stance_at(99.0), ChargeProfile.MAX_STANCE)


func test_stance_zero_is_identity() -> void:
	var h := prof.apply(_base_hit(), 0)
	assert_eq(h.damage, 20)
	assert_eq(h.knockback, 10.0)
	assert_false(h.poise_break)
	# -1 = golpe normal (não carregado)
	assert_eq(prof.apply(_base_hit(), -1).damage, 20)


func test_stance_one_multiplies() -> void:
	var h := prof.apply(_base_hit(), 1)
	assert_eq(h.damage, roundi(20 * prof.damage[1]))
	assert_almost_eq(h.knockback, 10.0 * prof.knockback[1], 0.001)
	assert_almost_eq(h.poise_mult, prof.poise[1], 0.001)
	assert_false(h.poise_break)
	assert_eq(h.launch, 0.0)


func test_poise_break_from_stance_two() -> void:
	assert_true(prof.apply(_base_hit(), prof.poise_break_from).poise_break)
	assert_true(prof.resists_break(prof.poise_break_from))
	assert_false(prof.resists_break(prof.poise_break_from - 1))


func test_max_stance_launches() -> void:
	var h := prof.apply(_base_hit(), ChargeProfile.MAX_STANCE)
	assert_eq(h.launch, prof.max_launch)
	assert_eq(h.hitstun, prof.max_hitstun)
	assert_true(prof.is_unshakable(ChargeProfile.MAX_STANCE))
	assert_false(prof.is_unshakable(ChargeProfile.MAX_STANCE - 1))


func test_every_weapon_has_a_profile() -> void:
	for ms in [LongSword.new(), Hammer.new(), Spear.new()]:
		assert_not_null(ms.charge, ms.display_name)
