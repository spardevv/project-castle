extends Node
## Contato entre personagens (autoload BodyContacts). Os corpos não colidem fisicamente entre si
## (só com o cenário); aqui cada par que se sobrepõe é afastado, dividindo o empurrão pela massa.
## Resultado: o player desliza ao redor dos inimigos e empurra os leves; o brutamontes mal se move;
## ninguém "trava" parado no outro. O deslocamento usa move_and_collide, então respeita paredes.
##
## Participantes: nós no grupo "body_contact" com contact_radius, contact_mass e contact_enabled.

const ITERATIONS := 2
## Diferença de altura acima da qual dois corpos não se empurram (um pulando sobre o outro).
const MAX_HEIGHT_GAP := 1.4


func _physics_process(_delta: float) -> void:
	var bodies := get_tree().get_nodes_in_group("body_contact")
	var n := bodies.size()
	for _it in ITERATIONS:
		for i in n:
			var a := bodies[i] as CharacterBody3D
			if a == null or not a.get("contact_enabled"):
				continue
			for j in range(i + 1, n):
				var b := bodies[j] as CharacterBody3D
				if b == null or not b.get("contact_enabled"):
					continue
				_separate(a, b)


func _separate(a: CharacterBody3D, b: CharacterBody3D) -> void:
	var d := b.global_position - a.global_position
	if absf(d.y) > MAX_HEIGHT_GAP:
		return
	d.y = 0.0
	var min_dist: float = float(a.get("contact_radius")) + float(b.get("contact_radius"))
	var dist := d.length()
	if dist >= min_dist:
		return
	var normal := d / dist if dist > 0.001 else Vector3.RIGHT
	var pen := min_dist - dist
	var ma: float = a.get("contact_mass")
	var mb: float = b.get("contact_mass")
	var total := ma + mb
	a.move_and_collide(-normal * pen * (mb / total))
	b.move_and_collide(normal * pen * (ma / total))
