class_name TeamOverlay
extends CanvasLayer
## Shared screen info drawn over both halves: team money, items, messages, boss bar.

var game  # Game

var _root: Control
var _money_label: Label
var _items_row: HBoxContainer
var _goal_label: Label
var _toasts: VBoxContainer
var _boss_box: VBoxContainer
var _boss_label: Label
var _boss_bar: ProgressBar
var _boss: Enemy
var _fade: ColorRect
var _intro: VBoxContainer
var _shown_money := 0.0


func _ready() -> void:
	layer = 5
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UIUtil.theme()
	add_child(_root)

	# Dark line between the two halves
	var divider := ColorRect.new()
	divider.color = Color(0, 0, 0)
	divider.anchor_left = 0.5
	divider.anchor_right = 0.5
	divider.anchor_bottom = 1.0
	divider.offset_left = -3
	divider.offset_right = 3
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(divider)

	var top := VBoxContainer.new()
	top.anchor_left = 0.5
	top.anchor_right = 0.5
	top.offset_left = -260
	top.offset_right = 260
	top.offset_top = 10
	top.alignment = BoxContainer.ALIGNMENT_BEGIN
	top.add_theme_constant_override("separation", 6)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(top)

	var money_panel := PanelContainer.new()
	var money_style := UIUtil.panel_style(Color(0.06, 0.03, 0.03, 0.85), Color(0.6, 0.45, 0.15))
	money_style.set_content_margin_all(8)
	money_style.content_margin_left = 16
	money_style.content_margin_right = 16
	money_panel.add_theme_stylebox_override("panel", money_style)
	money_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	top.add_child(money_panel)
	var money_row := HBoxContainer.new()
	money_row.add_theme_constant_override("separation", 10)
	money_panel.add_child(money_row)
	money_row.add_child(_CoinIcon.new())
	_money_label = UIUtil.label("0", 30, UIUtil.GOLD)
	money_row.add_child(_money_label)
	var sep := VSeparator.new()
	money_row.add_child(sep)
	_items_row = HBoxContainer.new()
	_items_row.add_theme_constant_override("separation", 14)
	money_row.add_child(_items_row)

	_goal_label = UIUtil.label("", 20, Color(1, 0.88, 0.75))
	_goal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(_goal_label)

	_boss_box = VBoxContainer.new()
	_boss_box.add_theme_constant_override("separation", 2)
	top.add_child(_boss_box)
	_boss_label = UIUtil.label("", 26, Color(1, 0.4, 0.3))
	_boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_box.add_child(_boss_label)
	_boss_bar = UIUtil.bar(Color(0.85, 0.12, 0.1))
	_boss_bar.custom_minimum_size = Vector2(520, 24)
	_boss_box.add_child(_boss_bar)
	_boss_box.visible = false

	_toasts = VBoxContainer.new()
	_toasts.anchor_left = 0.5
	_toasts.anchor_right = 0.5
	_toasts.anchor_top = 0.24
	_toasts.anchor_bottom = 0.24
	_toasts.offset_left = -400
	_toasts.offset_right = 400
	_toasts.add_theme_constant_override("separation", 4)
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_toasts)

	_intro = VBoxContainer.new()
	_intro.set_anchors_preset(Control.PRESET_CENTER)
	_intro.anchor_left = 0.0
	_intro.anchor_right = 1.0
	_intro.anchor_top = 0.42
	_intro.anchor_bottom = 0.42
	_intro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_intro)

	_fade = ColorRect.new()
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.color = Color(0, 0, 0, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_fade)


func setup(g) -> void:
	game = g
	_shown_money = GameState.money
	_goal_label.text = g.level_data.goal_text if g.level_data else ""
	refresh_items()


