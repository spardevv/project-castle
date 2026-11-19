extends Node3D
## Ferramenta de desenvolvimento: roda o rig em tempo real simulado (60 quadros/s, com molas, IK e
## cabelo) e monta uma tira de quadros de perfil — mostra o movimento como no jogo, inclusive trancos
## entre quadros que as folhas de pose (estáticas) escondem.
## Uso: godot --path . res://tools/motion_strip.tscn --resolution 1500x720 -- <pasta> [filtro]

const RIG := preload("res://characters/humanoid_rig.tscn")
const MODEL := preload("res://characters/models/elfa_rig.glb")
const DT := 1.0 / 60.0
const COLS := 8
const ROWS := 2
const CELL := Vector2i(220, 360)

var _rig: HumanoidRig
var _cam: Camera3D
var _out := "user://motion"
var _filter := ""


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	if args.size() > 1:
		_filter = args[1]
	DirAccess.make_dir_recursive_absolute(_out)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.3, 0.32, 0.36)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.7, 0.75)
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 60, 0)
	add_child(sun)
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.size = 2.6
	_cam.position = Vector3(5.0, 1.0, 0.0)
	_cam.rotation_degrees = Vector3(0, 90, 0) # perfil: personagem olhando para a direita da tela (+Z)
	add_child(_cam)
	# Chão com colisão: a trava de pé (IK) precisa dele.
	var floor_body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(400, 1, 400)
	cs.shape = box
	cs.position.y = -0.5
	floor_body.add_child(cs)
	add_child(floor_body)
	_rig = RIG.instantiate()
	_rig.body_model = MODEL
	_rig.feminine = true
	add_child(_rig)
	_rig.set_process(false)
	await _strip("roll", 0.6, func(t: float) -> void: _rig.set_dodge(t / 0.6, Vector3(0, 0, 1)))
	await _strip("dodge_back", 0.6, func(t: float) -> void: _rig.set_dodge(t / 0.6, Vector3(0, 0, -1)))
	await _strip("dodge_left", 0.6, func(t: float) -> void: _rig.set_dodge(t / 0.6, Vector3(1, 0, 0)))
	await _strip("jump", 1.75, func(t: float) -> void:
		var vy := 8.5 - 9.8 * t
		_rig.set_motion(0.0, t > 1.73, vy))
	await _strip("run_7", 0.6, func(_t: float) -> void:
		_rig.position.z += 7.0 * DT
		_cam.position.z = _rig.position.z
		_rig.set_motion(7.0, true, 0.0))
	await _strip("walk_3_6", 0.8, func(_t: float) -> void:
		_rig.position.z += 3.6 * DT
		_cam.position.z = _rig.position.z
		_rig.set_motion(3.6, true, 0.0))
	get_tree().quit()


## Simula `duration` segundos chamando setup(t) a cada quadro; tira COLS*ROWS fotos espaçadas.
func _strip(strip_name: String, duration: float, setup: Callable) -> void:
	if _filter != "" and not strip_name.contains(_filter):
		return
	_rig.position = Vector3.ZERO
	_cam.position.z = 0.0
	_rig.set_motion(0.0, true, 0.0)
	_rig.snap()
	for _i in 30: # parado um pouco antes (estado inicial assentado)
		_rig._process(DT)
	var shots := COLS * ROWS
	var steps := maxi(int(round(duration / DT)), shots)
	var sheet := Image.create(CELL.x * COLS, CELL.y * ROWS, false, Image.FORMAT_RGBA8)
	var taken := 0
	for s in steps + 1:
		var t := s * DT
		setup.call(t)
		_rig._process(DT)
		var want := int(round(float(taken) * steps / (shots - 1)))
		if s == want and taken < shots:
			await RenderingServer.frame_post_draw
			var img := get_viewport().get_texture().get_image()
			var vs := img.get_size()
			var crop := Rect2i(vs.x / 2 - vs.y * CELL.x / CELL.y / 2, 0, vs.y * CELL.x / CELL.y, vs.y)
			var cell := img.get_region(crop)
			cell.resize(CELL.x, CELL.y)
			cell.convert(Image.FORMAT_RGBA8)
			sheet.blit_rect(cell, Rect2i(Vector2i.ZERO, CELL), Vector2i((taken % COLS) * CELL.x, (taken / COLS) * CELL.y))
			taken += 1
	sheet.save_png(_out.path_join(strip_name + ".png"))
	print("saved ", strip_name)
