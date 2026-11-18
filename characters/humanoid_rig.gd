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
enum Weapon { SWORD, CLUB, NONE, BOW, HAMMER, STAFF, SPEAR }
## Equipamento secundário na mão esquerda.
enum Offhand { NONE, ORB, SHIELD, CROSSBOW }
enum Headgear { HELMET, HOOD, HAIR, GOLEM, WIZARD }

const HIP_Y := 0.95
## Distância do pomo do martelo até a mão (pegada no meio do cabo).
const HAMMER_GRIP := 0.5
## Onde a mão esquerda segura a arma nos golpes de duas mãos (z no soquete da arma).
const GRIP2 := {0: -0.14, 4: 0.12, 6: 0.62} # Weapon.SWORD, Weapon.HAMMER, Weapon.SPEAR
## Lança fora dos golpes: uma mão só, segurando perto do meio da haste (a haste desliza na mão para
## trás). Nos golpes ela volta para a pegada de estocada (mão direita atrás, esquerda à frente).
const SPEAR_REST_SHIFT := -0.75
## Juntas derivadas (não aparecem nas poses): peito, pescoço e clavículas dividem a rotação do
## tronco/cabeça/ombro e chegam com atraso próprio; a ponta do pé dobra ao desprender do chão.
const CHEST_Y := 0.22
const NECK_Y := 0.34
const CLAV_X := 0.09
const TOE_Z := 0.095
## Fração da rotação do tronco que fica no peito e da cabeça que fica no pescoço.
const CHEST_SHARE := 0.5
## Respiração: amplitude (graus no peito) parado e o extra depois de esforço (golpes, esquivas).
const BREATH_IDLE := 1.4
const BREATH_EXERTION := 3.5
## Animações em que as mãos ficam abertas (conjurar, puxar a corda do arco).
const OPEN_HAND_ANIMS := {"cast": true, "priest_cast": true, "e_draw": true, "taunt": true}
## Mira da besta de mão (camada sobre a locomoção): braço esquerdo estendido à frente na altura do
## ombro, tronco levemente virado para o braço. As pernas continuam andando/correndo.
const AIM_POSE := {
	"sh_l": Vector3(-86, -6, 6), "el_l": Vector3(-3, 0, 0),
	"spine": Vector3(4, 10, 0), "head": Vector3(0, -6, 0),
}
const AIM_BLEND_TIME := 0.12
const NECK_SHARE := 0.35
const THIGH_LEN := 0.45
const SHIN_LEN := 0.45
const FOOT_H := 0.06
const LEG_REACH := THIGH_LEN + SHIN_LEN - 0.012
## Tempo para soltar/prender o pé da trava e queda máxima do quadril para alcançar o pé travado.
const FOOT_BLEND := 0.1
## Quanto antes do toque o pé em balanço já é guiado ao ponto de pouso (s).
const PRE_PLANT := 0.09
const MAX_PELVIS_DROP := 0.15
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
var _atk_two_hand := false
var _spear_body: Node3D # haste da lança (desliza entre a pegada de descanso e a de estocada)
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
# Trava de pé (índice 0 = esquerdo, 1 = direito)
var _foot_lock: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _foot_w: Array[float] = [0.0, 0.0]
var _phase_rate := 0.0 # rad/s do ciclo de passos
var _stride_half := 0.0 # meio passo (m, já com a escala do rig)
var _pelvis_drop := 0.0
var _feet: Dictionary = {} # "l"/"r" -> pivô do pé
var _toes: Dictionary = {} # "l"/"r" -> pivô da ponta do pé
var _chest_lag := Vector3.ZERO # atraso do peito em relação à cintura (graus)
var _chest_lag_vel := Vector3.ZERO
var _clav := Vector2.ZERO # elevação das clavículas (graus): x = esquerda, y = direita
var _hands: Dictionary = {} # "l"/"r" -> nó da mão (pulso)
var _fingers: Dictionary = {} # "l"/"r" -> pivô dos dedos
var _finger_open := Vector2.ZERO # 0 = fechado, 1 = aberto (x = esquerda, y = direita)
var _wrist_l := Vector3.ZERO # arrasto do pulso esquerdo (graus)
var _wrist_l_vel := Vector3.ZERO
var _exertion := 0.0 # 0..1: sobe com golpes/esquivas, decai em ~3 s (respiração ofegante)
var _breath_phase := 0.0
var _aim := 0.0 # 0..1: peso da camada de mira da besta
var _aim_on := false


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


## two_handed: a mão esquerda segura o cabo da arma (AttackData.two_handed).
func set_attack(anim: String, startup: float, active: float, recovery: float, t: float, two_handed := false) -> void:
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
	_atk_two_hand = two_handed
	_atk = Vector4(startup, active, recovery, t)


## Mira da besta: braço esquerdo estendido sobre a locomoção (andar/correr continuam).
func set_aim(on: bool) -> void:
	_aim_on = on


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
	_aim = 1.0 if (_aim_on and _mode == Mode.LOCOMOTION) else 0.0
	_cur = _compute_target(0.0).duplicate()
	for j in Poses.JOINTS:
		_vel[j] = Vector3.ZERO
	_apply()
	_two_hand_apply(0.0, true)
	_update_skin()


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
	var pose := Poses.locomotion(_phase, _speed, _on_floor, _vy, _time, _carry_wrist(), weapon == Weapon.SPEAR)
	if _aim > 0.0:
		pose = pose.duplicate() # algumas poses vêm de cache
		var k := smoothstep(0.0, 1.0, _aim)
		for j in AIM_POSE:
			var base: Vector3 = pose.get(j, Vector3.ZERO)
			var aim: Vector3 = AIM_POSE[j]
			# Tronco e cabeça: a mira soma ao balanço do passo; o braço substitui.
			pose[j] = base.lerp(aim, k) if j in ["sh_l", "el_l"] else base + aim * k
	return pose


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
		_update_skin()
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
	_aim = move_toward(_aim, 1.0 if (_aim_on and _mode == Mode.LOCOMOTION) else 0.0, delta / AIM_BLEND_TIME)
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
	_leg_ik(delta)
	_update_skin()


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


