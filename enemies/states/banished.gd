extends EnemyState
## Banido para um plano alternativo (skill Banimento do mago). Durante BANISH_TIME s o inimigo:
##  - tem qualquer ação/skill cancelada (entrar neste estado interrompe o estado anterior);
##  - não interage com nada: não é alvo, não sofre dano nem empurra ninguém, atravessa paredes;
##  - fica translúcido como uma névoa verde.
## Ao voltar, criaturas grandes (sem lançamento / com armadura constante) ficam atordoadas por
## metade do tempo do banimento. O mago só recebe a recarga da skill agora (Summon.banish_finished).

const MIST := Color(0.45, 1.0, 0.6)
const GHOST_ALPHA := 0.65 # GeometryInstance3D.transparency: 0 opaco, 1 invisível

var _t := 0.0
var _duration := Summon.BANISH_TIME
var _caster: Node
var _base_y := 0.0
var _meshes: Array[Node] = []
var _mist: CPUParticles3D
var _saved_mask := 0
var _saved_layer := 0


func enter(msg: Dictionary = {}) -> void:
	var en := e
	_t = 0.0
	_duration = float(msg.get("duration", Summon.BANISH_TIME))
	_caster = msg.get("caster")
	_base_y = en.global_position.y
	en.velocity = Vector3.ZERO
	en.hitbox.deactivate()
	en.rig.trail_active = false
	en.contact_enabled = false
	en.remove_from_group("enemy") # ninguém o escolhe como alvo nem o inclui em áreas
	en.remove_from_group("body_contact")
	en.hurtbox.set_deferred("monitorable", false)
	_saved_mask = en.collision_mask
	_saved_layer = en.collision_layer
	en.collision_mask = 0
	en.collision_layer = 0
	var p := en.get_player()
	if p != null and p.get("lock_target") == en:
		p.set("lock_target", null)
	en.rig.set_glow(MIST * 0.5)
	_meshes = en.rig.find_children("*", "MeshInstance3D", true, false)
	for m in _meshes:
		(m as GeometryInstance3D).transparency = GHOST_ALPHA
	_mist = _make_mist()
	en.add_child(_mist)
	Sfx.play(&"debuff", en.global_position + Vector3(0, 1.0, 0), 0.0, 0.6)


func exit() -> void:
	var en := e
	for m in _meshes:
		if is_instance_valid(m):
			(m as GeometryInstance3D).transparency = 0.0
	en.rig.set_glow(Color.BLACK)
	if is_instance_valid(_mist):
		_mist.queue_free()
	en.collision_mask = _saved_mask
	en.collision_layer = _saved_layer
	en.contact_enabled = true
	if not en.is_in_group("enemy"):
		en.add_to_group("enemy")
	if not en.is_in_group("body_contact"):
		en.add_to_group("body_contact")
	en.hurtbox.set_deferred("monitorable", true)
	if is_instance_valid(_caster) and _caster.has_method("banish_finished"):
		_caster.call("banish_finished")


func physics_update(delta: float) -> void:
	var en := e
	_t += delta
	en.velocity = Vector3.ZERO
	en.global_position.y = _base_y + sin(_t * 2.0) * 0.12 # flutua como névoa
	en.rig.set_motion(0.0, true, 0.0)
	en.rig.set_glow(MIST * (0.35 + 0.15 * sin(_t * 3.0)))
	if _t >= _duration:
		_finish()


## Volta ao plano normal; grandes ficam atordoados por metade do tempo do banimento.
func _finish() -> void:
	var en := e
	var big := not en.can_be_launched or en.always_armored
	if big and en.health.current > 0:
		var hit := HitData.new()
		hit.damage = 0
		hit.knockback = 0.0
		hit.hitstun = _duration * 0.5
		hit.poise_break = true
		machine.change_to(&"Stagger", {"hit": hit})
	else:
		machine.change_to(en.engage_state)


func _make_mist() -> CPUParticles3D:
	var m := CPUParticles3D.new()
	m.amount = 28
	m.lifetime = 1.4
	m.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = 0.6
	m.direction = Vector3.UP
	m.spread = 25.0
	m.initial_velocity_min = 0.3
	m.initial_velocity_max = 0.9
	m.gravity = Vector3(0, 0.2, 0)
	m.position = Vector3(0, 1.0, 0)
	var mesh := SphereMesh.new()
	mesh.radius = 0.28
	mesh.height = 0.56
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(MIST.r, MIST.g, MIST.b, 0.18)
	mesh.material = mat
	m.mesh = mesh
	m.scale_amount_min = 0.6
	m.scale_amount_max = 1.5
	return m
