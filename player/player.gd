class_name Player
extends CharacterBody3D
## Dados e utilitários compartilhados. O comportamento vive nos estados em player/states/.

const FIREBALL := preload("res://combat/projectile.tscn")
const SUMMON_SCENES := {
	&"golem": preload("res://summon/summon.tscn"),
	&"priest": preload("res://summon/priest.tscn"),
}
## Cooldown (s) até poder invocar de novo depois de dispensar/trocar, ou depois que o summon morre.
const SUMMON_COOLDOWN := 8.0
const SUMMON_DEATH_COOLDOWN := 14.0
## Stance (poise): golpes que somam menos que isso não fazem o player cambalear. O escudo aumenta
## bastante o stance e reduz em 75% todo o dano recebido (não só com a guarda levantada).
const POISE_BASE := 9.0
const POISE_SHIELD := 60.0
const POISE_REGEN := 14.0
const SHIELD_DAMAGE_MULT := 0.25
## Colide só com o cenário; o contato com outros personagens é resolvido pelo BodyContacts
## (empurrões suaves por massa). A esquiva desliga o contato para atravessar inimigos.
const BODY_MASK := 1 << 0
const WORLD_MASK := 1 << 0
const BUFFERED_ACTIONS: Array[StringName] = [&"jump", &"dodge", &"attack", &"secondary", &"weapon_art"]
## Com LB (summon_mod) segurado, cada botão de face comanda uma skill da criatura:
## X = skill 1, Y = skill 2, B = skill 3, A = skill 4.
const SKILL_BUTTONS: Array = [[&"summon", 0], [&"attack", 1], [&"secondary", 2], [&"jump", 3]]
## Tempo segurando o botão de ataque para ativar a variante "hold" do combo.
const HOLD_TIME := 0.25
## Janela após o fim de um golpe em que o próximo toque conta como "pausa".
const COMBO_MEMORY := 0.7
## Medidor da arte da arma (RT): máximo 100, cada uso gasta ART_COST (2 segmentos).
const ART_MAX := 100.0
const ART_COST := 50.0
const ART_GAIN_PER_DAMAGE := 0.8
const ART_GAIN_ON_HURT := 4.0

@export var walk_speed := 3.6
@export var run_speed := 7.0
@export var acceleration := 45.0
@export var air_acceleration := 18.0
@export var jump_velocity := 8.5
@export var turn_speed := 14.0
@export var gravity_scale := 2.2
@export var coyote_time := 0.1
@export var input_buffer_time := 0.2
## Mostra a caixa translúcida do hitbox durante o golpe (para alinhar com a animação).
@export var debug_hitbox := false
## Direção em que o personagem olha ao nascer (graus de yaw; 180 = para -Z, o "norte" da arena).
## A câmera começa atrás dele.
@export var spawn_facing_degrees := 0.0
@export_group("Contato")
@export var contact_radius := 0.45
@export var contact_mass := 1.0

var contact_enabled := true

var moveset: MoveSet = LongSword.new() # equipamento primário (arma)
var poise := POISE_BASE
var _pending_poise := 0.0 # dano no poise do golpe em processamento (antes das reduções)
var guard_profile := GuardProfile.new() # sem escudo: postura defensiva básica

var is_running := false
var summon: Summon
var lock_target: Node3D
var coyote := 0.0
var dodge_cooldown := 0.0
var secondary_cooldown := 0.0
var art_meter := 0.0

## Direção do analógico no instante do último toque de ataque: "neutral", "fwd" ou "back".
var attack_dir := "neutral"
var attack_held_time := 0.0
var combo_memory_id := ""
var combo_memory_time := 0.0

@onready var visual: Node3D = $Visual
@onready var rig: HumanoidRig = $Visual/Rig
@onready var health: Health = $Health
@onready var attack_hitbox: Hitbox = $Visual/AttackHitbox
@onready var sword_arc: MeshInstance3D = $Visual/SwordArc
@onready var machine: StateMachine = $StateMachine

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _buffer: Dictionary = {}
var _run_idle := 0.0
var _summon_cd := 0.0


func _ready() -> void:
	add_to_group("player")
	add_to_group("body_contact")
	visual.rotation.y = deg_to_rad(spawn_facing_degrees)
	collision_layer = 1 << 1 # player
	collision_mask = BODY_MASK
	attack_hitbox.source = self
	attack_hitbox.sweep_rig = rig
	attack_hitbox.sweep_radius = 0.16
	attack_hitbox.hit_landed.connect(_on_hit_landed)
	health.hit_filter = _filter_hit
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	GameState.loadout_changed.connect(apply_loadout)
	GameState.summon_kind_changed.connect(_on_summon_kind_changed)
	apply_loadout()
	machine.start(self)


