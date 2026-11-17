extends Node
## Progresso e loadout globais (autoload GameState). Será a base do save na Fase 2.

signal loadout_changed
## Emitido quando o jogador troca de summon (o player dispensa o atual).
signal summon_kind_changed

const PRIMARIES: Array[StringName] = [&"sword", &"hammer"]
const PRIMARY_NAMES := {&"sword": "Espada longa", &"hammer": "Martelo"}
const SECONDARIES: Array[StringName] = [&"orb", &"shield"]
const SECONDARY_NAMES := {&"orb": "Orbe de fogo", &"shield": "Escudo"}
const SUMMON_KINDS: Array[StringName] = [&"golem", &"priest"]
const SUMMON_NAMES := {&"golem": "Golem de Pedra", &"priest": "Sacerdote"}

var abilities: Dictionary = {} # StringName -> bool
var world_flags: Dictionary = {} # StringName -> Variant

## Equipamento primário (arma) e secundário (mão esquerda; só um por vez).
var primary: StringName = &"sword"
var secondary: StringName = &"orb"
## Summon ativo. Cada summon guarda seus próprios slots de skills.
var summon_kind: StringName = &"golem"

## Slots comandados (LB+X, LB+Y, LB+B, LB+A) e passivos (ataques automáticos) de cada summon.
## &"" = vazio. Ids em SummonSkills.
var _slots := {
	&"golem": [&"quake", &"taunt", &"grab", &"rock"],
	&"priest": [&"heal", &"bless", &"hex", &"smite"],
}
var _passives := {
	&"golem": [&"slam", &"combo"],
	&"priest": [&"p_aura", &"p_heal"],
}

## Slots do summon ativo (a mesma lista é devolvida, então escrever nela altera o loadout).
var summon_slots: Array:
	get:
		return _slots[summon_kind]
var summon_passives: Array:
	get:
		return _passives[summon_kind]


func has_ability(ability: StringName) -> bool:
	return abilities.get(ability, false)


func unlock_ability(ability: StringName) -> void:
	abilities[ability] = true
	EventBus.ability_unlocked.emit(ability)


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
