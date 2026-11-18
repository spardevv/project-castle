extends GutTest
## Poise, super armor e parry dos inimigos (cenas reais de grunt e brutamontes).

const GRUNT := preload("res://enemies/enemy.tscn")
const BRUTE := preload("res://enemies/brute.tscn")


func _spawn(scene: PackedScene) -> Enemy:
	var en: Enemy = scene.instantiate()
	add_child_autofree(en)
	en.attack_cd = 99.0
	return en


func _hit(damage: int, poise_mult := 1.0) -> HitData:
	var h := HitData.new()
	h.damage = damage
	h.poise_mult = poise_mult
	h.hitstun = 0.3
	return h


func test_unarmored_grunt_staggers_on_any_hit() -> void:
	var en := _spawn(GRUNT)
	assert_eq(en.machine.current_name(), "Idle")
	en.health.take_hit(_hit(1))
	assert_eq(en.machine.current_name(), "Stagger")
	assert_eq(en.health.current, 59)


func test_brute_absorbs_light_hits() -> void:
	var en := _spawn(BRUTE)
	en.health.take_hit(_hit(20))
	assert_ne(en.machine.current_name(), "Stagger", "super armor segura golpe leve")
	assert_almost_eq(en.poise, en.poise_max - 20.0, 0.01)


func test_brute_poise_breaks_after_enough_damage() -> void:
	var en := _spawn(BRUTE)
	var hits := 0
	while en.machine.current_name() != "Stagger" and hits < 20:
		en.health.take_hit(_hit(20))
		hits += 1
	assert_eq(en.machine.current_name(), "Stagger")
	assert_eq(hits, ceili(en.poise_max / 20.0), "quebra exatamente quando o poise zera")
	assert_eq(en.poise, en.poise_max, "poise volta cheio ao cambalear")


func test_poise_mult_speeds_up_break() -> void:
	var en := _spawn(BRUTE)
	en.health.take_hit(_hit(20, 2.5)) # martelo: 50 de poise
	assert_almost_eq(en.poise, en.poise_max - 50.0, 0.01)


func test_poise_break_ignores_armor() -> void:
	var en := _spawn(BRUTE)
	var h := _hit(5)
	h.poise_break = true
	en.health.take_hit(h)
	assert_eq(en.machine.current_name(), "Stagger")


func test_brute_is_not_broken_by_launch() -> void:
	var en := _spawn(BRUTE)
	var h := _hit(5)
	h.launch = 8.0
	en.health.take_hit(h)
	assert_ne(en.machine.current_name(), "Stagger", "brutamontes não é lançado")


func test_launch_breaks_grunt_armor() -> void:
	var en := _spawn(GRUNT)
	en.machine.change_to(&"Attack")
	var h := _hit(5)
	h.launch = 8.0
	en.health.take_hit(h)
	assert_eq(en.machine.current_name(), "Stagger")


func test_parried_opens_enemy() -> void:
	var en := _spawn(BRUTE)
	en.poise = 3.0
	en.parried(null)
	assert_eq(en.machine.current_name(), "Stagger")
	assert_eq(en.poise, en.poise_max)


func test_poise_regenerates_outside_stagger() -> void:
	var en := _spawn(BRUTE)
	en.poise = 10.0
	en.tick(1.0)
	assert_almost_eq(en.poise, 10.0 + en.poise_regen, 0.01)