## Chamado pelo StateMachine antes do estado atual, a cada frame de física.
func tick(delta: float) -> void:
	coyote = coyote_time if is_on_floor() else maxf(coyote - delta, 0.0)
	if machine.current_name() != "Hurt":
		poise = minf(poise + POISE_REGEN * delta, poise_max())
	if has_lock():
		rig.set_look_target(lock_target.global_position + Vector3.UP * 1.4)
	else:
		rig.set_look_target(Vector3.ZERO, false)
	dodge_cooldown = maxf(dodge_cooldown - delta, 0.0)
	secondary_cooldown = maxf(secondary_cooldown - delta, 0.0)
	combo_memory_time = maxf(combo_memory_time - delta, 0.0)
	_summon_cd = maxf(_summon_cd - delta, 0.0)

	# LB segurado: botões de face comandam skills da criatura e não disparam ações normais.
	var mod := Input.is_action_pressed("summon_mod")
	if mod:
		for pair in SKILL_BUTTONS:
			if Input.is_action_just_pressed(pair[0]):
				command_skill(pair[1])
	elif Input.is_action_just_pressed("summon"):
		toggle_summon()

	if Input.is_action_just_pressed("attack") and not mod:
		attack_dir = stick_dir_class()
	var holding := Input.is_action_pressed("attack") and not mod
	attack_held_time = attack_held_time + delta if holding else 0.0

	# L3 alterna corrida; ao parar de andar por um instante, volta a andar.
	if Input.is_action_just_pressed("run_toggle"):
		is_running = not is_running
		_run_idle = 0.0
	if is_running:
		if get_move_dir().length() < 0.1:
			_run_idle += delta
			if _run_idle > 0.4:
				is_running = false
		else:
			_run_idle = 0.0

	for action in BUFFERED_ACTIONS:
		var blocked := mod and action != &"dodge" and action != &"weapon_art"
		if Input.is_action_just_pressed(action) and not blocked:
			_buffer[action] = input_buffer_time
		else:
			_buffer[action] = maxf(_buffer.get(action, 0.0) - delta, 0.0)


func buffered(action: StringName) -> bool:
	return _buffer.get(action, 0.0) > 0.0


func consume(action: StringName) -> bool:
	if buffered(action):
		_buffer[action] = 0.0
		return true
	return false


func is_attack_held() -> bool:
	return Input.is_action_pressed("attack")


func can_art() -> bool:
	return art_meter >= ART_COST


func add_art(amount: float) -> void:
	art_meter = clampf(art_meter + amount, 0.0, ART_MAX)


## Ganha medidor ao acertar (golpes da espada e explosões do player chamam isto).
func _on_hit_landed(hurtbox: Hurtbox) -> void:
	# A própria arte não recarrega o medidor (senão daria para usá-la sem parar).
	if machine.current_name() == "Art":
		return
	if hurtbox.health != null:
		add_art(hurtbox.health.last_damage * ART_GAIN_PER_DAMAGE)


func can_dodge() -> bool:
	return dodge_cooldown <= 0.0


func move_speed() -> float:
	return (run_speed if is_running else walk_speed) * StatusEffects.mult(self, "speed")


func poise_max() -> float:
	return POISE_SHIELD if GameState.secondary == &"shield" else POISE_BASE


func apply_gravity(delta: float, scale := 1.0) -> void:
	velocity.y -= _gravity * gravity_scale * scale * delta


func accelerate(dir: Vector3, speed: float, accel: float, delta: float) -> void:
	var target := dir * speed
	velocity.x = move_toward(velocity.x, target.x, accel * delta)
	velocity.z = move_toward(velocity.z, target.z, accel * delta)


## Direção de movimento (plano XZ) relativa à câmera. Comprimento entre 0 e 1.
func get_move_dir() -> Vector3:
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return Vector3(input.x, 0, input.y)
	return Basis(Vector3.UP, cam.global_rotation.y) * Vector3(input.x, 0, input.y)


func has_lock() -> bool:
	return lock_target != null and is_instance_valid(lock_target)


func forward() -> Vector3:
	return visual.global_transform.basis.z.normalized()


