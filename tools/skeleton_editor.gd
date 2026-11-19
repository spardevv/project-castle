@tool
extends Node3D
## Editor do esqueleto de um modelo (ex.: characters/models/elfa_rig.glb + .json).
## No editor: abra tools/skeleton_editor.tscn, selecione uma junta em "Juntas" e arraste (gizmo de mover);
## as linhas dos ossos acompanham. "Salvar no .json" grava as posições (o rig usa no próximo play).
## Os pesos da malha vêm do Blender: ajuste fino de pivôs aqui; mudanças grandes, refaça o rig_character.py.
## Render: godot --path . res://tools/skeleton_editor.tscn --resolution 1400x900 -- <pasta>
## (gera esqueleto_frente.png e esqueleto_lado.png e fecha).

@export var model: PackedScene = preload("res://characters/models/elfa_rig.glb"):
	set(v):
		model = v
		if is_inside_tree():
			_rebuild()
@export_tool_button("Recarregar do .json") var reload_btn := _rebuild
@export_tool_button("Salvar no .json") var save_btn := _save
## Malha semitransparente para ver os ossos por dentro.
@export_range(0.0, 1.0) var model_alpha := 0.45:
	set(v):
		model_alpha = v
		_apply_alpha()

## Ossos desenhados: junta -> filha.
const LINKS := [
	["hips", "spine"], ["spine", "chest"], ["chest", "neck"], ["neck", "head"],
	["chest", "clav_l"], ["chest", "clav_r"], ["clav_l", "sh_l"], ["clav_r", "sh_r"],
	["sh_l", "el_l"], ["sh_r", "el_r"], ["el_l", "wrist_l"], ["el_r", "wrist_r"],
	["wrist_l", "hand_l"], ["wrist_r", "hand_r"],
	["hips", "th_l"], ["hips", "th_r"], ["th_l", "kn_l"], ["th_r", "kn_r"], ["kn_l", "ft_l"], ["kn_r", "ft_r"],
	["ft_l", "toe_l"], ["ft_r", "toe_r"], ["toe_l", "toetip_l"], ["toe_r", "toetip_r"],
]
## Cor por região (tronco, esquerda, direita).
const COL_MID := Color(1.0, 0.85, 0.2)
const COL_L := Color(0.3, 0.8, 1.0)
const COL_R := Color(1.0, 0.35, 0.35)

var _data: Dictionary = {}
var _joints_root: Node3D
var _model_inst: Node3D
var _lines: MeshInstance3D
var _labels: Array[Label3D] = []


func _ready() -> void:
	_rebuild()
	if not Engine.is_editor_hint():
		var args := OS.get_cmdline_user_args()
		if args.size() > 0:
			_render(args[0])


func _json_path() -> String:
	return model.resource_path.get_basename() + ".json" if model != null else ""


func _rebuild() -> void:
	for c in get_children():
		if c.name in ["Modelo", "Juntas", "Ossos"]:
			remove_child(c)
			c.queue_free()
	_labels.clear()
	if model == null:
		return
	var f := FileAccess.open(_json_path(), FileAccess.READ)
	if f == null:
		push_error("sem .json: " + _json_path())
		return
	_data = JSON.parse_string(f.get_as_text())
	_model_inst = model.instantiate()
	_model_inst.name = "Modelo"
	add_child(_model_inst)
	_apply_alpha()
	_joints_root = Node3D.new()
	_joints_root.name = "Juntas"
	add_child(_joints_root)
	var owner_node := get_tree().edited_scene_root if Engine.is_editor_hint() else null
	for k in _data:
		var v = _data[k]
		if not (v is Array) or (v as Array).size() != 3 or (v[0] is Array):
			continue
		if k.begins_with("wr_") or k.begins_with("hair_"):
			continue # wr_ = wrist_ (salvo junto); cabelo tem cadeia própria
		var m := Marker3D.new()
		m.name = k
		m.position = Vector3(v[0], v[1], v[2])
		m.gizmo_extents = 0.03
		_joints_root.add_child(m)
		if Engine.is_editor_hint() and owner_node != null:
			m.owner = owner_node # aparece na árvore da cena para selecionar e arrastar
		var dot := MeshInstance3D.new()
		var sp := SphereMesh.new()
		sp.radius = 0.014
		sp.height = 0.028
		dot.mesh = sp
		dot.material_override = _line_mat(_side_color(k))
		m.add_child(dot)
		var lb := Label3D.new()
		lb.text = k
		lb.font_size = 22
		lb.pixel_size = 0.0012
		lb.no_depth_test = true
		lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lb.modulate = _side_color(k)
		lb.outline_size = 6
		lb.position = Vector3(0, 0.025, 0)
		m.add_child(lb)
		_labels.append(lb)
	_lines = MeshInstance3D.new()
	_lines.name = "Ossos"
	_lines.mesh = ImmediateMesh.new()
	_lines.material_override = _line_mat(Color.WHITE, true)
	add_child(_lines)
	_draw_bones()


