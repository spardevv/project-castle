extends Node
## Detecta o dispositivo em uso (teclado/mouse, Xbox, PlayStation, genérico) e traduz
## cada ação do Input Map para o nome do botão correspondente. Autoload InputGlyphs.

signal device_changed(device: String)

const KEYBOARD := "keyboard"
const XBOX := "xbox"
const PLAYSTATION := "playstation"
const GENERIC := "generic" # usa o layout Xbox (SDL), que é o padrão do Godot

const MOUSE_NAMES := {
	MOUSE_BUTTON_LEFT: "Mouse Esq.",
	MOUSE_BUTTON_RIGHT: "Mouse Dir.",
	MOUSE_BUTTON_MIDDLE: "Botão do meio",
}

const JOY_XBOX := {
	JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
	JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB",
	JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3",
	JOY_BUTTON_BACK: "Select", JOY_BUTTON_START: "Start",
}
const JOY_PLAYSTATION := {
	JOY_BUTTON_A: "✕", JOY_BUTTON_B: "○", JOY_BUTTON_X: "□", JOY_BUTTON_Y: "△",
	JOY_BUTTON_LEFT_SHOULDER: "L1", JOY_BUTTON_RIGHT_SHOULDER: "R1",
	JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3",
	JOY_BUTTON_BACK: "Share", JOY_BUTTON_START: "Options",
}

var device := KEYBOARD


func _input(event: InputEvent) -> void:
	var new_device := ""
	if event is InputEventKey or event is InputEventMouseButton:
		new_device = KEYBOARD
	elif event is InputEventMouseMotion and (event as InputEventMouseMotion).relative.length() > 4.0:
		new_device = KEYBOARD
	elif event is InputEventJoypadButton:
		new_device = _joy_type(event.device)
	elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.5:
		new_device = _joy_type(event.device)
	if new_device != "" and new_device != device:
		device = new_device
		device_changed.emit(device)


func is_gamepad() -> bool:
	return device != KEYBOARD


func device_name() -> String:
	match device:
		XBOX:
			return "Controle Xbox"
		PLAYSTATION:
			return "Controle PlayStation"
		GENERIC:
			return "Controle"
	return "Teclado e mouse"


## Nome do botão/tecla da ação para o dispositivo atual.
func label(action: StringName) -> String:
	for ev in InputMap.action_get_events(action):
		if device == KEYBOARD:
			if ev is InputEventKey:
				return OS.get_keycode_string(ev.physical_keycode)
			if ev is InputEventMouseButton:
				return MOUSE_NAMES.get(ev.button_index, "Mouse %d" % ev.button_index)
		else:
			if ev is InputEventJoypadButton:
				return _joy_button_name(ev.button_index)
			if ev is InputEventJoypadMotion:
				return _joy_axis_name(ev.axis)
	return "—"


## Rótulo para movimento e câmera, que usam várias ações/eixos.
func move_label() -> String:
	return "WASD" if device == KEYBOARD else "Analógico esq."


func camera_label() -> String:
	return "Mouse" if device == KEYBOARD else "Analógico dir."


func _joy_type(device_id: int) -> String:
	var joy_name := Input.get_joy_name(device_id).to_lower()
	if "playstation" in joy_name or "ps3" in joy_name or "ps4" in joy_name or "ps5" in joy_name \
			or "dualshock" in joy_name or "dualsense" in joy_name or "sony" in joy_name:
		return PLAYSTATION
	if "xbox" in joy_name or "xinput" in joy_name or "steam" in joy_name:
		return XBOX
	return GENERIC


func _joy_button_name(index: int) -> String:
	var table: Dictionary = JOY_PLAYSTATION if device == PLAYSTATION else JOY_XBOX
	return table.get(index, "Botão %d" % index)


func _joy_axis_name(axis: int) -> String:
	var ps := device == PLAYSTATION
	match axis:
		JOY_AXIS_TRIGGER_LEFT:
			return "L2" if ps else "LT"
		JOY_AXIS_TRIGGER_RIGHT:
			return "R2" if ps else "RT"
		JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y:
			return "Analógico esq."
		JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y:
			return "Analógico dir."
	return "Eixo %d" % axis
