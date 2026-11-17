class_name Enemy
extends CharacterBody3D
## Inimigo genérico: o arquétipo (soldado, brutamontes, arqueiro) vem dos exports da cena.
## Reusa Health/Hitbox/Hurtbox e StateMachine; os golpes vêm de EnemyMoves por move_set.

## Colide só com o cenário; o contato com outros personagens é do BodyContacts (empurrão por massa).
const BODY_MASK := 1 << 0

@export var move_speed := 3.5
@export var detect_range := 14.0
@export var attack_range := 1.9
## Tabela de golpes em EnemyMoves (ex.: "grunt", "brute", "archer").
@export var move_set: StringName = &"grunt"
## Estado de combate ao perceber o alvo: "Chase" (corpo a corpo) ou "Kite" (à distância).
@export var engage_state: StringName = &"Chase"
@export_group("Poise")
## Enquanto ataca, absorve golpes sem cambalear até esta quantidade de dano (super armor).
@export var poise_max := 30.0
@export var poise_regen := 10.0 # por segundo, fora do stagger
## Armadura também fora do ataque (brutamontes): golpes leves nunca o fazem cambalear.
@export var always_armored := false
@export_group("Reações")
## Knockback mínimo que derruba (golpes fortes no chão).
@export var knockdown_force := 9.5
## Falso: lançadores não tiram o inimigo do chão (brutamontes).
@export var can_be_launched := true
@export_group("Contato")
@export var contact_radius := 0.45
## Quanto resiste a ser empurrado (o player tem massa 1).
@export var contact_mass := 1.2
@export_group("Separação")
@export var separation_radius := 1.4
@export var separation_strength := 1.2

var attack_cd := 0.0
var shoot_cd := 1.5 # arqueiros
var contact_enabled := true
var taunt_target: Node3D
var taunt_time := 0.0
var poise := 30.0

@onready var visual: Node3D = $Visual
@onready var rig: HumanoidRig = $Visual/Rig
@onready var health: Health = $Health
@onready var hitbox: Hitbox = $Visual/Hitbox
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var machine: StateMachine = $StateMachine

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")


func _ready() -> void:
	add_to_group("enemy")
	add_to_group("body_contact")
	collision_layer = 1 << 2 # enemy
	collision_mask = BODY_MASK
	poise = poise_max
	hitbox.source = self
	hitbox.sweep_rig = rig
	hitbox.sweep_radius = 0.2 * rig.height
	# A forma do hitbox muda a cada golpe: cada inimigo precisa da sua própria cópia.
	var cs := hitbox.get_node("CollisionShape3D") as CollisionShape3D
	cs.shape = cs.shape.duplicate()
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	machine.start(self)


func tick(delta: float) -> void:
	attack_cd = maxf(attack_cd - delta, 0.0)
	shoot_cd = maxf(shoot_cd - delta, 0.0)
	taunt_time = maxf(taunt_time - delta, 0.0)
	if machine.current_name() != "Stagger":
		poise = minf(poise + poise_regen * delta, poise_max)
	var t := get_target()
	if t != null and machine.current_name() != "Idle":
		rig.set_look_target(t.global_position + Vector3.UP * 1.4)
	else:
		rig.set_look_target(Vector3.ZERO, false)


## Hit-stop local (chamado pelo GameFeel).
func hit_pause(duration: float, shake_body := false) -> void:
	machine.freeze(duration)
	rig.freeze(duration, shake_body)


func get_player() -> Node3D:
	return get_tree().get_first_node_in_group("player") as Node3D


## Quem o inimigo persegue: o provocador (ex.: summon) enquanto durar a provocação, senão o player.
func get_target() -> Node3D:
	if taunt_time > 0.0 and is_instance_valid(taunt_target):
		return taunt_target
	return get_player()


func taunt(target: Node3D, duration: float) -> void:
	taunt_target = target
	taunt_time = duration


func pull_toward(pos: Vector3) -> void:
	if health.current > 0:
		machine.change_to(&"Pulled", {"pos": pos})