func face(dir: Vector3, delta: float) -> void:
	var yaw := atan2(dir.x, dir.z)
	visual.rotation.y = lerp_angle(visual.rotation.y, yaw, 1.0 - exp(-turn_speed * delta))


func snap_face(dir: Vector3) -> void:
	visual.rotation.y = atan2(dir.x, dir.z)


## Em lock-on olha para o alvo (strafe); fora dele, olha para onde anda.
func update_facing(dir: Vector3, delta: float) -> void:
	if has_lock():
		var to := lock_target.global_position - global_position
		to.y = 0.0
		if to.length() > 0.1:
			face(to.normalized(), delta)
			return
	if dir.length_squared() > 0.01:
		face(dir, delta)


## Usado ao iniciar um ataque: vira para o input, ou para o alvo travado.
func snap_face_to_intent() -> void:
	var dir := get_move_dir()
	if dir.length() > 0.1:
		snap_face(dir.normalized())
	elif has_lock():
		var to := lock_target.global_position - global_position
		to.y = 0.0
		if to.length() > 0.1:
			snap_face(to.normalized())


## Classifica o analógico como "fwd"/"back"/"neutral". Só vale com lock-on:
## frente = em direção ao alvo. Sem lock-on o analógico serve só para mover.
func stick_dir_class() -> String:
	if not has_lock():
		return "neutral"
	var dir := get_move_dir()
	if dir.length() < 0.5:
		return "neutral"
	var ref := lock_target.global_position - global_position
	ref.y = 0.0
	if ref.length() < 0.01:
		return "neutral"
	var d := dir.normalized().dot(ref.normalized())
	if d > 0.6:
		return "fwd"
	if d < -0.6:
		return "back"
	return "neutral"


## Inicia o golpe certo do moveset: continuação "pause" se acabou de terminar um golpe.
func start_attack() -> void:
	var from_id := ""
	var kind := "tap"
	if combo_memory_time > 0.0:
		from_id = combo_memory_id
		kind = "pause"
	var move := moveset.resolve(from_id, kind, attack_dir, not is_on_floor())
	machine.change_to(&"Attack", {"move": move})


## B: ação do equipamento secundário do loadout — orbe conjura a bola de fogo, escudo faz a investida.
func use_secondary() -> void:
	if GameState.secondary == &"shield":
		machine.change_to(&"Bash")
	else:
		machine.change_to(&"Cast")


## Aplica o loadout do GameState: modelo na mão esquerda e perfil de guarda.
func apply_loadout() -> void:
	var shield := GameState.secondary == &"shield"
	rig.set_offhand(HumanoidRig.Offhand.SHIELD if shield else HumanoidRig.Offhand.ORB)
	guard_profile = GuardProfile.shield() if shield else GuardProfile.bare()
	var hammer := GameState.primary == &"hammer"
	rig.set_weapon(HumanoidRig.Weapon.HAMMER if hammer else HumanoidRig.Weapon.SWORD)
	attack_hitbox.sweep_radius = 0.32 if hammer else 0.16 # cabeça do martelo é grossa
	moveset = Hammer.new() if hammer else LongSword.new()
	combo_memory_time = 0.0
	poise = minf(poise, poise_max())


## Solta a bola de fogo a partir do orbe da mão esquerda, na direção do alvo travado ou à frente.
func fire_projectile() -> void:
	var origin := global_position + Vector3(0, 1.2, 0)
	if rig.offhand_tip != null:
		origin = rig.offhand_tip.global_position
	var dir := forward()
	if has_lock():
		dir = (lock_target.global_position + Vector3(0, 1.0, 0) - origin).normalized()
	else:
		dir.y = 0.0
		dir = dir.normalized()
	Sfx.play(&"fire", origin)
	var proj := FIREBALL.instantiate()
	proj.direction = dir
	proj.source = self
	get_parent().add_child(proj)
	proj.global_position = origin
	GameFeel.rumble(0.2, 0.0, 0.08)


## Trocou de summon no menu: dispensa o atual (o novo é invocado de novo com X).
func _on_summon_kind_changed() -> void:
	if has_summon():
		summon.dismiss()
		summon = null
		_summon_cd = SUMMON_COOLDOWN


## Segundos até poder invocar de novo (0 = pronto).
func summon_cooldown() -> float:
	return _summon_cd


func has_summon() -> bool:
	return summon != null and is_instance_valid(summon)