## Elevação da clavícula (graus) para a pose atual do ombro do lado `n`.
func _clav_raise(n: String) -> float:
	var sh: Vector3 = _cur["sh_" + n]
	var lift := clampf((-sh.x - 60.0) / 100.0, 0.0, 1.0) # braço erguido à frente/acima
	var abduct := clampf((absf(sh.z) - 35.0) / 70.0, 0.0, 1.0) # braço aberto para o lado
	return 16.0 * maxf(lift, abduct)


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
		_phase_rate = TAU * hv / (2.0 * step)
		_stride_half = 0.5 * step
		_phase += _phase_rate * delta
	else:
		_phase_rate = 0.0


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

	# Peito atrasa em relação à cintura: quanto mais rápido o tronco gira, mais o peito fica para trás
	# e depois "alcança" (sobreposição de movimento).
	var spine_v: Vector3 = _vel["spine"]
	var lag_target := (-spine_v * CHEST_SHARE * 0.035).clamp(Vector3.ONE * -9.0, Vector3.ONE * 9.0)
	var cw := 16.0
	_chest_lag_vel += ((lag_target - _chest_lag) * cw * cw - _chest_lag_vel * 2.0 * 0.5 * cw) * delta
	_chest_lag += _chest_lag_vel * delta
	# Clavículas: braço acima da linha do ombro (X < -60) ou aberto para o lado levanta o ombro.
	var clav_target := Vector2(_clav_raise("l"), _clav_raise("r"))
	_clav = _clav.lerp(clav_target, 1.0 - exp(-14.0 * delta))

	# Esforço: golpes e esquivas deixam o personagem ofegante por alguns segundos.
	if _mode in [Mode.ATTACK, Mode.DODGE]:
		_exertion = minf(_exertion + delta * 0.9, 1.0)
	else:
		_exertion = maxf(_exertion - delta * 0.3, 0.0)
	_breath_phase += delta * lerpf(0.5, 1.6, _exertion) # ~15 respirações/min parado, ~48 ofegante
	# Mãos: abrem ao conjurar/puxar o arco e na guarda sem escudo; fecham no resto.
	var open_l := 1.0 if (_mode == Mode.ATTACK and OPEN_HAND_ANIMS.has(_atk_anim)) or (_mode == Mode.GUARD and not _guard_shield) else 0.0
	var open_r := 1.0 if weapon in [Weapon.NONE] and _mode == Mode.ATTACK and OPEN_HAND_ANIMS.has(_atk_anim) else 0.0
	if _mode in [Mode.DEAD, Mode.KNOCKDOWN]:
		open_l = 0.6 # mão solta, meio aberta
		open_r = 0.6 if weapon == Weapon.NONE else 0.0
	_finger_open = _finger_open.lerp(Vector2(open_l, open_r), 1.0 - exp(-12.0 * delta))
	# Pulso esquerdo (mão livre): arrasta atrás do movimento do antebraço e assenta com mola.
	var el_v: Vector3 = _vel["el_l"]
	var sh_v: Vector3 = _vel["sh_l"]
	var wl_target := Vector3.ZERO
	if _two_hand < 0.05 and offhand != Offhand.CROSSBOW:
		wl_target = (-(el_v + sh_v) * 0.03).clamp(Vector3.ONE * -25.0, Vector3.ONE * 25.0)
		wl_target.y = 0.0
	var ww := 18.0
	_wrist_l_vel += ((wl_target - _wrist_l) * ww * ww - _wrist_l_vel * 2.0 * 0.45 * ww) * delta
	_wrist_l += _wrist_l_vel * delta

	# Olhar: deslocamento da cabeça em direção ao alvo, limitado e suavizado.
	var want := Vector3.ZERO
	var weight: float = LOOK_WEIGHT.get(_mode, 0.0)
	if _look_on and weight > 0.0:
		var head: Node3D = _joints["head"]
		var parent: Node3D = _joints["chest"] # olhar medido do peito (pescoço + cabeça somam a rotação)
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
	# Tronco dividido entre cintura e peito (o peito ainda atrasa um pouco: _chest_lag).
	var torso: Vector3 = _cur["spine"]
	(_joints["spine"] as Node3D).rotation_degrees = torso * (1.0 - CHEST_SHARE)
	(_joints["chest"] as Node3D).rotation_degrees = torso * CHEST_SHARE + _chest_lag
	# Cabeça dividida entre pescoço e cabeça (inclui o olhar).
	var look: Vector3 = (_cur["head"] as Vector3) + _head_off
	# Estabilização: a cabeça compensa parte da inclinação do corpo ao correr/curvar (olhar nivelado).
	if _mode == Mode.LOCOMOTION:
		look -= Vector3(_lean.x, 0.0, _lean.y) * 0.6
	(_joints["neck"] as Node3D).rotation_degrees = look * NECK_SHARE
	(_joints["head"] as Node3D).rotation_degrees = look * (1.0 - NECK_SHARE)
	# Respiração: peito sobe e desce (mais forte e rápido depois de esforço); ombros acompanham.
	var breath := sin(_breath_phase * TAU * 0.5) * lerpf(BREATH_IDLE, BREATH_EXERTION, _exertion)
	if _mode in [Mode.LOCOMOTION, Mode.GUARD]:
		(_joints["chest"] as Node3D).rotation_degrees.x -= breath
		(_joints["neck"] as Node3D).rotation_degrees.x += breath * 0.7
	# Dedos (0° = punho fechado) e pulso esquerdo.
	if _fingers.has("l"):
		(_fingers["l"] as Node3D).rotation_degrees = Vector3(-75.0 * _finger_open.x, 0.0, 0.0)
		(_fingers["r"] as Node3D).rotation_degrees = Vector3(-75.0 * _finger_open.y, 0.0, 0.0)
		(_hands["l"] as Node3D).rotation_degrees = _wrist_l
	# Clavículas: sobem (gira em Z) com o braço erguido; um pouco também ao inspirar.
	var inhale := maxf(sin(_breath_phase * TAU * 0.5), 0.0) * lerpf(0.6, 2.5, _exertion)
	(_joints["clav_l"] as Node3D).rotation_degrees = Vector3(0, -_clav.x * 0.35, _clav.x + inhale)
	(_joints["clav_r"] as Node3D).rotation_degrees = Vector3(0, _clav.y * 0.35, -_clav.y - inhale)
	if _charge_level >= 0 and _mode == Mode.ATTACK:
		var amp := 0.4 + 0.9 * _charge_level
		var tremor := sin(_time * 63.0) * amp
		(_joints["chest"] as Node3D).rotation_degrees.x += tremor
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
	var want := _mode == Mode.ATTACK and GRIP2.has(int(weapon)) and _atk_two_hand
	var goal := 1.0 if want else 0.0
	_two_hand = goal if instant else move_toward(_two_hand, goal, delta / 0.14)
	if _spear_body != null and is_instance_valid(_spear_body):
		_spear_body.position.z = lerpf(SPEAR_REST_SHIFT, 0.0, smoothstep(0.0, 1.0, _two_hand))
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


