extends Node3D
## Ferramenta de desenvolvimento: renderiza "folhas de pose" em PNG.
## Cada folha mostra uma animação congelada em 6 momentos: linha de cima em 3/4, linha de baixo de perfil.
## Uso: godot --path . res://tools/pose_sheet.tscn --resolution 1500x720 -- <pasta_saida> [filtro]

const RIG := preload("res://characters/humanoid_rig.tscn")
const COLS := 6
const SPACING := 1.75

var _rigs: Array[HumanoidRig] = []
var _out_dir := "user://pose_sheets"
var _filter := ""
var _hammer := false
var _shield := false
var _spear := false
var _armed := false
var _model: PackedScene


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out_dir = args[0]
	if args.size() > 1:
		_filter = args[1]
	if _filter.begins_with("clip:"): # "clip:atk_a1" = jogador armado (clipes do Mixamo para golpes/corrida/guarda)
		_filter = _filter.substr(5)
		_armed = true
	if _filter.begins_with("sh:"): # "sh:move_run" = folhas com escudo
		_filter = _filter.substr(3)
		_shield = true
	if _filter.begins_with("hm:"): # "hm:move_" = folhas com o martelo
		_filter = _filter.substr(3)
		_hammer = true
	if _filter.begins_with("elfa:"): # "elfa:move_" = corpo do modelo characters/models/elfa_rig.glb
		_filter = _filter.substr(5)
		_model = load("res://characters/models/elfa_rig.glb")
	if _filter.begins_with("sp:"): # "sp:move_" = folhas com a lança
		_filter = _filter.substr(3)
		_spear = true
	DirAccess.make_dir_recursive_absolute(_out_dir)
	_build_stage()
	await _render_all()
	get_tree().quit()


func _build_stage() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.3, 0.32, 0.36)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.65, 0.65, 0.7)
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 25, 0)
	add_child(sun)

	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 5.2
	cam.position = Vector3((COLS - 1) * SPACING * 0.5, 2.2, 12.0)
	add_child(cam)
	cam.current = true

	for row in 2:
		var y := 2.5 if row == 0 else 0.0
		var floor_mesh := BoxMesh.new()
		floor_mesh.size = Vector3(COLS * SPACING, 0.02, 1.2)
		var floor_mi := MeshInstance3D.new()
		floor_mi.mesh = floor_mesh
		floor_mi.position = Vector3((COLS - 1) * SPACING * 0.5, y - 0.01, 0)
		add_child(floor_mi)
		for col in COLS:
			var rig: HumanoidRig = RIG.instantiate()
			rig.body_model = _model
			rig.armed_clips = _armed
			rig.offhand = HumanoidRig.Offhand.SHIELD if _shield else HumanoidRig.Offhand.ORB
			if _hammer or _filter.contains("hm_"):
				rig.offhand = HumanoidRig.Offhand.NONE
				rig.weapon = HumanoidRig.Weapon.HAMMER
			if _spear or _filter.contains("sp_"):
				rig.weapon = HumanoidRig.Weapon.SPEAR
			if _filter.begins_with("golem"):
				rig.offhand = HumanoidRig.Offhand.NONE
				rig.weapon = HumanoidRig.Weapon.NONE
				rig.headgear = HumanoidRig.Headgear.GOLEM
				rig.tabard = false
				rig.skin = Color(0.5, 0.5, 0.52)
				rig.cloth = Color(0.4, 0.4, 0.42)
				rig.accent = Color(0.3, 0.33, 0.28)
				rig.height = 1.25
				rig.bulk = 1.7
				rig.pauldron_scale = 1.5
				rig.fist_scale = 1.8
				rig.runes = true
			rig.position = Vector3(col * SPACING, y, 0)
			# 3/4 mostrando o lado da espada; perfil olhando para a direita da imagem.
			rig.rotation_degrees.y = -35.0 if row == 0 else 90.0
			add_child(rig)
			_rigs.append(rig)


