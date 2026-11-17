class_name HumanoidRig
extends Node3D
## Boneco humanoide montado com primitivas (cápsulas, caixas, esferas) em pivôs de juntas.
## As animações são poses (characters/poses.gd); o rig as segue com juntas de MOLA (inércia,
## um leve "passar do ponto" e assentar) e acrescenta movimento secundário: capa e tabardo que
## balançam, cabeça que olha para o alvo, inclinação ao acelerar/curvar, amortecimento na
## aterrissagem, passos sincronizados com a distância andada e IK nas pernas (pés no chão).
## Os estados do personagem só informam o que está acontecendo (set_motion / set_attack / ...).
## Pés em y=0, ~1,9 m de altura, frente = +Z.

enum Mode { LOCOMOTION, ATTACK, DODGE, GUARD, HURT, DEAD, AIR_HURT, KNOCKDOWN }
enum Weapon { SWORD, CLUB, NONE, BOW, HAMMER, STAFF }
## Equipamento secundário na mão esquerda.
enum Offhand { NONE, ORB, SHIELD }
enum Headgear { HELMET, HOOD, HAIR, GOLEM }

const HIP_Y := 0.95
## Distância do pomo do martelo até a mão (pegada no meio do cabo).
const HAMMER_GRIP := 0.5
## Onde a mão esquerda segura a arma nos golpes de duas mãos (z no soquete da arma).
const GRIP2 := {0: -0.14, 4: 0.12} # Weapon.SWORD, Weapon.HAMMER
const THIGH_LEN := 0.45
const SHIN_LEN := 0.45
const FOOT_H := 0.06
const ROT_JOINTS: Array[String] = [
	"hips", "spine", "head", "sh_l", "el_l", "sh_r", "el_r", "wr_r", "th_l", "kn_l", "th_r", "kn_r",
]
## Mola por modo: x = frequência (rad/s), y = amortecimento (<1 passa um pouco do ponto e assenta).
const SPRING := {
	Mode.LOCOMOTION: Vector2(13.0, 0.8), Mode.ATTACK: Vector2(32.0, 0.55), Mode.DODGE: Vector2(22.0, 0.7),
	Mode.GUARD: Vector2(15.0, 0.75), Mode.HURT: Vector2(26.0, 0.42), Mode.DEAD: Vector2(11.0, 0.75),
	Mode.AIR_HURT: Vector2(12.0, 0.5), Mode.KNOCKDOWN: Vector2(15.0, 0.6),
}
## Juntas "pesadas" respondem mais devagar; o braço livre e a cabeça ficam um pouco atrás (arrasto).
const JOINT_FREQ := {
	"root": 0.8, "pitch": 0.8, "hips": 0.85, "spine": 0.9, "head": 0.85,
	"sh_l": 0.9, "el_l": 0.75, "th_l": 1.1, "kn_l": 1.15, "th_r": 1.1, "kn_r": 1.15,
}
## Quanto a cabeça segue o alvo do olhar em cada modo.
const LOOK_WEIGHT := {
	Mode.LOCOMOTION: 1.0, Mode.GUARD: 1.0, Mode.ATTACK: 0.5, Mode.DODGE: 0.3,
	Mode.HURT: 0.0, Mode.DEAD: 0.0, Mode.AIR_HURT: 0.0, Mode.KNOCKDOWN: 0.0,
}

@export var skin := Color(0.92, 0.74, 0.6)
@export var cloth := Color(0.55, 0.1, 0.15)
@export var accent := Color(0.22, 0.22, 0.26)
@export var height := 1.0
@export var bulk := 1.0
@export var weapon: Weapon = Weapon.SWORD
@export var trail_color := Color(0.8, 0.9, 1.0)
@export var offhand: Offhand = Offhand.NONE
@export var offhand_color := Color(1.0, 0.45, 0.1)
@export_group("Visual")
@export var headgear: Headgear = Headgear.HELMET
@export var cape := false
@export var cape_color := Color(0.4, 0.05, 0.08)
@export var tabard := true
@export var pauldron_scale := 1.0
## Escala das mãos/punhos (golem: punhos enormes).
@export var fist_scale := 1.0
## Runas brilhantes no peito e nos olhos (golem). Material próprio: não apaga com set_glow.
@export var runes := false
@export var rune_color := Color(0.3, 0.9, 1.0)
## Pés se ajustam ao chão (degraus, poses agachadas).
@export var foot_ik := true

## Pontos da lâmina (para o rastro). Ficam na mão direita.
var sword_base: Marker3D
var sword_tip: Marker3D
## Ponto de onde saem as magias (centro do orbe na mão esquerda). Nulo sem equipamento secundário.
var offhand_tip: Marker3D

var _hand_l: Node3D
var _wrist: Node3D
var _weapon_mat: StandardMaterial3D
var _rune_mat: StandardMaterial3D
var _guard_shield := false
var _orb_mat: StandardMaterial3D
var _orb_light: OmniLight3D
var _orb_boost := 0.0 # brilho extra ao conjurar (0..1)
## Ligado pelo estado de ataque durante a janela ativa; o WeaponTrail lê isso.
var trail_active := false

var _mats: Array[StandardMaterial3D] = []
var _joints: Dictionary = {}
var _body_root: Node3D
var _hips: Node3D
var _cur: Dictionary = {}

var _mode := Mode.LOCOMOTION
var _time := 0.0
var _phase := 0.0
var _speed := 0.0
var _on_floor := true
var _vy := 0.0
var _atk_anim := ""
var _atk := Vector4.ZERO # startup, active, recovery, t
var _charge_level := -1 # estância de carga (-1 = não carregando): tremor de esforço
var _shield_front := 0.0 # 0 = escudo de lado no antebraço, 1 = de frente (guarda e investida)
var _two_hand := 0.0 # 0..1: mão esquerda segurando a arma (golpes de duas mãos)
var _sway := Vector2.ZERO # balanço da arma: x = lâmina (graus), y = abertura do ombro (graus)
var _sway_vel := Vector2.ZERO
var _atk_from: Dictionary = {} # pose do corpo quando o golpe atual começou
var _progress := 0.0 # dodge/hurt (0..1) ou tempo (dead/knockdown/air)
var _hurt_dir := Vector3.ZERO # direção do empurrão no espaço local do rig
var _down_dur := 1.2
var _flash_tween: Tween
var _freeze_t := 0.0
var _freeze_shake := false
var _freeze_snap := false

