class_name SpellSlots
extends Control
## The four magic buttons in the corner of each player's screen, with cooldowns.

const ORDER := ["shield_weak", "shield_strong", "spell_weak", "spell_strong"]
const RADIUS := 30.0
const STEP := 88.0

var wizard: Wizard


func _ready() -> void:
	custom_minimum_size = Vector2(STEP * 4, 120)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if wizard == null or wizard.spell == null:
		return
	var font := get_theme_default_font()
	var color := wizard.element_color()
	for i in ORDER.size():
		var slot: String = ORDER[i]
		var c := Vector2(STEP * (i + 0.5), 58)
		var cd := wizard.cooldown_fraction(slot)
		var active := wizard.shield_active(slot)
		var ready := cd <= 0.0
		draw_circle(c, RADIUS, Color(0.05, 0.03, 0.04, 0.85))
		_draw_symbol(slot, c, color if ready or active else color.darkened(0.5))
		if cd > 0.0 and not active:
			_draw_pie(c, RADIUS - 2.0, cd, Color(0, 0, 0, 0.6))
		var ring := color if ready else Color(0.45, 0.42, 0.42)
		draw_arc(c, RADIUS, 0.0, TAU, 40, ring, 6.0 if active else 3.0, true)
		if active:
			draw_arc(c, RADIUS + 6.0, 0.0, TAU, 40, Color(color, 0.5), 3.0, true)
		# Button name above, spell name below.
		var button_text := _button_text(slot)
		_centered(font, button_text, c + Vector2(0, -RADIUS - 8), 18, Color(1, 1, 1))
		_spell_name(font, wizard.spell.slot_name(slot), c + Vector2(0, RADIUS + 19))


## Long names like "Snowflake Guard" go on two lines.
func _spell_name(font: Font, text: String, pos: Vector2) -> void:
	var color := Color(1, 0.92, 0.82)
	var too_wide := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x > STEP - 8.0
	var space := text.rfind(" ")
	if too_wide and space > 0:
		_centered(font, text.substr(0, space), pos, 14, color)
		_centered(font, text.substr(space + 1), pos + Vector2(0, 15), 14, color)
	else:
		_centered(font, text, pos, 14, color)


func _button_text(slot: String) -> String:
	if PlayerInput.has_joypad(wizard.player_index):
		return (PlayerInput.PAD_ICONS[slot] as String).to_upper()
	return PlayerInput.key_label(wizard.player_index, slot)


func _draw_symbol(slot: String, c: Vector2, color: Color) -> void:
	match slot:
		"spell_strong":
			draw_circle(c, 13.0, color)
			draw_circle(c + Vector2(-4, -4), 4.0, Color(1, 1, 1, 0.6))
		"spell_weak":
			for k in 3:
				draw_circle(c + Vector2(-11 + k * 11, 4 - k * 4), 4.5, color)
		"shield_strong":
			draw_arc(c + Vector2(0, 6), 16.0, PI, TAU, 24, color, 6.0, true)
			draw_line(c + Vector2(-19, 6), c + Vector2(19, 6), color, 3.0, true)
		"shield_weak":
			draw_arc(c + Vector2(0, 6), 13.0, PI, TAU, 24, color, 2.5, true)


func _draw_pie(c: Vector2, r: float, fraction: float, color: Color) -> void:
	var points := PackedVector2Array([c])
	var steps := maxi(3, int(32 * fraction))
	for k in steps + 1:
		var a := -PI * 0.5 + TAU * fraction * float(k) / float(steps)
		points.append(c + Vector2(cos(a), sin(a)) * r)
	draw_colored_polygon(points, color)


func _centered(font: Font, text: String, pos: Vector2, font_size: int, color: Color) -> void:
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var p := Vector2(pos.x - w * 0.5, pos.y)
	draw_string_outline(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 5, Color(0, 0, 0, 0.9))
	draw_string(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