func _render_all() -> void:
	var two_handed := AttackData.two_handed_anims()
	for anim in Poses.ATTACKS.keys() + Poses._spear_defs().keys() + ["choke_lift", "heal", "magic_attack"]:
		var prefix := "golem_atk_" if _filter.begins_with("golem") else "atk_"
		await _sheet(prefix + anim, func(rig: HumanoidRig, i: int) -> void:
			var su := 0.3
			var ac := 0.15
			var re := 0.45
			var times := [0.0, su * 0.6, su, su + ac * 0.5, su + ac, su + ac + re * 0.5]
			rig.set_attack(anim, su, ac, re, times[i], two_handed.has(anim)))
	# Dano: empurrado para trás, para frente, para a direita, para a esquerda; depois o recuo voltando.
	await _sheet("react_hurt", func(rig: HumanoidRig, i: int) -> void:
		var local_dirs := [Vector3(0, 0, -1), Vector3(0, 0, 1), Vector3(-1, 0, 0), Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 0, -1)]
		var progress := [0.15, 0.15, 0.15, 0.15, 0.6, 0.85]
		rig.set_hurt(progress[i], rig.global_transform.basis * local_dirs[i]))
	await _sheet("react_air", func(rig: HumanoidRig, i: int) -> void: rig.set_air_hurt(i * 0.15))
	await _sheet("react_knockdown", func(rig: HumanoidRig, i: int) -> void:
		var times := [0.12, 0.3, 0.9, 1.55, 1.75, 1.95]
		rig.set_knockdown(times[i], 2.0))
	await _sheet("react_dodge", func(rig: HumanoidRig, i: int) -> void: rig.set_dodge(i / 5.0))
	await _sheet("react_dead", func(rig: HumanoidRig, i: int) -> void: rig.set_dead(i * 0.12))
	await _sheet("react_guard", func(rig: HumanoidRig, _i: int) -> void: rig.set_guard())
	await _sheet("shield_guard", func(rig: HumanoidRig, _i: int) -> void:
		rig.set_offhand(HumanoidRig.Offhand.SHIELD)
		rig.set_guard(true))
	await _sheet("shield_bash", func(rig: HumanoidRig, i: int) -> void:
		rig.set_offhand(HumanoidRig.Offhand.SHIELD)
		var times := [0.0, 0.06, 0.1, 0.18, 0.26, 0.4]
		rig.set_attack("bash", 0.1, 0.16, 0.3, times[i]))
	await _sheet("archer_draw", func(rig: HumanoidRig, i: int) -> void:
		rig.set_offhand(HumanoidRig.Offhand.NONE)
		var times := [0.0, 0.35, 0.7, 0.74, 0.8, 1.0]
		rig.set_attack("e_draw", 0.7, 0.06, 0.4, times[i]))
	await _sheet("move_run", func(rig: HumanoidRig, i: int) -> void:
		rig.set_motion(7.0, true, 0.0)
		rig._phase = i * TAU / 6.0)
	await _sheet("move_walk", func(rig: HumanoidRig, i: int) -> void:
		rig.set_motion(3.6, true, 0.0)
		rig._phase = i * TAU / 6.0)
	# Besta: mirando parado (2 primeiros), andando (2) e correndo (2).
	await _sheet("aim_crossbow", func(rig: HumanoidRig, i: int) -> void:
		rig.set_offhand(HumanoidRig.Offhand.CROSSBOW)
		rig.set_aim(true)
		rig.set_motion([0.0, 0.0, 3.6, 3.6, 7.0, 7.0][i], true, 0.0)
		rig._phase = [0.0, 0.0, 0.0, PI, 0.0, PI][i])
	await _sheet("move_idle", func(rig: HumanoidRig, i: int) -> void:
		rig.set_motion(0.0, true, 0.0)
		rig._time = i * 0.5)


func _sheet(sheet_name: String, setup: Callable) -> void:
	if _filter != "" and not sheet_name.contains(_filter):
		return
	for idx in _rigs.size():
		var rig := _rigs[idx]
		setup.call(rig, idx % COLS)
		rig.snap()
	for _f in 3:
		await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(_out_dir.path_join(sheet_name + ".png"))
	print("saved ", sheet_name)
