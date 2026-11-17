extends EnemyState
## Agarrado pelo golem: segue o ponto de segurança do dono, sem IA nem física, balançando no ar.
## Sai sozinho se o dono sumir ou deixar de estar no estado Grab (segurança contra ficar preso).

var holder: Node3D
var _t := 0.0


func enter(msg: Dictionary = {}) -> void:
	var en := e
	holder = msg.get("holder")
	_t = 0.0
	en.velocity = Vector3.ZERO
	en.contact_enabled = false
	en.hitbox.deactivate()
	en.rig.trail_active = false
	en.rig.set_glow(Color.BLACK)


func exit() -> void:
	e.contact_enabled = true


func physics_update(delta: float) -> void:
	var en := e
	_t += delta
	if not is_instance_valid(holder) or str(holder.get("machine").current_name()) != "Grab":
		machine.change_to(en.engage_state)
		return
	en.velocity = Vector3.ZERO
	en.global_position = holder.hold_point()
	var to: Vector3 = holder.global_position - en.global_position
	to.y = 0.0
	en.face(to.normalized(), delta, 12.0)
	en.rig.set_air_hurt(_t)
