extends Node
## Creates the input actions for both players at startup.
## Every action is called "p1_<name>" or "p2_<name>", for example "p1_spell_strong".
## Player 1 uses the first controller and player 2 the second one.
## The keyboard always works for both players (handy for testing).

signal devices_changed

const PLAYER_COUNT := 2
const STICK_DEADZONE := 0.25
const TRIGGER_DEADZONE := 0.3

const ACTIONS := [
	"move_left", "move_right", "move_forward", "move_back",
	"cam_left", "cam_right", "cam_up", "cam_down",
	"jump", "interact", "spell_strong", "spell_weak", "shield_strong", "shield_weak",
	"pause", "back", "answer_1", "answer_2", "answer_3",
]

## Keyboard keys for player 1 and player 2.
const KEYS := [
	{
		"move_left": KEY_A, "move_right": KEY_D, "move_forward": KEY_W, "move_back": KEY_S,
		"cam_left": KEY_Q, "cam_right": KEY_Z,
		"jump": KEY_SPACE, "interact": KEY_E,
		"spell_strong": KEY_F, "spell_weak": KEY_G,
		"shield_strong": KEY_R, "shield_weak": KEY_T,
		"pause": KEY_ESCAPE, "back": KEY_BACKSPACE,
		"answer_1": KEY_1, "answer_2": KEY_2, "answer_3": KEY_3,
	},
	{
		"move_left": KEY_LEFT, "move_right": KEY_RIGHT, "move_forward": KEY_UP, "move_back": KEY_DOWN,
		"cam_left": KEY_COMMA, "cam_right": KEY_PERIOD,
		"jump": KEY_SHIFT, "interact": KEY_ENTER,
		"spell_strong": KEY_K, "spell_weak": KEY_L,
		"shield_strong": KEY_I, "shield_weak": KEY_O,
		"pause": KEY_P, "back": KEY_DELETE,
		"answer_1": KEY_8, "answer_2": KEY_9, "answer_3": KEY_0,
	},
]

## PS5 DualSense buttons (Godot uses Xbox names: A = Cross, X = Square, B = Circle).
const PAD_BUTTONS := {
	"jump": JOY_BUTTON_A,
	"interact": JOY_BUTTON_X,
	"spell_weak": JOY_BUTTON_RIGHT_SHOULDER,
	"shield_weak": JOY_BUTTON_LEFT_SHOULDER,
	"pause": JOY_BUTTON_START,
	"back": JOY_BUTTON_B,
	"answer_1": JOY_BUTTON_DPAD_LEFT,
	"answer_2": JOY_BUTTON_DPAD_UP,
	"answer_3": JOY_BUTTON_DPAD_RIGHT,
}

const PAD_AXES := {
	"move_left": [JOY_AXIS_LEFT_X, -1.0],
	"move_right": [JOY_AXIS_LEFT_X, 1.0],
	"move_forward": [JOY_AXIS_LEFT_Y, -1.0],
	"move_back": [JOY_AXIS_LEFT_Y, 1.0],
	"cam_left": [JOY_AXIS_RIGHT_X, -1.0],
	"cam_right": [JOY_AXIS_RIGHT_X, 1.0],
	"cam_up": [JOY_AXIS_RIGHT_Y, -1.0],
	"cam_down": [JOY_AXIS_RIGHT_Y, 1.0],
	"spell_strong": [JOY_AXIS_TRIGGER_RIGHT, 1.0],
	"shield_strong": [JOY_AXIS_TRIGGER_LEFT, 1.0],
}

## Which on-screen controller icon belongs to each action.
const PAD_ICONS := {
	"jump": "cross", "interact": "square", "back": "circle", "pause": "options",
	"spell_strong": "r2", "spell_weak": "r1", "shield_strong": "l2", "shield_weak": "l1",
	"answer_1": "dpad_left", "answer_2": "dpad_up", "answer_3": "dpad_right",
}

## Controller device id for each player, -1 = no controller.
var player_device: Array[int] = [-1, -1]

