extends GutTest
## Skills guardadas dos summons só entram nas escolhas do menu depois de liberadas por recompensa.

var _saved: Dictionary


func before_each() -> void:
	_saved = GameState.abilities.duplicate()
	GameState.abilities.clear()


func after_each() -> void:
	GameState.abilities = _saved


func test_locked_skill_hidden_until_unlocked() -> void:
	assert_eq(SummonSkills.choices_for(&"golem"), SummonSkills.GOLEM_CHOICES, "só o kit inicial")
	assert_true(SummonSkills.unlock(&"quake"))
	assert_has(SummonSkills.choices_for(&"golem"), &"quake")
	assert_does_not_have(SummonSkills.choices_for(&"mage"), &"quake", "não vaza para outro summon")


func test_unlock_twice_or_unknown_returns_false() -> void:
	assert_true(SummonSkills.unlock(&"blast"))
	assert_false(SummonSkills.unlock(&"blast"))
	assert_false(SummonSkills.unlock(&"nao_existe"))


func test_passive_unlock_is_separate_from_active() -> void:
	assert_true(SummonSkills.unlock_passive(&"slam"))
	assert_has(SummonSkills.passive_choices_for(&"golem"), &"slam")
	assert_does_not_have(SummonSkills.choices_for(&"golem"), &"slam")


func test_unlock_emits_event() -> void:
	watch_signals(EventBus)
	SummonSkills.unlock(&"ward")
	assert_signal_emitted(EventBus, "ability_unlocked")
