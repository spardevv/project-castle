class_name EnchantedChest
extends Node3D
## Baú encantado: só abre se o jogador estiver com o Sacerdote invocado (e a Benção equipada) e apertar o
## botão de interação perto dele. Fica no grupo "interactable"; o Player chama interact(player).
## Recompensa configurável: `reward_kind = "skill"` libera uma skill guardada de summon (SummonSkills.unlock /
## unlock_passive) e `"heal"` cura o jogador. Com `chest_id`, fica aberto entre recargas da cena
## (GameState.world_flags). Sempre emite `opened`.

signal opened(by: Node3D)

const HINT_RANGE := 3.2
const GOLD := Color(1.0, 0.9, 0.5)

@export_enum("skill", "heal") var reward_kind: String = "skill"
## Id da skill ativa (SummonSkills.LIBRARY) ou passiva (SummonSkills.PASSIVES, com `reward_is_passive`).
@export var reward_skill: StringName = &""
@export var reward_is_passive := false
## Fração da vida máxima curada quando `reward_kind = "heal"`.
@export_range(0.0, 1.0) var heal_fraction := 1.0
## Id para lembrar que este baú já foi aberto (vazio = não lembra).
@export var chest_id: StringName = &""

var is_open := false

var _lid: MeshInstance3D
var _hint: Label3D


func _ready() -> void:
	add_to_group("interactable")
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.35, 0.22, 0.12)
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(0.9, 0.8, 0.35)
	glow.emission_enabled = true
	glow.emission = Color(1.0, 0.85, 0.35)
	glow.emission_energy_multiplier = 1.5
	var base := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.2, 0.6, 0.8)
	bm.material = wood
	base.mesh = bm
	base.position.y = 0.3
	add_child(base)
	_lid = MeshInstance3D.new()
	var lm := BoxMesh.new()
	lm.size = Vector3(1.24, 0.25, 0.84)
	lm.material = glow
	_lid.mesh = lm
	_lid.position = Vector3(0, 0.72, 0)
	add_child(_lid)
	var col := StaticBody3D.new()
	col.collision_layer = 1 << 0
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.2, 0.85, 0.8)
	cs.shape = box
	cs.position.y = 0.42
	col.add_child(cs)
	add_child(col)
	_hint = Label3D.new()
	_hint.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_hint.no_depth_test = true
	_hint.pixel_size = 0.006
	_hint.position = Vector3(0, 1.6, 0)
	_hint.visible = false
	add_child(_hint)
	if chest_id != &"" and GameState.world_flags.get(chest_id, false):
		is_open = true
		_lid.rotation_degrees.x = -100.0


func _process(_delta: float) -> void:
	var p := get_tree().get_first_node_in_group("player") as Node3D
	if is_open or p == null or p.global_position.distance_to(global_position) > HINT_RANGE:
		_hint.visible = false
		return
	_hint.visible = true
	if _priest_present(p):
		_hint.text = "[%s] Abrir" % InputGlyphs.label(&"interact")
		_hint.modulate = GOLD
	else:
		_hint.text = "Baú encantado\n(precisa do Sacerdote)"
		_hint.modulate = Color(0.75, 0.7, 0.9)


func _priest_present(p: Node) -> bool:
	if not p.has_method("has_summon") or not p.has_summon():
		return false
	var s: Variant = p.get("summon")
	return s != null and s.has_method("can_open_enchanted") and s.can_open_enchanted()


## Chamado pelo Player ao apertar interagir perto. Retorna true se abriu.
func interact(by: Node3D) -> bool:
	if is_open:
		return false
	if not _priest_present(by):
		Sfx.play(&"denied", global_position)
		Fx.damage_number(self, global_position + Vector3(0, 1.4, 0), 0, Color(0.75, 0.7, 0.9), "Selado")
		return false
	is_open = true
	Sfx.play(&"heal", global_position + Vector3(0, 0.8, 0), 0.0, 1.2)
	Fx.burst(self, global_position + Vector3(0, 0.8, 0), 1.6, Color(1.0, 0.9, 0.5), 0.6)
	var tw := create_tween()
	tw.tween_property(_lid, "rotation_degrees:x", -100.0, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if chest_id != &"":
		GameState.world_flags[chest_id] = true
	_give_reward(by)
	opened.emit(by)
	return true


## Entrega a recompensa e mostra o que foi ganho flutuando sobre o baú.
func _give_reward(by: Node3D) -> void:
	var text := ""
	if reward_kind == "heal":
		var hp: Health = by.get("health") as Health
		if hp != null:
			hp.heal(ceili(hp.max_health * heal_fraction))
		text = "Vida restaurada"
	elif reward_is_passive:
		if SummonSkills.unlock_passive(reward_skill):
			text = "Nova passiva: %s" % SummonSkills.passive_name(reward_skill)
	elif SummonSkills.unlock(reward_skill):
		text = "Nova skill: %s" % SummonSkills.name_of(reward_skill)
	if text != "":
		Fx.damage_number(self, global_position + Vector3(0, 1.8, 0), 0, GOLD, text)