var _names: Array[Dictionary] = [{}, {}]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for p in PLAYER_COUNT:
		for action_name in ACTIONS:
			_names[p][action_name] = StringName("p%d_%s" % [p + 1, action_name])
	var pads := Input.get_connected_joypads()
	for i in mini(PLAYER_COUNT, pads.size()):
		player_device[i] = pads[i]
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	rebuild()


func action(player: int, action_name: String) -> StringName:
	return _names[player][action_name]


func get_move(player: int) -> Vector2:
	return Input.get_vector(action(player, "move_left"), action(player, "move_right"),
		action(player, "move_forward"), action(player, "move_back"))


func get_look(player: int) -> Vector2:
	return Input.get_vector(action(player, "cam_left"), action(player, "cam_right"),
		action(player, "cam_up"), action(player, "cam_down"))


func pressed(player: int, action_name: String) -> bool:
	return Input.is_action_pressed(action(player, action_name))


func just_pressed(player: int, action_name: String) -> bool:
	return Input.is_action_just_pressed(action(player, action_name))


func has_joypad(player: int) -> bool:
	var dev := player_device[player]
	return dev >= 0 and Input.get_connected_joypads().has(dev)


func player_of_device(device: int) -> int:
	return player_device.find(device)


## Gives a controller to a player. If another player had it, they swap.
func assign_device(player: int, device: int) -> void:
	var other := player_device.find(device)
	if other == player:
		return
	if other >= 0:
		player_device[other] = player_device[player]
	player_device[player] = device
	rebuild()


func rumble(player: int, weak: float, strong: float, duration: float) -> void:
	if has_joypad(player):
		Input.start_joy_vibration(player_device[player], weak, strong, duration)


## Short text for a keyboard key, e.g. "F" or "Space".
func key_label(player: int, action_name: String) -> String:
	if player == 1 and action_name == "jump":
		return "R-Shift"
	var keys: Dictionary = KEYS[player]
	if not keys.has(action_name):
		return ""
	var text := OS.get_keycode_string(keys[action_name])
	match text:
		"Escape":
			return "Esc"
		"Backspace":
			return "Bksp"
		"Comma":
			return ","
		"Period":
			return "."
	return text


func move_keys_label(player: int) -> String:
	return "WASD" if player == 0 else "Arrows"


func camera_keys_label(player: int) -> String:
	return "Q/Z" if player == 0 else ",/."


func rebuild() -> void:
	for p in PLAYER_COUNT:
		var keys: Dictionary = KEYS[p]
		var dev := player_device[p]
		for action_name in ACTIONS:
			var act := action(p, action_name)
			var deadzone := TRIGGER_DEADZONE if action_name in ["spell_strong", "shield_strong"] else STICK_DEADZONE
			if InputMap.has_action(act):
				InputMap.action_erase_events(act)
				InputMap.action_set_deadzone(act, deadzone)
			else:
				InputMap.add_action(act, deadzone)
			if keys.has(action_name):
				var key := InputEventKey.new()
				key.keycode = keys[action_name]
				key.device = -1
				if p == 1 and action_name == "jump":
					key.location = KEY_LOCATION_RIGHT
				InputMap.action_add_event(act, key)
			if dev < 0:
				continue
			if PAD_BUTTONS.has(action_name):
				var button := InputEventJoypadButton.new()
				button.device = dev
				button.button_index = PAD_BUTTONS[action_name]
				InputMap.action_add_event(act, button)
			if PAD_AXES.has(action_name):
				var motion := InputEventJoypadMotion.new()
				motion.device = dev
				motion.axis = PAD_AXES[action_name][0]
				motion.axis_value = PAD_AXES[action_name][1]
				InputMap.action_add_event(act, motion)
	devices_changed.emit()


func _on_joy_connection_changed(device: int, connected: bool) -> void:
	if connected:
		if player_device.has(device):
			rebuild()
			return
		# Fill the first player slot that has no working controller.
		var pads := Input.get_connected_joypads()
		for p in PLAYER_COUNT:
			if player_device[p] < 0 or not pads.has(player_device[p]):
				player_device[p] = device
				break
	else:
		# Keep the slot free so the controller (or a new one) can take it back.
		var p := player_device.find(device)
		if p >= 0:
			player_device[p] = -1
	rebuild()