## IK nas pernas com TRAVA DE PÉ. Ao andar, o pé de apoio fica preso a um ponto do mundo desde o
## toque até o desprendimento (sem deslizar, a qualquer velocidade ou direção); o pé que vai pousar
## é guiado ao ponto previsto de toque (meio passo à frente do quadril) e o quadril desce o
## necessário para a perna alcançar. Fora do ciclo de passos, só levanta o pé que estiver abaixo
## do chão (degrau, agachamento, aterrissagem).
func _leg_ik(delta: float) -> void:
	if not foot_ik or not is_inside_tree():
		return
	if _mode in [Mode.DEAD, Mode.AIR_HURT, Mode.KNOCKDOWN]:
		_foot_w = [0.0, 0.0]
		return
	var space := get_world_3d().direct_space_state
	var walking := _mode == Mode.LOCOMOTION and _on_floor and _speed > 0.4 and _phase_rate > 0.01
	var c := cos(_phase)
	var goals: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
	var need := 0.0
	# 1) alvo de cada tornozelo (mundo) e quanto o quadril precisa descer para alcançá-lo
	for i in 2:
		var names := ["l", "r"]
		var th: Node3D = _joints["th_" + names[i]]
		var kn: Node3D = _joints["kn_" + names[i]]
		var ankle := kn.global_transform * Vector3(0, -SHIN_LEN, 0)
		var stance := walking and ((c < 0.0) if i == 0 else (c > 0.0))
		var plant := stance
		if walking and not stance:
			# Balanço: prevê o ponto de toque; perto do toque o pé já é guiado até lá.
			var rem := fposmod((PI * 0.5 if i == 0 else PI * 1.5) - _phase, TAU) / _phase_rate
			_foot_lock[i] = _predict_touchdown(1.0 if i == 0 else -1.0, rem)
			plant = rem < PRE_PLANT
		_foot_w[i] = move_toward(_foot_w[i], 1.0 if plant else 0.0, delta / FOOT_BLEND)
		var goal := ankle
		var w: float = smoothstep(0.0, 1.0, _foot_w[i])
		if w > 0.0:
			var lock: Vector3 = _foot_lock[i]
			var lq := PhysicsRayQueryParameters3D.create(lock + Vector3.UP * 0.5 * height, lock - Vector3.UP * 0.35 * height, 1)
			var lh := space.intersect_ray(lq)
			if not lh.is_empty():
				lock.y = (lh["position"] as Vector3).y + FOOT_H * height
				_foot_lock[i] = lock
				goal = ankle.lerp(lock, w)
				var inv := (th.get_parent() as Node3D).global_transform.affine_inverse()
				var rel := inv * goal - th.position
				var horiz := Vector2(rel.x, rel.z).length()
				var vert := sqrt(maxf(LEG_REACH * LEG_REACH - horiz * horiz, 0.0))
				need = maxf(need, -rel.y - vert)
		goals[i] = goal
	# 2) quadril desce suavemente (limitado: além disso o pé fica um pouco "curto" e só levanta)
	need = clampf(need, 0.0, MAX_PELVIS_DROP)
	_pelvis_drop = lerpf(_pelvis_drop, need, 1.0 - exp(-24.0 * delta))
	_hips.position.y -= _pelvis_drop
	# 3) resolve cada perna
	for i in 2:
		var names := ["l", "r"]
		var th: Node3D = _joints["th_" + names[i]]
		var kn: Node3D = _joints["kn_" + names[i]]
		var goal := goals[i]
		if _foot_w[i] <= 0.0:
			# Sem trava: a pose manda, mas o pé nunca fica abaixo do chão.
			var ankle := kn.global_transform * Vector3(0, -SHIN_LEN, 0)
			var up := Vector3.UP * height
			var q := PhysicsRayQueryParameters3D.create(ankle + up * 0.6, ankle - up * 0.25, 1)
			var hit := space.intersect_ray(q)
			if hit.is_empty():
				continue
			var min_y: float = (hit["position"] as Vector3).y + FOOT_H * height
			if ankle.y >= min_y:
				continue
			goal = Vector3(ankle.x, min_y, ankle.z)
		_solve_leg(th, kn, goal)
	_orient_feet(walking)


## Pés planos no chão durante o apoio, com ponta para baixo ao desprender e calcanhar primeiro ao pousar.
func _orient_feet(walking: bool) -> void:
	var flat := Basis(Vector3.UP, global_rotation.y)
	for i in 2:
		var n: String = "l" if i == 0 else "r"
		var ft: Node3D = _feet[n]
		var toe: Node3D = _toes[n]
		var w: float = smoothstep(0.0, 1.0, _foot_w[i])
		if w <= 0.0:
			ft.rotation = Vector3.ZERO
			toe.rotation = Vector3.ZERO
			continue
		var start := PI * 0.5 if i == 0 else PI * 1.5
		var u := fposmod(_phase - start, TAU) / PI # 0..1 durante o apoio, >1 no balanço
		var pitch := 0.0
		if walking:
			if u < 1.0:
				pitch = deg_to_rad(28.0) * smoothstep(0.75, 1.0, u) - deg_to_rad(10.0) * (1.0 - smoothstep(0.0, 0.2, u))
			else:
				pitch = -deg_to_rad(14.0) # calcanhar primeiro, antes do toque
		var want := flat * Basis(Vector3.RIGHT, pitch)
		# Calcanhar subindo (pitch > 0): a ponta dobra para ficar apoiada no chão.
		toe.rotation = Vector3(-maxf(pitch, 0.0) * w, 0.0, 0.0)
		var kb := (_joints["kn_" + n] as Node3D).global_transform.basis.orthonormalized()
		var local_q := (kb.inverse() * want).get_rotation_quaternion()
		ft.basis = Basis(Quaternion.IDENTITY.slerp(local_q, w))


