extends GutTest
## Save do progresso (GameState.save_to / load_from / reset_progress). Usa arquivos temporários em user://;
## em headless o GameState não toca no user://save.cfg do jogador.

const TMP := "user://test_save.cfg"
const BACKUP := "user://test_save_backup.cfg"


func before_each() -> void:
	GameState.save_to(BACKUP)
	GameState.reset_progress()


func after_each() -> void:
	GameState.load_from(BACKUP)
	for path in [TMP, BACKUP]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_headless_does_not_persist() -> void:
	assert_false(GameState.persistence, "probes/GUT não gravam o save do jogador")


func test_round_trip() -> void:
	SummonSkills.unlock(&"quake")
	GameState.set_flag(&"chest_a")
	GameState.set_primary(&"hammer")
	GameState.set_secondary(&"shield")
	GameState.set_summon_kind(&"golem")
	GameState.set_summon_slot(0, &"quake")
	assert_eq(GameState.save_to(TMP), OK)
	GameState.reset_progress()
	assert_false(SummonSkills.is_unlocked(&"quake"), "reset apaga o desbloqueio")
	assert_true(GameState.load_from(TMP))
	assert_true(SummonSkills.is_unlocked(&"quake"))
	assert_true(GameState.get_flag(&"chest_a", false))
	assert_eq(GameState.primary, &"hammer")
	assert_eq(GameState.secondary, &"shield")
	assert_eq(GameState._slots[&"golem"][0], &"quake")


func test_invalid_values_fall_back_to_default() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("loadout", "primary", &"machado_que_nao_existe")
	cfg.set_value("loadout", "summon_kind", &"dragao")
	# quake não foi liberada: o slot volta ao padrão; lista maior que o padrão é cortada.
	cfg.set_value("loadout", "slots", {&"golem": [&"quake", &"taunt"]})
	cfg.save(TMP)
	assert_true(GameState.load_from(TMP))
	assert_eq(GameState.primary, &"sword")
	assert_eq(GameState.summon_kind, &"golem")
	assert_eq(GameState._slots[&"golem"], [&"grab"])


func test_missing_file_keeps_state() -> void:
	GameState.set_primary(&"spear")
	assert_false(GameState.load_from("user://nao_existe.cfg"))
	assert_eq(GameState.primary, &"spear")