func refresh_items() -> void:
	for child in _items_row.get_children():
		child.queue_free()
	if game == null or game.level_data == null:
		return
	for id in game.level_data.required_items:
		var have: bool = game.has_item(id)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var icon := _ItemIcon.new()
		icon.item_id = id
		icon.have = have
		row.add_child(icon)
		var text := UIUtil.label(game.item_name(id), 22, UIUtil.GOLD if have else Color(0.55, 0.5, 0.5))
		row.add_child(text)
		_items_row.add_child(row)


func toast(text: String, color := Color(1, 0.95, 0.85)) -> void:
	var l := UIUtil.label(text, 32, color, 10)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toasts.add_child(l)
	while _toasts.get_child_count() > 4:
		var old := _toasts.get_child(0)
		_toasts.remove_child(old)
		old.queue_free()
	var tw := l.create_tween()
	l.modulate.a = 0.0
	tw.tween_property(l, "modulate:a", 1.0, 0.2)
	tw.tween_interval(2.8)
	tw.tween_property(l, "modulate:a", 0.0, 0.5)
	tw.tween_callback(l.queue_free)


func show_intro(title: String, subtitle: String) -> void:
	var big := UIUtil.label(title, 72, UIUtil.GOLD, 14)
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_intro.add_child(big)
	var small := UIUtil.label(subtitle, 40, Color(1, 0.8, 0.65), 12)
	small.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_intro.add_child(small)
	var tw := _intro.create_tween()
	tw.tween_interval(3.0)
	tw.tween_property(_intro, "modulate:a", 0.0, 1.0)
	tw.tween_callback(_clear_intro)


func _clear_intro() -> void:
	for c in _intro.get_children():
		c.queue_free()
	_intro.modulate.a = 1.0


func show_boss(enemy: Enemy) -> void:
	_boss = enemy
	_boss_label.text = enemy.display_name.to_upper()
	_boss_box.visible = true


## Fades the whole screen to black (1.0) or back (0.0). Use with await.
func fade_to(alpha: float, time: float) -> void:
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", alpha, time)
	await tw.finished


func _process(delta: float) -> void:
	# Money counts up smoothly.
	_shown_money = move_toward(_shown_money, GameState.money, maxf(200.0, absf(GameState.money - _shown_money) * 4.0) * delta)
	_money_label.text = str(int(round(_shown_money)))
	if _boss_box.visible:
		if _boss == null or not is_instance_valid(_boss) or _boss.dead:
			_boss_box.visible = false
			_boss = null
		else:
			_boss_bar.value = _boss.health / _boss.max_health


class _CoinIcon extends Control:
	func _ready() -> void:
		custom_minimum_size = Vector2(30, 30)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER

	func _draw() -> void:
		var c := size * 0.5
		draw_circle(c, 14.0, Color(0.75, 0.5, 0.1))
		draw_circle(c, 11.0, UIUtil.GOLD)
		draw_arc(c, 7.0, 0.0, TAU, 20, Color(0.75, 0.5, 0.1), 2.0, true)


class _ItemIcon extends Control:
	var item_id := "key"
	var have := false

	func _ready() -> void:
		custom_minimum_size = Vector2(28, 28)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER

	func _draw() -> void:
		var col := UIUtil.GOLD if have else Color(0.4, 0.37, 0.37)
		var c := size * 0.5
		if item_id == "key":
			draw_arc(c + Vector2(-6, 0), 6.0, 0.0, TAU, 16, col, 3.0, true)
			draw_line(c + Vector2(0, 0), c + Vector2(13, 0), col, 3.0)
			draw_line(c + Vector2(9, 0), c + Vector2(9, 6), col, 3.0)
			draw_line(c + Vector2(13, 0), c + Vector2(13, 5), col, 3.0)
		else:
			var pts := PackedVector2Array([c + Vector2(0, -12), c + Vector2(10, 0), c + Vector2(0, 12), c + Vector2(-10, 0)])
			draw_colored_polygon(pts, col.darkened(0.3))
			pts.append(pts[0])
			draw_polyline(pts, col, 2.0, true)
		if have:
			draw_circle(c + Vector2(10, 10), 5.0, Color(0.3, 0.9, 0.3))