## Onde o pé do lado `side` (+1 esquerdo, -1 direito) vai pousar daqui a `time` s: meio passo à
## frente do quadril, na direção do movimento.
func _predict_touchdown(side: float, time: float) -> Vector3:
	var b := global_transform.basis.orthonormalized()
	var hv := Vector3(_world_vel.x, 0.0, _world_vel.z)
	var dir := hv.normalized() if hv.length() > 0.1 else b.z
	var p := global_position + b.x * (side * 0.11 * bulk * height) + hv * time
	return p + dir * _stride_half


## IK de duas juntas em 3D: coloca o tornozelo em `goal` (mundo). O joelho dobra para frente.
func _solve_leg(th: Node3D, kn: Node3D, goal: Vector3) -> void:
	var parent := th.get_parent() as Node3D
	var v := parent.global_transform.affine_inverse() * goal - th.position
	var dist := clampf(v.length(), 0.1, THIGH_LEN + SHIN_LEN - 0.001)
	var u := v.normalized()
	var fwd := Vector3(0, 0, 1)
	var f0 := fwd - u * fwd.dot(u)
	f0 = f0.normalized() if f0.length() > 0.05 else Vector3.UP
	var knee_int := acos(clampf((THIGH_LEN * THIGH_LEN + SHIN_LEN * SHIN_LEN - dist * dist) / (2.0 * THIGH_LEN * SHIN_LEN), -1.0, 1.0))
	var alpha := acos(clampf((THIGH_LEN * THIGH_LEN + dist * dist - SHIN_LEN * SHIN_LEN) / (2.0 * THIGH_LEN * dist), -1.0, 1.0))
	var d := (u * cos(alpha) + f0 * sin(alpha)).normalized() # direção da coxa
	var f := (fwd - d * fwd.dot(d)).normalized()
	var x := -(d.cross(f)).normalized() # eixo de dobra do joelho
	var y := -d
	th.basis = Basis(x, y, x.cross(y))
	kn.rotation = Vector3(PI - knee_int, 0.0, 0.0)


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
	_soft_box(_hips, Vector3(0.41 * b, 0.07, 0.28 * b), Vector3(0, 0.08, 0), m_leather, 0.3) # cinto
	_soft_box(_hips, Vector3(0.08, 0.06, 0.03), Vector3(0, 0.08, 0.145 * b), m_acc, 0.2) # fivela
	if tabard:
		_tab_f = _build_tabard(Vector3(0, 0.04, 0.13 * b), m_cloth)
		_tab_b = _build_tabard(Vector3(0, 0.04, -0.13 * b), m_cloth)

	# Tronco em duas juntas: "spine" (abdômen) e "chest" (peito), que divide a rotação do tronco e
	# chega com atraso (o peito "segue" a cintura). Pescoço é uma junta própria entre peito e cabeça.
	var spine := _pivot(_hips, "spine", Vector3(0, 0.08, 0))
	var chest := _pivot(spine, "chest", Vector3(0, CHEST_Y, 0))
	_soft_box(chest, Vector3(0.42 * b, 0.27, 0.07), Vector3(0, 0.15, 0.125 * b), m_acc, 0.35) # peitoral
	_soft_box(chest, Vector3(0.54 * b, 0.1, 0.27 * b), Vector3(0, 0.3, 0), m_acc, 0.4) # ombros
	var neck := _pivot(chest, "neck", Vector3(0, NECK_Y, 0))
	if runes:
		var m_rune := _rune_material()
		_box(chest, Vector3(0.05, 0.22, 0.02), Vector3(0, 0.14, 0.165 * b), m_rune)
		_box(chest, Vector3(0.18, 0.04, 0.02), Vector3(0, 0.18, 0.165 * b), m_rune)
		_box(chest, Vector3(0.12, 0.04, 0.02), Vector3(0, 0.08, 0.165 * b), m_rune)
	if cape:
		_build_cape(chest)
	if weapon == Weapon.BOW:
		var quiver := _soft_box(chest, Vector3(0.12, 0.5, 0.12), Vector3(0.12 * b, 0.14, -0.2 * b), m_leather, 0.4)
		quiver.rotation_degrees = Vector3(0, 0, -18)
		for k in 3:
			_box(quiver, Vector3(0.02, 0.18, 0.02), Vector3(-0.03 + k * 0.03, 0.32, 0), m_cloth)

	# Cabeça e o que vai nela
	var head := _pivot(neck, "head", Vector3(0, 0.62 - CHEST_Y - NECK_Y, 0))
	_sphere(head, 0.12, Vector3(0, 0.14, 0), m_skin, Vector3(0.95, 1.05, 1.0))
	match headgear:
		Headgear.HELMET:
			_sphere(head, 0.135, Vector3(0, 0.18, -0.005), m_acc, Vector3(1.0, 0.78, 1.05))
			_box(head, Vector3(0.2, 0.035, 0.04), Vector3(0, 0.15, 0.115), m_dark) # fresta da viseira
			_box(head, Vector3(0.03, 0.07, 0.24), Vector3(0, 0.29, -0.02), m_cloth) # crista
		Headgear.HOOD:
			_sphere(head, 0.15, Vector3(0, 0.16, -0.025), m_cloth, Vector3(1.05, 1.02, 1.1))
			_box(head, Vector3(0.12, 0.03, 0.02), Vector3(0, 0.15, 0.115), m_dark) # sombra dos olhos
		Headgear.WIZARD:
			# Chapéu pontudo de aba larga.
			_sphere(head, 0.2, Vector3(0, 0.27, 0), m_cloth, Vector3(1.0, 0.12, 1.0))
			var cone := CylinderMesh.new()
			cone.top_radius = 0.0
			cone.bottom_radius = 0.14
			cone.height = 0.42
			var cone_mi := _add(head, cone, Vector3(0, 0.48, -0.02), m_cloth)
			cone_mi.rotation_degrees = Vector3(-10, 0, 0)
			_box(head, Vector3(0.2, 0.03, 0.04), Vector3(0, 0.3, 0.12), m_acc) # faixa
			_box(head, Vector3(0.1, 0.07, 0.04), Vector3(0, 0.1, 0.11), m_cloth) # barba curta
		Headgear.GOLEM:
			# Cabeça de pedra: bloco com sobrancelha pesada, mandíbula e olhos brilhantes.
			_soft_box(head, Vector3(0.27, 0.22, 0.25), Vector3(0, 0.13, 0), m_skin, 0.2)
			_soft_box(head, Vector3(0.3, 0.07, 0.1), Vector3(0, 0.22, 0.12), m_acc, 0.2) # sobrancelha
			_soft_box(head, Vector3(0.2, 0.07, 0.1), Vector3(0, 0.02, 0.1), m_acc, 0.2) # mandíbula
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
		# Clavícula: levanta e projeta o ombro quando o braço sobe ou vai à frente.
		var clav := _pivot(chest, "clav_" + n, Vector3(sg * CLAV_X * b, 0.48 - CHEST_Y, 0))
		var sh := _pivot(clav, "sh_" + n, Vector3(sg * (0.3 - CLAV_X) * b, 0, 0))
		var pr := 0.09 * b * pauldron_scale
		_sphere(sh, pr, Vector3(sg * 0.02, 0.03, 0), m_acc, Vector3(1.15, 0.8, 1.05))
		var el := _pivot(sh, "el_" + n, Vector3(0, -0.3, 0))
		_sphere(el, 0.05 * b, Vector3.ZERO, m_acc)
		_soft_box(el, Vector3(0.11 * b, 0.13, 0.11 * b), Vector3(0, -0.2, 0), m_leather, 0.45) # manopla
		var hand := Node3D.new()
		hand.name = "hand_" + n
		hand.position = Vector3(0, -0.29, 0)
		el.add_child(hand)
		hand.scale = Vector3.ONE * fist_scale
		_soft_box(hand, Vector3(0.085 * b, 0.075, 0.095), Vector3(0, 0.0, 0.005), m_leather, 0.5) # palma
		_hands[n] = hand
		# Dedos: pivô nos nós dos dedos. 0° = punho fechado; abre girando para fora (palma aberta).
		var fingers := Node3D.new()
		fingers.name = "fingers_" + n
		fingers.position = Vector3(0, -0.035, 0.045)
		hand.add_child(fingers)
		_fingers[n] = fingers
		_soft_box(fingers, Vector3(0.085 * b, 0.045, 0.06), Vector3(0, -0.015, -0.02), m_leather, 0.6) # falanges
		_soft_box(fingers, Vector3(0.08 * b, 0.03, 0.035), Vector3(0, -0.045, -0.04), m_leather, 0.6) # pontas
		var thumb := _capsule(hand, 0.019, 0.07, Vector3(-sg * 0.045 * b, -0.015, 0.04), m_leather) # polegar
		thumb.rotation_degrees = Vector3(35, 0, sg * 20)
		if n == "r":
			_build_weapon(hand, m_acc)
		else:
			_hand_l = hand
			_build_offhand()
			if weapon == Weapon.BOW:
				_build_bow(hand, m_acc)

		# Pernas: coxa, joelheira, cano da bota e pé
		var th := _pivot(_hips, "th_" + n, Vector3(sg * 0.11 * b, -0.02, 0))
		var kn := _pivot(th, "kn_" + n, Vector3(0, -THIGH_LEN, 0))
		_sphere(kn, 0.07 * b, Vector3(0, 0, 0.035), m_acc, Vector3(1.0, 1.0, 0.8))
		var ft := Node3D.new() # tornozelo: o pé gira por conta própria para acompanhar o chão
		ft.name = "ft_" + n
		ft.position = Vector3(0, -SHIN_LEN, 0)
		kn.add_child(ft)
		_feet[n] = ft
		# Pé em duas partes: calcanhar/peito do pé e ponta, que dobra (junta "toe") ao desprender.
		_soft_box(ft, Vector3(0.115 * b, 0.09, 0.17), Vector3(0, 0.02, 0.01), m_leather, 0.45)
		_soft_box(ft, Vector3(0.12 * b, 0.025, 0.18), Vector3(0, -0.02, 0.01), m_dark, 0.25) # sola
		var toe := Node3D.new()
		toe.name = "toe_" + n
		toe.position = Vector3(0, -0.02, TOE_Z)
		ft.add_child(toe)
		_toes[n] = toe
		_soft_box(toe, Vector3(0.112 * b, 0.07, 0.1), Vector3(0, 0.035, 0.04), m_leather, 0.55)
		_soft_box(toe, Vector3(0.118 * b, 0.025, 0.1), Vector3(0, 0.0, 0.04), m_dark, 0.35) # sola

	# Corpo (tronco, pescoço, braços e pernas) numa malha contínua com esqueleto: dobra suave nas
	# articulações, sem emendas entre peças. Armaduras, mãos, pés e cabeça continuam peças presas.
	_build_body_skin(m_skin, m_cloth, m_leather)


