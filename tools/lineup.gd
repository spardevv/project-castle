extends Node3D
## Ferramenta de desenvolvimento: renderiza os bonecos de todos os personagens lado a lado (PNG).
## Linha de cima: 3/4 em guarda; linha de baixo: perfil num golpe.
## Uso: godot --path . res://tools/lineup.tscn --resolution 1500x720 -- <arquivo.png>

const SCENES := [
	"res://player/player.tscn", "res://player/player.tscn", "res://enemies/enemy.tscn", "res://enemies/brute.tscn",
	"res://enemies/archer.tscn", "res://summon/summon.tscn", "res://summon/priest.tscn",
]
const ATTACKS := ["a1", "e_swing", "e_swing", "e_smash", "e_draw", "punch_r", "priest_cast"]
const SPACING := 2.1


func _ready() -> void:
	var out := "user://lineup.png"
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
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 6.8
	cam.position = Vector3((SCENES.size() - 1) * SPACING * 0.5, 2.6, 12.0)
	add_child(cam)
	cam.current = true

	for row in 2:
		var y := 3.0 if row == 0 else 0.0
		var floor_mesh := BoxMesh.new()
		floor_mesh.size = Vector3(SCENES.size() * SPACING, 0.02, 1.4)
		var fl := MeshInstance3D.new()
		fl.mesh = floor_mesh
		fl.position = Vector3((SCENES.size() - 1) * SPACING * 0.5, y - 0.01, 0)
		add_child(fl)
		for i in SCENES.size():
			var character: Node = load(SCENES[i]).instantiate()
			var rig: HumanoidRig = character.get_node("Visual/Rig")
			character.get_node("Visual").remove_child(rig)
			rig.owner = null
			character.free()
			rig.position = Vector3(i * SPACING, y, 0)
			rig.rotation_degrees.y = -35.0 if row == 0 else 90.0
			add_child(rig)
			if i == 1: # segundo player: martelo e escudo (só dá para trocar com o rig já na cena)
				rig.set_weapon(HumanoidRig.Weapon.HAMMER)
				rig.set_offhand(HumanoidRig.Offhand.SHIELD)
			if row == 0:
				rig.set_guard(i == 0)
			else:
				rig.set_attack(ATTACKS[i], 0.3, 0.15, 0.45, 0.42)
			rig.snap()

	for _f in 8:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out)
	print("saved ", out)
	get_tree().quit()
