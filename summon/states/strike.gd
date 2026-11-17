extends SummonState
## Golpe da criatura (básico ou pancada em área), definido pelos parâmetros recebidos.

var _p: Dictionary
var _t := 0.0
var _started := false
var _ended := false


func enter(msg: Dictionary = {}) -> void:
	var c := s
	_p = msg
	_t = 0.0
	_started = false
	_ended = false
	var shape := c.hitbox.get_node("CollisionShape3D") as CollisionShape3D
	(shape.shape as BoxShape3D).size = _p["size"]
	c.hitbox.position = _p["offset"]


func exit() -> void:
	var c := s
	c.hitbox.deactivate()
	c.rig.set_glow(Color.BLACK)
	c.rig.trail_active = false
	c.attack_cd = 0.7
	if _p.get("name", "") == "slam":
		c.slam_cd = 7.0


func physics_update(delta: float) -> void:
	var c := s
	_t += delta
	c.apply_gravity(delta)
	var active_start: float = _p["windup"]
	var active_end: float = active_start + _p["active"]
	# Esquiva cancela a preparação e a recuperação (não a fase ativa do próprio golpe).
	if (_t < active_start * 0.6 or _t >= active_end) and c.should_dodge():
		machine.change_to(&"Dodge")
		return
	var anim: String = _p.get("anim", "overhead" if _p["name"] == "slam" else "a1")
	c.rig.set_attack(anim, active_start, _p["active"], _p["recovery"], _t)

	if _t < active_start:
		c.accelerate(Vector3.ZERO, 0.0, 30.0, delta)
		c.rig.set_glow(Color(0.3, 0.6, 1.0) * (_t / active_start))
	elif _t < active_end:
		if not _started:
			_started = true
			var hit := HitData.new()
			hit.damage = _p["damage"]
			hit.knockback = _p["knockback"]
			hit.hitstun = _p["hitstun"]
			hit.hitstop = 0.06
			c.hitbox.activate(hit, not _p.get("area", _p["name"] == "slam")) # básico segue a clava; pancada/giro são em área
			c.rig.set_glow(Color(0.6, 0.9, 1.0))
			c.rig.trail_active = true
			var big: bool = _p["name"] == "slam" or _p["name"] == "spin"
			Sfx.play(&"swing_heavy" if big else &"punch", c.global_position + Vector3(0, 1.4, 0), 0.0, 0.8 if big else 1.0)
			if _p["name"] == "slam" or _p["name"] == "spin" or (_p["name"] == "punch" and int(_p["combo_left"]) == 0):
				GameFeel.shake(0.14)
		var fwd := c.forward() * float(_p["lunge"])
		c.velocity.x = fwd.x
		c.velocity.z = fwd.z
	else:
		if not _ended:
			_ended = true
			c.hitbox.deactivate()
			c.rig.set_glow(Color.BLACK)
			c.rig.trail_active = false
		c.accelerate(Vector3.ZERO, 0.0, 25.0, delta)

	c.move_and_slide()
	if _t >= active_end + float(_p["recovery"]):
		if int(_p.get("combo_left", 0)) > 0:
			# Próximo soco da sequência (alterna os braços; o último é o mais forte).
			machine.change_to(&"Strike", Summon.punch_hit(int(_p["index"]) + 1, int(_p["total"]), int(_p["dmg"])))
		else:
			machine.change_to(&"Chase")
