extends Node3D
## Ferramenta de desenvolvimento: renderiza lança, besta e mago (perfil e 3/4) em PNG.
## Uso: godot --path . res://tools/gear_shot.tscn --resolution 1500x720 -- <arquivo.png>

const SPACING := 2.4


func _ready() -> void:
	var out := "user://gear.png"
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
	cam.size = 7.0
	cam.position = Vector3(3.6, 2.6, 12.0)
	add_child(cam)
	cam.current = true

	var player_scene: PackedScene = load("res://player/player.tscn")
	var mage_scene: PackedScene = load("res://summon/mage.tscn")
	for row in 2:
		var y := 3.2 if row == 0 else 0.0
		for i in 4:
			var scene := mage_scene if i == 3 else player_scene
			var node: Node = scene.instantiate()
			var rig: HumanoidRig = node.get_node("Visual/Rig")
			node.get_node("Visual").remove_child(rig)
			rig.owner = null
			node.free()
			rig.position = Vector3(i * SPACING, y, 0)
			rig.rotation_degrees.y = -35.0 if row == 0 else 90.0
			add_child(rig)
			match i:
				0:
					rig.set_weapon(HumanoidRig.Weapon.SPEAR)
					rig.set_attack("sp_thrust1", 0.16, 0.14, 0.34, 0.3 if row == 1 else 0.0, true)
				1:
					rig.set_weapon(HumanoidRig.Weapon.SWORD)
					rig.set_offhand(HumanoidRig.Offhand.CROSSBOW)
					rig.set_aim(true)
					rig.set_motion(0.0, true, 0.0)
				2:
					rig.set_weapon(HumanoidRig.Weapon.SPEAR)
					rig.set_offhand(HumanoidRig.Offhand.CROSSBOW)
					rig.set_attack("sp_heavy", 0.3, 0.14, 0.5, 0.36 if row == 1 else 0.0, true)
				3:
					rig.set_attack("priest_cast", 0.35, 0.1, 0.25, 0.4 if row == 1 else 0.0)
			rig.snap()
	for _f in 4:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out)
	print("saved ", out)
	get_tree().quit()
