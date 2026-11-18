extends GutTest
## Defesa do jogador: stance (poise), escudo, guarda/parry e mitigação do ataque carregado.

const PLAYER := preload("res://player/player.tscn")

var p: Player
var _old_secondary: StringName
var _old_primary: StringName


func before_each() -> void:
	_old_secondary = GameState.secondary
	_old_primary = GameState.primary
	GameState.set_secondary(&"orb")
	GameState.set_primary(&"sword")
	p = PLAYER.instantiate()
	add_child_autofree(p)


func after_each() -> void:
	GameState.set_secondary(_old_secondary)
	GameState.set_primary(_old_primary)
	Engine.time_scale = 1.0


func _hit(damage: int) -> HitData:
	var h := HitData.new()
	h.damage = damage
	h.hitstun = 0.3
	h.knockback = 5.0
	return h


func _guard() -> void:
	p.machine.change_to(&"Guard")
	p.machine.current.time = 0.0


func test_light_hit_does_not_stagger() -> void:
	p.health.take_hit(_hit(int(Player.POISE_BASE) - 2))
	assert_ne(p.machine.current_name(), "Hurt")


func test_hit_over_poise_staggers() -> void:
	p.health.take_hit(_hit(int(Player.POISE_BASE) + 1))
	assert_eq(p.machine.current_name(), "Hurt")
	assert_eq(p.poise, p.poise_max())


func test_bare_guard_reduces_damage() -> void:
	_guard()
	p.health.take_hit(_hit(20))
	assert_eq(p.health.last_damage, roundi(20 * GuardProfile.bare().damage_multiplier))


func test_bare_guard_has_no_parry() -> void:
	_guard()
	p.health.take_hit(_hit(20))
	assert_ne(p.health.last_tag, "PARRY")
	assert_gt(p.health.last_damage, 0)


func test_shield_cuts_damage_without_guard() -> void:
	GameState.set_secondary(&"shield")
	p.health.take_hit(_hit(40))
	assert_eq(p.health.last_damage, roundi(40 * Player.SHIELD_DAMAGE_MULT))


func test_shield_parry_window_negates() -> void:
	GameState.set_secondary(&"shield")
	_guard()
	var before := p.health.current
	p.health.take_hit(_hit(40))
	assert_eq(p.health.last_tag, "PARRY")
	assert_eq(p.health.current, before)
	assert_eq(p.machine.current_name(), "Guard")


func test_shield_block_after_parry_window() -> void:
	GameState.set_secondary(&"shield")
	_guard()
	p.machine.current.time = p.guard_profile.parry_window + 0.05
	p.health.take_hit(_hit(40))
	assert_ne(p.health.last_tag, "PARRY")
	assert_eq(p.health.last_damage, 0, "escudo levantado nega o dano")
	assert_eq(p.machine.current_name(), "Guard", "bloqueio sem colisão")


func test_parry_gives_art_meter() -> void:
	GameState.set_secondary(&"shield")
	_guard()
	var before := p.art_meter
	p.health.take_hit(_hit(10))
	assert_gt(p.art_meter, before)


func test_charge_armor_mitigates_damage() -> void:
	p.armor_level = 2
	p.health.take_hit(_hit(40))
	assert_eq(p.health.last_damage, roundi(40 * p.moveset.charge.armor_damage[2]))


func test_max_stance_is_unshakable() -> void:
	p.armor_level = ChargeProfile.MAX_STANCE
	p.health.take_hit(_hit(80))
	assert_ne(p.machine.current_name(), "Hurt")


func test_max_stance_still_launched() -> void:
	p.armor_level = ChargeProfile.MAX_STANCE
	var h := _hit(10)
	h.launch = 6.0
	p.health.take_hit(h)
	assert_eq(p.machine.current_name(), "Hurt")


func test_high_stance_resists_poise_break() -> void:
	p.armor_level = p.moveset.charge.poise_break_from
	var h := _hit(2)
	h.poise_break = true
	p.health.take_hit(h)
	assert_ne(p.machine.current_name(), "Hurt")


func test_low_stance_broken_by_poise_break() -> void:
	p.armor_level = 0
	var h := _hit(2)
	h.poise_break = true
	p.health.take_hit(h)
	assert_eq(p.machine.current_name(), "Hurt")


func test_dodge_is_invulnerable() -> void:
	p.machine.change_to(&"Dodge")
	assert_false(p.health.take_hit(_hit(30)), "esquiva tem i-frames no início")
