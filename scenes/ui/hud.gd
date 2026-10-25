class_name PlayerHUD
extends CanvasLayer
## One player's half of the screen: health, magic buttons, prompts, riddles.

@export var player_index := 0

var wizard: Wizard
var game  # Game

var _root: Control
var _name_label: Label
var _health_bar: ProgressBar
var _slots: SpellSlots
var _prompt_row: HBoxContainer
var _prompt_label: Label
var _center_label: Label
var _team_label: Label
var _message_left := 0.0
var _hurt: ColorRect
var _hurt_alpha := 0.0
var _help: VBoxContainer
var _help_time := 30.0

var _riddle_panel: PanelContainer
var _riddle_question: Label
var _riddle_answers: Array[Label] = []
var _riddle_feedback: Label
var _riddle_stone  # RiddleStone
var _riddle := {}
var _riddle_wait := 0.0
var _riddle_state := ""


func _ready() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UIUtil.theme()
	add_child(_root)

	_hurt = ColorRect.new()
	_hurt.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hurt.color = Color(0.9, 0.05, 0.0, 0.0)
	_hurt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_hurt)

	# Health, top left
	# Player 2's health sits on the right edge so the middle stays free for team info.
	var right_side := player_index == 1
	var top := VBoxContainer.new()
	top.add_theme_constant_override("separation", 4)
	top.anchor_left = 1.0 if right_side else 0.0
	top.anchor_right = top.anchor_left
	top.offset_left = -324.0 if right_side else 24.0
	top.offset_right = -24.0 if right_side else 324.0
	top.offset_top = 18
	_root.add_child(top)
	_name_label = UIUtil.label("Wizard", 26)
	if right_side:
		_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top.add_child(_name_label)
	_health_bar = UIUtil.bar(Color(0.9, 0.2, 0.2))
	_health_bar.custom_minimum_size = Vector2(300, 26)
	top.add_child(_health_bar)

	# Magic buttons, bottom right
	_slots = SpellSlots.new()
	_root.add_child(_slots)
	_slots.anchor_left = 1.0
	_slots.anchor_top = 1.0
	_slots.anchor_right = 1.0
	_slots.anchor_bottom = 1.0
	_slots.offset_left = -SpellSlots.STEP * 4 - 16
	_slots.offset_top = -134
	_slots.offset_right = -16
	_slots.offset_bottom = -14

	# Interact prompt, bottom middle
	_prompt_row = HBoxContainer.new()
	_prompt_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_prompt_row.add_theme_constant_override("separation", 10)
	_prompt_row.anchor_left = 0.0
	_prompt_row.anchor_right = 1.0
	_prompt_row.anchor_top = 0.68
	_prompt_row.anchor_bottom = 0.68
	_root.add_child(_prompt_row)
	_prompt_row.add_child(ButtonIcon.make("square", player_index, "interact"))
	_prompt_label = UIUtil.label("", 28)
	_prompt_row.add_child(_prompt_label)
	_prompt_row.visible = false

	# Big message in the middle (falling, reviving, lava)
	_center_label = UIUtil.label("", 40, Color(1, 0.9, 0.8), 10)
	_center_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_center_label.anchor_left = 0.0
	_center_label.anchor_right = 1.0
	_center_label.anchor_top = 0.38
	_center_label.anchor_bottom = 0.38
	_root.add_child(_center_label)

	# Teammate status, under the health bar
	_team_label = UIUtil.label("", 22, Color(1, 0.75, 0.6))
	_team_label.anchor_left = top.anchor_left
	_team_label.anchor_right = top.anchor_right
	_team_label.offset_left = -500.0 if right_side else 24.0
	_team_label.offset_right = -24.0 if right_side else 500.0
	_team_label.offset_top = 96
	_root.add_child(_team_label)
	if right_side:
		_team_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	_build_riddle_panel()


func setup(w: Wizard, g) -> void:
	wizard = w
	game = g
	_slots.wizard = w
	_name_label.text = w.display_name()
	_name_label.add_theme_color_override("font_color", w.element_color())
	(_health_bar.get_theme_stylebox("fill") as StyleBoxFlat).bg_color = w.element_color()
	_build_help()


func _build_help() -> void:
	_help = VBoxContainer.new()
	_help.add_theme_constant_override("separation", 4)
	_help.anchor_top = 1.0
	_help.anchor_bottom = 1.0
	_help.offset_left = 20
	_help.offset_top = -300
	_root.add_child(_help)
	var p := player_index
	_help.add_child(UIUtil.hint_row("lstick", p, "", "Move", 20, PlayerInput.move_keys_label(p)))
	_help.add_child(UIUtil.hint_row("rstick", p, "", "Camera", 20, PlayerInput.camera_keys_label(p)))
	_help.add_child(UIUtil.hint_row("cross", p, "jump", "Jump", 20))
	_help.add_child(UIUtil.hint_row("r2", p, "spell_strong", "Strong spell", 20))
	_help.add_child(UIUtil.hint_row("r1", p, "spell_weak", "Fast spell", 20))
	_help.add_child(UIUtil.hint_row("l2", p, "shield_strong", "Big shield (hold)", 20))
	_help.add_child(UIUtil.hint_row("l1", p, "shield_weak", "Quick shield", 20))


func set_prompt(text: String) -> void:
	if _riddle_stone:
		text = ""
	_prompt_row.visible = text != ""
	_prompt_label.text = text


