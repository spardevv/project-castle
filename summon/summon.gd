class_name Summon
extends CharacterBody3D
## Golem de Pedra (primeiro summon): segue o jogador e luta sozinho com socos, pisadas e pedras.
## Skills comandadas (LB + botão) vêm do loadout; passivas são usadas automaticamente em combate.

const BASIC := {
	"name": "basic", "anim": "punch_r", "area": true, "windup": 0.34, "active": 0.12, "recovery": 0.5,
	"damage": 9, "knockback": 5.0, "hitstun": 0.3,
	"size": Vector3(2.0, 1.7, 1.8), "offset": Vector3(0, 1.1, 1.2), "lunge": 3.0,
}
const SLAM := {
	"name": "slam", "anim": "e_smash", "area": true, "windup": 0.65, "active": 0.15, "recovery": 0.7,
	"damage": 18, "knockback": 9.0, "hitstun": 0.5,
	"size": Vector3(4.4, 1.9, 4.4), "offset": Vector3(0, 1, 0.0), "lunge": 0.0,
}
const SPIN := {
	"name": "spin", "anim": "spin", "area": true, "windup": 0.3, "active": 0.3, "recovery": 0.5,
	"damage": 14, "knockback": 8.0, "hitstun": 0.5,
	"size": Vector3(4.6, 1.9, 4.6), "offset": Vector3(0, 1, 0.0), "lunge": 0.0,
}
const JUMP_VELOCITY := 9.0


## Golpe nº `index` (0-based) de uma sequência de `total` socos alternando os braços.
## O último é mais forte e derruba. O estado Strike encadeia o próximo sozinho (combo_left).
static func punch_hit(index: int, total: int, dmg: int) -> Dictionary:
	var last := index == total - 1
	return {
		"name": "punch", "anim": "punch_r" if index % 2 == 0 else "punch_l", "area": true,
		"windup": 0.26 if last else 0.18, "active": 0.1, "recovery": 0.4 if last else 0.1,
		"damage": dmg + (6 if last else 0), "knockback": 9.5 if last else 4.0, "hitstun": 0.5 if last else 0.3,
		"size": Vector3(2.0, 1.7, 1.9), "offset": Vector3(0, 1.1, 1.2), "lunge": 4.5 if last else 3.0,
		"index": index, "total": total, "dmg": dmg, "combo_left": total - 1 - index,
	}

## Como chega ao ser invocado: "meteor" (cai do céu, dano em área) ou "holy" (explosão de cura).
@export var arrival: StringName = &"meteor"
@export var speed := 6.5
@export var follow_distance := 3.0
@export var aggro_range := 12.0
@export var attack_range := 1.8
@export var grab_radius := 10.0
@export var contact_radius := 0.7
@export var contact_mass := 4.0

var contact_enabled := true

var owner_player: Node3D
var attack_cd := 0.0
var slam_cd := 0.0 # (legado) a pancada agora é uma passiva
var hold_height := 1.2 # altura do inimigo agarrado (animada pelo estado Grab)
var dodge_cd := 0.0
var jump_cd := 0.0
## Cooldown restante de cada skill passiva equipada (id -> segundos).
var passive_timers: Dictionary = {}
## Skills comandadas pelo jogador, uma por slot (LB+X, LB+Y, LB+B, LB+A), vindas do loadout.
## Cada uma: {"id", "name", "cooldown", "timer"}; id vazio = slot vazio.
var skills: Array[Dictionary] = []

@onready var visual: Node3D = $Visual
@onready var rig: HumanoidRig = $Visual/Rig
@onready var health: Health = $Health
@onready var hitbox: Hitbox = $Visual/Hitbox
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var machine: StateMachine = $StateMachine

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")


func _ready() -> void:
	add_to_group("summon")
	add_to_group("body_contact")
	collision_layer = 0
	collision_mask = 1 << 0 # world
	hitbox.source = self
	hitbox.sweep_rig = rig
	hitbox.sweep_radius = 0.2
	health.damaged.connect(func(_hit: HitData) -> void: rig.flash(Color(1, 1, 1)))
	health.died.connect(func() -> void: machine.change_to(&"Dead"))
	var cs := hitbox.get_node("CollisionShape3D") as CollisionShape3D
	cs.shape = cs.shape.duplicate()
	GameState.loadout_changed.connect(_load_skills)
	_load_skills()
	machine.start(self)


## Monta os slots a partir do loadout, preservando cooldowns de skills que continuam equipadas.
func _load_skills() -> void:
	var old_timers := {}
	for s in skills:
		old_timers[s["id"]] = s["timer"]
	skills.clear()
	for id in GameState.summon_slots:
		skills.append({
			"id": id, "name": SummonSkills.name_of(id),
			"cooldown": SummonSkills.cooldown_of(id), "timer": old_timers.get(id, 0.0),
		})


func tick(delta: float) -> void:
	attack_cd = maxf(attack_cd - delta, 0.0)
	slam_cd = maxf(slam_cd - delta, 0.0)
	dodge_cd = maxf(dodge_cd - delta, 0.0)
	jump_cd = maxf(jump_cd - delta, 0.0)
	for id in passive_timers.keys():
		passive_timers[id] = maxf(float(passive_timers[id]) - delta, 0.0)
	for s in skills:
		s["timer"] = maxf(s["timer"] - delta, 0.0)


## Hit-stop local (chamado pelo GameFeel).
func hit_pause(duration: float, shake_body := false) -> void:
	machine.freeze(duration)
	rig.freeze(duration, shake_body)


## Dispensar: animação própria de saída (sem skill). Quem morre em combate usa o estado Dead.
func dismiss() -> void:
	var n := machine.current_name()
	if n != "Dead" and n != "Dismiss":
		machine.change_to(&"Dismiss")


