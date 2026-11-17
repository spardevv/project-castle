extends SummonState
## Esquiva do summon: dash curto na diagonal para longe do inimigo que vai atacar, com i-frames.

const DURATION := 0.35
const IFRAMES := 0.25
const SPEED := 12.0
const COOLDOWN := 3.0

var _t := 0.0
var _dir := Vector3.BACK


func enter(_msg: Dictionary = {}) -> void:
	var c := s
	_t = 0.0
	c.dodge_cd = COOLDOWN
	c.health.invulnerable = true
	var threat := c.nearest_enemy_within(4.0)
	var away := -c.forward()
	if threat != null:
		away = c.global_position - threat.global_position
		away.y = 0.0
		away = away.normalized() if away.length() > 0.01 else -c.forward()
	var side := Vector3(-away.z, 0.0, away.x) * (1.0 if randf() < 0.5 else -1.0)
	_dir = (away * 0.5 + side).normalized()


func exit() -> void:
	s.health.invulnerable = false


func physics_update(delta: float) -> void:
	var c := s
	_t += delta
	c.apply_gravity(delta)
	var spd := SPEED * clampf(1.0 - _t / DURATION, 0.2, 1.0)
	c.velocity.x = _dir.x * spd
	c.velocity.z = _dir.z * spd
	c.rig.set_dodge(_t / DURATION)
	if _t >= IFRAMES:
		c.health.invulnerable = false
	c.move_and_slide()
	if _t >= DURATION:
		machine.change_to(&"Chase")
