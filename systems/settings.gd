extends Node
## Configurações do jogador (autoload Settings): vídeo, áudio e controles. Salvas em
## user://settings.cfg e aplicadas ao iniciar e a cada mudança (sinal `changed`).

signal changed

const PATH := "user://settings.cfg"

const WINDOW_MODES: Array[String] = ["Janela", "Tela cheia (sem borda)", "Tela cheia exclusiva"]
const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(3840, 2160),
]
const RENDER_SCALES: Array[float] = [0.5, 0.67, 0.75, 0.85, 1.0]
const FPS_LIMITS: Array[int] = [0, 30, 60, 120, 144, 240] # 0 = sem limite
const MSAA_LEVELS: Array[String] = ["Desligado", "2×", "4×", "8×"]

# Vídeo
var window_mode := 0
var resolution := Vector2i(1920, 1080)
var render_scale := 1.0
var vsync := true
var max_fps := 0
var msaa := 1
var show_fps := false
# Áudio (0..1)
var master_volume := 0.8
# Controles
var camera_sensitivity := 1.0 # multiplica mouse e analógico
var invert_y := false
var screen_shake := true
var vibration := true
# Debug (não salvo): desenha hurtboxes (verde), varredura das armas (vermelho) e caixas de golpe (laranja).
var debug_hitboxes := false


func _ready() -> void:
	load_settings()
	apply()


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	window_mode = clampi(int(cfg.get_value("video", "window_mode", window_mode)), 0, WINDOW_MODES.size() - 1)
	resolution = cfg.get_value("video", "resolution", resolution)
	render_scale = clampf(float(cfg.get_value("video", "render_scale", render_scale)), 0.25, 1.0)
	vsync = bool(cfg.get_value("video", "vsync", vsync))
	max_fps = maxi(int(cfg.get_value("video", "max_fps", max_fps)), 0)
	msaa = clampi(int(cfg.get_value("video", "msaa", msaa)), 0, MSAA_LEVELS.size() - 1)
	show_fps = bool(cfg.get_value("video", "show_fps", show_fps))
	master_volume = clampf(float(cfg.get_value("audio", "master_volume", master_volume)), 0.0, 1.0)
	camera_sensitivity = clampf(float(cfg.get_value("controls", "camera_sensitivity", camera_sensitivity)), 0.1, 3.0)
	invert_y = bool(cfg.get_value("controls", "invert_y", invert_y))
	screen_shake = bool(cfg.get_value("controls", "screen_shake", screen_shake))
	vibration = bool(cfg.get_value("controls", "vibration", vibration))


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("video", "window_mode", window_mode)
	cfg.set_value("video", "resolution", resolution)
	cfg.set_value("video", "render_scale", render_scale)
	cfg.set_value("video", "vsync", vsync)
	cfg.set_value("video", "max_fps", max_fps)
	cfg.set_value("video", "msaa", msaa)
	cfg.set_value("video", "show_fps", show_fps)
	cfg.set_value("audio", "master_volume", master_volume)
	cfg.set_value("controls", "camera_sensitivity", camera_sensitivity)
	cfg.set_value("controls", "invert_y", invert_y)
	cfg.set_value("controls", "screen_shake", screen_shake)
	cfg.set_value("controls", "vibration", vibration)
	cfg.save(PATH)


## Aplica tudo, salva e avisa quem depende (câmera, HUD).
func commit() -> void:
	apply()
	save_settings()
	changed.emit()


func apply() -> void:
	var root := get_tree().root
	root.scaling_3d_scale = render_scale
	root.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X, Viewport.MSAA_8X][msaa]
	Engine.max_fps = max_fps
	var db := linear_to_db(master_volume) if master_volume > 0.001 else -80.0
	AudioServer.set_bus_volume_db(0, db)
	AudioServer.set_bus_mute(0, master_volume <= 0.001)
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	match window_mode:
		1:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		2:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		_:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			var screen := DisplayServer.window_get_current_screen()
			var usable := DisplayServer.screen_get_usable_rect(screen)
			var size := Vector2i(mini(resolution.x, usable.size.x), mini(resolution.y, usable.size.y))
			DisplayServer.window_set_size(size)
			DisplayServer.window_set_position(usable.position + (usable.size - size) / 2)
