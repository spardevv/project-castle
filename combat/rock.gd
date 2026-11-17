class_name Rock
extends Projectile
## Pedra arremessada pelo golem: voa em arco (balística) e explode em área ao tocar um inimigo ou o chão.

const GRAVITY := 14.0

var velocity := Vector3.ZERO


## Calcula a velocidade inicial para atingir `target` (mundo) em `flight` segundos a partir da posição atual.
func throw_at(target: Vector3, flight := 0.8) -> void:
	var d := target - global_position
	velocity = Vector3(d.x / flight, (d.y + 0.5 * GRAVITY * flight * flight) / flight, d.z / flight)


func _physics_process(delta: float) -> void:
	if _exploded:
		return
	velocity.y -= GRAVITY * delta
	global_position += velocity * delta
	rotate_x(delta * 6.0)
	lifetime -= delta
	if lifetime <= 0.0 or global_position.y < -2.0:
		explode()