# --- Malha contínua com esqueleto ----------------------------------------------

## Ossos do corpo: espelham as juntas animadas (cada osso copia a transformação da sua junta).
const SKIN_BONES: Array[String] = [
	"hips", "spine", "chest", "neck", "head", "clav_l", "clav_r", "sh_l", "sh_r", "el_l", "el_r",
	"th_l", "th_r", "kn_l", "kn_r", "ft_l", "ft_r",
]
## Vértices por anel das malhas tubulares (mais = mais redondo).
const RING_SEGMENTS := 28

var _skel: Skeleton3D
var _skin_res: Skin
var _bone_nodes: Array[Node3D] = []


func _bone_node(bone: String) -> Node3D:
	if bone.begins_with("ft_"):
		return _feet[bone.substr(3)]
	return _joints[bone]


func _build_body_skin(m_skin: StandardMaterial3D, m_cloth: StandardMaterial3D, m_leather: StandardMaterial3D) -> void:
	_skel = Skeleton3D.new()
	_skel.name = "BodySkeleton"
	add_child(_skel)
	_skin_res = Skin.new()
	_bone_nodes.clear()
	var inv := _skel.global_transform.affine_inverse()
	var rest := {} # osso -> origem em repouso (espaço do esqueleto)
	for i in SKIN_BONES.size():
		var node := _bone_node(SKIN_BONES[i])
		_bone_nodes.append(node)
		var xf := inv * node.global_transform
		xf.basis = xf.basis.orthonormalized()
		_skel.add_bone(SKIN_BONES[i])
		_skel.set_bone_rest(i, xf)
		_skin_res.add_bind(i, xf.affine_inverse())
		rest[SKIN_BONES[i]] = xf.origin
	var bi := func(bone: String) -> int: return SKIN_BONES.find(bone)
	var b := bulk
	var hy: float = (rest["hips"] as Vector3).y
	var sy: float = (rest["spine"] as Vector3).y
	var cy: float = (rest["chest"] as Vector3).y
	var ny: float = (rest["neck"] as Vector3).y
	var hdy: float = (rest["head"] as Vector3).y
	var H: int = bi.call("hips")
	var S: int = bi.call("spine")
	var C: int = bi.call("chest")
	var N: int = bi.call("neck")
	var HD: int = bi.call("head")
	# Anel: [centro, raio x, raio z, osso a, osso b, peso de b]
	_tube([
		[Vector3(0, hy - 0.11, 0), 0.11 * b, 0.09 * b, H, H, 0.0],
		[Vector3(0, hy - 0.03, 0), 0.175 * b, 0.125 * b, H, H, 0.0],
		[Vector3(0, sy, 0.0), 0.172 * b, 0.12 * b, H, S, 0.5],
		[Vector3(0, sy + 0.11, 0.005), 0.165 * b, 0.115 * b, S, S, 0.0],
		[Vector3(0, cy, 0.01), 0.19 * b, 0.125 * b, S, C, 0.5],
		[Vector3(0, cy + 0.12, 0.012), 0.235 * b, 0.14 * b, C, C, 0.0],
		[Vector3(0, cy + 0.23, 0.0), 0.25 * b, 0.13 * b, C, C, 0.0],
		[Vector3(0, cy + 0.3, -0.005), 0.2 * b, 0.105 * b, C, C, 0.0],
		[Vector3(0, ny - 0.01, 0.0), 0.075, 0.068, C, N, 0.3],
	], m_cloth)
	_tube([
		[Vector3(0, ny - 0.03, 0.0), 0.062, 0.058, C, N, 0.5],
		[Vector3(0, ny + 0.05, 0.005), 0.057, 0.054, N, N, 0.0],
		[Vector3(0, hdy + 0.0, 0.01), 0.055, 0.052, N, HD, 0.6],
		[Vector3(0, hdy + 0.08, 0.01), 0.05, 0.05, HD, HD, 0.0],
	], m_skin)
	for n in ["l", "r"]:
		var CL: int = bi.call("clav_" + n)
		var SH: int = bi.call("sh_" + n)
		var EL: int = bi.call("el_" + n)
		var TH: int = bi.call("th_" + n)
		var KN: int = bi.call("kn_" + n)
		var FT: int = bi.call("ft_" + n)
		var sh: Vector3 = rest["sh_" + n]
		var el: Vector3 = rest["el_" + n]
		var th: Vector3 = rest["th_" + n]
		var kn: Vector3 = rest["kn_" + n]
		var ft: Vector3 = rest["ft_" + n]
		# Braço (roupa) e antebraço (pele): o anel do cotovelo é o mesmo nos dois (sem emenda).
		_tube([
			[sh + Vector3(0, 0.04, 0), 0.062 * b, 0.062 * b, CL, SH, 0.6],
			[sh + Vector3(0, -0.04, 0), 0.068 * b, 0.066 * b, SH, SH, 0.0],
			[sh + Vector3(0, -0.13, 0.008), 0.072 * b, 0.07 * b, SH, SH, 0.0],
			[sh + Vector3(0, -0.23, 0.0), 0.058 * b, 0.056 * b, SH, SH, 0.0],
			[el + Vector3(0, 0.02, 0), 0.051 * b, 0.05 * b, SH, EL, 0.4],
			[el + Vector3(0, -0.01, 0), 0.05 * b, 0.049 * b, SH, EL, 0.6],
		], m_cloth)
		_tube([
			[el + Vector3(0, -0.01, 0), 0.05 * b, 0.049 * b, SH, EL, 0.6],
			[el + Vector3(0, -0.07, 0.004), 0.055 * b, 0.052 * b, EL, EL, 0.0],
			[el + Vector3(0, -0.17, 0.0), 0.047 * b, 0.044 * b, EL, EL, 0.0],
			[el + Vector3(0, -0.27, 0.0), 0.04 * b, 0.038 * b, EL, EL, 0.0],
		], m_skin)
		# Coxa (roupa) e canela/bota (couro).
		_tube([
			[th + Vector3(0, 0.07, 0), 0.095 * b, 0.1 * b, H, TH, 0.3],
			[th + Vector3(0, -0.02, 0), 0.1 * b, 0.102 * b, H, TH, 0.75],
			[th + Vector3(0, -0.16, 0.008), 0.098 * b, 0.1 * b, TH, TH, 0.0],
			[th + Vector3(0, -0.34, 0.0), 0.08 * b, 0.08 * b, TH, TH, 0.0],
			[kn + Vector3(0, 0.03, 0), 0.072 * b, 0.072 * b, TH, KN, 0.4],
			[kn + Vector3(0, -0.01, 0), 0.071 * b, 0.071 * b, TH, KN, 0.6],
		], m_cloth)
		_tube([
			[kn + Vector3(0, -0.01, 0), 0.071 * b, 0.071 * b, TH, KN, 0.6],
			[kn + Vector3(0, -0.12, -0.01), 0.078 * b, 0.08 * b, KN, KN, 0.0],
			[kn + Vector3(0, -0.28, 0.0), 0.064 * b, 0.064 * b, KN, KN, 0.0],
			[ft + Vector3(0, 0.05, 0.0), 0.06 * b, 0.062 * b, KN, FT, 0.3],
		], m_leather)