func show_message(text: String, time: float) -> void:
	_center_label.text = text
	_message_left = time


func flash_hurt() -> void:
	_hurt_alpha = 0.35


func _process(delta: float) -> void:
	if wizard == null:
		return
	_health_bar.value = wizard.health / wizard.max_health
	_hurt_alpha = maxf(0.0, _hurt_alpha - delta * 1.2)
	_hurt.color.a = _hurt_alpha
	if _help and _help_time > 0.0:
		_help_time -= delta
		_help.modulate.a = clampf(_help_time / 3.0, 0.0, 1.0)
		if _help_time <= 0.0:
			_help.visible = false
	if wizard.is_down:
		_center_label.text = "You fell!\nBack in %d..." % ceili(wizard.revive_left)
		_prompt_row.visible = false
	elif _message_left > 0.0:
		_message_left -= delta
		if _message_left <= 0.0:
			_center_label.text = ""
	else:
		_center_label.text = ""
	_update_team_label()
	_update_riddle(delta)


func _update_team_label() -> void:
	var text := ""
	if game:
		for w in game.wizards:
			if w != wizard and w.is_down:
				text = "%s is down! Back in %d" % [w.display_name(), ceili(w.revive_left)]
	_team_label.text = text


# --- Riddles -----------------------------------------------------------------

func _build_riddle_panel() -> void:
	_riddle_panel = PanelContainer.new()
	_riddle_panel.anchor_left = 0.08
	_riddle_panel.anchor_right = 0.92
	_riddle_panel.anchor_top = 0.2
	_riddle_panel.anchor_bottom = 0.2
	_riddle_panel.add_theme_stylebox_override("panel", UIUtil.panel_style(Color(0.08, 0.04, 0.12, 0.94), Color(0.7, 0.45, 1.0)))
	_root.add_child(_riddle_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	_riddle_panel.add_child(box)
	var title := UIUtil.label("RIDDLE STONE", 22, Color(0.85, 0.65, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	_riddle_question = UIUtil.label("", 30)
	_riddle_question.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_riddle_question.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_riddle_question.custom_minimum_size = Vector2(400, 0)
	box.add_child(_riddle_question)
	for i in 3:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var kind: String = ["dpad_left", "dpad_up", "dpad_right"][i]
		row.add_child(ButtonIcon.make(kind, player_index, "answer_%d" % (i + 1)))
		var answer := UIUtil.label("", 28, Color(1, 0.92, 0.75))
		row.add_child(answer)
		_riddle_answers.append(answer)
		box.add_child(row)
	_riddle_feedback = UIUtil.label("", 28, UIUtil.GOLD)
	_riddle_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_riddle_feedback)
	var close_row := HBoxContainer.new()
	close_row.alignment = BoxContainer.ALIGNMENT_CENTER
	close_row.add_theme_constant_override("separation", 8)
	close_row.add_child(ButtonIcon.make("circle", player_index, "back"))
	close_row.add_child(UIUtil.label("Close", 20))
	box.add_child(close_row)
	_riddle_panel.visible = false


func open_riddle(stone) -> void:
	_riddle_stone = stone
	_riddle_wait = 0.3
	_show_new_riddle()
	_riddle_panel.visible = true
	set_prompt("")


func _show_new_riddle() -> void:
	_riddle = _riddle_stone.next_riddle()
	_riddle_state = "ask"
	_riddle_question.text = str(_riddle.get("question", ""))
	var answers: Array = _riddle.get("answers", [])
	for i in 3:
		_riddle_answers[i].text = str(answers[i]) if i < answers.size() else ""
		_riddle_answers[i].add_theme_color_override("font_color", Color(1, 0.92, 0.75))
	_riddle_feedback.text = "Pick an answer!"
	_riddle_feedback.add_theme_color_override("font_color", Color(0.85, 0.75, 1.0))


func close_riddle() -> void:
	_riddle_stone = null
	_riddle_panel.visible = false
	if wizard:
		wizard.controls_locked = false


func _update_riddle(delta: float) -> void:
	if _riddle_stone == null:
		return
	if wizard.is_down:
		close_riddle()
		return
	_riddle_wait -= delta
	if _riddle_wait > 0.0:
		return
	match _riddle_state:
		"right":
			close_riddle()
			return
		"wrong":
			_show_new_riddle()
			return
	var p := player_index
	if PlayerInput.just_pressed(p, "back") or PlayerInput.just_pressed(p, "interact"):
		close_riddle()
		return
	var choice := -1
	for i in 3:
		if PlayerInput.just_pressed(p, "answer_%d" % (i + 1)):
			choice = i
	if PlayerInput.just_pressed(p, "move_left"):
		choice = 0
	elif PlayerInput.just_pressed(p, "move_forward"):
		choice = 1
	elif PlayerInput.just_pressed(p, "move_right"):
		choice = 2
	if choice < 0:
		return
	if choice == int(_riddle.get("correct", -1)):
		_riddle_answers[choice].add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
		_riddle_feedback.text = "Correct! Well done!"
		_riddle_feedback.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
		_riddle_state = "right"
		_riddle_wait = 1.5
		_riddle_stone.solve()
	else:
		_riddle_answers[choice].add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
		_riddle_feedback.text = "Not quite! Here is another one..."
		_riddle_feedback.add_theme_color_override("font_color", Color(1.0, 0.5, 0.4))
		_riddle_state = "wrong"
		_riddle_wait = 1.8
