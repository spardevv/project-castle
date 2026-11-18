extends GutTest
## Health: dano, invulnerabilidade, i-frames, filtro de golpe e cura.

var health: Health


func before_each() -> void:
	health = Health.new()
	health.max_health = 100
	add_child_autofree(health)


func _hit(damage: int) -> HitData:
	var h := HitData.new()
	h.damage = damage
	return h


func test_starts_full() -> void:
	assert_eq(health.current, 100)


func test_take_hit_reduces_and_emits() -> void:
	watch_signals(health)
	assert_true(health.take_hit(_hit(30)))
	assert_eq(health.current, 70)
	assert_eq(health.last_damage, 30)
	assert_signal_emitted(health, "damaged")
	assert_signal_emitted_with_parameters(health, "changed", [70, 100])


func test_damage_clamps_at_zero_and_dies_once() -> void:
	watch_signals(health)
	health.take_hit(_hit(250))
	assert_eq(health.current, 0)
	assert_signal_emit_count(health, "died", 1)
	assert_false(health.take_hit(_hit(10)), "morto não recebe mais golpes")
	assert_signal_emit_count(health, "died", 1)


func test_invulnerable_ignores_hit() -> void:
	health.invulnerable = true
	assert_false(health.take_hit(_hit(30)))
	assert_eq(health.current, 100)


func test_iframes_expire() -> void:
	health.grant_iframes(0.2)
	assert_false(health.take_hit(_hit(10)))
	health._process(0.25)
	assert_true(health.take_hit(_hit(10)))
	assert_eq(health.current, 90)


func test_grant_iframes_keeps_longest() -> void:
	health.grant_iframes(0.5)
	health.grant_iframes(0.1)
	health._process(0.3)
	assert_true(health.is_invulnerable())


func test_hit_filter_modifies_damage() -> void:
	health.hit_filter = func(h: HitData) -> HitData:
		var copy: HitData = h.duplicate()
		copy.damage = h.damage / 2
		return copy
	health.take_hit(_hit(40))
	assert_eq(health.current, 80)
	assert_eq(health.last_damage, 20)


func test_heal_caps_and_returns_amount() -> void:
	health.take_hit(_hit(30))
	assert_eq(health.heal(50), 30)
	assert_eq(health.current, 100)


func test_dead_cannot_be_healed() -> void:
	health.take_hit(_hit(100))
	assert_eq(health.heal(50), 0)
	assert_eq(health.current, 0)


func test_heal_over_time_accumulates_fractions() -> void:
	health.take_hit(_hit(10))
	for i in 4:
		health.heal_over_time(0.5)
	assert_eq(health.current, 92)
