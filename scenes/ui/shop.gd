extends Control
## Between levels: spend the team's money on stronger spells and shields.

const SLOT_LABELS := {
	"spell_strong": "Strong spell", "spell_weak": "Fast spell",
	"shield_strong": "Big shield", "shield_weak": "Quick shield",
}
const SLOT_ICONS := {"spell_strong": "r2", "spell_weak": "r1", "shield_strong": "l2", "shield_weak": "l1"}

var _money_label: Label
var _message: Label
var _buttons := {}   # "fire/spell_strong" -> Button
var _rank_labels := {}
var _next_button: Button


func _ready() -> void:
	theme = UIUtil.theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := TextureRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.texture = _background()
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	center.add_child(box)
	var title := UIUtil.label("MAGIC SHOP", 72, UIUtil.GOLD, 14)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	_money_label = UIUtil.label("", 34, UIUtil.GOLD)
	_money_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_money_label)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 30)
	columns.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(columns)
	for element in GameState.ELEMENTS:
		columns.add_child(_wizard_column(element))
	_message = UIUtil.label("Each upgrade makes that magic 15% stronger.", 24, Color(1, 0.85, 0.7))
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_message)
	var level_text := "Next level" if GameState.is_level_built(GameState.level) else "Play again (more levels coming soon!)"
	_next_button = UIUtil.button("%s  >" % level_text, 32)
	_next_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_next_button.pressed.connect(_on_next)
	box.add_child(_next_button)
	_refresh()
	GameState.save_game()
	await get_tree().process_frame
	_next_button.grab_focus()


func _background() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(0.18, 0.05, 0.04))
	g.set_color(1, Color(0.02, 0.01, 0.03))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill_from = Vector2(0.5, 0.0)
	t.fill_to = Vector2(0.5, 1.0)
	return t


func _wizard_column(element: String) -> Control:
	var color := UIUtil.element_color(element)
	var data := GameState.spell_data(element)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIUtil.panel_style(Color(0.08, 0.04, 0.05, 0.95), color))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	box.add_child(UIUtil.label("%s  -  %s" % [UIUtil.wizard_name(element), data.set_name], 28, color))
	for slot in GameState.SLOTS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		row.add_child(ButtonIcon.make(SLOT_ICONS[slot]))
		var name_box := VBoxContainer.new()
		name_box.custom_minimum_size = Vector2(250, 0)
		name_box.add_theme_constant_override("separation", 0)
		name_box.add_child(UIUtil.label(data.slot_name(slot), 24))
		var rank_label := UIUtil.label("", 20, UIUtil.GOLD)
		name_box.add_child(rank_label)
		row.add_child(name_box)
		var buy := UIUtil.button("", 22)
		buy.custom_minimum_size = Vector2(190, 0)
		buy.pressed.connect(_on_buy.bind(element, slot))
		row.add_child(buy)
		box.add_child(row)
		_buttons["%s/%s" % [element, slot]] = buy
		_rank_labels["%s/%s" % [element, slot]] = rank_label
	return panel


func _refresh() -> void:
	_money_label.text = "Team money: %d" % GameState.money
	for element in GameState.ELEMENTS:
		for slot in GameState.SLOTS:
			var key := "%s/%s" % [element, slot]
			var rank := GameState.rank(element, slot)
			var max_rank := GameState.balance.shop_max_rank
			var stars := ""
			for i in max_rank:
				stars += "*" if i < rank else "-"
			(_rank_labels[key] as Label).text = "%s %s  rank %d/%d" % [SLOT_LABELS[slot], stars, rank, max_rank]
			var button: Button = _buttons[key]
			if not GameState.can_upgrade(element, slot):
				button.text = "MAX"
			else:
				button.text = "Buy  %d" % GameState.upgrade_price(element, slot)


func _on_buy(element: String, slot: String) -> void:
	if not GameState.can_upgrade(element, slot):
		_message.text = "That one is already as strong as it gets!"
		return
	var price := GameState.upgrade_price(element, slot)
	if GameState.buy_upgrade(element, slot):
		_message.text = "%s got stronger!" % GameState.spell_data(element).slot_name(slot)
	else:
		_message.text = "Not enough money! You need %d more." % (price - GameState.money)
	_refresh()


func _on_next() -> void:
	GameState.save_game()
	get_tree().change_scene_to_file("res://scenes/game.tscn")
