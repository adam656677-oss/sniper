extends Node

# Device-aware control prompts, registered as the InputGlyphs autoload. Tracks
# whether the last meaningful input came from the keyboard and mouse or from a
# gamepad, and names an action's current binding on that device. Bindings are
# read from the InputMap, so a remapped key shows its new key. Gamepad buttons
# use Xbox-style labels as text; production glyph images are a later job.
#
# Prompt text names actions as {action} tokens inside a translated string, for
# example tr("Raise your zero to 300 m with {zero_up}"), and fill() swaps each
# token for the binding. Translators keep the tokens and may move them.

signal device_changed(gamepad: bool)

const STICK_THRESHOLD := 0.4 # stick or trigger travel that counts as using the controller
const MOUSE_THRESHOLD := 4.0 # pixels of mouse travel in one event that count as using the mouse

var gamepad := false
var token := RegEx.create_from_string("\\{(\\w+)\\}")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _input(event: InputEvent) -> void:
	note_event(event)

# Switch device on a deliberate input; releases, drift and tiny mouse jitter do not count.
# Returns true when the device changed.
func note_event(event: InputEvent) -> bool:
	if event is InputEventJoypadButton:
		return event.pressed and set_gamepad(true)
	if event is InputEventJoypadMotion:
		return absf(event.axis_value) >= STICK_THRESHOLD and set_gamepad(true)
	if event is InputEventKey:
		return event.pressed and not event.echo and set_gamepad(false)
	if event is InputEventMouseButton:
		return event.pressed and set_gamepad(false)
	if event is InputEventMouseMotion:
		return event.relative.length() >= MOUSE_THRESHOLD and set_gamepad(false)
	return false

func set_gamepad(value: bool) -> bool:
	if gamepad == value:
		return false
	gamepad = value
	device_changed.emit(gamepad)
	return true

static func is_pad_event(event: InputEvent) -> bool:
	return event is InputEventJoypadButton or event is InputEventJoypadMotion

static func is_keyboard_mouse_event(event: InputEvent) -> bool:
	return event is InputEventKey or event is InputEventMouseButton

func binding(action: String, pad: bool) -> InputEvent:
	if not InputMap.has_action(action):
		return null
	for event in InputMap.action_get_events(action):
		var on_device := is_pad_event(event) if pad else is_keyboard_mouse_event(event)
		if on_device:
			return event
	return null

func has_binding(action: String, pad: bool) -> bool:
	return binding(action, pad) != null

# The binding on the given device, else on the other device, else "Unbound".
func glyph_for(action: String, pad: bool) -> String:
	var event := binding(action, pad)
	if event == null:
		event = binding(action, not pad)
	return tr("Unbound") if event == null else event_text(event)

func glyph(action: String) -> String:
	return glyph_for(action, gamepad)

# Replace {action} tokens with the current device's bindings. Tokens that are
# not actions are left as written.
func fill(text: String) -> String:
	var result := text
	for found in token.search_all(text):
		var action := found.get_string(1)
		if InputMap.has_action(action):
			result = result.replace(found.get_string(), glyph(action))
	return result

# fill(), or "" when any action in the text has no binding on the current device.
func fill_bound(text: String) -> String:
	for found in token.search_all(text):
		var action := found.get_string(1)
		if InputMap.has_action(action) and not has_binding(action, gamepad):
			return ""
	return fill(text)

func event_text(event: InputEvent) -> String:
	if event is InputEventKey:
		return key_text(event.keycode if event.keycode != KEY_NONE else event.physical_keycode)
	if event is InputEventMouseButton:
		return mouse_text(event.button_index)
	if event is InputEventJoypadButton:
		return pad_button_text(event.button_index)
	if event is InputEventJoypadMotion:
		return pad_axis_text(event.axis)
	return tr("Unbound")

# Printable keys show their character ("E", "]"); named keys show the engine's name ("Shift", "F5").
func key_text(code: Key) -> String:
	if code > KEY_SPACE and code < 127:
		return char(code)
	return tr(OS.get_keycode_string(code))

func mouse_text(index: MouseButton) -> String:
	match index:
		MOUSE_BUTTON_LEFT:
			return tr("Left click")
		MOUSE_BUTTON_RIGHT:
			return tr("Right click")
		MOUSE_BUTTON_MIDDLE:
			return tr("Middle click")
		MOUSE_BUTTON_WHEEL_UP:
			return tr("Wheel up")
		MOUSE_BUTTON_WHEEL_DOWN:
			return tr("Wheel down")
		MOUSE_BUTTON_WHEEL_LEFT:
			return tr("Wheel left")
		MOUSE_BUTTON_WHEEL_RIGHT:
			return tr("Wheel right")
	return tr("Mouse button %d") % index

# Xbox-style names. Letters and shoulder, trigger and stick abbreviations are
# the same in every language and stay literal; words go through tr().
func pad_button_text(index: JoyButton) -> String:
	match index:
		JOY_BUTTON_A:
			return "A"
		JOY_BUTTON_B:
			return "B"
		JOY_BUTTON_X:
			return "X"
		JOY_BUTTON_Y:
			return "Y"
		JOY_BUTTON_BACK:
			return tr("View")
		JOY_BUTTON_GUIDE:
			return tr("Guide")
		JOY_BUTTON_START:
			return tr("Start")
		JOY_BUTTON_LEFT_STICK:
			return "L3"
		JOY_BUTTON_RIGHT_STICK:
			return "R3"
		JOY_BUTTON_LEFT_SHOULDER:
			return "LB"
		JOY_BUTTON_RIGHT_SHOULDER:
			return "RB"
		JOY_BUTTON_DPAD_UP:
			return tr("D-pad Up")
		JOY_BUTTON_DPAD_DOWN:
			return tr("D-pad Down")
		JOY_BUTTON_DPAD_LEFT:
			return tr("D-pad Left")
		JOY_BUTTON_DPAD_RIGHT:
			return tr("D-pad Right")
		JOY_BUTTON_MISC1:
			return tr("Share")
		JOY_BUTTON_TOUCHPAD:
			return tr("Touchpad")
	if index >= JOY_BUTTON_PADDLE1 and index <= JOY_BUTTON_PADDLE4:
		return tr("Paddle %d") % (index - JOY_BUTTON_PADDLE1 + 1)
	return tr("Button %d") % index

func pad_axis_text(axis: JoyAxis) -> String:
	match axis:
		JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y:
			return tr("Left stick")
		JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y:
			return tr("Right stick")
		JOY_AXIS_TRIGGER_LEFT:
			return "LT"
		JOY_AXIS_TRIGGER_RIGHT:
			return "RT"
	return tr("Axis %d") % axis
