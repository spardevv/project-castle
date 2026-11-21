extends SummonState
## Lançar pedra (passiva do golem): ergue a pedra com as duas mãos, vira para o alvo e arremessa em arco.
## Dano moderado + stun de 2 s.

const ROCK := preload("res://combat/rock.tscn")
const WINDUP := 0.55
const ACTIVE := 0.1
const RECOVERY := 0.45

const DAMAGE := 16
const STUN := 2.0

var _t := 0.0
var _thrown := false
var _target: Node3D


func enter(_msg: Dictionary = {}) -> void:
	_t = 0.0
	_thrown = false
	# Prioriza inimigos aéreos e a longa distância (Summon.pick_rock_target); senão o alvo normal.
	_target = s.pick_rock_target()
	if _target == null:
		_target = s.find_target()


func exit() -> void:
	s.rig.set_glow(Color.BLACK)


func physics_update(delta: float) -> void:
	var c := s
	_t += delta
	c.apply_gravity(delta)
	c.accelerate(Vector3.ZERO, 0.0, 40.0, delta)
	c.rig.set_attack("rock_throw", WINDUP, ACTIVE, RECOVERY, _t)

	var target := _target if is_instance_valid(_target) else c.find_target()
	if not _thrown and target != null:
		var to := target.global_position - c.global_position
		to.y = 0.0
		c.face(to.normalized(), delta, 14.0)

	if not _thrown:
		c.rig.set_glow(Color(0.7, 0.6, 0.4) * clampf(_t / WINDUP, 0.0, 1.0) * 0.5)
		if _t >= WINDUP:
			_thrown = true
			c.rig.set_glow(Color.BLACK)
			_throw(target)

	c.move_and_slide()
	if _t >= WINDUP + ACTIVE + RECOVERY:
		machine.change_to(&"Chase")


func _throw(target: Node3D) -> void:
	var c := s
	var rock: Rock = ROCK.instantiate()
	Sfx.play(&"swing_heavy", c.global_position + Vector3(0, 2.0, 0), 0.0, 0.7)
	rock.source = c
	# Dano moderado e stun de 2 s (quebra a super armor); sem lançar, para o stun valer.
	rock.explosion_damage = DAMAGE
	rock.explosion_radius = 2.2
	rock.explosion_launch = 0.0
	rock.explosion_knockback = 2.5
	rock.explosion_hitstun = STUN
	rock.explosion_poise_break = true
	c.get_parent().add_child(rock)
	rock.global_position = c.global_position + Vector3(0, 2.3, 0) + c.forward() * 0.4
	var dest := c.global_position + c.forward() * 9.0
	if target != null:
		dest = target.global_position
		var dist := Vector2(dest.x - c.global_position.x, dest.z - c.global_position.z).length()
		rock.throw_at(dest + Vector3(0, 0.3, 0), clampf(dist / 14.0, 0.45, 1.0))
	else:
		rock.throw_at(dest, 0.8)
	GameFeel.shake(0.08)
