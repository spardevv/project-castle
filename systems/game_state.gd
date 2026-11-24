extends Node
## Progresso e loadout globais (autoload GameState), salvos em user://save.cfg.
## Salva sozinho (no fim do quadro) quando algo muda: habilidade liberada, flag do mundo ou loadout.
## Headless (probes, GUT) ou com o argumento de usuário `--no-save`, não lê nem grava o arquivo, para os testes
## não sujarem o save do jogador; save_to()/load_from() continuam disponíveis para os testes do próprio save.

signal loadout_changed
## Emitido quando o jogador troca de summon (o player dispensa o atual).
signal summon_kind_changed

const PRIMARIES: Array[StringName] = [&"sword", &"hammer", &"spear"]
const PRIMARY_NAMES := {&"sword": "Espada longa", &"hammer": "Martelo", &"spear": "Lança"}
const SECONDARIES: Array[StringName] = [&"orb", &"shield", &"crossbow"]
const SECONDARY_NAMES := {&"orb": "Orbe de fogo", &"shield": "Escudo", &"crossbow": "Besta automática"}
const SUMMON_KINDS: Array[StringName] = [&"golem", &"priest", &"mage"]
const SUMMON_NAMES := {&"golem": "Golem de Pedra", &"priest": "Sacerdote", &"mage": "Mago"}
const SAVE_PATH := "user://save.cfg"
## Versão do formato do save (para migrar no futuro).
const SAVE_VERSION := 1
const DEFAULT_SLOTS := {&"golem": [&"grab"], &"priest": [&"heal"], &"mage": [&"banish"]}
const DEFAULT_PASSIVES := {&"golem": [&"rock"], &"priest": [&"p_blessing"], &"mage": [&"m_orbs"]}

var abilities: Dictionary = {} # StringName -> bool
var world_flags: Dictionary = {} # StringName -> Variant

## Equipamento primário (arma) e secundário (mão esquerda; só um por vez).
var primary: StringName = &"sword"
var secondary: StringName = &"orb"
## Summon ativo. Cada summon guarda seus próprios slots de skills.
var summon_kind: StringName = &"golem"

## Slots comandados (LB+X, LB+Y, LB+B, LB+A) e passivos (ataques automáticos) de cada summon.
## &"" = vazio. Ids em SummonSkills.
var _slots: Dictionary = DEFAULT_SLOTS.duplicate(true)
var _passives: Dictionary = DEFAULT_PASSIVES.duplicate(true)

## Grava/lê user://save.cfg? Desligado em headless ou com `--no-save`.
var persistence := true
var _save_queued := false

## Slots do summon ativo (a mesma lista é devolvida, então escrever nela altera o loadout).
var summon_slots: Array:
	get:
		return _slots[summon_kind]
var summon_passives: Array:
	get:
		return _passives[summon_kind]


func _ready() -> void:
	persistence = DisplayServer.get_name() != "headless" and not ("--no-save" in OS.get_cmdline_user_args())
	if persistence:
		load_from(SAVE_PATH)
	loadout_changed.connect(_queue_save)


func has_ability(ability: StringName) -> bool:
	return abilities.get(ability, false)


func unlock_ability(ability: StringName) -> void:
	abilities[ability] = true
	EventBus.ability_unlocked.emit(ability)
	_queue_save()


func get_flag(flag: StringName, default: Variant = null) -> Variant:
	return world_flags.get(flag, default)


## Marca algo do mundo (baú aberto, porta aberta...) e salva.
func set_flag(flag: StringName, value: Variant = true) -> void:
	world_flags[flag] = value
	_queue_save()


func set_primary(id: StringName) -> void:
	if id in PRIMARIES and id != primary:
		primary = id
		loadout_changed.emit()


func set_secondary(id: StringName) -> void:
	if id in SECONDARIES and id != secondary:
		secondary = id
		loadout_changed.emit()