# Molas das juntas
var _vel: Dictionary = {}
# Movimento do corpo no mundo (para inclinação, passos e tecido)
var _prev_pos := Vector3.ZERO
var _world_vel := Vector3.ZERO
var _prev_world_vel := Vector3.ZERO
var _accel := Vector3.ZERO
var _prev_yaw := 0.0
var _yaw_rate := 0.0
var _was_on_floor := true
# Secundário
var _lean := Vector2.ZERO # x = pitch, y = roll (graus)
var _lean_vel := Vector2.ZERO
var _land := 0.0 # afundamento extra do quadril (m)
var _land_vel := 0.0
var _look_on := false
var _look_pos := Vector3.ZERO
var _head_off := Vector3.ZERO
var _cape: Array[Dictionary] = [] # {"pivot": Node3D, "angle": float, "vel": float}
var _tab_f: Node3D
var _tab_b: Node3D
var _tab := Vector2.ZERO # ângulos atuais (frente, trás)


func _ready() -> void:
	scale = Vector3.ONE * height
	_build()
	_cur = Poses.full({})
	for j in Poses.JOINTS:
		_vel[j] = Vector3.ZERO
	_prev_pos = global_position
	_prev_yaw = global_rotation.y
	_apply()


# --- API usada pelos estados -------------------------------------------------

func set_motion(speed: float, on_floor: bool, vel_y: float) -> void:
	_mode = Mode.LOCOMOTION
	_speed = speed
	_on_floor = on_floor
	_vy = vel_y


func set_attack(anim: String, startup: float, active: float, recovery: float, t: float) -> void:
	# Golpe novo (outra animação, vindo de outro modo, ou o tempo recomeçou): guarda a pose atual
	# do corpo. A preparação parte dela, então encadear golpes é um gesto contínuo.
	if anim != _atk_anim or _mode != Mode.ATTACK or t < _atk.w - 0.0001:
		# Normaliza o giro de 360° do golpe anterior para não "desenrolar" ao encadear.
		var yaw: Vector3 = _cur["yaw"]
		yaw.x = wrapf(yaw.x, -180.0, 180.0)
		_cur["yaw"] = yaw
		_atk_from = _cur.duplicate()
	_mode = Mode.ATTACK
	_atk_anim = anim
	_atk = Vector4(startup, active, recovery, t)


func set_dodge(progress: float) -> void:
	_mode = Mode.DODGE
	_progress = progress


func set_guard(with_shield := false) -> void:
	_mode = Mode.GUARD
	_guard_shield = with_shield


## push_dir_world: direção em que o golpe empurra (do atacante para a vítima). ZERO = pela frente.
func set_hurt(progress: float, push_dir_world := Vector3.ZERO) -> void:
	_mode = Mode.HURT
	_progress = progress
	if push_dir_world != Vector3.ZERO:
		_hurt_dir = global_transform.basis.inverse() * push_dir_world
		_hurt_dir.y = 0.0
		_hurt_dir = _hurt_dir.normalized()
	elif progress <= 0.0:
		_hurt_dir = Vector3.ZERO


## Inimigo lançado/no ar (juggle): corpo largado e tombando para trás.
func set_air_hurt(time: float) -> void:
	_mode = Mode.AIR_HURT
	_progress = time


## Derrubado: cai de costas, fica no chão e se levanta no fim de `duration`.
func set_knockdown(time: float, duration: float) -> void:
	_mode = Mode.KNOCKDOWN
	_progress = time
	_down_dur = duration


func set_dead(time: float) -> void:
	_mode = Mode.DEAD
	_progress = time


## Carregando um golpe: nível 0..3 aumenta o tremor de esforço do corpo. -1 desliga.
func set_charge(level: int) -> void:
	_charge_level = level


## Aplica a pose-alvo atual imediatamente, sem suavização (usado por ferramentas de preview).
func snap() -> void:
	_cur = _compute_target(0.0).duplicate()
	for j in Poses.JOINTS:
		_vel[j] = Vector3.ZERO
	_apply()
	_two_hand_apply(0.0, true)


## A cabeça vira para este ponto (com atraso e limites). active=false volta a olhar para frente.
func set_look_target(world_pos: Vector3, active := true) -> void:
	_look_on = active
	_look_pos = world_pos


## Impulso numa junta (graus/s) — tranco de impacto que a mola absorve.
func kick(joint: String, impulse: Vector3) -> void:
	if _vel.has(joint):
		_vel[joint] = (_vel[joint] as Vector3) + impulse


## Brilho emissivo em todo o corpo (telegrafia de ataque, flash de dano).
func set_glow(color: Color) -> void:
	for m in _mats:
		m.emission_enabled = true
		m.emission = color


func flash(color := Color.WHITE, time := 0.18) -> void:
	if _flash_tween:
		_flash_tween.kill()
	set_glow(color)
	_flash_tween = create_tween()
	_flash_tween.tween_method(set_glow, color, Color.BLACK, time)


# --- Animação ---------------------------------------------------------------

## Hit-stop local: segura a pose atual (encaixando na pose do golpe/reação) por alguns instantes.
## shake_body = tremor curto do corpo, usado na vítima.
func freeze(duration: float, shake_body := false) -> void:
	_freeze_t = maxf(_freeze_t, duration)
	_freeze_shake = shake_body
	_freeze_snap = true


