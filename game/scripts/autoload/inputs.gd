extends Node
## Builds the input map for keyboard/mouse and gamepad, and tracks which device was used last
## so on-screen prompts can show the right glyphs.

signal device_changed(pad: bool)

var using_pad := false

const KEYS := {
	"move_forward": [KEY_W], "move_back": [KEY_S], "move_left": [KEY_A], "move_right": [KEY_D],
	"light": [], "heavy": [], "special": [KEY_Q], "guard": [KEY_CTRL], "dodge": [KEY_SPACE],
	"jump": [KEY_F], "interact": [KEY_E], "item": [KEY_R], "lock_on": [KEY_TAB],
	"act1": [KEY_1], "act2": [KEY_2], "act3": [KEY_3], "act4": [KEY_4],
	"menu": [KEY_ESCAPE], "journal": [KEY_J], "map": [KEY_M],
	"ui_accept": [KEY_ENTER, KEY_SPACE, KEY_E], "ui_cancel": [KEY_ESCAPE, KEY_BACKSPACE],
	"tab_next": [KEY_PAGEDOWN, KEY_X], "tab_prev": [KEY_PAGEUP, KEY_Z],
	"cam_left": [], "cam_right": [], "cam_up": [], "cam_down": [],
}
const MOUSE := {"light": MOUSE_BUTTON_LEFT, "heavy": MOUSE_BUTTON_RIGHT, "lock_on": MOUSE_BUTTON_MIDDLE}
const PAD := {
	"light": JOY_BUTTON_RIGHT_SHOULDER, "guard": JOY_BUTTON_LEFT_SHOULDER, "dodge": JOY_BUTTON_B,
	"jump": JOY_BUTTON_A, "interact": JOY_BUTTON_A, "item": JOY_BUTTON_X, "lock_on": JOY_BUTTON_RIGHT_STICK,
	"act1": JOY_BUTTON_DPAD_UP, "act2": JOY_BUTTON_DPAD_RIGHT, "act3": JOY_BUTTON_DPAD_DOWN, "act4": JOY_BUTTON_DPAD_LEFT,
	"menu": JOY_BUTTON_START, "journal": JOY_BUTTON_BACK, "map": JOY_BUTTON_Y,
	"ui_accept": JOY_BUTTON_A, "ui_cancel": JOY_BUTTON_B, "tab_next": JOY_BUTTON_RIGHT_SHOULDER, "tab_prev": JOY_BUTTON_LEFT_SHOULDER,
}
## Axis bindings: [axis, direction]
const AXES := {
	"move_forward": [JOY_AXIS_LEFT_Y, -1.0], "move_back": [JOY_AXIS_LEFT_Y, 1.0],
	"move_left": [JOY_AXIS_LEFT_X, -1.0], "move_right": [JOY_AXIS_LEFT_X, 1.0],
	"cam_left": [JOY_AXIS_RIGHT_X, -1.0], "cam_right": [JOY_AXIS_RIGHT_X, 1.0],
	"cam_up": [JOY_AXIS_RIGHT_Y, -1.0], "cam_down": [JOY_AXIS_RIGHT_Y, 1.0],
	"heavy": [JOY_AXIS_TRIGGER_RIGHT, 1.0], "special": [JOY_AXIS_TRIGGER_LEFT, 1.0],
}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for action in KEYS:
		if not InputMap.has_action(action): InputMap.add_action(action, 0.25)
		if action.begins_with("ui_"):
			pass
		else:
			InputMap.action_erase_events(action)
		for k in KEYS[action]:
			var e := InputEventKey.new(); e.physical_keycode = k; InputMap.action_add_event(action, e)
		if MOUSE.has(action):
			var mb := InputEventMouseButton.new(); mb.button_index = MOUSE[action]; InputMap.action_add_event(action, mb)
		if PAD.has(action):
			var jb := InputEventJoypadButton.new(); jb.button_index = PAD[action]; InputMap.action_add_event(action, jb)
		if AXES.has(action):
			var ja := InputEventJoypadMotion.new(); ja.axis = AXES[action][0]; ja.axis_value = AXES[action][1]
			InputMap.action_add_event(action, ja)
	InputMap.action_set_deadzone("cam_left", 0.15); InputMap.action_set_deadzone("cam_right", 0.15)
	InputMap.action_set_deadzone("cam_up", 0.15); InputMap.action_set_deadzone("cam_down", 0.15)
	for a in ["move_forward", "move_back", "move_left", "move_right"]: InputMap.action_set_deadzone(a, 0.2)


func _input(event: InputEvent) -> void:
	var pad := event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.4)
	var kb := event is InputEventKey or event is InputEventMouseButton
	if pad and not using_pad:
		using_pad = true; device_changed.emit(true)
	elif kb and using_pad:
		using_pad = false; device_changed.emit(false)


## Button label for prompts.
func glyph(action: String) -> String:
	if using_pad:
		return {"light": "RB", "heavy": "RT", "special": "LT", "guard": "LB", "dodge": "B", "jump": "A", "interact": "A",
			"item": "X", "lock_on": "R3", "act1": "D-Up", "act2": "D-Right", "act3": "D-Down", "act4": "D-Left",
			"menu": "Start", "journal": "Back", "map": "Y", "ui_accept": "A", "ui_cancel": "B", "tab_next": "RB", "tab_prev": "LB"}.get(action, action)
	return {"light": "LMB", "heavy": "RMB", "special": "Q", "guard": "Ctrl", "dodge": "Space", "jump": "F", "interact": "E",
		"item": "R", "lock_on": "Tab", "act1": "1", "act2": "2", "act3": "3", "act4": "4", "menu": "Esc", "journal": "J", "map": "M",
		"ui_accept": "Enter", "ui_cancel": "Esc", "tab_next": "X", "tab_prev": "Z"}.get(action, action)
