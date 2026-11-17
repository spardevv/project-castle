class_name Hitbox
extends Area3D
## Área de dano. Fica com monitoring desligado e só é ativada durante a janela do golpe.
##
## Dois modos:
##  - Caixa (padrão): a forma da própria Area3D (golpes em área, investidas, projéteis).
##  - Varredura da arma (activate(..., true)): a cada quadro de física testa uma cápsula ao longo
##    da lâmina/clava (sword_base -> sword_tip do rig), com subpassos entre a posição anterior e a
##    atual. O golpe só acerta onde a arma realmente passa.

signal hit_landed(hurtbox: Hurtbox)

const SWEEP_SUBSTEPS := 3

var hit_data: HitData
var source: Node3D
## Rig cuja arma é varrida no modo de varredura (definido pelo dono).
var sweep_rig: HumanoidRig
var sweep_radius := 0.15

var _already: Array = []
var _sweeping := false
var _prev_base := Vector3.ZERO
var _prev_tip := Vector3.ZERO
var _sweep_shape := CapsuleShape3D.new()
var _contact := Vector3.ZERO
var _has_contact := false


func _ready() -> void:
	area_entered.connect(_on_area_entered)


func activate(data: HitData, sweep := false) -> void:
	hit_data = data
	_already.clear()
	if sweep and sweep_rig != null and sweep_rig.sword_tip != null:
		_sweeping = true
		_prev_base = sweep_rig.sword_base.global_position
		_prev_tip = sweep_rig.sword_tip.global_position
		set_deferred("monitoring", false)
	else:
		_sweeping = false
		set_deferred("monitoring", true)


func deactivate() -> void:
	_sweeping = false
	set_deferred("monitoring", false)


func _physics_process(_delta: float) -> void:
	if not _sweeping or sweep_rig == null:
		return
	var base := sweep_rig.sword_base.global_position
	var tip := sweep_rig.sword_tip.global_position
	for i in SWEEP_SUBSTEPS:
		var t := float(i + 1) / SWEEP_SUBSTEPS
		_query_segment(_prev_base.lerp(base, t), _prev_tip.lerp(tip, t))
		if not _sweeping:
			break
	_prev_base = base
	_prev_tip = tip


## Cápsula da base à ponta da arma; acerta Hurtboxes da máscara deste hitbox.
func _query_segment(a: Vector3, b: Vector3) -> void:
	var length := a.distance_to(b)
	if length < 0.01:
		return
	var y := (b - a) / length
	var ref := Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.95 else Vector3.RIGHT
	var x := y.cross(ref).normalized()
	var z := x.cross(y)
	_sweep_shape.radius = sweep_radius
	_sweep_shape.height = length + sweep_radius * 2.0
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = _sweep_shape
	params.transform = Transform3D(Basis(x, y, z), (a + b) * 0.5)
	params.collision_mask = collision_mask
	params.collide_with_areas = true
	params.collide_with_bodies = false
	for r in get_world_3d().direct_space_state.intersect_shape(params, 8):
		var area := r["collider"] as Area3D
		if area == null:
			continue
		# Ponto de contato: o ponto da arma mais próximo do centro do corpo atingido.
		var center := area.global_position + Vector3.UP * 1.0
		_contact = Geometry3D.get_closest_point_to_segment(center, a, b)
		_has_contact = true
		_on_area_entered(area)
		_has_contact = false


func _on_area_entered(area: Area3D) -> void:
	var hurtbox := area as Hurtbox
	if hurtbox == null or hurtbox.health == null or hit_data == null or _already.has(hurtbox):
		return
	_already.append(hurtbox)
	var hit: HitData = hit_data.duplicate()
	hit.source = source
	# Buffs/debuffs de quem ataca (Bênção, Maldição...) e do alvo (Maldição) alteram o dano.
	if source != null:
		hit.damage = roundi(hit.damage * StatusEffects.mult(source, "damage_out"))
	if hurtbox.health != null:
		hit.damage = roundi(hit.damage * StatusEffects.mult(hurtbox.health.get_parent(), "damage_in"))
	if not hurtbox.receive_hit(hit):
		return

	var health: Health = hurtbox.health
	var victim: Node = health.get_parent()
	var killed: bool = health.current <= 0
	var pos: Vector3 = _contact if _has_contact else hurtbox.global_position + Vector3(0, 1.0, 0)
	var on_player: bool = victim.is_in_group("player")
	hit_landed.emit(hurtbox)
	EventBus.hit_landed.emit(hurtbox.global_position, hit.damage)
	Fx.spark(self, pos, Color(1.0, 0.3, 0.3) if on_player else Color(1.0, 0.85, 0.4))
	var number_color := Color(1.0, 0.4, 0.35) if on_player else Color(1, 1, 1)
	if health.last_tag != "":
		number_color = Color(0.5, 0.8, 1.0)
	Fx.damage_number(self, pos + Vector3(0, 0.7, 0), health.last_damage, number_color, health.last_tag)
	GameFeel.on_hit(hit, victim, killed, health.last_damage == 0)
