extends Node
## Takes screenshots of Level 1 in a real window (not headless). Run with:
##   Godot --path . res://tests/screenshots.tscn -- <output folder>

var game: Game
var out_dir := "user://screenshots"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	GameState.save_enabled = false
	GameState.reset_progress()
	game = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(game)
	await _wait(2.0)
	await _shot("01_start")
	var fire := game.wizards[0]
	var ice := game.wizards[1]

	# Spells in the first corridor
	fire.teleport(Vector3(1.5, 0.3, -13))
	ice.teleport(Vector3(-1.5, 0.3, -13))
	await _wait(0.6)
	fire.cast(true)
	ice.cast(true)
	await _wait(0.15)
	fire.cast(false)
	ice.cast(false)
	await _wait(0.15)
	await _shot("02_spells")
	fire._try_shield("shield_strong")
	ice._try_shield("shield_weak")
	await _wait(0.2)
	await _shot("03_shields")
	await _wait(1.5)

	# Lava trench
	fire.teleport(Vector3(1.5, 0.3, -69))
	ice.teleport(Vector3(-1.5, 0.3, -69))
	await _wait(1.0)
	await _shot("04_lava")
	(game.level.get_node("LavaTrench") as LavaTrench).freeze()
	await _wait(0.8)
	await _shot("05_ice_bridge")

	# Arena fight
	fire.teleport(Vector3(0, 0.3, -46))
	await _wait(3.0)
	await _shot("06_arena")
	for i in 6:
		fire._cooldowns["spell_weak"] = 0.0
		fire.cast(false)
		ice._cooldowns["spell_weak"] = 0.0
		ice.cast(false)
		await _wait(0.12)
	await _shot("07_arena_magic")
	game.get_tree().call_group("arenas", "reset")
	await _wait(0.5)

	# Ice door and riddle
	fire.teleport(Vector3(1.5, 0.3, -127))
	ice.teleport(Vector3(-1.5, 0.3, -127))
	ice.camera_rig.set_yaw(0.0)
	await _wait(1.0)
	await _shot("08_ice_door")
	var stone := game.level.get_node("RiddleStone") as RiddleStone
	game.open_riddle(ice, stone)
	await _wait(0.5)
	await _shot("09_riddle")
	ice.hud.close_riddle()

	# Demon knight
	var knight: Enemy = (load("res://scenes/enemies/demon_knight.tscn") as PackedScene).instantiate()
	game.level.add_child(knight)
	knight.global_position = Vector3(0, 0, -150)
	(game.level.get_node("IceDoor") as Node3D).queue_free()
	fire.teleport(Vector3(2, 0.3, -140))
	ice.teleport(Vector3(-2, 0.3, -140))
	await _wait(1.5)
	await _shot("10_knight")

	# Portal
	game.collect_item("key")
	game.collect_item("rune")
	knight.queue_free()
	fire.teleport(Vector3(1.5, 0.3, -180))
	ice.teleport(Vector3(-1.5, 0.3, -180))
	await _wait(1.5)
	await _shot("11_portal")

	fire.take_damage(9999.0)
	await _wait(1.0)
	await _shot("12_downed")
	get_tree().quit()


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(out_dir.path_join(name + ".png"))
	print("saved ", name)
