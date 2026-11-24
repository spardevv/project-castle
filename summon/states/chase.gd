extends SummonState
## Persegue o inimigo mais próximo, esquiva de golpes, pula degraus e escolhe entre as skills
## passivas equipadas (por cooldown/condições) e os golpes básicos (Summon.next_basic).


func physics_update(delta: float) -> void:
	var c := s
	c.apply_gravity(delta)
	if c.should_dodge():
		machine.change_to(&"Dodge")
		return
	var target := c.find_target()
	if target == null:
		machine.change_to(&"Follow")
		return
	c.try_jump()

	var to := target.global_position - c.global_position
	to.y = 0.0
	var dist := to.length()
	var dir := to / maxf(dist, 0.001)
	if dist > c.attack_range * 0.9:
		c.accelerate(dir, c.speed, 30.0, delta)
	else:
		c.accelerate(Vector3.ZERO, 0.0, 30.0, delta)
	c.face(dir, delta, 12.0)
	c.move_and_slide()
	c.anim_motion()

	if not c.is_on_floor():
		return
	var passive := c.pick_passive(dist)
	if passive != &"":
		c.start_passive(passive)
	elif c.attack_cd <= 0.0:
		# Básicos do golem: soco D, soco E, chute espartano; ombrada para fechar distância.
		var basic := c.next_basic(dist)
		if not basic.is_empty():
			machine.change_to(&"Strike", basic)