## X: invoca a criatura ou a dispensa se já estiver em campo.
func toggle_summon() -> void:
	if has_summon():
		summon.dismiss()
		summon = null
		_summon_cd = SUMMON_COOLDOWN # cooldown entre summons
		return
	if _summon_cd > 0.0:
		Sfx.play(&"denied")
		return
	summon = SUMMON_SCENES[GameState.summon_kind].instantiate()
	summon.owner_player = self
	get_parent().add_child(summon)
	# Chega com animação e skill própria (golem: meteoro | sacerdote: explosão de cura).
	summon.arrive(global_position + forward() * 3.0)
	summon.health.died.connect(func() -> void: _summon_cd = SUMMON_DEATH_COOLDOWN)


## LB + botão: comanda a skill do slot (0 = X, 1 = Y, 2 = B, 3 = A).
func command_skill(index: int) -> void:
	if has_summon():
		summon.use_skill(index)


func flash() -> void:
	rig.flash(Color(1, 1, 1))


## Informa ao rig a locomoção atual (andar/correr/pulo/queda).
func anim_motion() -> void:
	rig.set_motion(Vector2(velocity.x, velocity.z).length(), is_on_floor(), velocity.y)


## Aplicado pelo Health antes do dano: a guarda reduz dano/knockback ou nega (parry).
func _filter_hit(hit: HitData) -> HitData:
	_pending_poise = hit.damage * hit.poise_mult
	if machine.current_name() != "Guard":
		# Escudo equipado: corta 75% de todo o dano recebido, mesmo sem levantar a guarda.
		if GameState.secondary == &"shield":
			var s: HitData = hit.duplicate()
			s.source = hit.source
			s.damage = roundi(hit.damage * SHIELD_DAMAGE_MULT)
			return s
		return hit
	var g := guard_profile
	var h: HitData = hit.duplicate()
	h.source = hit.source
	if float(machine.current.get("time")) < g.parry_window:
		h.damage = 0
		h.knockback = 0.0
		h.hitstun = 0.0
		health.last_tag = "PARRY"
		_on_parry(hit)
		return h
	h.damage = roundi(hit.damage * g.damage_multiplier)
	h.knockback = hit.knockback * g.knockback_multiplier
	if g.cancels_hitstun:
		h.hitstun = 0.0
	return h


## Parry: golpe corpo a corpo faz o atacante cambalear aberto; projéteis só são negados.
func _on_parry(hit: HitData) -> void:
	rig.flash(Color(0.4, 0.8, 1.0), 0.3)
	Fx.spark(self, global_position + Vector3(0, 1.3, 0) + forward() * 0.6, Color(0.5, 0.85, 1.0))
	GameFeel.slowmo(0.15, 0.18)
	GameFeel.shake(0.18)
	GameFeel.rumble(0.6, 0.4, 0.15)
	add_art(10.0)
	if hit.freeze_attacker and is_instance_valid(hit.source) and hit.source.has_method("parried"):
		# Estamos dentro de um callback de física: muda o estado do atacante no fim do quadro.
		hit.source.call_deferred("parried", self)


## Hit-stop local (chamado pelo GameFeel): congela estado e animação.
func hit_pause(duration: float, shake_body := false) -> void:
	machine.freeze(duration)
	rig.freeze(duration, shake_body)


func _on_damaged(hit: HitData) -> void:
	EventBus.player_damaged.emit(hit.damage)
	if hit.damage > 0:
		add_art(ART_GAIN_ON_HURT)
	var guarding := machine.current_name() == "Guard"
	rig.flash(Color(0.5, 0.75, 1.0) if guarding else Color(1, 1, 1))
	if health.current <= 0:
		return
	# Guarda que cancela hitstun: bloqueou sem colisão, continua na postura.
	if hit.hitstun <= 0.0 and guarding:
		return
	# Stance: golpes que não quebram o poise não fazem o player cambalear (só o dano é aplicado).
	var state := machine.current_name()
	if state != "Hurt" and not hit.poise_break and hit.launch <= 0.0 and hit.damage > 0:
		poise -= _pending_poise
		if poise > 0.0:
			rig.flash(Color(1.0, 0.85, 0.4), 0.2)
			rig.kick("spine", Vector3(-120, 0, 0)) # tranco curto: sentiu o golpe mas não caiu
			return
	poise = poise_max()
	machine.change_to(&"Hurt", {"hit": hit})


func _on_died() -> void:
	machine.change_to(&"Dead")
