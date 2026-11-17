extends SummonState
## Acompanha o jogador; entra em combate quando há inimigo perto dele.


func physics_update(delta: float) -> void:
	var c := s
	c.apply_gravity(delta)
	var owner_p := c.owner_player
	if not is_instance_valid(owner_p):
		c.move_and_slide()
		return

	var to := owner_p.global_position - c.global_position
	to.y = 0.0
	var dist := to.length()
	if dist > 28.0: # ficou para trás: reaparece perto do jogador
		c.global_position = owner_p.global_position + Vector3(2, 0.3, 2)
		return

	var dir := to / maxf(dist, 0.001)
	if dist > c.follow_distance:
		var spd := c.speed * (1.6 if dist > 9.0 else 1.0)
		c.accelerate(dir, spd, 30.0, delta)
		c.face(dir, delta)
	else:
		c.accelerate(Vector3.ZERO, 0.0, 30.0, delta)
	c.try_jump()
	c.move_and_slide()
	c.anim_motion()

	if c.should_dodge():
		machine.change_to(&"Dodge")
		return

	if c.find_target() != null:
		machine.change_to(&"Chase")
