extends CanvasLayer
## Shown when both wizards go through the exit portal. Shows the new magic.

var _box: VBoxContainer
var _button: Button
var _accepts_input := false


func _ready() -> void:
	layer = 15
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = UIUtil.theme()
	add_child(root)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.03, 0.0, 0.02, 0.85)
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 18)
	center.add_child(_box)
	visible = false


func open(level_number: int, earned: int, unlocked: Dictionary, secrets := Vector2i.ZERO) -> void:
	for c in _box.get_children():
		c.queue_free()
	var title := UIUtil.label("LEVEL %d COMPLETE!" % level_number, 72, UIUtil.GOLD, 14)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(title)
	var money := UIUtil.label("Team money: %d   (+%d this level)" % [GameState.money, earned], 30, UIUtil.GOLD)
	money.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(money)
	if secrets.y > 0:
		var found := UIUtil.label("Secrets found: %d of %d" % [secrets.x, secrets.y], 26,
			UIUtil.GOLD if secrets.x == secrets.y else Color(1, 0.85, 0.7))
		found.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_box.add_child(found)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 30)
	_box.add_child(row)
	for element in GameState.ELEMENTS:
		row.add_child(_magic_card(element, unlocked.get(element)))
	_button = UIUtil.button("Go to the Magic Shop", 32)
	_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_button.pressed.connect(_on_shop)
	_box.add_child(_button)
	var hint := HBoxContainer.new()
	hint.alignment = BoxContainer.ALIGNMENT_CENTER
	hint.add_child(UIUtil.hint_row("cross", -1, "", "Continue", 22))
	_box.add_child(hint)
	visible = true
	_box.modulate.a = 0.0
	create_tween().tween_property(_box, "modulate:a", 1.0, 0.6)
	# Short wait so a Cross press meant as a jump doesn't skip this screen.
	await get_tree().create_timer(1.0).timeout
	_accepts_input = true
	_button.grab_focus()


func _process(_delta: float) -> void:
	if visible and _accepts_input:
		UIUtil.ensure_focus(_button)


func _magic_card(element: String, data: SpellData) -> Control:
	var color := UIUtil.element_color(element)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIUtil.panel_style(Color(0.08, 0.04, 0.05, 0.95), color))
	panel.custom_minimum_size = Vector2(420, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	box.add_child(UIUtil.label(UIUtil.wizard_name(element), 30, color))
	if data == null:
		box.add_child(UIUtil.label("More magic coming soon!", 24))
		return panel
	box.add_child(UIUtil.label("NEW MAGIC: %s" % data.set_name, 26, UIUtil.GOLD))
	var names := [["r2", data.strong_name], ["r1", data.weak_name], ["l2", data.shield_strong_name], ["l1", data.shield_weak_name]]
	for pair in names:
		box.add_child(UIUtil.hint_row(pair[0], -1, "", pair[1], 24))
	return panel


func _on_shop() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/shop.tscn")
