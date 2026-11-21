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


## Ataques básicos do golem: soco direito, soco esquerdo e chute espartano (em sequência); a ombrada é
## a investida que o aproxima do inimigo (ver `next_basic` e `SHOULDER_CD`).
const PUNCH_R := {
	"name": "basic", "anim": "punch_r", "area": true, "windup": 0.3, "active": 0.12, "recovery": 0.35,
	"damage": 9, "knockback": 5.0, "hitstun": 0.3,
	"size": Vector3(2.0, 1.7, 1.8), "offset": Vector3(0, 1.1, 1.2), "lunge": 3.0,
}
const PUNCH_L := {
	"name": "basic", "anim": "punch_l", "area": true, "windup": 0.3, "active": 0.12, "recovery": 0.35,
	"damage": 9, "knockback": 5.0, "hitstun": 0.3,
	"size": Vector3(2.0, 1.7, 1.8), "offset": Vector3(0, 1.1, 1.2), "lunge": 3.0,
}
const KICK := {
	"name": "kick", "anim": "kick", "area": true, "windup": 0.4, "active": 0.14, "recovery": 0.5,
	"damage": 14, "knockback": 10.0, "hitstun": 0.5,
	"size": Vector3(1.9, 1.5, 2.0), "offset": Vector3(0, 0.9, 1.3), "lunge": 1.5,
}
const SHOULDER := {
	"name": "shoulder", "anim": "shoulder", "area": true, "windup": 0.3, "active": 0.35, "recovery": 0.5,
	"damage": 12, "knockback": 7.0, "hitstun": 0.45,
	"size": Vector3(2.2, 2.0, 2.0), "offset": Vector3(0, 1.0, 1.1), "lunge": 12.0,
}
## Ombrada: só quando o inimigo está nessa faixa de distância (para fechar o espaço) e fora de recarga.
const SHOULDER_MIN := 3.2
const SHOULDER_MAX := 9.0
const SHOULDER_CD := 5.0
## Chegada do golem: dano massivo em área (meteoro).
const METEOR_DAMAGE := 60
const METEOR_RADIUS := 6.5

## Banimento (mago): duração e recarga (só conta depois que o banimento acaba).
const BANISH_TIME := 20.0
const BANISH_COOLDOWN := 30.0
## Skill de agarrar: segura o inimigo por este tempo.
const GRAB_HOLD_TIME := 4.0


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
var shoulder_cd := 0.0
var _basic_step := 0
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
	shoulder_cd = maxf(shoulder_cd - delta, 0.0)
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


## Invocação: entra com a animação/skill de chegada no ponto indicado (meteoro, explosão de cura ou zona arcana).
func arrive(spot: Vector3) -> void:
	machine.change_to(&"Arrive", {"spot": spot})


## Onde o summon chega ao ser invocado:
##  - golem (meteoro): cai sobre o inimigo travado ou o mais próximo do jogador (sem inimigos: à frente);
##  - sacerdote (cura): ao lado e um pouco atrás do jogador;
##  - mago: à frente do jogador.
static func arrival_spot(kind: Variant, player: Player) -> Vector3:
	var fwd := player.forward()
	var right := fwd.cross(Vector3.UP).normalized()
	if kind == &"meteor":
		var t: Node3D = null
		var locked = player.get("lock_target")
		if locked is Enemy and is_instance_valid(locked):
			t = locked
		else:
			var best := 25.0
			for e in player.get_tree().get_nodes_in_group("enemy"):
				var d := (e as Node3D).global_position.distance_to(player.global_position)
				if d < best:
					best = d
					t = e
		if t != null:
			return t.global_position
		return player.global_position + fwd * 3.0
	if kind == &"holy":
		return player.global_position + right * 1.8 - fwd * 1.0
	return player.global_position + fwd * 3.0


## Comanda a skill do slot (0 = LB+X). Retorna true se foi usada.
func use_skill(index: int) -> bool:
	if index >= skills.size() or skills[index]["id"] == &"":
		return false
	# Banimento no próprio jogador: apertar a skill de novo o traz de volta (sem recarga).
	if skills[index]["id"] == &"banish" and is_instance_valid(owner_player) and owner_player.has_method("end_banish") and owner_player.is_banished():
		owner_player.end_banish()
		return true
	var n := machine.current_name()
	if n == "Dead" or n == "Arrive" or n == "Dismiss":
		return false
	# Conjurando: só a seta arcana (ataque básico do mago) pode ser interrompida por um comando.
	if n == "Skill" and machine.current.get("_id") != &"arrow":
		return false
	if skills[index]["timer"] > 0.0:
		return false
	if skills[index]["id"] == &"banish":
		return _use_banish(index)
	# Agarrar só é usado com um inimigo ao alcance ou uma porta pesada perto (sem gastar a recarga à toa).
	if skills[index]["id"] == &"grab" and grab_target() == null and nearest_heavy_door() == null:
		Sfx.play(&"denied")
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