## Vetor horizontal até o alvo atual (ZERO se não houver). Mantém o nome por compatibilidade.
func to_player() -> Vector3:
	var p := get_target()
	if p == null:
		return Vector3.ZERO
	var v := p.global_position - global_position
	v.y = 0.0
	return v


## Empurrão para longe de inimigos próximos, para não se empilharem no player.
func separation() -> Vector3:
	var push := Vector3.ZERO
	for other in get_tree().get_nodes_in_group("enemy"):
		if other == self:
			continue
		var away: Vector3 = global_position - (other as Node3D).global_position
		away.y = 0.0
		var d := away.length()
		if d > 0.01 and d < separation_radius:
			push += away / d * (1.0 - d / separation_radius)
	return push * separation_strength


## Velocidade de movimento com debuffs (Lentidão).
func move_spd() -> float:
	return move_speed * StatusEffects.mult(self, "speed")


func anim_motion() -> void:
	rig.set_motion(Vector2(velocity.x, velocity.z).length(), is_on_floor(), velocity.y)


func apply_gravity(delta: float, scale := 1.0) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * 2.2 * scale * delta


func accelerate(dir: Vector3, speed: float, accel: float, delta: float) -> void:
	velocity.x = move_toward(velocity.x, dir.x * speed, accel * delta)
	velocity.z = move_toward(velocity.z, dir.z * speed, accel * delta)


func face(dir: Vector3, delta: float, turn := 10.0) -> void:
	if dir.length_squared() < 0.001:
		return
	visual.rotation.y = lerp_angle(visual.rotation.y, atan2(dir.x, dir.z), 1.0 - exp(-turn * delta))


func forward() -> Vector3:
	return visual.global_transform.basis.z.normalized()


func _on_damaged(hit: HitData) -> void:
	if health.current <= 0:
		rig.flash(Color(1, 1, 1))
		return
	# Agarrado: só pisca; o golem decide quando o solta (e o golpe de soltar já vem depois).
	if machine.current_name() == "Held":
		rig.flash(Color(1, 1, 1))
		return
	# Super armor: atacando (ou sempre, no brutamontes), absorve golpes até o poise quebrar.
	# Lançadores (em quem pode ser lançado) e a investida de escudo sempre quebram.
	var state := machine.current_name()
	var armored := state == "Attack" or (always_armored and state != "Stagger")
	var breaks := hit.poise_break or (hit.launch > 0.0 and can_be_launched)
	if armored and not breaks:
		poise -= hit.damage * hit.poise_mult
		if poise > 0.0:
			rig.flash(Color(1.0, 0.6, 0.2)) # brilho laranja = golpe absorvido
			return
	poise = poise_max
	rig.flash(Color(1, 1, 1))
	machine.change_to(&"Stagger", {"hit": hit})


## Atingido por outro corpo arremessado (ex.: inimigo jogado contra este). velocity = velocidade do impacto.
func bumped(impact_velocity: Vector3, by: Node3D) -> void:
	if health.current <= 0:
		return
	var hit := HitData.new()
	hit.damage = 4
	hit.knockback = impact_velocity.length()
	hit.hitstun = 0.45
	hit.hitstop = 0.05
	hit.source = by
	if health.take_hit(hit):
		Fx.spark(self, (global_position + by.global_position) * 0.5 + Vector3.UP, Color(1.0, 0.9, 0.6))
		GameFeel.shake(0.08)


## Chamado (adiado) pelo player quando um golpe deste inimigo sofre parry: fica aberto ~1 s.
func parried(by: Node3D) -> void:
	if health.current <= 0 or not is_inside_tree():
		return
	poise = poise_max
	rig.flash(Color(0.4, 0.8, 1.0), 0.3)
	var hit := HitData.new()
	hit.knockback = 3.0
	hit.hitstun = 1.1
	hit.source = by
	machine.change_to(&"Stagger", {"hit": hit})


func _on_died() -> void:
	machine.change_to(&"Dead")
