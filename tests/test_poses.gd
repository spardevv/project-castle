extends GutTest
## Testes básicos das poses do rig (rode com: godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit).


func test_step_length_grows_with_speed() -> void:
	assert_gt(Poses.step_length(1.0), Poses.step_length(0.0))


func test_locomotion_has_all_joints() -> void:
	var pose := Poses.locomotion(0.5, 5.0, true, 0.0, 0.0)
	for j in Poses.JOINTS:
		assert_true(pose.has(j), "falta a junta %s" % j)