## Invocação: entra com a animação/skill de chegada no ponto indicado (meteoro ou explosão de cura).
func arrive(spot: Vector3) -> void:
	machine.change_to(&"Arrive", {"spot": spot})


## Comanda a skill do slot (0 = LB+X). Retorna true se foi usada.
func use_skill(index: int) -> bool:
	if index >= skills.size() or skills[index]["id"] == &"" or skills[index]["timer"] > 0.0:
		return false
	var n := machine.current_name()
	if n == "Dead" or n == "Skill":
		return false
	skills[index]["timer"] = skills[index]["cooldown"]
	match skills[index]["id"]:
		&"punches":
			machine.change_to(&"Strike", punch_hit(0, 5, 9))
		&"rock":
			machine.change_to(&"Rock")
		&"grab":
			machine.change_to(&"Grab")
		var id:
			machine.change_to(&"Skill", {"id": id})
	return true


## Ponto onde o golem segura o inimigo agarrado (acima das mãos, à frente).
func hold_point() -> Vector3:
	return global_position + forward() * 0.8 + Vector3.UP * hold_height


## Inimigo mais próximo da criatura entre os que estão perto do jogador.
func find_target() -> Node3D:
	if not is_instance_valid(owner_player):
		return null
	var best: Node3D = null
	var best_d := INF
	for e in get_tree().get_nodes_in_group("enemy"):
		var en := e as Node3D
		if en.global_position.distance_to(owner_player.global_position) > aggro_range:
			continue
		var d := en.global_position.distance_to(global_position)
		if d < best_d:
			best_d = d
			best = en
	return best


## Escolhe uma skill passiva pronta cujas condições (distância ao alvo, inimigos por perto) valem agora.
func pick_passive(dist: float) -> StringName:
	for id in GameState.summon_passives:
		if id == &"" or not SummonSkills.PASSIVES.has(id) or float(passive_timers.get(id, 0.0)) > 0.0:
			continue
		var def: Dictionary = SummonSkills.PASSIVES[id]
		if dist < float(def["min"]) or dist > float(def["max"]):
			continue
		if int(def["crowd"]) > 0 and count_enemies_within(float(def["crowd_radius"])) < int(def["crowd"]):
			continue
		return id
	return &""


## Executa a passiva: entra no estado certo e inicia o cooldown.
func start_passive(id: StringName) -> void:
	passive_timers[id] = float(SummonSkills.PASSIVES[id]["cooldown"])
	match id:
		&"slam":
			machine.change_to(&"Strike", SLAM)
		&"spin":
			machine.change_to(&"Strike", SPIN)
		&"combo":
			machine.change_to(&"Strike", punch_hit(0, 3, 8))
		&"rock":
			machine.change_to(&"Rock")
		&"leap":
			machine.change_to(&"Leap")


## Pula quando o jogador (ou o alvo) está num nível acima — degraus, plataformas.
func try_jump() -> void:
	if jump_cd > 0.0 or not is_on_floor():
		return
	var want := false
	if is_instance_valid(owner_player):
		var d := owner_player.global_position - global_position
		if d.y > 1.1 and Vector2(d.x, d.z).length() < 8.0:
			want = true
	var t := find_target()
	if t != null:
		var dt := t.global_position - global_position
		if dt.y > 1.1 and Vector2(dt.x, dt.z).length() < 4.0:
			want = true
	# Degrau ou obstáculo baixo bloqueando o caminho enquanto anda.
	if not want and is_on_wall() and Vector2(velocity.x, velocity.z).length() > 1.0:
		want = true
	if want:
		velocity.y = JUMP_VELOCITY
		jump_cd = 1.2


## Esquiva quando um inimigo próximo está na metade final da preparação de um golpe.
func should_dodge() -> bool:
	if dodge_cd > 0.0 or not is_on_floor():
		return false
	for e in get_tree().get_nodes_in_group("enemy"):
		var en := e as Enemy
		var d := en.global_position.distance_to(global_position)
		if d > 3.6 or en.machine.current_name() != "Attack":
			continue
		if en.get_target() != self and d > 2.4:
			continue
		var st: Node = en.machine.current
		var m: Variant = st.get("_m")
		if m == null or float(st.get("_t")) < float(m["windup"]) * 0.55:
			continue
		return true
	return false


func nearest_enemy_within(radius: float) -> Node3D:
	var best: Node3D = null
	var best_d := radius
	for e in get_tree().get_nodes_in_group("enemy"):
		var d := (e as Node3D).global_position.distance_to(global_position)
		if d < best_d:
			best_d = d
			best = e
	return best


func count_enemies_within(radius: float) -> int:
	var n := 0
	for e in get_tree().get_nodes_in_group("enemy"):
		if (e as Node3D).global_position.distance_to(global_position) <= radius:
			n += 1
	return n


func anim_motion() -> void:
	rig.set_motion(Vector2(velocity.x, velocity.z).length(), is_on_floor(), velocity.y)


func apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * 2.2 * delta


func accelerate(dir: Vector3, spd: float, accel: float, delta: float) -> void:
	velocity.x = move_toward(velocity.x, dir.x * spd, accel * delta)
	velocity.z = move_toward(velocity.z, dir.z * spd, accel * delta)


func face(dir: Vector3, delta: float, turn := 10.0) -> void:
	if dir.length_squared() < 0.001:
		return
	visual.rotation.y = lerp_angle(visual.rotation.y, atan2(dir.x, dir.z), 1.0 - exp(-turn * delta))


func forward() -> Vector3:
	return visual.global_transform.basis.z.normalized()
