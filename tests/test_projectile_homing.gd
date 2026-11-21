extends GutTest
## A bola de fogo com alvo travado curva em direção a ele; sem alvo voa reto.


func _make(target: Node3D) -> Projectile:
	var p := Projectile.new()
	p.direction = Vector3.FORWARD
	p.homing_target = target
	add_child_autofree(p)
	return p


func test_curves_toward_target() -> void:
	var t := Node3D.new()
	add_child_autofree(t)
	t.global_position = Vector3(8, -1, -8) # à direita da linha de voo
	var p := _make(t)
	for i in 20:
		p._steer(1.0 / 60.0)
	assert_gt(p.direction.x, 0.2, "virou para o alvo")


func test_straight_without_target() -> void:
	var p := _make(null)
	for i in 20:
		p._steer(1.0 / 60.0)
	assert_eq(p.direction, Vector3.FORWARD)
