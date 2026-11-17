extends SummonState
## Dispensar (sem skill, só animação):
##  - golem: desmorona e afunda no chão numa nuvem de poeira.
##  - sacerdote: ergue os braços e sobe aos céus numa luz, encolhendo até sumir.

const GOLEM_TIME := 1.2
const PRIEST_TIME := 1.0

var _t := 0.0
var _puffed := false


func enter(_msg: Dictionary = {}) -> void:
	var c := s
	_t = 0.0
	_puffed = false
	c.health.invulnerable = true
	c.contact_enabled = false
	c.remove_from_group("body_contact")
	c.hitbox.deactivate()
	c.hurtbox.set_deferred("monitorable", false)
	c.velocity = Vector3.ZERO
	if c.arrival == &"meteor":
		Sfx.play(&"dismiss_golem", c.global_position, 2.0)
	else:
		Sfx.play(&"dismiss_priest", c.global_position, 1.0)


func physics_update(delta: float) -> void:
	var c := s
	_t += delta
	c.apply_gravity(delta)
	c.accelerate(Vector3.ZERO, 0.0, 40.0, delta)
	if c.arrival == &"meteor":
		_golem(c)
	else:
		_priest(c, delta)
	c.move_and_slide()


## Desmorona (pose de queda) e depois afunda no chão levantando poeira.
func _golem(c: Summon) -> void:
	c.rig.set_dead(_t)
	if _t >= 0.5:
		if not _puffed:
			_puffed = true
			Fx.burst(c, c.global_position + Vector3(0, 0.3, 0), 2.6, Color(0.6, 0.55, 0.45), 0.6)
			GameFeel.shake(0.1)
		c.visual.position.y = lerpf(0.0, -1.9, clampf((_t - 0.5) / 0.7, 0.0, 1.0))
	if _t >= GOLEM_TIME:
		c.queue_free()


## Braços para o alto, brilhando; sobe encolhendo e solta faíscas até sumir.
func _priest(c: Summon, delta: float) -> void:
	c.rig.set_attack("priest_cast", 0.2, 0.6, 0.2, _t)
	c.rig.set_glow(Color(1.0, 0.95, 0.7) * clampf(_t / 0.4, 0.0, 1.0))
	if _t >= 0.35:
		var k := clampf((_t - 0.35) / 0.65, 0.0, 1.0)
		c.visual.position.y = k * k * 5.0
		c.visual.scale = Vector3.ONE * lerpf(1.0, 0.25, k)
		if fmod(_t, 0.12) < delta:
			Fx.spark(c, c.global_position + Vector3(0, 1.0 + c.visual.position.y, 0), Color(1.0, 0.95, 0.6))
	if _t >= PRIEST_TIME:
		Fx.burst(c, c.global_position + Vector3(0, 5.0, 0), 1.6, Color(1.0, 0.95, 0.7), 0.4)
		c.queue_free()