func _compute_target(delta: float) -> Dictionary:
	match _mode:
		Mode.ATTACK:
			return Poses.attack(_atk_anim, _atk.x, _atk.y, _atk.z, _atk.w, _atk_from)
		Mode.DODGE:
			return Poses.dodge(_progress)
		Mode.GUARD:
			return Poses.guard(_time, _guard_shield)
		Mode.HURT:
			return Poses.hurt(_progress, _hurt_dir)
		Mode.DEAD:
			return Poses.dead(_progress)
		Mode.AIR_HURT:
			return Poses.air_hurt(_progress)
		Mode.KNOCKDOWN:
			return Poses.knockdown(_progress, _down_dur)
	# A fase do passo avança com a distância andada (em _track_motion), não com o tempo.
	return Poses.locomotion(_phase, _speed, _on_floor, _vy, _time, _carry_wrist())


func _process(delta: float) -> void:
	if _freeze_t > 0.0:
		_freeze_t -= delta
		if _freeze_snap: # encaixa de uma vez na pose do impacto
			_freeze_snap = false
			var snap_pose := _compute_target(0.0)
			for j in Poses.JOINTS:
				_cur[j] = snap_pose.get(j, Vector3.ZERO)
				_vel[j] = Vector3.ZERO
		_apply()
		_two_hand_apply(0.0)
		if _freeze_shake and _freeze_t > 0.0:
			_body_root.position = Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)) * 0.03
		else:
			_body_root.position = Vector3.ZERO
		_prev_pos = global_position
		return
	_body_root.position = Vector3.ZERO
	if delta <= 0.0:
		return

	_time += delta
	_update_orb()
	_track_motion(delta)
	var target := _compute_target(delta)

	if _mode != Mode.ATTACK:
		var yaw: Vector3 = _cur["yaw"]
		yaw.x = wrapf(yaw.x, -180.0, 180.0)
		_cur["yaw"] = yaw

	_integrate(target, delta)
	_update_secondary(delta)
	_apply()
	_two_hand_apply(delta)
	_update_cloth(delta)
	_leg_ik()


## Juntas como molas amortecidas (Euler semi-implícito, subpassos para estabilidade).
func _integrate(target: Dictionary, delta: float) -> void:
	var sp: Vector2 = SPRING[_mode]
	if _mode == Mode.ATTACK:
		# Espada: mola mais firme e bem amortecida (fluida, sem tremer). Martelo: mais lenta e com
		# folga (a massa passa um pouco do ponto e assenta). Outros: o padrão.
		if weapon == Weapon.SWORD:
			sp = Vector2(36.0, 0.72)
		elif weapon == Weapon.HAMMER:
			sp = Vector2(24.0, 0.46)
	var steps := maxi(1, ceili(delta / (1.0 / 90.0)))
	var dt := delta / steps
	for j in Poses.JOINTS:
		var w: float = sp.x * float(JOINT_FREQ.get(j, 1.0))
		var k := w * w
		var c := 2.0 * sp.y * w
		var x: Vector3 = _cur[j]
		var v: Vector3 = _vel[j]
		var tgt: Vector3 = target.get(j, Vector3.ZERO)
		for _i in steps:
			v += (k * (tgt - x) - c * v) * dt
			x += v * dt
		_cur[j] = x
		_vel[j] = v


## Mede velocidade/aceleração/giro reais do corpo e avança a fase do passo pela distância.
func _track_motion(delta: float) -> void:
	var pos := global_position
	var v := (pos - _prev_pos) / delta
	_prev_pos = pos
	if v.length() > 40.0: # teleporte
		v = Vector3.ZERO
	_world_vel = _world_vel.lerp(v, 1.0 - exp(-14.0 * delta))
	var a := (_world_vel - _prev_world_vel) / delta
	_prev_world_vel = _world_vel
	_accel = _accel.lerp(a, 1.0 - exp(-8.0 * delta))
	var yaw := global_rotation.y
	_yaw_rate = lerpf(_yaw_rate, wrapf(yaw - _prev_yaw, -PI, PI) / delta, 1.0 - exp(-10.0 * delta))
	_prev_yaw = yaw

	if _mode == Mode.LOCOMOTION and _on_floor:
		var hv := Vector2(v.x, v.z).length()
		var run := clampf(inverse_lerp(2.5, 7.0, _speed), 0.0, 1.0)
		# Um ciclo (2 passos) por 2 comprimentos de passo: o pé de apoio não desliza.
		var step := Poses.step_length(run) * height
		_phase += TAU * hv * delta / (2.0 * step)


## Inclinação (aceleração e curva), amortecimento de aterrissagem e olhar.
func _update_secondary(delta: float) -> void:
	# Inclinação: acelerar para frente inclina para frente; curvar inclina para dentro da curva.
	var target_lean := Vector2.ZERO
	if _mode == Mode.LOCOMOTION and _on_floor:
		var local_acc := global_transform.basis.orthonormalized().inverse() * _accel
		var hspeed := Vector2(_world_vel.x, _world_vel.z).length()
		target_lean.x = clampf(local_acc.z * 1.4, -12.0, 14.0)
		target_lean.y = clampf(-_yaw_rate * hspeed * 1.6, -16.0, 16.0)
	var lw := 9.0
	_lean_vel += ((target_lean - _lean) * lw * lw - _lean_vel * 2.0 * 0.7 * lw) * delta
	_lean += _lean_vel * delta

	# Arma acompanha o corpo: acelerar a deixa para trás, curvar a joga para fora, e ela balança
	# com o passo ao correr.
	var sway_target := Vector2.ZERO
	if _mode == Mode.LOCOMOTION and _on_floor and _speed > 0.4:
		var la := global_transform.basis.orthonormalized().inverse() * _accel
		var run_k := clampf(inverse_lerp(2.5, 7.0, _speed), 0.0, 1.0)
		sway_target.x = clampf(la.z * 1.6, -14.0, 14.0) + sin(_phase * 2.0) * 3.5 * run_k
		sway_target.y = clampf(-la.x * 1.2 - _yaw_rate * 2.0, -10.0, 10.0)
	var sw := 11.0
	_sway_vel += ((sway_target - _sway) * sw * sw - _sway_vel * 2.0 * 0.45 * sw) * delta
	_sway += _sway_vel * delta

	# Aterrissagem: tranco para baixo no quadril; a mola devolve (e o IK dobra os joelhos).
	if _mode == Mode.LOCOMOTION:
		if _on_floor and not _was_on_floor and _world_vel.y < -2.0:
			_land_vel -= clampf(-_world_vel.y * 0.35, 0.8, 3.2)
		_was_on_floor = _on_floor
	var gw := 15.0
	_land_vel += (-_land * gw * gw - _land_vel * 2.0 * 0.45 * gw) * delta
	_land += _land_vel * delta

	# Olhar: deslocamento da cabeça em direção ao alvo, limitado e suavizado.
	var want := Vector3.ZERO
	var weight: float = LOOK_WEIGHT.get(_mode, 0.0)
	if _look_on and weight > 0.0:
		var head: Node3D = _joints["head"]
		var parent := head.get_parent() as Node3D
		var dir := parent.global_transform.basis.orthonormalized().inverse() * (_look_pos - head.global_position)
		var horiz := Vector2(dir.x, dir.z).length()
		if horiz > 0.05:
			var yaw_d := rad_to_deg(atan2(dir.x, dir.z)) - (_cur["head"] as Vector3).y
			var pitch_d := rad_to_deg(atan2(-dir.y, horiz)) - (_cur["head"] as Vector3).x
			want = Vector3(clampf(pitch_d, -30.0, 30.0), clampf(yaw_d, -70.0, 70.0), 0.0) * weight
	_head_off = _head_off.lerp(want, 1.0 - exp(-7.0 * delta))


