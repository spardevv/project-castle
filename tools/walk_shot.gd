extends Node3D
## Ferramenta de desenvolvimento: filma o rig andando/correndo de perfil e salva uma tira de quadros (PNG).
## Uso: godot --path . res://tools/walk_shot.tscn --resolution 1200x400 -- <arquivo.png>

const SPEEDS := [3.6, 7.0]
const FRAMES := 6
const DT := 1.0 / 60.0

var _rig: HumanoidRig
var _mover: Node3D
var _cam: Camera3D


func _ready() -> void:
	var out := "user://walk.png"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.3, 0.32, 0.36)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.6, 0.65)
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 25, 0)
	add_child(sun)
	var fl := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(400, 1, 400)
	cs.shape = box
	cs.position.y = -0.5
	fl.add_child(cs)
	add_child(fl)
	var fm := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(400, 0.02, 400)
	fm.mesh = bm
	fm.position.y = -0.01
	add_child(fm)
	_mover = Node3D.new()
	add_child(_mover)
	_rig = HumanoidRig.new()
	_mover.add_child(_rig)
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.size = 2.6
	add_child(_cam)
	_cam.current = true
	var sheet: Image
	for si in SPEEDS.size():
		var v: float = SPEEDS[si]
		_mover.position = Vector3.ZERO
		for f in 90:
			_step(v)
			await get_tree().process_frame
		for k in FRAMES:
			for f in 5:
				_step(v)
				await get_tree().process_frame
			_cam.position = Vector3(8.0, 1.0, _mover.position.z)
			_cam.rotation_degrees = Vector3(0, 90, 0)
			await RenderingServer.frame_post_draw
			var img := get_viewport().get_texture().get_image()
			img.convert(Image.FORMAT_RGBA8)
			if sheet == null:
				sheet = Image.create(img.get_width(), img.get_height() * SPEEDS.size(), false, Image.FORMAT_RGBA8)
			var w := img.get_width() / FRAMES
			sheet.blit_rect(img, Rect2i(img.get_width() / 2 - w / 2, 0, w, img.get_height()), Vector2i(k * w, si * img.get_height()))
	sheet.save_png(out)
	print("saved ", out)
	get_tree().quit()


func _step(v: float) -> void:
	_mover.position.z += v * DT
	_rig.set_motion(v, true, 0.0)
