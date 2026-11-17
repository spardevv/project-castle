extends PlayerState
## Morte: cai de lado e a cena recarrega após alguns segundos.

var _t := 0.0


func enter(_msg: Dictionary = {}) -> void:
	_t = 0.0
	player.velocity.x = 0.0
	player.velocity.z = 0.0
	player.lock_target = null


func physics_update(delta: float) -> void:
	var p := player
	_t += delta
	p.apply_gravity(delta)
	p.accelerate(Vector3.ZERO, 0.0, 20.0, delta)
	p.rig.set_dead(_t)
	p.move_and_slide()
	if _t >= 2.0:
		Engine.time_scale = 1.0
		p.get_tree().reload_current_scene()