func _apply() -> void:
	_hips.position = Vector3(0.0, HIP_Y + _land, 0.0) + (_cur["root"] as Vector3)
	_body_root.rotation_degrees = Vector3((_cur["pitch"] as Vector3).x + _lean.x, (_cur["yaw"] as Vector3).x, _lean.y)
	for j in ROT_JOINTS:
		(_joints[j] as Node3D).rotation_degrees = _cur[j]
	(_joints["head"] as Node3D).rotation_degrees += _head_off
	if _charge_level >= 0 and _mode == Mode.ATTACK:
		var amp := 0.4 + 0.9 * _charge_level
		var tremor := sin(_time * 63.0) * amp
		(_joints["spine"] as Node3D).rotation_degrees.x += tremor
		(_joints["sh_r"] as Node3D).rotation_degrees.x += sin(_time * 71.0) * amp * 1.4
		_hips.position.y -= absf(tremor) * 0.006
	if _mode == Mode.LOCOMOTION:
		(_joints["wr_r"] as Node3D).rotation_degrees.x += _sway.x
		(_joints["sh_r"] as Node3D).rotation_degrees.z += _sway.y


## Ângulo do pulso (graus) para apoiar a arma no ombro ao andar; 999 = arma que não se apoia.
func _carry_wrist() -> float:
	match weapon:
		Weapon.HAMMER:
			return -112.0
		Weapon.SWORD, Weapon.CLUB:
			return -92.0
	return 999.0


## Golpes de duas mãos: a mão esquerda segue o cabo da arma (IK de dois ossos) e o que ela
## segurava (orbe, escudo) é guardado enquanto isso.
func _two_hand_apply(delta: float, instant := false) -> void:
	var want := _mode == Mode.ATTACK and GRIP2.has(int(weapon)) and Poses.TWO_HANDED.has(_atk_anim)
	var goal := 1.0 if want else 0.0
	_two_hand = goal if instant else move_toward(_two_hand, goal, delta / 0.14)
	# Escudo: de lado no antebraço (andar, atacar, parado); de frente só na guarda e na investida.
	var forearm: Node3D = _joints["el_l"]
	var shield := forearm.get_node_or_null("ShieldSocket") as Node3D
	if shield != null:
		var front := (_mode == Mode.GUARD and _guard_shield) or (_mode == Mode.ATTACK and _atk_anim == "bash")
		var goal_f := 1.0 if front else 0.0
		_shield_front = goal_f if instant else move_toward(_shield_front, goal_f, delta / 0.15)
		var q_side := Quaternion.from_euler(Vector3(0, 0, PI / 2.0))
		var q_front := Quaternion.from_euler(Vector3(PI / 2.0, 0, 0))
		shield.basis = Basis(q_side.slerp(q_front, _shield_front))
		shield.position = Vector3(0.09, -0.16, 0.0).lerp(Vector3(0, -0.16, -0.07), _shield_front)
	var stow := _two_hand > 0.3
	var holders: Array = [[_hand_l, "OffhandSocket"], [_joints.get("el_l"), "ShieldSocket"]]
	for pair in holders:
		var holder := pair[0] as Node
		if holder == null:
			continue
		var item := holder.get_node_or_null(pair[1] as String) as Node3D
		if item != null:
			item.visible = not stow
	if _two_hand <= 0.001 or _wrist == null:
		return
	var socket := _wrist.get_node_or_null("WeaponSocket") as Node3D
	if socket == null:
		return
	var sh: Node3D = _joints["sh_l"]
	var el: Node3D = _joints["el_l"]
	var spine := sh.get_parent() as Node3D
	var grip: Vector3 = spine.global_transform.affine_inverse() * (socket.global_transform * Vector3(0, 0, GRIP2[int(weapon)]))
	var a := 0.3
	var b := 0.29
	var v := grip - sh.position
	var d := clampf(v.length(), 0.12, a + b - 0.01)
	var dir := v.normalized()
	var bend := PI - acos(clampf((a * a + b * b - d * d) / (2.0 * a * b), -1.0, 1.0))
	var al := acos(clampf((a * a + d * d - b * b) / (2.0 * a * d), -1.0, 1.0))
	var pole := Vector3(0.6, -1.0, -0.3) # cotovelo aponta para baixo e um pouco para fora
	var perp := pole - dir * pole.dot(dir)
	perp = perp.normalized() if perp.length() > 0.01 else Vector3.RIGHT
	var upper := dir * cos(al) + perp * sin(al)
	var elbow := sh.position + upper * a
	var fore := (sh.position + dir * d - elbow).normalized()
	var zax := (fore - upper * fore.dot(upper)).normalized()
	var yax := -upper
	var ik := Basis(yax.cross(zax), yax, zax)
	var k := smoothstep(0.0, 1.0, _two_hand)
	sh.basis = Basis(sh.basis.get_rotation_quaternion().slerp(ik.get_rotation_quaternion(), k))
	el.rotation_degrees = el.rotation_degrees.lerp(Vector3(-rad_to_deg(bend), 0, 0), k)


