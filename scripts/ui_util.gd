class_name UIUtil
## Shared look for menus and labels.

const FIRE_COLOR := Color(1.0, 0.5, 0.15)
const ICE_COLOR := Color(0.4, 0.82, 1.0)
const GOLD := Color(1.0, 0.82, 0.3)

static var _theme: Theme


static func element_color(element: String) -> Color:
	return FIRE_COLOR if element == "fire" else ICE_COLOR


static func wizard_name(element: String) -> String:
	return "Fire Wizard" if element == "fire" else "Ice Wizard"


static func label(text: String, font_size := 24, color := Color.WHITE, outline := 8) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", outline)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func panel_style(bg := Color(0.08, 0.03, 0.05, 0.88), border := Color(0.55, 0.25, 0.18)) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(3)
	s.set_corner_radius_all(14)
	s.set_content_margin_all(18)
	return s


static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font_size = 26
	var normal := panel_style(Color(0.14, 0.06, 0.07, 0.95), Color(0.45, 0.22, 0.16))
	normal.set_content_margin_all(14)
	normal.content_margin_left = 28
	normal.content_margin_right = 28
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.3, 0.12, 0.08, 0.95)
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_color = GOLD
	focus.set_border_width_all(4)
	focus.set_corner_radius_all(14)
	focus.expand_margin_left = 3
	focus.expand_margin_right = 3
	focus.expand_margin_top = 3
	focus.expand_margin_bottom = 3
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(0.1, 0.08, 0.08, 0.8)
	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("pressed", "Button", hover)
	t.set_stylebox("hover_pressed", "Button", hover)
	t.set_stylebox("focus", "Button", focus)
	t.set_stylebox("disabled", "Button", disabled)
	t.set_color("font_color", "Button", Color(1.0, 0.93, 0.82))
	t.set_color("font_hover_color", "Button", Color(1, 1, 1))
	t.set_color("font_focus_color", "Button", Color(1, 1, 1))
	t.set_color("font_pressed_color", "Button", GOLD)
	t.set_color("font_disabled_color", "Button", Color(0.5, 0.45, 0.42))
	t.set_stylebox("panel", "PanelContainer", panel_style())
	t.set_constant("outline_size", "Label", 6)
	t.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.95))
	_theme = t
	return t


static func button(text: String, font_size := 28) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", font_size)
	return b


static func bar(fill: Color, bg := Color(0.05, 0.02, 0.03, 0.85)) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.max_value = 1.0
	b.step = 0.0
	var fg_style := StyleBoxFlat.new()
	fg_style.bg_color = fill
	fg_style.set_corner_radius_all(6)
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = bg
	bg_style.set_corner_radius_all(6)
	bg_style.border_color = Color(0, 0, 0, 0.9)
	bg_style.set_border_width_all(2)
	b.add_theme_stylebox_override("fill", fg_style)
	b.add_theme_stylebox_override("background", bg_style)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


## A row with a button icon and some text, like "[X] Jump".
static func hint_row(icon_kind: String, player: int, action_name: String, text: String,
		font_size := 22, key_text := "") -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(ButtonIcon.make(icon_kind, player, action_name, key_text))
	var l := label(text, font_size)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(l)
	return row