## Malha tubular com pesos de osso: anéis elípticos no plano XZ ligados por quads, com tampas.
## Cada anel: [centro: Vector3, raio x, raio z, osso a, osso b, peso de b].
func _tube(rings: Array, mat: StandardMaterial3D) -> MeshInstance3D:
	var n := RING_SEGMENTS
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var axis_dir: Vector3 = ((rings[rings.size() - 1][0] as Vector3) - (rings[0][0] as Vector3)).normalized()
	for ring in rings:
		for k in n:
			var a := TAU * k / n
			var off := Vector3(cos(a) * float(ring[1]), 0.0, sin(a) * float(ring[2]))
			var nrm := Vector3(cos(a) * float(ring[2]), 0.0, sin(a) * float(ring[1])).normalized()
			_skin_vertex(st, (ring[0] as Vector3) + off, nrm, ring)
	# Tampas (centro de cada ponta).
	var first: Array = rings[0]
	var last: Array = rings[rings.size() - 1]
	_skin_vertex(st, first[0], -axis_dir, first)
	_skin_vertex(st, last[0], axis_dir, last)
	var cap0 := rings.size() * n
	var cap1 := cap0 + 1
	# Ordem dos triângulos: os anéis vão no sentido de axis_dir; escolhe o giro que aponta para fora.
	var flip := axis_dir.y < 0.0
	for i in rings.size() - 1:
		for k in n:
			var a0 := i * n + k
			var a1 := i * n + (k + 1) % n
			var b0 := (i + 1) * n + k
			var b1 := (i + 1) * n + (k + 1) % n
			_tri(st, a0, b0, a1, flip)
			_tri(st, a1, b0, b1, flip)
	var top := (rings.size() - 1) * n
	for k in n:
		_tri(st, cap0, k, (k + 1) % n, flip)
		_tri(st, cap1, top + (k + 1) % n, top + k, flip)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	_skel.add_child(mi)
	mi.skin = _skin_res
	mi.skeleton = NodePath("..")
	return mi


