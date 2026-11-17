extends EnemyState
## Morte: cai de costas, fica um instante no chão e some encolhendo.

var _t := 0.0


func enter(_msg: Dictionary = {}) -> void:
	var en := e
	_t = 0.0
	en.remove_from_group("enemy")
	en.remove_from_group("body_contact")
	en.contact_enabled = false
	en.hitbox.deactivate()
	en.rig.set_glow(Color.BLACK)
	en.get_node("CollisionShape3D").set_deferred("disabled", true)
	en.hurtbox.set_deferred("monitorable", false)
	en.velocity = Vector3.ZERO
	EventBus.enemy_killed.emit(en)
	var tween := en.create_tween()
	tween.tween_interval(1.1)
	# Escala mínima (não zero): o Jolt rejeita transformações singulares no hitbox filho.
	tween.tween_property(en.visual, "scale", Vector3.ONE * 0.01, 0.5)
	tween.tween_callback(en.queue_free)


func physics_update(delta: float) -> void:
	_t += delta
	e.rig.set_dead(_t)