## Tabardo e capa: seguem o corpo com atraso e tendem a pender para baixo no mundo.
func _update_cloth(delta: float) -> void:
	if _tab_f != null:
		var th_l: float = (_cur["th_l"] as Vector3).x
		var th_r: float = (_cur["th_r"] as Vector3).x
		var local_v := global_transform.basis.orthonormalized().inverse() * _world_vel
		var drag := clampf(local_v.z * 2.5, -10.0, 25.0) # andar para frente joga o pano para trás
		var want := Vector2(clampf(minf(th_l, th_r) * 0.8 + drag, -60.0, 20.0), clampf(maxf(th_l, th_r) * 0.8 + drag, -10.0, 60.0))
		_tab = _tab.lerp(want, 1.0 - exp(-10.0 * delta))
		_tab_f.rotation_degrees.x = _tab.x
		_tab_b.rotation_degrees.x = _tab.y

	# Capa: cada segmento mira "para baixo no mundo + contra o movimento", com mola frouxa.
	var flow := -_world_vel * 0.09
	flow.y = 0.0
	for seg in _cape:
		var pivot: Node3D = seg["pivot"]
		var parent := pivot.get_parent() as Node3D
		var d := Vector3.DOWN + flow
		var dl := parent.global_transform.basis.orthonormalized().inverse() * d
		var target := clampf(atan2(-dl.z, -dl.y), deg_to_rad(-4.0), deg_to_rad(80.0))
		var w := 11.0
		seg["vel"] = float(seg["vel"]) + ((target - float(seg["angle"])) * w * w - float(seg["vel"]) * 2.0 * 0.35 * w) * delta
		seg["angle"] = float(seg["angle"]) + float(seg["vel"]) * delta
		pivot.rotation.x = seg["angle"]


## IK de duas juntas: se o tornozelo estiver abaixo do chão (degrau, agachamento, aterrissagem),
## dobra joelho e coxa para apoiar o pé sobre o chão. Só levanta o pé; nunca estica a perna.
func _leg_ik() -> void:
	if not foot_ik or not is_inside_tree():
		return
	if _mode in [Mode.DEAD, Mode.AIR_HURT, Mode.KNOCKDOWN]:
		return
	var space := get_world_3d().direct_space_state
	for n in ["l", "r"]:
		var th: Node3D = _joints["th_" + n]
		var kn: Node3D = _joints["kn_" + n]
		var ankle := kn.global_transform * Vector3(0, -SHIN_LEN, 0)
		var up := Vector3.UP * height
		var q := PhysicsRayQueryParameters3D.create(ankle + up * 0.6, ankle - up * 0.25, 1)
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			continue
		var min_y: float = (hit["position"] as Vector3).y + FOOT_H * height
		if ankle.y >= min_y:
			continue
		var parent := th.get_parent() as Node3D
		var inv := parent.global_transform.affine_inverse()
		var h_l := inv * th.global_position
		var t_l := inv * Vector3(ankle.x, min_y, ankle.z)
		var dy := t_l.y - h_l.y
		var dz := t_l.z - h_l.z
		var dist := clampf(sqrt(dy * dy + dz * dz), 0.1, THIGH_LEN + SHIN_LEN - 0.001)
		var phi := atan2(dz, -dy) # ângulo a partir da vertical; positivo = para frente
		var knee_int := acos(clampf((THIGH_LEN * THIGH_LEN + SHIN_LEN * SHIN_LEN - dist * dist) / (2.0 * THIGH_LEN * SHIN_LEN), -1.0, 1.0))
		var alpha := acos(clampf((THIGH_LEN * THIGH_LEN + dist * dist - SHIN_LEN * SHIN_LEN) / (2.0 * THIGH_LEN * dist), -1.0, 1.0))
		th.rotation.x = -(phi + alpha)
		kn.rotation.x = PI - knee_int


# --- Construção do corpo ----------------------------------------------------

