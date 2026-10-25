extends Node
## Headless test: menus work with a controller (D-pad and Cross). Run with:
##   Godot --headless --path . res://tests/menu_test.tscn

var _failures := 0


func _ready() -> void:
	GameState.save_enabled = false
	GameState.reset_progress()
	await _run()
	print("MENU TEST: %s (%d failures)" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		_failures += 1


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## Presses and releases a controller button, like a player would.
func _pad(device: int, button: JoyButton) -> void:
	for pressed in [true, false]:
		var e := InputEventJoypadButton.new()
		e.device = device
		e.button_index = button
		e.pressed = pressed
		Input.parse_input_event(e)
		await _frames(2)


func _run() -> void:
	# Title screen: both players join with Cross, then Cross starts the game.
	var menu: Control = (load("res://scenes/main_menu.tscn") as PackedScene).instantiate()
	add_child(menu)
	await _frames(2)
	PlayerInput.player_device = [0, 1]
	PlayerInput.rebuild()
	await _pad(0, JOY_BUTTON_A)
	await _pad(1, JOY_BUTTON_A)
	_check(GameState.joined[0] and GameState.joined[1], "both players join with Cross")
	await get_tree().create_timer(0.5).timeout
	var play: Button = menu._first_button
	play.pressed.disconnect(menu._on_play)
	var started := [false]
	play.pressed.connect(func() -> void: started[0] = true)
	_check(play.has_focus(), "start button has focus")
	await _pad(0, JOY_BUTTON_A)
	_check(started[0], "Cross presses the start button")
	menu.queue_free()
	await _frames(2)

	# Shop: D-pad moves between upgrades and Cross buys.
	GameState.money = 1000
	var shop: Control = (load("res://scenes/ui/shop.tscn") as PackedScene).instantiate()
	add_child(shop)
	await _frames(4)
	_check(shop._next_button.has_focus(), "next level button has focus in the shop")
	await _pad(0, JOY_BUTTON_DPAD_UP)
	var focused := get_viewport().gui_get_focus_owner()
	_check(focused != null and focused != shop._next_button, "D-pad up moves to an upgrade")
	await _pad(0, JOY_BUTTON_A)
	_check(GameState.money < 1000, "Cross buys the upgrade (money %d)" % GameState.money)
	get_viewport().gui_release_focus()
	await _frames(2)
	_check(shop._next_button.has_focus(), "focus comes back when it gets lost")
	shop.queue_free()
