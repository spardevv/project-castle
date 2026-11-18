extends GutTest
## Integridade dos movesets e dos golpes (.tres): grafo de combos, resolve() e sanidade dos números.

func _all_sets() -> Array[MoveSet]:
	return [LongSword.new(), Hammer.new(), Spear.new()]


func _all_moves(ms: MoveSet) -> Array[AttackData]:
	var out: Array[AttackData] = []
	for d in ms.moves.values():
		out.append(d)
	out.append_array(ms.art_sequence)
	return out


## Mesma busca de Poses.attack(): alias, tabela principal e poses da lança.
func _has_pose(anim: String) -> bool:
	return Poses.ATTACKS.has(Poses.ALIAS.get(anim, anim)) or Poses._spear_defs().has(anim)


func test_every_edge_and_start_points_to_existing_move() -> void:
	for ms in _all_sets():
		for table in [ms.start, ms.start_air]:
			assert_true(table.has("tap"), "%s: start sem 'tap'" % ms.display_name)
			for k in table:
				assert_true(ms.moves.has(table[k]), "%s: start '%s' -> '%s' inexistente" % [ms.display_name, k, table[k]])
		for from_id in ms.edges:
			assert_true(ms.moves.has(from_id), "%s: aresta de '%s' inexistente" % [ms.display_name, from_id])
			for k in ms.edges[from_id]:
				var to: String = ms.edges[from_id][k]
				assert_true(ms.moves.has(to), "%s: %s.%s -> '%s' inexistente" % [ms.display_name, from_id, k, to])


func test_every_move_id_matches_its_key() -> void:
	for ms in _all_sets():
		for id in ms.moves:
			assert_eq(ms.moves[id].id, id, "%s: id do .tres difere da chave" % ms.display_name)


func test_art_has_three_hits() -> void:
	for ms in _all_sets():
		assert_eq(ms.art_sequence.size(), 3, ms.display_name)
		for d in ms.art_sequence:
			assert_not_null(d, "%s: golpe da arte não carregou" % ms.display_name)


func test_every_ground_combo_has_a_charge() -> void:
	for ms in _all_sets():
		var first: String = ms.start["tap"]
		assert_true(ms.has_edge(first, "hold"), "%s: primeiro golpe sem 'hold'" % ms.display_name)


func test_attack_numbers_are_sane() -> void:
	for ms in _all_sets():
		for d in _all_moves(ms):
			var who := "%s/%s" % [ms.display_name, d.id]
			assert_gt(d.damage, 0, who + " dano")
			assert_gt(d.startup, 0.0, who + " startup")
			assert_gt(d.active, 0.0, who + " active")
			assert_true(d.recovery >= 0.0, who + " recovery")
			assert_true(d.poise_mult > 0.0, who + " poise_mult")
			assert_true(_has_pose(d.anim_id()), who + " anim '%s' sem pose" % d.anim_id())
			# cancel_start 99 = golpe que não encadeia; senão precisa caber no golpe.
			assert_true(d.cancel_start >= 99.0 or d.cancel_start <= d.total_time(), who + " cancel_start")


func test_spear_is_fully_two_handed() -> void:
	for d in _all_moves(Spear.new()):
		assert_true(d.two_handed, "lança/%s" % d.id)


func test_two_handed_anims_lookup() -> void:
	var anims := AttackData.two_handed_anims()
	assert_true(anims.has("hm_smash"))
	assert_true(anims.has("overhead"))
	assert_false(anims.has("a1"), "corte leve da espada é de uma mão")


func test_resolve_follows_tap_chain() -> void:
	var ms := LongSword.new()
	var first := ms.resolve("", "tap", "neutral", false)
	assert_eq(first.id, ms.start["tap"])
	var second := ms.resolve(first.id, "tap", "neutral", false)
	assert_eq(second.id, ms.edges[first.id]["tap"])


func test_resolve_uses_direction_from_neutral() -> void:
	var ms := Hammer.new()
	assert_eq(ms.resolve("", "tap", "fwd", false).id, "h_lunge")
	assert_eq(ms.resolve("", "tap", "back", false).id, "h_rising")
	assert_eq(ms.resolve("", "tap", "back", true).id, "h_plunge")


func test_resolve_falls_back_to_start_without_edge() -> void:
	var ms := Spear.new()
	# s3 é fim de combo: o próximo toque recomeça o moveset.
	assert_eq(ms.resolve("s3", "tap", "neutral", false).id, "s1")


func test_resolve_hold_goes_to_charge() -> void:
	for ms in _all_sets():
		var first: String = ms.start["tap"]
		var charged := ms.resolve(first, "hold", "neutral", false)
		assert_eq(charged.id, ms.edges[first]["hold"], ms.display_name)


func test_make_hit_data_copies_fields() -> void:
	var d: AttackData = load("res://data/attacks/hammer/h_charge.tres")
	var h := d.make_hit_data()
	assert_eq(h.damage, d.damage)
	assert_eq(h.knockback, d.knockback)
	assert_eq(h.hitstun, d.hitstun)
	assert_eq(h.poise_break, d.poise_break)
	assert_eq(h.poise_mult, d.poise_mult)
	assert_true(h != d.make_hit_data(), "cada acerto recebe uma cópia nova")