func _build() -> void:
	var m_skin := _mat(skin, 0.7)
	var m_cloth := _mat(cloth, 0.85)
	var m_acc := _mat(accent, 0.45)
	m_acc.metallic = 0.35
	var m_leather := _mat(Color(0.26, 0.17, 0.1), 0.8)
	var m_dark := _mat(Color(0.08, 0.07, 0.07), 0.6)
	if headgear == Headgear.GOLEM: # golem: nada de couro, tudo é pedra (mãos e botas mais escuras)
		m_leather = _mat(skin.darkened(0.3), 0.95)
	var b := bulk

	_body_root = Node3D.new()
	_body_root.name = "BodyRoot"
	add_child(_body_root)

	# Quadril, cinto e tabardo
	_hips = _pivot(_body_root, "hips", Vector3(0, HIP_Y, 0))
	_box(_hips, Vector3(0.36 * b, 0.18, 0.24 * b), Vector3(0, 0.0, 0), m_cloth)
	_box(_hips, Vector3(0.4 * b, 0.07, 0.27 * b), Vector3(0, 0.08, 0), m_leather) # cinto
	_box(_hips, Vector3(0.08, 0.06, 0.03), Vector3(0, 0.08, 0.14 * b), m_acc) # fivela
	if tabard:
		_tab_f = _build_tabard(Vector3(0, 0.04, 0.13 * b), m_cloth)
		_tab_b = _build_tabard(Vector3(0, 0.04, -0.13 * b), m_cloth)

	# Tronco: abdômen, peito, peitoral, ombros e pescoço
	var spine := _pivot(_hips, "spine", Vector3(0, 0.08, 0))
	_box(spine, Vector3(0.38 * b, 0.24, 0.24 * b), Vector3(0, 0.12, 0), m_cloth)
	_box(spine, Vector3(0.48 * b, 0.32, 0.28 * b), Vector3(0, 0.36, 0), m_cloth)
	_box(spine, Vector3(0.42 * b, 0.26, 0.05), Vector3(0, 0.37, 0.14 * b), m_acc) # peitoral
	_box(spine, Vector3(0.56 * b, 0.1, 0.26 * b), Vector3(0, 0.52, 0), m_acc) # ombros
	_capsule(spine, 0.06, 0.14, Vector3(0, 0.6, 0), m_skin) # pescoço
	if runes:
		var m_rune := _rune_material()
		_box(spine, Vector3(0.05, 0.22, 0.02), Vector3(0, 0.36, 0.16 * b), m_rune)
		_box(spine, Vector3(0.18, 0.04, 0.02), Vector3(0, 0.4, 0.16 * b), m_rune)
		_box(spine, Vector3(0.12, 0.04, 0.02), Vector3(0, 0.3, 0.16 * b), m_rune)
	if cape:
		_build_cape(spine)
	if weapon == Weapon.BOW:
		var quiver := _box(spine, Vector3(0.12, 0.5, 0.12), Vector3(0.12 * b, 0.36, -0.2 * b), m_leather)
		quiver.rotation_degrees = Vector3(0, 0, -18)
		for k in 3:
			_box(quiver, Vector3(0.02, 0.18, 0.02), Vector3(-0.03 + k * 0.03, 0.32, 0), m_cloth)

	# Cabeça e o que vai nela
	var head := _pivot(spine, "head", Vector3(0, 0.62, 0))
	_sphere(head, 0.12, Vector3(0, 0.14, 0), m_skin, Vector3(0.95, 1.05, 1.0))
	match headgear:
		Headgear.HELMET:
			_sphere(head, 0.135, Vector3(0, 0.18, -0.005), m_acc, Vector3(1.0, 0.78, 1.05))
			_box(head, Vector3(0.2, 0.035, 0.04), Vector3(0, 0.15, 0.115), m_dark) # fresta da viseira
			_box(head, Vector3(0.03, 0.07, 0.24), Vector3(0, 0.29, -0.02), m_cloth) # crista
		Headgear.HOOD:
			_sphere(head, 0.15, Vector3(0, 0.16, -0.025), m_cloth, Vector3(1.05, 1.02, 1.1))
			_box(head, Vector3(0.12, 0.03, 0.02), Vector3(0, 0.15, 0.115), m_dark) # sombra dos olhos
		Headgear.GOLEM:
			# Cabeça de pedra: bloco com sobrancelha pesada, mandíbula e olhos brilhantes.
			_box(head, Vector3(0.27, 0.22, 0.25), Vector3(0, 0.13, 0), m_skin)
			_box(head, Vector3(0.3, 0.07, 0.1), Vector3(0, 0.22, 0.12), m_acc) # sobrancelha
			_box(head, Vector3(0.2, 0.07, 0.1), Vector3(0, 0.02, 0.1), m_acc) # mandíbula
			_box(head, Vector3(0.08, 0.1, 0.1), Vector3(-0.09, 0.28, -0.05), m_acc) # pedras no topo
			_box(head, Vector3(0.1, 0.07, 0.1), Vector3(0.08, 0.27, 0.0), m_acc)
			var m_eye := _rune_material()
			for ex in [-0.065, 0.065]:
				_box(head, Vector3(0.05, 0.035, 0.03), Vector3(ex, 0.15, 0.125), m_eye)
		_:
			_sphere(head, 0.128, Vector3(0, 0.2, -0.015), m_dark, Vector3(1.0, 0.6, 1.0)) # cabelo
			for ex in [-0.045, 0.045]:
				_box(head, Vector3(0.03, 0.025, 0.02), Vector3(ex, 0.15, 0.112), m_dark) # olhos

	# Braços: ombreira, braço, cotovelo, antebraço, manopla e punho
	for side in [["r", -1.0], ["l", 1.0]]:
		var n: String = side[0]
		var sg: float = side[1]
		var sh := _pivot(spine, "sh_" + n, Vector3(sg * 0.3 * b, 0.48, 0))
		var pr := 0.09 * b * pauldron_scale
		_sphere(sh, pr, Vector3(sg * 0.02, 0.03, 0), m_acc, Vector3(1.15, 0.8, 1.05))
		_capsule(sh, 0.056 * b, 0.3, Vector3(0, -0.15, 0), m_cloth)
		var el := _pivot(sh, "el_" + n, Vector3(0, -0.3, 0))
		_sphere(el, 0.05 * b, Vector3.ZERO, m_acc)
		_capsule(el, 0.048 * b, 0.26, Vector3(0, -0.13, 0), m_skin)
		_box(el, Vector3(0.11 * b, 0.13, 0.11 * b), Vector3(0, -0.2, 0), m_leather) # manopla
		var hand := Node3D.new()
		hand.name = "hand_" + n
		hand.position = Vector3(0, -0.29, 0)
		el.add_child(hand)
		hand.scale = Vector3.ONE * fist_scale
		_box(hand, Vector3(0.085 * b, 0.1, 0.095), Vector3(0, -0.01, 0.005), m_leather) # punho
		if n == "r":
			_build_weapon(hand, m_acc)
		else:
			_hand_l = hand
			_build_offhand()
			if weapon == Weapon.BOW:
				_build_bow(hand, m_acc)

		# Pernas: coxa, joelheira, cano da bota e pé
		var th := _pivot(_hips, "th_" + n, Vector3(sg * 0.11 * b, -0.02, 0))
		_capsule(th, 0.085 * b, THIGH_LEN, Vector3(0, -THIGH_LEN * 0.5, 0), m_cloth)
		var kn := _pivot(th, "kn_" + n, Vector3(0, -THIGH_LEN, 0))
		_sphere(kn, 0.07 * b, Vector3(0, 0, 0.035), m_acc, Vector3(1.0, 1.0, 0.8))
		_capsule(kn, 0.072 * b, 0.4, Vector3(0, -0.21, 0), m_leather)
		_box(kn, Vector3(0.115 * b, 0.08, 0.25), Vector3(0, -0.43, 0.05), m_leather)
		_box(kn, Vector3(0.12 * b, 0.025, 0.26), Vector3(0, -0.47, 0.05), m_dark) # sola


