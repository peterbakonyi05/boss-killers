class_name ButtonIcon
extends Control
## Draws a PS5 controller button (Cross, Square, R2, ...) on screen.
## When the player has no controller, it shows the keyboard key instead.

## cross, circle, square, triangle, r1, r2, l1, l2, options, lstick, rstick,
## dpad_left, dpad_up, dpad_right
@export var kind := "cross"
## Player 0 or 1. With -1 the controller icon is always shown.
@export var player := -1
## Action name used to look up the keyboard key, e.g. "jump".
@export var action_name := ""
## Fixed keyboard text (used instead of looking up the action).
@export var key_text := ""

const CROSS_COLOR := Color(0.49, 0.67, 1.0)
const CIRCLE_COLOR := Color(1.0, 0.42, 0.45)
const SQUARE_COLOR := Color(0.95, 0.56, 0.85)
const TRIANGLE_COLOR := Color(0.3, 0.85, 0.65)
const BG := Color(0.08, 0.08, 0.1, 0.92)
const EDGE := Color(0.92, 0.92, 0.95)


static func make(icon_kind: String, for_player := -1, action := "", fixed_key := "") -> ButtonIcon:
	var icon := ButtonIcon.new()
	icon.kind = icon_kind
	icon.player = for_player
	icon.action_name = action
	icon.key_text = fixed_key
	return icon


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	PlayerInput.devices_changed.connect(_refresh)
	_refresh()


func _keyboard_text() -> String:
	if player < 0 or PlayerInput.has_joypad(player):
		return ""
	if key_text != "":
		return key_text
	if action_name != "":
		return PlayerInput.key_label(player, action_name)
	return ""


func _refresh() -> void:
	var text := _keyboard_text()
	var h := 34.0
	if text != "":
		var font := get_theme_default_font()
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		custom_minimum_size = Vector2(maxf(h, w + 16.0), h)
	elif kind in ["r1", "r2", "l1", "l2", "options"]:
		custom_minimum_size = Vector2(46, h)
	else:
		custom_minimum_size = Vector2(h, h)
	queue_redraw()


func _draw() -> void:
	var font := get_theme_default_font()
	var text := _keyboard_text()
	var rect := Rect2(Vector2.ZERO, size)
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5 - 1.0
	if text != "":
		_key_cap(rect, text, font)
		return
	match kind:
		"cross":
			_round_button(c, r)
			var d := r * 0.42
			draw_line(c + Vector2(-d, -d), c + Vector2(d, d), CROSS_COLOR, 3.0, true)
			draw_line(c + Vector2(-d, d), c + Vector2(d, -d), CROSS_COLOR, 3.0, true)
		"circle":
			_round_button(c, r)
			draw_arc(c, r * 0.45, 0.0, TAU, 24, CIRCLE_COLOR, 3.0, true)
		"square":
			_round_button(c, r)
			var d := r * 0.4
			draw_rect(Rect2(c - Vector2(d, d), Vector2(d, d) * 2.0), SQUARE_COLOR, false, 3.0)
		"triangle":
			_round_button(c, r)
			var d := r * 0.48
			var pts := PackedVector2Array([c + Vector2(0, -d), c + Vector2(d, d * 0.7), c + Vector2(-d, d * 0.7), c + Vector2(0, -d)])
			draw_polyline(pts, TRIANGLE_COLOR, 3.0, true)
		"r1", "r2", "l1", "l2", "options":
			var t: String = kind.to_upper() if kind != "options" else "OPT"
			_key_cap(rect, t, font, kind in ["r2", "l2"])
		"lstick", "rstick":
			_round_button(c, r)
			draw_arc(c, r * 0.62, 0.0, TAU, 24, EDGE.darkened(0.3), 2.0, true)
			_centered_text("L" if kind == "lstick" else "R", c, font, 15, EDGE)
		"dpad_left", "dpad_up", "dpad_right":
			_round_button(c, r)
			var arm := r * 0.32
			var arm_len := r * 0.75
			var dirs := {"dpad_left": Vector2.LEFT, "dpad_up": Vector2.UP, "dpad_right": Vector2.RIGHT}
			for dir in [Vector2.LEFT, Vector2.UP, Vector2.RIGHT, Vector2.DOWN]:
				var active: bool = dir == dirs[kind]
				var col := Color(1, 0.85, 0.35) if active else Color(0.45, 0.45, 0.5)
				var rect_size := Vector2(arm_len, arm * 2.0) if dir.y == 0.0 else Vector2(arm * 2.0, arm_len)
				var center: Vector2 = c + dir * arm_len * 0.5
				draw_rect(Rect2(center - rect_size * 0.5, rect_size), col, true)
		_:
			_round_button(c, r)


func _round_button(c: Vector2, r: float) -> void:
	draw_circle(c, r, BG)
	draw_arc(c, r, 0.0, TAU, 32, EDGE, 2.0, true)


func _key_cap(rect: Rect2, text: String, font: Font, tall := false) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = BG
	box.border_color = EDGE
	box.set_border_width_all(2)
	box.set_corner_radius_all(8 if not tall else 12)
	draw_style_box(box, rect.grow(-1.0))
	_centered_text(text, rect.get_center(), font, 17, EDGE)


func _centered_text(text: String, center: Vector2, font: Font, font_size: int, color: Color) -> void:
	var s := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var pos := Vector2(center.x - s.x * 0.5, center.y + font.get_ascent(font_size) * 0.5 - 2.0)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
