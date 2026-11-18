class_name Hitbox
extends Area3D
## Área de dano. Fica com monitoring desligado e só é ativada durante a janela do golpe.
##
## Dois modos:
##  - Caixa (padrão): a forma da própria Area3D (golpes em área, investidas, projéteis).
##  - Varredura da arma (activate(..., true)): a cada quadro de física testa uma cápsula ao longo
##    da lâmina/clava (sword_base -> sword_tip do rig). Entre o quadro anterior e o atual a arma é
##    interpolada pela rotação (não em linha reta), com subpassos proporcionais ao quanto a ponta
##    andou: arcos rápidos não "cortam caminho" nem atravessam o alvo entre dois quadros.
## As Hurtboxes com rig são cápsulas por parte do corpo; o ponto de contato é o ponto da arma mais
## próximo da parte atingida.

signal hit_landed(hurtbox: Hurtbox)

## Distância máxima (em raios da varredura) que a ponta anda entre dois subpassos.
const SWEEP_STEP_RADII := 1.2
const SWEEP_MAX_SUBSTEPS := 16

var hit_data: HitData
var source: Node3D
## Rig cuja arma é varrida no modo de varredura (definido pelo dono).
var sweep_rig: HumanoidRig
var sweep_radius := 0.15

var _already: Array = []
var _sweeping := false
var _prev_xf := Transform3D.IDENTITY # transformação global do suporte da arma no quadro anterior
var _sweep_shape := CapsuleShape3D.new()
var _contact := Vector3.ZERO
var _has_contact := false
var _part := "" # parte do corpo atingida pela varredura (vazio em golpes de área)


func _ready() -> void:
	area_entered.connect(_on_area_entered)


func activate(data: HitData, sweep := false) -> void:
	hit_data = data
	_already.clear()
	if sweep and sweep_rig != null and sweep_rig.sword_tip != null:
		_sweeping = true
		_prev_xf = _weapon_xf()
		set_deferred("monitoring", false)
	else:
		_sweeping = false
		set_deferred("monitoring", true)


func deactivate() -> void:
	_sweeping = false
	set_deferred("monitoring", false)


## Transformação global do nó que segura base e ponta da arma (soquete ou haste da lança).
func _weapon_xf() -> Transform3D:
	return (sweep_rig.sword_tip.get_parent() as Node3D).global_transform


func _process(_delta: float) -> void:
	if Settings.debug_hitboxes and monitoring and not _sweeping:
		for child in get_children():
			var cs := child as CollisionShape3D
			if cs != null and cs.shape is BoxShape3D:
				DebugDraw3D.draw_box_xf(cs.global_transform.scaled_local((cs.shape as BoxShape3D).size), Color(1.0, 0.5, 0.1), true, 0.0)


func _physics_process(_delta: float) -> void:
	if not _sweeping or sweep_rig == null or not is_instance_valid(sweep_rig.sword_tip):
		return
	var xf := _weapon_xf()
	var base_l := sweep_rig.sword_base.position
	var tip_l := sweep_rig.sword_tip.position
	var travel := (_prev_xf * tip_l).distance_to(xf * tip_l)
	var steps := clampi(ceili(travel / maxf(sweep_radius * SWEEP_STEP_RADII, 0.02)), 1, SWEEP_MAX_SUBSTEPS)
	for i in steps:
		var t := float(i + 1) / steps
		var sub_xf := _prev_xf.interpolate_with(xf, t) # gira junto com a arma (arco, não corda)
		_query_segment(sub_xf * base_l, sub_xf * tip_l)
		if not _sweeping:
			break
	_prev_xf = xf


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
	if Settings.debug_hitboxes:
		DebugDraw3D.draw_capsule_ab(a, b, sweep_radius, Color(1.0, 0.25, 0.2), 0.12)
	# Várias partes do mesmo corpo podem aparecer: o primeiro contato vale, o resto é ignorado.
	for r in get_world_3d().direct_space_state.intersect_shape(params, 32):
		var area := r["collider"] as Area3D
		if area == null or _already.has(area):
			continue
		var hurtbox := area as Hurtbox
		_part = ""
		if hurtbox != null and not hurtbox.parts.is_empty():
			var part := hurtbox.part_for_shape(int(r["shape"]))
			if not part.is_empty():
				_part = part["name"]
				var seg := hurtbox.part_segment(part)
				_contact = Geometry3D.get_closest_points_between_segments(a, b, seg[0], seg[1])[0]
			else:
				_contact = hurtbox.closest_point(a, b)
		else:
			_contact = Geometry3D.get_closest_point_to_segment(area.global_position + Vector3.UP, a, b)
		_has_contact = true
		_on_area_entered(area)
		_has_contact = false
		_part = ""


func _on_area_entered(area: Area3D) -> void:
	var hurtbox := area as Hurtbox
	if hurtbox == null or hurtbox.health == null or hit_data == null or _already.has(hurtbox):
		return
	_already.append(hurtbox)
	var hit: HitData = hit_data.duplicate()
	hit.source = source
	hit.part = _part
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
	var pos: Vector3 = _contact if _has_contact else hurtbox.closest_point(global_position, global_position)
	var on_player: bool = victim.is_in_group("player")
	hit_landed.emit(hurtbox)
	EventBus.hit_landed.emit(hurtbox.global_position, hit.damage)
	Fx.spark(self, pos, Color(1.0, 0.3, 0.3) if on_player else Color(1.0, 0.85, 0.4))
	var number_color := Color(1.0, 0.4, 0.35) if on_player else Color(1, 1, 1)
	if health.last_tag != "":
		number_color = Color(0.5, 0.8, 1.0)
	Fx.damage_number(self, pos + Vector3(0, 0.7, 0), health.last_damage, number_color, health.last_tag)
	GameFeel.on_hit(hit, victim, killed, health.last_damage == 0)
