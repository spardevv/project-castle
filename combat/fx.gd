class_name Fx
extends RefCounted
## Efeitos visuais simples reutilizáveis.


static func flash(node: Node, mat: StandardMaterial3D, color := Color.WHITE, time := 0.18) -> void:
	if mat == null or not node.is_inside_tree():
		return
	mat.emission_enabled = true
	mat.emission = color
	var tween := node.create_tween()
	tween.tween_property(mat, "emission", Color.BLACK, time)


## Número de dano flutuante (Label3D que sobe e some). amount 0 = "BLOQUEADO"; tag substitui o texto.
static func damage_number(from: Node, pos: Vector3, amount: int, color := Color.WHITE, tag := "") -> void:
	var scene := from.get_tree().current_scene
	if scene == null:
		return
	var l := Label3D.new()
	if tag != "":
		l.text = tag
	else:
		l.text = str(amount) if amount > 0 else "BLOQUEADO"
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.fixed_size = false
	l.pixel_size = 0.008
	l.font_size = 72 if amount >= 18 else 56
	l.outline_size = 16
	l.modulate = color
	scene.add_child(l)
	l.global_position = pos + Vector3(randf_range(-0.2, 0.2), 0.0, randf_range(-0.2, 0.2))
	var tween := l.create_tween()
	tween.set_parallel(true)
	tween.tween_property(l, "global_position:y", pos.y + 1.1, 0.7).set_ease(Tween.EASE_OUT)
	tween.tween_property(l, "modulate:a", 0.0, 0.7).set_delay(0.25)
	tween.chain().tween_callback(l.queue_free)


## Esfera de luz que se expande e some (só visual, sem dano): explosão de cura, poeira, aura.
static func burst(from: Node, pos: Vector3, radius: float, color: Color, time := 0.5) -> void:
	var scene := from.get_tree().current_scene
	if scene == null:
		return
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color(color.r, color.g, color.b, 0.7)
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.scale = Vector3.ONE * 0.2
	scene.add_child(mi)
	mi.global_position = pos
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 6.0
	light.omni_range = radius * 2.0
	mi.add_child(light)
	var tw := mi.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * radius, time * 0.6).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, time).set_delay(time * 0.15)
	tw.tween_property(light, "light_energy", 0.0, time)
	tw.chain().tween_callback(mi.queue_free)
	spark(from, pos, color)
	spark(from, pos + Vector3(0, 0.4, 0), Color(1, 1, 1))


## Faíscas de impacto (one-shot) na posição do acerto.
static func spark(from: Node, pos: Vector3, color := Color(1.0, 0.85, 0.4)) -> void:
	var scene := from.get_tree().current_scene
	if scene == null:
		return
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = 14
	p.lifetime = 0.35
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 2.5
	p.initial_velocity_max = 6.0
	p.gravity = Vector3(0, -9.0, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.05, 0.05, 0.05)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mesh.material = mat
	p.mesh = mesh
	scene.add_child(p)
	p.global_position = pos
	p.emitting = true
	from.get_tree().create_timer(0.8).timeout.connect(p.queue_free)