func _tri(st: SurfaceTool, a: int, b: int, c: int, flip: bool) -> void:
	st.add_index(a)
	st.add_index(c if flip else b)
	st.add_index(b if flip else c)


func _skin_vertex(st: SurfaceTool, pos: Vector3, nrm: Vector3, ring: Array) -> void:
	var w := float(ring[5])
	st.set_normal(nrm)
	st.set_bones(PackedInt32Array([int(ring[3]), int(ring[4]), 0, 0]))
	st.set_weights(PackedFloat32Array([1.0 - w, w, 0.0, 0.0]))
	st.add_vertex(pos)


## Copia a transformação de cada junta animada para o osso correspondente (malha deforma junto).
func _update_skin() -> void:
	if _skel == null:
		return
	var inv := _skel.global_transform.affine_inverse()
	for i in _bone_nodes.size():
		var xf := inv * _bone_nodes[i].global_transform
		_skel.set_bone_pose_position(i, xf.origin)
		_skel.set_bone_pose_rotation(i, xf.basis.get_rotation_quaternion())
		_skel.set_bone_pose_scale(i, xf.basis.get_scale())


## Partes do corpo para o Hurtbox: cápsulas no espaço local de cada junta (antes da escala do rig).
## Cada uma: {"name", "node": Node3D, "a": Vector3, "b": Vector3, "r": float}; a == b = esfera.
func hurt_parts() -> Array[Dictionary]:
	var b := bulk
	var out: Array[Dictionary] = []
	var head_r := 0.17 if headgear == Headgear.GOLEM else 0.145
	out.append({"name": "head", "node": _joints["head"], "a": Vector3(0, 0.15, 0), "b": Vector3(0, 0.15, 0), "r": head_r})
	out.append({"name": "chest", "node": _joints["chest"], "a": Vector3(-0.1 * b, 0.15, 0), "b": Vector3(0.1 * b, 0.15, 0), "r": 0.15 * b})
	out.append({"name": "belly", "node": _joints["spine"], "a": Vector3(-0.07 * b, 0.12, 0), "b": Vector3(0.07 * b, 0.12, 0), "r": 0.125 * b})
	out.append({"name": "pelvis", "node": _hips, "a": Vector3(-0.07 * b, -0.01, 0), "b": Vector3(0.07 * b, -0.01, 0), "r": 0.13 * b})
	for n in ["l", "r"]:
		out.append({"name": "arm_" + n, "node": _joints["sh_" + n], "a": Vector3(0, 0.0, 0), "b": Vector3(0, -0.28, 0), "r": 0.07 * b})
		out.append({"name": "forearm_" + n, "node": _joints["el_" + n], "a": Vector3.ZERO, "b": Vector3(0, -0.26, 0), "r": 0.06 * b})
		out.append({"name": "hand_" + n, "node": _joints["el_" + n], "a": Vector3(0, -0.31, 0.01), "b": Vector3(0, -0.31, 0.01), "r": 0.055 * b * fist_scale})
		out.append({"name": "thigh_" + n, "node": _joints["th_" + n], "a": Vector3(0, -0.02, 0), "b": Vector3(0, -THIGH_LEN, 0), "r": 0.09 * b})
		out.append({"name": "shin_" + n, "node": _joints["kn_" + n], "a": Vector3.ZERO, "b": Vector3(0, -SHIN_LEN + 0.04, 0), "r": 0.075 * b})
		out.append({"name": "foot_" + n, "node": _feet[n], "a": Vector3(0, 0.02, -0.06), "b": Vector3(0, 0.02, 0.15), "r": 0.055 * b})
	return out


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

	_spear_body = null
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
		Weapon.SPEAR:
			# Lança: haste longa com ponta de aço em folha; alcance bem maior que a espada.
			var shaft := _mat(Color(0.5, 0.36, 0.2), 0.8)
			var head_steel := _mat(Color(0.82, 0.86, 0.92), 0.25)
			head_steel.metallic = 0.8
			# Tudo num nó próprio, que desliza ao longo da haste (pegada no meio fora dos golpes).
			var body := Node3D.new()
			body.name = "SpearBody"
			socket.add_child(body)
			_spear_body = body
			_box(body, Vector3(0.04, 0.04, 2.3), Vector3(0, 0, 0.85), shaft)
			_box(body, Vector3(0.06, 0.06, 0.1), Vector3(0, 0, -0.28), mat) # contrapeso
			_box(body, Vector3(0.012, 0.11, 0.34), Vector3(0, 0, 2.08), head_steel) # folha
			_box(body, Vector3(0.012, 0.05, 0.14), Vector3(0, 0, 2.3), head_steel) # ponta
			_box(body, Vector3(0.07, 0.07, 0.05), Vector3(0, 0, 1.9), mat) # colar
			_box(body, Vector3(0.012, 0.2, 0.03), Vector3(0, 0, 1.9), mat) # aletas
			socket.remove_child(sword_base)
			socket.remove_child(sword_tip)
			body.add_child(sword_base)
			body.add_child(sword_tip)
			sword_base.position = Vector3(0, 0, 0.9)
			sword_tip.position = Vector3(0, 0, 2.35)
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
	_soft_box(pivot, Vector3(0.28 * bulk, 0.42, 0.025), Vector3(0, -0.21, 0), mat, 0.25)
	return pivot