func _process(_delta: float) -> void:
	_draw_bones()


func _draw_bones() -> void:
	if _lines == null or _joints_root == null:
		return
	var im := _lines.mesh as ImmediateMesh
	im.clear_surfaces()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	for pair in LINKS:
		var a := _joints_root.get_node_or_null(pair[0]) as Node3D
		var b := _joints_root.get_node_or_null(pair[1]) as Node3D
		if a == null or b == null:
			continue
		var c := _side_color(pair[1])
		im.surface_set_color(c)
		im.surface_add_vertex(a.position)
		im.surface_set_color(c)
		im.surface_add_vertex(b.position)
	# Linha de prumo do quadril até o chão (ver se os pés ficam embaixo do quadril).
	var hips := _joints_root.get_node_or_null("hips") as Node3D
	if hips != null:
		im.surface_set_color(Color(1, 1, 1, 0.5))
		im.surface_add_vertex(hips.position)
		im.surface_set_color(Color(1, 1, 1, 0.5))
		im.surface_add_vertex(Vector3(hips.position.x, 0.0, hips.position.z))
	im.surface_end()


func _save() -> void:
	if _joints_root == null:
		return
	for m in _joints_root.get_children():
		var p := (m as Node3D).position
		_data[m.name] = [snappedf(p.x, 0.0001), snappedf(p.y, 0.0001), snappedf(p.z, 0.0001)]
		if String(m.name).begins_with("wrist_"):
			_data["wr_" + String(m.name).substr(6)] = _data[m.name]
	var f := FileAccess.open(_json_path(), FileAccess.WRITE)
	f.store_string(JSON.stringify(_data, " "))
	print("esqueleto salvo em ", _json_path())


func _side_color(k: String) -> Color:
	if k.ends_with("_l"):
		return COL_L
	if k.ends_with("_r"):
		return COL_R
	return COL_MID


func _line_mat(c: Color, vertex_color := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	m.no_depth_test = true
	m.render_priority = 10
	m.vertex_color_use_as_albedo = vertex_color
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


func _apply_alpha() -> void:
	if _model_inst == null:
		return
	var stack: Array[Node] = [_model_inst]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		if n is MeshInstance3D:
			var mi := n as MeshInstance3D
			for s in mi.mesh.get_surface_count():
				var src := mi.mesh.surface_get_material(s)
				var mat: StandardMaterial3D = (src.duplicate() if src is StandardMaterial3D else StandardMaterial3D.new())
				mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS if model_alpha < 1.0 else BaseMaterial3D.TRANSPARENCY_DISABLED
				mat.albedo_color.a = model_alpha
				mi.set_surface_override_material(s, mat)


## Fotos de frente e de lado (câmera ortográfica), sai do jogo.
func _render(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.2, 0.21, 0.24)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.8, 0.8, 0.8)
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 30, 0)
	add_child(sun)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 2.1
	add_child(cam)
	cam.current = true
	for shot in [["frente", Vector3(0, 0.98, 4), 0.0], ["lado", Vector3(4, 0.98, 0), 90.0]]:
		cam.position = shot[1]
		cam.rotation_degrees = Vector3(0, shot[2], 0)
		for _i in 6:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(dir.path_join("esqueleto_%s.png" % shot[0]))
	get_tree().quit()
