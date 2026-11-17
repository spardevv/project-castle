extends PlayerState
## Hitstun com knockback. A pose de recuo segue a direção do golpe (frente/trás/lados).

var _t := 0.0
var _duration := 0.3
var _push := Vector3.ZERO


func enter(msg: Dictionary = {}) -> void:
	var p := player
	var hit: HitData = msg.get("hit")
	_t = 0.0
	p.combo_memory_time = 0.0
	_duration = hit.hitstun if hit else 0.3
	_push = -p.forward()
	if hit and is_instance_valid(hit.source):
		var d := p.global_position - hit.source.global_position
		d.y = 0.0
		if d.length() > 0.01:
			_push = d.normalized()
	var force := hit.knockback if hit else 4.0
	p.velocity = Vector3(_push.x * force, 3.0, _push.z * force)
	p.health.grant_iframes(0.9)
	p.rig.set_hurt(0.0, _push) # já na pose de recuo quando o hit-stop congelar


func physics_update(delta: float) -> void:
	var p := player
	_t += delta
	p.apply_gravity(delta)
	p.accelerate(Vector3.ZERO, 0.0, 14.0, delta)
	p.rig.set_hurt(_t / maxf(_duration, 0.01), _push)
	p.move_and_slide()
	if _t >= _duration:
		land_or_fall()
