extends EnemyState
## Ataque corpo a corpo do inimigo. O golpe é sorteado da tabela do arquétipo (EnemyMoves, por
## Enemy.move_set). Telegrafia com brilho na cor do golpe durante a preparação.
## Golpes com "explosion" soltam uma onda de choque em área contra o player (pisão do brutamontes).

var _m: Dictionary
var _t := 0.0
var _started := false
var _ended := false


func enter(_msg: Dictionary = {}) -> void:
	var en := e
	_t = 0.0
	_started = false
	_ended = false
	_m = EnemyMoves.pick(en.move_set)
	var shape := en.hitbox.get_node("CollisionShape3D") as CollisionShape3D
	(shape.shape as BoxShape3D).size = _m["size"]
	en.hitbox.position = _m["offset"]


func exit() -> void:
	e.hitbox.deactivate()
	e.rig.set_glow(Color.BLACK)
	e.rig.trail_active = false
	e.attack_cd = float(_m.get("cooldown", 1.2))


func physics_update(delta: float) -> void:
	var en := e
	_t += delta
	var windup: float = _m["windup"]
	var active: float = _m["active"]
	var recovery: float = _m["recovery"]
	en.apply_gravity(delta)
	en.rig.set_attack(_m["anim"], windup, active, recovery, _t)

	if _t < windup:
		en.face(en.to_player().normalized(), delta, 12.0)
		en.accelerate(Vector3.ZERO, 0.0, 30.0, delta)
		en.rig.set_glow((_m["glow"] as Color) * (_t / windup))
	elif _t < windup + active:
		if not _started:
			_started = true
			var hit := HitData.new()
			hit.damage = _m["damage"]
			hit.knockback = _m["knockback"]
			hit.hitstun = _m["hitstun"]
			hit.hitstop = _m["hitstop"]
			var heavy_move: bool = float(_m["damage"]) >= 16.0
			Sfx.play(&"swing_heavy" if heavy_move else &"swing", en.global_position + Vector3(0, 1.2, 0), 0.0, 0.8 if heavy_move else 1.0)
			if _m.has("explosion"):
				_shockwave(float(_m["explosion"]), hit)
			else:
				en.hitbox.activate(hit, true) # acerta onde a clava passa
				en.rig.trail_active = true
		var fwd := en.forward() * float(_m["lunge"])
		en.velocity.x = fwd.x
		en.velocity.z = fwd.z
	else:
		if not _ended:
			_ended = true
			en.hitbox.deactivate()
			en.rig.set_glow(Color.BLACK)
			en.rig.trail_active = false
			if _m.has("shake"):
				GameFeel.shake(float(_m["shake"]))
		en.accelerate(Vector3.ZERO, 0.0, 25.0, delta)

	en.move_and_slide()
	if _t >= windup + active + recovery:
		machine.change_to(en.engage_state)


## Onda de choque em volta do pé da frente: Explosion contra o player e o summon.
func _shockwave(radius: float, hit: HitData) -> void:
	var en := e
	var ex := Explosion.new()
	ex.hits_player = true
	ex.radius = radius
	ex.damage = hit.damage
	ex.knockback = hit.knockback
	ex.launch = 0.0
	ex.color = Color(0.85, 0.45, 0.15)
	ex.instigator = en
	ex.position = en.global_position + en.forward() * 1.2 + Vector3(0, 0.3, 0)
	en.get_parent().add_child(ex)