## O sacerdote com a Benção equipada consegue abrir baús encantados (EnchantedChest).
func can_open_enchanted() -> bool:
	return arrival == &"holy" and GameState.summon_passives.has(&"p_blessing")


## Alvo do Agarrar: o inimigo travado pelo jogador ou o mais próximo (15 m). Null = nenhum.
func grab_target() -> Enemy:
	if is_instance_valid(owner_player):
		var locked = owner_player.get("lock_target")
		if locked is Enemy and is_instance_valid(locked) and (locked as Enemy).health.current > 0 and not (locked as Enemy).is_banished():
			return locked
	var best: Enemy = null
	var best_d := 15.0
	for e in get_tree().get_nodes_in_group("enemy"):
		var en := e as Enemy
		var d := en.global_position.distance_to(global_position)
		if d < best_d and en.health.current > 0:
			best_d = d
			best = en
	return best


## Porta pesada fechada mais próxima, ao alcance do golem (8 m), mas só se NÃO houver inimigo por perto (12 m).
func nearest_heavy_door() -> Node3D:
	if nearest_enemy_within(12.0) != null:
		return null
	var best: Node3D = null
	var best_d := 8.0
	for d in get_tree().get_nodes_in_group("heavy_door"):
		var door := d as Node3D
		if door.get("is_open") == true:
			continue
		var dist := door.global_position.distance_to(global_position)
		if dist < best_d:
			best_d = dist
			best = door
	return best


## Banimento: alvo = inimigo travado ou o mais próximo (15 m). Sem inimigo, bane o jogador.
## No inimigo a recarga só começa quando o banimento termina (banish_finished); no jogador não há recarga.
func _use_banish(index: int) -> bool:
	var target := banish_target()
	if target != null:
		skills[index]["timer"] = 1.0e9 # segura até o banimento acabar
	machine.change_to(&"Skill", {"id": &"banish", "target": target})
	return true


func banish_target() -> Enemy:
	if is_instance_valid(owner_player):
		var locked = owner_player.get("lock_target")
		if locked is Enemy and is_instance_valid(locked) and (locked as Enemy).health.current > 0 and not (locked as Enemy).is_banished():
			return locked
	var best: Enemy = null
	var best_d := 15.0
	for e in get_tree().get_nodes_in_group("enemy"):
		var en := e as Enemy
		var d := en.global_position.distance_to(global_position)
		if d < best_d and en.health.current > 0 and not en.is_banished():
			best_d = d
			best = en
	return best


## Chamado quando o inimigo banido volta: a recarga da skill passa a contar a partir de agora.
func banish_finished() -> void:
	for s in skills:
		if s["id"] == &"banish":
			s["timer"] = s["cooldown"]


## Ponto onde o golem segura o inimigo agarrado (acima das mãos, à frente).
func hold_point() -> Vector3:
	return global_position + forward() * 1.1 + Vector3.UP * hold_height


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


## Escolhe o próximo ataque básico do golem para um alvo a `dist` metros:
## longe (3,2–9 m) e ombrada pronta → investida; perto → soco direito, soco esquerdo, chute (em ciclo).
func next_basic(dist: float) -> Dictionary:
	if shoulder_cd <= 0.0 and dist >= SHOULDER_MIN and dist <= SHOULDER_MAX:
		shoulder_cd = SHOULDER_CD
		return SHOULDER
	if dist > attack_range:
		return {}
	_basic_step = (_basic_step + 1) % 3
	match _basic_step:
		1:
			return PUNCH_L
		2:
			return KICK
		_:
			return PUNCH_R


## Alvo da pedra: prioriza inimigos aéreos (lançados, fora do chão); entre iguais, o mais distante.
## Só considera inimigos a 4,5–16 m do golem.
func pick_rock_target() -> Node3D:
	var best: Node3D = null
	var best_score := -INF
	for e in get_tree().get_nodes_in_group("enemy"):
		var en := e as Enemy
		if en.health.current <= 0:
			continue
		var d := en.global_position.distance_to(global_position)
		if d < 4.5 or d > 16.0:
			continue
		# Aéreo: bem acima do golem ou subindo/caindo fora do chão (lançado, juggle).
		var airborne := en.global_position.y - global_position.y > 1.5 or (not en.is_on_floor() and absf(en.velocity.y) > 0.5)
		var score := d + (100.0 if airborne else 0.0)
		if score > best_score:
			best_score = score
			best = en
	return best


## Dano contínuo (aperto do golem, zona arcana): fere sem reação de golpe.
func deal_dot(target: Node3D, damage: int, color := Color(1, 1, 1)) -> void:
	Health.dot(target, damage, self, color)


## Escolhe uma skill passiva pronta cujas condições (distância ao alvo, inimigos por perto) valem agora.
func pick_passive(dist: float) -> StringName:
	for id in GameState.summon_passives:
		if id == &"" or not SummonSkills.PASSIVES.has(id) or float(passive_timers.get(id, 0.0)) > 0.0:
			continue
		var def: Dictionary = SummonSkills.PASSIVES[id]
		if id == &"rock":
			if pick_rock_target() != null:
				return id
			continue
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
