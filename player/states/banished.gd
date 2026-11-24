extends PlayerState
## Banido (skill Banimento do mago usada no próprio jogador, sem inimigos por perto): por até MAX_TIME s o
## jogador vira névoa verde, não interage com nada (não é atingido, não ataca) e flutua. Colide com o
## cenário normal (chão, teto, paredes externas) e só atravessa paredes secretas (SecretWall), que ficam
## reveladas enquanto dura o banimento; também não sobe mais que MAX_RISE acima do chão logo abaixo dele
## (para não escapar por cima das paredes; saindo de um degrau, desce). Apertar a skill de novo (LB + botão) o traz de volta quando ele NÃO
## está dentro de uma parede secreta; no fim do tempo, sai assim que houver espaço.

const MAX_TIME := Summon.BANISH_TIME
const SPEED := 6.0
const VERTICAL := 4.0
## Altura máxima (m) que pode subir acima do chão logo abaixo dele.
const MAX_RISE := 2.5
const MIST := Color(0.45, 1.0, 0.6)
const GHOST_ALPHA := 0.6

var _t := 0.0
var _meshes: Array[Node] = []
var _mist: CPUParticles3D
var _warn := 0.0


func enter(_msg: Dictionary = {}) -> void:
	var p := player
	_t = 0.0
	_warn = 0.0
	p.velocity = Vector3.ZERO
	p.lock_target = null
	p.health.invulnerable = true
	p.contact_enabled = false
	SecretWall.set_passable(p, true)
	var hb := p.get_node_or_null("Hurtbox") as Area3D
	if hb != null:
		hb.set_deferred("monitorable", false)
	p.attack_hitbox.deactivate()
	p.rig.set_glow(MIST * 0.4)
	_meshes = p.rig.find_children("*", "MeshInstance3D", true, false)
	for m in _meshes:
		(m as GeometryInstance3D).transparency = GHOST_ALPHA
	_mist = CPUParticles3D.new()
	_mist.amount = 24
	_mist.lifetime = 1.2
	_mist.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_mist.emission_sphere_radius = 0.5
	_mist.direction = Vector3.UP
	_mist.spread = 25.0
	_mist.initial_velocity_min = 0.3
	_mist.initial_velocity_max = 0.8
	_mist.gravity = Vector3.ZERO
	_mist.position = Vector3(0, 1.0, 0)
	var mesh := SphereMesh.new()
	mesh.radius = 0.22
	mesh.height = 0.44
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(MIST.r, MIST.g, MIST.b, 0.2)
	mesh.material = mat
	_mist.mesh = mesh
	p.add_child(_mist)
	Sfx.play(&"buff", p.global_position + Vector3(0, 1.0, 0), 0.0, 0.6)


func exit() -> void:
	var p := player
	for m in _meshes:
		if is_instance_valid(m):
			(m as GeometryInstance3D).transparency = 0.0
	if is_instance_valid(_mist):
		_mist.queue_free()
	p.rig.set_glow(Color.BLACK)
	SecretWall.set_passable(p, false)
	p.contact_enabled = true
	p.health.invulnerable = false
	var hb := p.get_node_or_null("Hurtbox") as Area3D
	if hb != null:
		hb.set_deferred("monitorable", true)


func physics_update(delta: float) -> void:
	var p := player
	_t += delta
	var dir := p.get_move_dir()
	var up := 0.0
	if Input.is_action_pressed("jump"):
		up += 1.0
	if Input.is_action_pressed("dodge"):
		up -= 1.0
	p.velocity.x = move_toward(p.velocity.x, dir.x * SPEED, 40.0 * delta)
	p.velocity.z = move_toward(p.velocity.z, dir.z * SPEED, 40.0 * delta)
	p.velocity.y = move_toward(p.velocity.y, up * VERTICAL, 30.0 * delta)
	var max_y := _ceiling_y()
	if p.global_position.y > max_y + 0.05:
		p.velocity.y = minf(p.velocity.y, -VERTICAL)
	elif p.global_position.y >= max_y and p.velocity.y > 0.0:
		p.velocity.y = 0.0
	p.update_facing(dir, delta)
	p.move_and_slide() # colide com o cenário; as paredes secretas são exceções de colisão
	p.rig.set_motion(Vector2(p.velocity.x, p.velocity.z).length(), true, 0.0)
	p.rig.set_glow(MIST * (0.3 + 0.12 * sin(_t * 3.0)))
	_warn = maxf(_warn - delta, 0.0)
	if _t >= MAX_TIME:
		try_exit(true)


## Altura máxima do jogador: MAX_RISE acima do chão logo abaixo (ignora as paredes secretas). Sem chão
## abaixo, não deixa subir além de onde está.
func _ceiling_y() -> float:
	var p := player
	var from := p.global_position + Vector3(0, 0.5, 0)
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 60.0, p.collision_mask)
	var ex: Array[RID] = [p.get_rid()]
	for w in p.get_tree().get_nodes_in_group("secret_wall"):
		ex.append((w as CollisionObject3D).get_rid())
	q.exclude = ex
	var hit := p.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return p.global_position.y
	return (hit["position"] as Vector3).y + MAX_RISE


## Tenta voltar ao plano normal. Dentro de uma parede secreta/objeto sólido não dá: continua banido até haver espaço.
func try_exit(quiet := false) -> bool:
	var p := player
	if _blocked():
		if not quiet and _warn <= 0.0:
			_warn = 1.0
			Sfx.play(&"denied")
			Fx.damage_number(p, p.global_position + Vector3(0, 2.4, 0), 0, MIST, "Sem espaço")
		return false
	p.velocity = Vector3.ZERO
	land_or_fall()
	return true


## Há cenário sólido dentro do corpo do jogador? Usa uma cápsula um pouco menor, para encostar no chão não contar.
## A consulta ignora as exceções de colisão, então detecta as paredes secretas que ele está atravessando.
func _blocked() -> bool:
	var p := player
	var cs := p.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if cs == null or not (cs.shape is CapsuleShape3D):
		return false
	var cap := (cs.shape as CapsuleShape3D).duplicate() as CapsuleShape3D
	cap.radius *= 0.8
	cap.height = maxf(cap.height * 0.85, cap.radius * 2.0 + 0.01)
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = cap
	q.transform = cs.global_transform
	q.collision_mask = p.collision_mask
	q.exclude = [p.get_rid()]
	return not p.get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()