## Espada/clava na mão direita. O pulso ("wr_r") é uma junta animada: com rotação zero a lâmina
## continua a linha do antebraço; X negativo inclina a lâmina para o lado do polegar (para cima
## quando o braço aponta para frente), X positivo para o lado oposto.
func _build_weapon(hand: Node3D, mat: StandardMaterial3D) -> void:
	_wrist = _pivot(hand, "wr_r", Vector3.ZERO)
	_weapon_mat = mat
	_make_weapon()


## Troca a arma em tempo de execução (menu de equipamento).
func set_weapon(kind: Weapon) -> void:
	if kind == weapon or _wrist == null:
		return
	weapon = kind
	var old := _wrist.get_node_or_null("WeaponSocket")
	if old != null:
		old.name = "_removed"
		old.queue_free()
	_make_weapon()


func _make_weapon() -> void:
	var mat := _weapon_mat
	var socket := Node3D.new()
	socket.name = "WeaponSocket"
	socket.rotation_degrees = Vector3(90, 0, 0) # +Z do soquete = linha do antebraço
	_wrist.add_child(socket)

	sword_base = Marker3D.new()
	sword_tip = Marker3D.new()
	socket.add_child(sword_base)
	socket.add_child(sword_tip)

	match weapon:
		Weapon.SWORD:
			var steel := _mat(Color(0.82, 0.86, 0.92), 0.25)
			steel.metallic = 0.8
			_box(socket, Vector3(0.04, 0.04, 0.16), Vector3(0, 0, 0.03), mat) # empunhadura
			_box(socket, Vector3(0.04, 0.04, 0.2), Vector3(0, 0, -0.1), mat) # cabo longo (2ª mão)
			_box(socket, Vector3(0.05, 0.22, 0.04), Vector3(0, 0, 0.12), mat) # guarda
			_box(socket, Vector3(0.012, 0.07, 0.95), Vector3(0, 0, 0.6), steel) # lâmina
			sword_base.position = Vector3(0, 0, 0.12)
			sword_tip.position = Vector3(0, 0, 1.07)
		Weapon.CLUB:
			var wood := _mat(Color(0.35, 0.24, 0.15), 0.9)
			_box(socket, Vector3(0.07, 0.07, 0.3), Vector3(0, 0, 0.1), wood)
			_box(socket, Vector3(0.16, 0.16, 0.45), Vector3(0, 0, 0.55), wood)
			sword_base.position = Vector3(0, 0, 0.3)
			sword_tip.position = Vector3(0, 0, 0.8)
		Weapon.HAMMER:
			# Cabo longo e cabeça de aço maciça: pesado e largo.
			var haft := _mat(Color(0.36, 0.24, 0.14), 0.85)
			var iron := _mat(Color(0.55, 0.57, 0.62), 0.35)
			iron.metallic = 0.7
			_box(socket, Vector3(0.055, 0.055, 1.45), Vector3(0, 0, 0.675), haft)
			_box(socket, Vector3(0.07, 0.07, 0.1), Vector3(0, 0, -0.06), mat) # pomo
			_box(socket, Vector3(0.3, 0.24, 0.22), Vector3(0, 0, 1.4), iron) # cabeça
			_box(socket, Vector3(0.33, 0.07, 0.25), Vector3(0, 0.14, 1.4), mat) # reforço
			# Pegada no meio do cabo: a mão fica 0,5 m depois do pomo (o +Z do soquete desce pelo antebraço).
			socket.position = Vector3(0, HAMMER_GRIP, 0)
			sword_base.position = Vector3(0, 0, 0.05) # varre o cabo inteiro (acerta também de perto)
			sword_tip.position = Vector3(0, 0, 1.52)
		Weapon.STAFF:
			# Cajado do sacerdote: haste com um cristal brilhante no topo.
			var wood := _mat(Color(0.5, 0.38, 0.22), 0.8)
			_box(socket, Vector3(0.045, 0.045, 1.7), Vector3(0, 0, 0.5), wood)
			_sphere(socket, 0.075, Vector3(0, 0, 1.38), _rune_material())
			_box(socket, Vector3(0.1, 0.1, 0.05), Vector3(0, 0, 1.28), mat)
			sword_base.position = Vector3(0, 0, 1.2)
			sword_tip.position = Vector3(0, 0, 1.4)
		_:
			sword_base.position = Vector3(0, 0, 0.0)
			sword_tip.position = Vector3(0, 0, 0.25)


## Painel de tecido pendurado no cinto (frente ou trás); gira em X a partir do topo.
func _build_tabard(pos: Vector3, mat: StandardMaterial3D) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = pos
	_hips.add_child(pivot)
	_box(pivot, Vector3(0.28 * bulk, 0.42, 0.02), Vector3(0, -0.21, 0), mat)
	return pivot


## Capa em 3 segmentos presos às costas; cada um balança com atraso em relação ao anterior.
func _build_cape(spine: Node3D) -> void:
	var m := _mat(cape_color, 0.9)
	var parent: Node3D = spine
	var pos := Vector3(0, 0.54, -0.15 * bulk)
	var widths := [0.5, 0.54, 0.58]
	for i in 3:
		var pivot := Node3D.new()
		pivot.position = pos
		parent.add_child(pivot)
		_box(pivot, Vector3(widths[i] * bulk, 0.33, 0.02), Vector3(0, -0.165, 0), m)
		_cape.append({"pivot": pivot, "angle": 0.0, "vel": 0.0})
		parent = pivot
		pos = Vector3(0, -0.33, 0)