## Capa em 3 segmentos presos às costas; cada um balança com atraso em relação ao anterior.
func _build_cape(spine: Node3D) -> void:
	var m := _mat(cape_color, 0.9)
	var parent: Node3D = spine
	var pos := Vector3(0, 0.54 - CHEST_Y, -0.15 * bulk)
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
		Offhand.CROSSBOW:
			_build_crossbow(_hand_l)


## Besta na mão esquerda, apontando pela linha do antebraço (-Y da mão = frente quando o braço
## estica). `offhand_tip` fica na boca do canal, de onde saem os virotes.
func _build_crossbow(hand: Node3D) -> void:
	var holder := Node3D.new()
	holder.name = "OffhandSocket"
	holder.position = Vector3(0, -0.02, 0.0)
	hand.add_child(holder)
	var wood := _mat(Color(0.4, 0.27, 0.15), 0.8)
	var iron := _mat(Color(0.55, 0.57, 0.62), 0.35)
	iron.metallic = 0.7
	# Besta de mão: pequena, tipo pistola — cabo, coronha curta, arco estreito.
	_box(holder, Vector3(0.05, 0.3, 0.06), Vector3(0, -0.1, 0.0), wood) # coronha
	_box(holder, Vector3(0.03, 0.22, 0.02), Vector3(0, -0.14, 0.04), iron) # trilho
	_box(holder, Vector3(0.3, 0.03, 0.03), Vector3(0, -0.22, 0.01), iron) # arco
	_box(holder, Vector3(0.26, 0.008, 0.008), Vector3(0, -0.19, 0.02), _mat(Color(0.9, 0.9, 0.85), 0.5)) # corda
	_box(holder, Vector3(0.06, 0.07, 0.09), Vector3(0, 0.02, -0.02), wood) # cabo
	offhand_tip = Marker3D.new()
	offhand_tip.position = Vector3(0, -0.26, 0.04)
	holder.add_child(offhand_tip)


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


static var _soft_cache := {}


## Caixa de cantos arredondados (superelipsoide): roundness 0 = quase caixa, 1 = elipsoide.
## Mais vértices que uma BoxMesh e com normais suaves; a malha é compartilhada por tamanho.
func _soft_box(parent: Node3D, size: Vector3, pos: Vector3, mat: StandardMaterial3D, roundness := 0.4) -> MeshInstance3D:
	var key := "%.3f,%.3f,%.3f|%.2f" % [size.x, size.y, size.z, roundness]
	if not _soft_cache.has(key):
		_soft_cache[key] = _make_soft_box(size, roundness)
	return _add(parent, _soft_cache[key], pos, mat)


static func _make_soft_box(size: Vector3, roundness: float) -> ArrayMesh:
	var sphere := SphereMesh.new()
	sphere.radial_segments = 32
	sphere.rings = 16
	var arrays := sphere.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var half := size * 0.5
	# Superfície Σ|p/half|^(2/e) = 1: e pequeno = caixa, e = 1 = elipsoide.
	var e := lerpf(0.15, 1.0, clampf(roundness, 0.0, 1.0))
	var n_exp := 2.0 / e
	for i in verts.size():
		var d := verts[i].normalized()
		var q := Vector3(signf(d.x) * pow(absf(d.x), e), signf(d.y) * pow(absf(d.y), e), signf(d.z) * pow(absf(d.z), e))
		verts[i] = q * half
		# Normal = gradiente da superfície implícita.
		var g := Vector3(
			signf(q.x) * pow(absf(q.x), n_exp - 1.0) / half.x,
			signf(q.y) * pow(absf(q.y), n_exp - 1.0) / half.y,
			signf(q.z) * pow(absf(q.z), n_exp - 1.0) / half.z)
		normals[i] = g.normalized() if g.length_squared() > 0.0 else d
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TANGENT] = null
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _capsule(parent: Node3D, radius: float, length: float, pos: Vector3, mat: StandardMaterial3D) -> MeshInstance3D:
	var m := CapsuleMesh.new()
	m.radius = radius
	m.height = maxf(length, radius * 2.0)
	m.radial_segments = 32
	m.rings = 12
	return _add(parent, m, pos, mat)
