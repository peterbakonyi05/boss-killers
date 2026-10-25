extends Control
## Title screen. Each player presses Cross (or their jump key) to join.
## The game only starts when both wizards have joined.

var _join_labels: Array[Label] = []
var _join_panels: Array[PanelContainer] = []
var _menu: VBoxContainer
var _first_button: Button
var _time := 0.0
var _title_fire: Label
var _title_ice: Label


func _ready() -> void:
	get_tree().paused = false
	theme = UIUtil.theme()
	GameState.joined = [false, false]
	var bg := TextureRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var g := Gradient.new()
	g.set_color(0, Color(0.25, 0.05, 0.03))
	g.set_color(1, Color(0.01, 0.0, 0.02))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 1.1)
	t.fill_to = Vector2(0.5, 0.0)
	bg.texture = t
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 26)
	center.add_child(box)

	var title := HBoxContainer.new()
	title.alignment = BoxContainer.ALIGNMENT_CENTER
	title.add_theme_constant_override("separation", 28)
	_title_fire = UIUtil.label("BOSS", 130, UIUtil.FIRE_COLOR, 20)
	_title_ice = UIUtil.label("KILLERS", 130, UIUtil.ICE_COLOR, 20)
	title.add_child(_title_fire)
	title.add_child(_title_ice)
	box.add_child(title)
	var sub := UIUtil.label("A fire wizard and an ice wizard against the underworld", 28, Color(1, 0.85, 0.7))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)

	var joins := HBoxContainer.new()
	joins.alignment = BoxContainer.ALIGNMENT_CENTER
	joins.add_theme_constant_override("separation", 40)
	box.add_child(joins)
	for p in 2:
		joins.add_child(_join_panel(p))

	_menu = VBoxContainer.new()
	_menu.add_theme_constant_override("separation", 12)
	_menu.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(_menu)
	var play_text := "Play Level %d" % GameState.level if GameState.has_save() else "Start the adventure!"
	_first_button = UIUtil.button(play_text, 34)
	_first_button.pressed.connect(_on_play)
	_menu.add_child(_first_button)
	if GameState.has_save():
		var new_game := UIUtil.button("New game (start over)", 26)
		new_game.pressed.connect(_on_new_game)
		_menu.add_child(new_game)
	var quit := UIUtil.button("Quit", 26)
	quit.pressed.connect(func() -> void: get_tree().quit())
	_menu.add_child(quit)
	for b in _menu.get_children():
		(b as Control).size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_menu.visible = false

	var tip := UIUtil.label("Tip: pair two PS5 controllers in Bluetooth settings before starting.", 20, Color(0.75, 0.65, 0.6))
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(tip)
	PlayerInput.devices_changed.connect(_refresh)
	_refresh()


func _join_panel(p: int) -> Control:
	var element: String = GameState.ELEMENTS[p]
	var color := UIUtil.element_color(element)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIUtil.panel_style(Color(0.06, 0.03, 0.04, 0.9), color.darkened(0.4)))
	panel.custom_minimum_size = Vector2(440, 170)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var name_label := UIUtil.label("Player %d: %s" % [p + 1, UIUtil.wizard_name(element)], 32, color)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(name_label)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	row.add_child(ButtonIcon.make("cross"))
	var status := UIUtil.label("", 26)
	row.add_child(status)
	box.add_child(row)
	_join_labels.append(status)
	_join_panels.append(panel)
	return panel


func _refresh() -> void:
	for p in 2:
		var element: String = GameState.ELEMENTS[p]
		if GameState.joined[p]:
			_join_labels[p].text = "READY!"
			_join_labels[p].add_theme_color_override("font_color", UIUtil.GOLD)
			_join_panels[p].add_theme_stylebox_override("panel", UIUtil.panel_style(Color(0.12, 0.05, 0.04, 0.95), UIUtil.element_color(element)))
		else:
			var key := "Space" if p == 0 else "Right Shift"
			var pad := "  (controller connected)" if PlayerInput.has_joypad(p) else ""
			_join_labels[p].text = "Press to join  (or %s)%s" % [key, pad]


func _input(event: InputEvent) -> void:
	var pad := event as InputEventJoypadButton
	if pad and pad.pressed and pad.button_index == JOY_BUTTON_A:
		var p := PlayerInput.player_of_device(pad.device)
		if p < 0:
			# A controller that has no player yet takes the first free spot.
			p = GameState.joined.find(false)
			if p < 0:
				return
			PlayerInput.assign_device(p, pad.device)
		if not GameState.joined[p]:
			_join(p)
			get_viewport().set_input_as_handled()
		return
	var key := event as InputEventKey
	if key and key.pressed and not key.echo:
		for p in 2:
			if not GameState.joined[p] and (key.is_action_pressed(PlayerInput.action(p, "jump")) \
					or key.is_action_pressed(PlayerInput.action(p, "interact"))):
				_join(p)
				get_viewport().set_input_as_handled()
				return


func _join(p: int) -> void:
	GameState.joined[p] = true
	_refresh()
	var panel := _join_panels[p]
	panel.pivot_offset = panel.size * 0.5
	var tw := panel.create_tween()
	tw.tween_property(panel, "scale", Vector2(1.08, 1.08), 0.1)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.15)
	if GameState.joined[0] and GameState.joined[1]:
		await get_tree().create_timer(0.35).timeout
		_menu.visible = true
		_first_button.grab_focus()


func _process(delta: float) -> void:
	_time += delta
	_title_fire.add_theme_color_override("font_color", UIUtil.FIRE_COLOR.lerp(Color(1, 0.8, 0.3), 0.5 + 0.5 * sin(_time * 3.0)))
	_title_ice.add_theme_color_override("font_color", UIUtil.ICE_COLOR.lerp(Color(0.85, 0.97, 1.0), 0.5 + 0.5 * sin(_time * 3.0 + 1.5)))


func _on_play() -> void:
	get_tree().change_scene_to_file("res://scenes/game.tscn")


func _on_new_game() -> void:
	GameState.new_game()
	_on_play()