## Arco na mão esquerda (arqueiros). O eixo do arco segue o +Z da mão: fica na vertical
## quando o braço aponta para frente. A corda fica do lado do arqueiro (+Y da mão).
func _build_bow(hand: Node3D, mat: StandardMaterial3D) -> void:
	var wood := _mat(Color(0.45, 0.3, 0.16), 0.8)
	var upper := _box(hand, Vector3(0.035, 0.035, 0.5), Vector3(0, 0.05, 0.27), wood)
	upper.rotation_degrees = Vector3(-14, 0, 0)
	var lower := _box(hand, Vector3(0.035, 0.035, 0.5), Vector3(0, 0.05, -0.27), wood)
	lower.rotation_degrees = Vector3(14, 0, 0)
	_box(hand, Vector3(0.05, 0.05, 0.12), Vector3.ZERO, mat) # empunhadura
	_box(hand, Vector3(0.008, 0.008, 1.02), Vector3(0, 0.12, 0), _mat(Color(0.9, 0.9, 0.85), 0.5)) # corda


## Troca o equipamento secundário em tempo de execução (menu de equipamento).
func set_offhand(kind: Offhand) -> void:
	if kind == offhand or _hand_l == null:
		return
	offhand = kind
	for socket_name in ["OffhandSocket", "ShieldSocket"]:
		for parent in [_hand_l, _joints.get("el_l")]:
			var old: Node = (parent as Node).get_node_or_null(socket_name)
			if old != null:
				old.name = "_removed"
				old.queue_free()
	_orb_mat = null
	_orb_light = null
	offhand_tip = null
	_build_offhand()


func _build_offhand() -> void:
	match offhand:
		Offhand.ORB:
			_build_orb(_hand_l)
		Offhand.SHIELD:
			_build_shield(_joints["el_l"])


## Escudo redondo preso ao antebraço esquerdo. A face aponta para o -Z do antebraço:
## fica de frente para o inimigo quando o braço está erguido na guarda.
func _build_shield(forearm: Node3D) -> void:
	var socket := Node3D.new()
	socket.name = "ShieldSocket"
	socket.position = Vector3(0, -0.16, -0.07)
	socket.rotation_degrees = Vector3(90, 0, 0)
	forearm.add_child(socket)
	var wood := _mat(Color(0.42, 0.26, 0.14), 0.85)
	var metal := _mat(Color(0.7, 0.7, 0.75), 0.3)
	metal.metallic = 0.7
	var disc := CylinderMesh.new()
	disc.top_radius = 0.32
	disc.bottom_radius = 0.32
	disc.height = 0.05
	_add(socket, disc, Vector3.ZERO, wood)
	var rim := TorusMesh.new()
	rim.inner_radius = 0.3
	rim.outer_radius = 0.34
	_add(socket, rim, Vector3.ZERO, metal)
	var boss := SphereMesh.new()
	boss.radius = 0.07
	boss.height = 0.14
	_add(socket, boss, Vector3(0, -0.03, 0), metal)


## Orbe flutuando logo à frente da palma esquerda, com luz própria e brilho pulsante.
func _build_orb(hand: Node3D) -> void:
	var holder := Node3D.new()
	holder.name = "OffhandSocket"
	holder.position = Vector3(0, -0.1, 0.04)
	hand.add_child(holder)

	_orb_mat = StandardMaterial3D.new()
	_orb_mat.albedo_color = offhand_color
	_orb_mat.emission_enabled = true
	_orb_mat.emission = offhand_color
	_orb_mat.emission_energy_multiplier = 1.5
	var orb := SphereMesh.new()
	orb.radius = 0.085
	orb.height = 0.17
	_add(holder, orb, Vector3.ZERO, _orb_mat)

	# Anel metálico que "segura" o orbe.
	var ring := TorusMesh.new()
	ring.inner_radius = 0.085
	ring.outer_radius = 0.105
	var ring_mi := _add(holder, ring, Vector3.ZERO, _mat(Color(0.75, 0.62, 0.3), 0.35))
	ring_mi.rotation_degrees = Vector3(90, 0, 0)

	_orb_light = OmniLight3D.new()
	_orb_light.light_color = offhand_color
	_orb_light.light_energy = 0.6
	_orb_light.omni_range = 1.6
	holder.add_child(_orb_light)

	offhand_tip = Marker3D.new()
	holder.add_child(offhand_tip)


## Intensifica o brilho do orbe (0 = repouso, 1 = conjurando).
func set_offhand_charge(amount: float) -> void:
	_orb_boost = clampf(amount, 0.0, 1.0)


func _update_orb() -> void:
	if _orb_mat == null:
		return
	var pulse := 0.5 + 0.5 * sin(_time * 4.0)
	_orb_mat.emission_energy_multiplier = 1.2 + pulse * 0.6 + _orb_boost * 5.0
	_orb_light.light_energy = 0.4 + pulse * 0.3 + _orb_boost * 3.0


func _pivot(parent: Node3D, joint: String, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.name = joint
	n.position = pos
	parent.add_child(n)
	_joints[joint] = n
	return n


## Material emissivo das runas; fica fora de _mats para não ser apagado pelo set_glow/flash.
func _rune_material() -> StandardMaterial3D:
	if _rune_mat == null:
		_rune_mat = StandardMaterial3D.new()
		_rune_mat.albedo_color = rune_color
		_rune_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return _rune_mat


func _mat(color: Color, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	_mats.append(m)
	return m


func _add(parent: Node3D, mesh: Mesh, pos: Vector3, mat: StandardMaterial3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = mat
	parent.add_child(mi)
	return mi


func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: StandardMaterial3D) -> MeshInstance3D:
	var m := BoxMesh.new()
	m.size = size
	return _add(parent, m, pos, mat)


func _sphere(parent: Node3D, radius: float, pos: Vector3, mat: StandardMaterial3D, squash := Vector3.ONE) -> MeshInstance3D:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	var mi := _add(parent, m, pos, mat)
	mi.scale = squash
	return mi


func _capsule(parent: Node3D, radius: float, length: float, pos: Vector3, mat: StandardMaterial3D) -> MeshInstance3D:
	var m := CapsuleMesh.new()
	m.radius = radius
	m.height = maxf(length, radius * 2.0)
	return _add(parent, m, pos, mat)
