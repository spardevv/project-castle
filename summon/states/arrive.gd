extends SummonState
## Chegada ao ser invocado — vem junto com uma skill:
##  - "meteor" (golem): cai do céu como um meteoro sobre o inimigo travado (ou o mais próximo) e causa
##    dano MASSIVO em área ao bater no chão (Summon.arrival_spot escolhe o ponto).
##  - "holy" (sacerdote): surge ao lado do jogador e explode em cura: +30% da vida máxima e regeneração de 2 s.
##  - "arcane" (mago): abre uma zona de dano arcano contínuo que causa lentidão.
## Fica invulnerável e sem contato físico durante a chegada.

const FALL_HEIGHT := 24.0
const FALL_SPEED := 38.0
const METEOR_RADIUS := Summon.METEOR_RADIUS
const METEOR_DAMAGE := Summon.METEOR_DAMAGE
const HOLY_RADIUS := 10.0
const HOLY_HEAL_RATIO := 0.30
const HOLY_REGEN_TIME := 2.0

var _spot := Vector3.ZERO
var _t := 0.0
var _phase := "fall"
var _trail: CPUParticles3D


func enter(msg: Dictionary = {}) -> void:
	var c := s
	_spot = msg.get("spot", c.global_position)
	_t = 0.0
	c.health.invulnerable = true
	c.contact_enabled = false
	if c.arrival == &"meteor":
		_phase = "fall"
		c.global_position = _spot + Vector3.UP * FALL_HEIGHT
		c.velocity = Vector3.DOWN * FALL_SPEED
		c.rig.set_glow(Color(1.0, 0.5, 0.15))
		_trail = _make_trail()
		c.add_child(_trail)
		Sfx.play(&"meteor_fall", _spot, 3.0)
	else:
		_phase = "rise"
		c.global_position = _spot
		c.velocity = Vector3.ZERO
		c.visual.scale = Vector3.ONE * 0.2
		c.rig.set_glow(Color(1.0, 0.95, 0.7))
		Sfx.play(&"summon_priest", _spot, 2.0)


func exit() -> void:
	var c := s
	c.health.invulnerable = false
	c.contact_enabled = true
	c.visual.scale = Vector3.ONE
	c.rig.set_glow(Color.BLACK)
	if is_instance_valid(_trail):
		_trail.queue_free()


func physics_update(delta: float) -> void:
	var c := s
	_t += delta
	if c.arrival == &"meteor":
		_meteor(c, delta)
	else:
		_holy(c, delta)


func _meteor(c: Summon, delta: float) -> void:
	match _phase:
		"fall":
			c.velocity = Vector3.DOWN * FALL_SPEED
			c.rig.set_motion(0.0, false, -FALL_SPEED)
			c.move_and_slide()
			if c.is_on_floor() or c.global_position.y <= _spot.y + 0.05:
				_impact(c)
		"land":
			c.velocity = Vector3(0, c.velocity.y, 0)
			c.apply_gravity(delta)
			# Agachado no impacto, depois se levanta.
			c.rig.set_attack("e_smash", 0.05, 0.1, 0.75, _t + 0.12)
			c.move_and_slide()
			if _t >= 0.8:
				machine.change_to(&"Chase")


## Impacto do meteoro: explosão em área (dano + lançamento), cratera de poeira, tremor e som.
func _impact(c: Summon) -> void:
	_phase = "land"
	_t = 0.0
	c.rig.set_glow(Color.BLACK)
	if is_instance_valid(_trail):
		_trail.emitting = false
	var ex := Explosion.new()
	ex.radius = METEOR_RADIUS
	ex.damage = METEOR_DAMAGE
	ex.knockback = 12.0
	ex.launch = 8.0
	ex.color = Color(1.0, 0.55, 0.15)
	ex.instigator = c.owner_player
	ex.position = c.global_position + Vector3(0, 0.3, 0)
	c.get_parent().add_child(ex)
	Fx.burst(c, c.global_position + Vector3(0, 0.3, 0), METEOR_RADIUS * 0.9, Color(0.7, 0.55, 0.35), 0.7)
	GameFeel.shake(0.45)
	GameFeel.rumble(0.8, 0.9, 0.3)
	GameFeel.slowmo(0.3, 0.1)
	Sfx.play(&"boom", c.global_position, 6.0, 0.6)


func _holy(c: Summon, delta: float) -> void:
	c.velocity = Vector3.ZERO
	c.rig.set_attack("priest_cast", 0.3, 0.2, 0.5, _t)
	c.visual.scale = Vector3.ONE * lerpf(0.2, 1.0, clampf(_t / 0.35, 0.0, 1.0))
	if _phase == "rise" and _t >= 0.3:
		_phase = "burst"
		_holy_burst(c)
	c.move_and_slide()
	if _t >= 0.95:
		machine.change_to(&"Chase")


## Explosão de cura: restaura o jogador (e regenera um pouco) e o próprio sacerdote.
func _holy_burst(c: Summon) -> void:
	if c.arrival == &"arcane":
		_arcane_burst(c)
		return
	var color := Color(0.6, 1.0, 0.7)
	Fx.burst(c, c.global_position + Vector3(0, 0.8, 0), HOLY_RADIUS, color, 0.8)
	Fx.burst(c, c.global_position + Vector3(0, 0.8, 0), HOLY_RADIUS * 0.5, Color(1.0, 0.95, 0.7), 0.5)
	c.rig.flash(Color(1.0, 0.95, 0.7), 0.5)
	var p := c.owner_player
	if is_instance_valid(p) and p.global_position.distance_to(c.global_position) <= HOLY_RADIUS:
		var ph := p.get_node_or_null("Health") as Health
		if ph != null:
			var got := ph.heal(ceili(ph.max_health * HOLY_HEAL_RATIO))
			Fx.damage_number(c, p.global_position + Vector3(0, 2.2, 0), got, color, "+%d" % got)
		StatusEffects.apply(p, &"regen", HOLY_REGEN_TIME)
	GameFeel.shake(0.12)
	Sfx.play(&"heal", c.global_position + Vector3(0, 1.0, 0), 3.0, 0.9)


## Chegada do mago: abre uma zona de dano arcano contínuo que deixa os inimigos lentos.
func _arcane_burst(c: Summon) -> void:
	var color := Color(0.5, 0.75, 1.0)
	Fx.burst(c, c.global_position + Vector3(0, 0.8, 0), 5.0, color, 0.7)
	c.rig.flash(Color(0.7, 0.85, 1.0), 0.5)
	var zone := ArcaneZone.new()
	zone.instigator = c
	zone.position = c.global_position + Vector3(0, 0.05, 0)
	c.get_parent().add_child(zone)
	Sfx.play(&"zap", c.global_position + Vector3(0, 1.0, 0), 2.0, 0.8)


func _make_trail() -> CPUParticles3D:
	var t := CPUParticles3D.new()
	t.amount = 60
	t.lifetime = 0.5
	t.local_coords = false
	t.direction = Vector3.UP
	t.spread = 25.0
	t.initial_velocity_min = 3.0
	t.initial_velocity_max = 8.0
	t.gravity = Vector3.ZERO
	t.position = Vector3(0, 1.4, 0)
	var mesh := SphereMesh.new()
	mesh.radius = 0.35
	mesh.height = 0.7
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.5, 0.12)
	mesh.material = mat
	t.mesh = mesh
	t.scale_amount_min = 0.5
	t.scale_amount_max = 1.4
	return t
