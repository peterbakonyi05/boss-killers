extends CanvasLayer
## Options button (Esc / P on keyboard) pauses the game for both players.

var game  # Game

var _panel: Control
var _first_button: Button


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = UIUtil.theme()
	add_child(root)
	_panel = root
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.6)
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	center.add_child(box)
	var title := UIUtil.label("PAUSED", 64, UIUtil.GOLD, 12)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	_first_button = UIUtil.button("Keep playing")
	_first_button.pressed.connect(close)
	box.add_child(_first_button)
	var restart := UIUtil.button("Back to checkpoint")
	restart.pressed.connect(_on_restart)
	box.add_child(restart)
	var quit := UIUtil.button("Quit to title")
	quit.pressed.connect(_on_quit)
	box.add_child(quit)
	var hint := UIUtil.label("Use the D-pad and Cross to pick", 20, Color(0.8, 0.75, 0.7))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)
	visible = false


func _process(_delta: float) -> void:
	if game and game.finished:
		return
	for p in PlayerInput.PLAYER_COUNT:
		if PlayerInput.just_pressed(p, "pause"):
			if visible:
				close()
			else:
				open()
			return
		if visible and PlayerInput.just_pressed(p, "back"):
			close()
			return


func open() -> void:
	visible = true
	get_tree().paused = true
	_first_button.grab_focus.call_deferred()


func close() -> void:
	visible = false
	get_tree().paused = false


func _on_restart() -> void:
	close()
	if game:
		game.back_to_checkpoint()


func _on_quit() -> void:
	close()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
