extends SummonState
## Dispensada ou derrotada: cai, fica um instante e some encolhendo.

var _t := 0.0


func enter(_msg: Dictionary = {}) -> void:
	var c := s
	_t = 0.0
	c.hitbox.deactivate()
	c.remove_from_group("body_contact")
	c.contact_enabled = false
	c.rig.set_glow(Color.BLACK)
	c.hurtbox.set_deferred("monitorable", false)
	c.velocity = Vector3.ZERO
	var tween := c.create_tween()
	tween.tween_interval(0.7)
	# Escala mínima (não zero): o Jolt rejeita transformações singulares no hitbox filho.
	tween.tween_property(c.visual, "scale", Vector3.ONE * 0.01, 0.4)
	tween.tween_callback(c.queue_free)


func physics_update(delta: float) -> void:
	_t += delta
	s.rig.set_dead(_t)
