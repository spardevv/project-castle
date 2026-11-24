extends GutTest
## Todo .gd do projeto (fora de addons/) precisa compilar. A carga no editor headless só abre os scripts usados
## pelas cenas carregadas, então erros em tools/ (probes, shots) passariam sem este teste.

const SKIP_DIRS: Array[String] = ["res://addons", "res://.godot"]


func test_all_scripts_compile() -> void:
	var paths: Array[String] = []
	_collect("res://", paths)
	assert_gt(paths.size(), 20, "achou os scripts do projeto")
	var broken: Array[String] = []
	for path in paths:
		var script := load(path) as Script
		if script == null or not script.can_instantiate():
			broken.append(path)
	assert_eq(broken, [] as Array[String], "scripts que não compilam: %s" % ", ".join(broken))


func _collect(dir_path: String, out: Array[String]) -> void:
	if dir_path.trim_suffix("/") in SKIP_DIRS:
		return
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for sub in dir.get_directories():
		_collect(dir_path.path_join(sub), out)
	for f in dir.get_files():
		if f.ends_with(".gd"):
			out.append(dir_path.path_join(f))