func set_summon_kind(kind: StringName) -> void:
	if kind in SUMMON_KINDS and kind != summon_kind:
		summon_kind = kind
		summon_kind_changed.emit()
		loadout_changed.emit()


func set_summon_passive(index: int, skill_id: StringName) -> void:
	var list := summon_passives
	if index >= 0 and index < list.size() and list[index] != skill_id:
		list[index] = skill_id
		loadout_changed.emit()


func set_summon_slot(index: int, skill_id: StringName) -> void:
	var list := summon_slots
	if index >= 0 and index < list.size() and list[index] != skill_id:
		list[index] = skill_id
		loadout_changed.emit()


# --- Save ----------------------------------------------------------------------

## Pede um save no fim do quadro (várias mudanças seguidas viram uma gravação só).
func _queue_save() -> void:
	if persistence and not _save_queued:
		_save_queued = true
		_flush_save.call_deferred()


func _flush_save() -> void:
	_save_queued = false
	save_to(SAVE_PATH)


func save_to(path: String) -> Error:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "version", SAVE_VERSION)
	cfg.set_value("progress", "abilities", abilities)
	cfg.set_value("progress", "world_flags", world_flags)
	cfg.set_value("loadout", "primary", primary)
	cfg.set_value("loadout", "secondary", secondary)
	cfg.set_value("loadout", "summon_kind", summon_kind)
	cfg.set_value("loadout", "slots", _slots)
	cfg.set_value("loadout", "passives", _passives)
	return cfg.save(path)


## Lê o save. Valores inválidos (arma/summon/skill que não existe mais) voltam ao padrão.
## Retorna false se o arquivo não existe ou não abre (o estado atual fica como está).
func load_from(path: String) -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return false
	var ab: Variant = cfg.get_value("progress", "abilities", {})
	abilities = (ab as Dictionary).duplicate() if ab is Dictionary else {}
	var wf: Variant = cfg.get_value("progress", "world_flags", {})
	world_flags = (wf as Dictionary).duplicate() if wf is Dictionary else {}
	var p := StringName(str(cfg.get_value("loadout", "primary", primary)))
	primary = p if p in PRIMARIES else &"sword"
	var sec := StringName(str(cfg.get_value("loadout", "secondary", secondary)))
	secondary = sec if sec in SECONDARIES else &"orb"
	var kind := StringName(str(cfg.get_value("loadout", "summon_kind", summon_kind)))
	summon_kind = kind if kind in SUMMON_KINDS else &"golem"
	_slots = _sanitize(cfg.get_value("loadout", "slots", {}), DEFAULT_SLOTS, false)
	_passives = _sanitize(cfg.get_value("loadout", "passives", {}), DEFAULT_PASSIVES, true)
	loadout_changed.emit()
	return true


## Mantém o tamanho padrão das listas e troca ids que não estão nas escolhas liberadas pelo padrão.
func _sanitize(saved: Variant, defaults: Dictionary, passive: bool) -> Dictionary:
	var out: Dictionary = defaults.duplicate(true)
	if not saved is Dictionary:
		return out
	for kind: StringName in defaults:
		var list: Variant = (saved as Dictionary).get(kind)
		if not list is Array:
			continue
		var allowed := SummonSkills.passive_choices_for(kind) if passive else SummonSkills.choices_for(kind)
		var target: Array = out[kind]
		for i in mini(target.size(), (list as Array).size()):
			var id := StringName(str((list as Array)[i]))
			if id in allowed:
				target[i] = id
	return out


## Volta tudo ao início (progresso e loadout) e apaga o arquivo de save.
func reset_progress() -> void:
	abilities = {}
	world_flags = {}
	primary = &"sword"
	secondary = &"orb"
	summon_kind = &"golem"
	_slots = DEFAULT_SLOTS.duplicate(true)
	_passives = DEFAULT_PASSIVES.duplicate(true)
	if persistence and FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	summon_kind_changed.emit()
	loadout_changed.emit()
