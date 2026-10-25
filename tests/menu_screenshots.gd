extends Node
## Screenshots of the menus. Run with:
##   Godot --path . res://tests/menu_screenshots.tscn -- <output folder>

var out_dir := "user://screenshots"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	GameState.save_enabled = false
	GameState.reset_progress()
	var menu: Control = (load("res://scenes/main_menu.tscn") as PackedScene).instantiate()
	add_child(menu)
	await _wait(0.5)
	await _shot("20_menu")
	menu._join(0)
	menu._join(1)
	await _wait(0.8)
	await _shot("21_menu_joined")
	menu.queue_free()
	var done: CanvasLayer = (load("res://scenes/ui/level_complete.tscn") as PackedScene).instantiate()
	add_child(done)
	GameState.money = 2350
	done.open(1, 2350, {"fire": GameState.spell_data("fire"), "ice": GameState.spell_data("ice")})
	await _wait(1.2)
	await _shot("22_level_complete")
	done.queue_free()
	var shop: Control = (load("res://scenes/ui/shop.tscn") as PackedScene).instantiate()
	add_child(shop)
	await _wait(0.4)
	shop._on_buy("fire", "spell_strong")
	await _wait(0.2)
	await _shot("23_shop")
	get_tree().quit()


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
	print("saved ", name)
