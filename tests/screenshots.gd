extends Node
## Takes screenshots of Level 1 in a real window (not headless). Run with:
##   Godot --always-on-top --path . res://tests/screenshots.tscn -- <output folder>
## Add `level=2` after the folder for the jungle level shots (j01_start ...).
## (--always-on-top: macOS stops drawing hidden windows, which makes the script hang.)

var game: Game
var out_dir := "user://screenshots"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	GameState.save_enabled = false
	GameState.reset_progress()
	if "level=2" in args:
		GameState.level = 2
	game = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(game)
	await _wait(2.0)
	if GameState.level == 2:
		await _jungle_shots()
		get_tree().quit()
		return
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
	fire.teleport(Vector3(1.5, 0.3, -187))
	ice.teleport(Vector3(-1.5, 0.3, -187))
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
	knight.global_position = Vector3(0, 0, -210)
	(game.level.get_node("IceDoor") as Node3D).queue_free()
	fire.teleport(Vector3(2, 0.3, -200))
	ice.teleport(Vector3(-2, 0.3, -200))
	await _wait(1.5)
	await _shot("10_knight")

	# Portal
	game.collect_item("key")
	game.collect_item("rune")
	knight.queue_free()
	fire.teleport(Vector3(1.5, 0.3, -240))
	ice.teleport(Vector3(-1.5, 0.3, -240))
	await _wait(1.5)
	await _shot("11_portal")

	fire.take_damage(9999.0)
	await _wait(1.0)
	await _shot("12_downed")
	fire.revive(true)

	# Close-up of the monsters and wizards side by side
	fire.teleport(Vector3(-1.2, 0.3, -5))
	ice.teleport(Vector3(1.2, 0.3, -5))
	fire.camera_rig.set_yaw(0.0)
	ice.camera_rig.set_yaw(0.0)
	var x := -2.6
	for path in ["imp", "spitter", "brute"]:
		var m: Enemy = (load("res://scenes/enemies/%s.tscn" % path) as PackedScene).instantiate()
		m.aggro_range = 0.0
		game.level.add_child(m)
		m.global_position = Vector3(x, 0, -8.5)
		x += 2.6
	await _wait(1.0)
	await _shot("13_lineup")

	# New areas: ambush tunnel, lava cavern, secret ledge
	game.get_tree().call_group("enemies", "queue_free")
	fire.teleport(Vector3(-1.2, 0.3, -117))
	ice.teleport(Vector3(1.2, 0.3, -139))
	fire.camera_rig.set_yaw(0.0)
	ice.camera_rig.set_yaw(0.0)
	await _wait(1.5)
	await _shot("14_tunnel_and_cavern")
	fire.teleport(Vector3(-1, 0.3, -30))
	fire.camera_rig.set_yaw(PI / 2.0)
	ice.teleport(Vector3(-9, 0.3, -161))
	ice.camera_rig.set_yaw(0.3)
	await _wait(1.5)
	await _shot("15_secrets")

	# Theme dressing: props along the walls, and every prop kind in a row
	fire.teleport(Vector3(-1, 0.3, -24))
	fire.camera_rig.set_yaw(-0.6)
	ice.teleport(Vector3(0, 0.3, -183))
	ice.camera_rig.set_yaw(0.5)
	await _wait(1.5)
	await _shot("16_props")
	var gallery := Node3D.new()
	game.level.add_child(gallery)
	var rng := RandomNumberGenerator.new()
	var theme := LevelTheme.of(game.level)
	for i in Props.KINDS.size():
		var row := i / 8
		var pos := Vector3(-5.6 + (i % 8) * 1.6, 0.0 if Props.KINDS[i] not in ["cage", "chandelier", "cobweb", "chains"] else 3.5, -6.0 - row * 2.5)
		Props.spawn(Props.KINDS[i], gallery, pos, 0.0, rng, theme)
	fire.teleport(Vector3(-2.5, 0.3, -1))
	ice.teleport(Vector3(2.5, 0.3, -1))
	fire.camera_rig.set_yaw(0.0)
	ice.camera_rig.set_yaw(0.0)
	await _wait(1.0)
	await _shot("17_prop_gallery")

	# Monster close-up: every look side by side, facing the cameras
	gallery.queue_free()
	var mx := -4.5
	for path in ["imp", "spitter", "brute", "demon_knight"]:
		var m: Enemy = (load("res://scenes/enemies/%s.tscn" % path) as PackedScene).instantiate()
		m.aggro_range = 0.0
		game.level.add_child(m)
		m.global_position = Vector3(mx, 0, -9)
		m.rotation.y = PI
		mx += 3.0
	fire.teleport(Vector3(-2.0, 0.3, -3))
	ice.teleport(Vector3(2.0, 0.3, -3))
	await _wait(1.0)
	await _shot("18_monster_closeup")

	# Tier 2 magic: meteor falling + twin flames, glacier spear + twin icicles
	fire.spell = load("res://data/spells/fire_2.tres")
	ice.spell = load("res://data/spells/ice_2.tres")
	fire.cast(true)
	ice.cast(true)
	await _wait(0.12)
	fire.cast(false)
	ice.cast(false)
	await _wait(0.1)
	await _shot("19_spells_tier2")
	await _wait(0.6)
	await _shot("20_meteor_landing")
	for slot in Wizard.SLOTS:
		fire._cooldowns[slot] = 0.0
		ice._cooldowns[slot] = 0.0
	fire._try_shield("shield_weak")
	ice._try_shield("shield_weak")
	await _wait(0.15)
	await _shot("21_shield_patterns")
	get_tree().quit()


## Level 2: the jungle, its water monsters and the Jungle Demon.
func _jungle_shots() -> void:
	var fire := game.wizards[0]
	var ice := game.wizards[1]
	await _shot("j01_start")
	_place(fire, Vector3(-1.5, 0.3, -16), 0.0)
	_place(ice, Vector3(1.5, 0.3, -16), 0.0)
	await _wait(2.0)
	await _shot("j02_trail_jaguars")
	game.get_tree().call_group("enemies", "queue_free")
	_place(fire, Vector3(0, 0.3, -46.5), 0.0)
	_place(ice, Vector3(-2, 0.3, -45), -0.4)
	var fish := _monster_at("piranha", Vector3(-3, -0.6, -51))
	fish.aggro_range = 0.0
	await _wait(1.0)
	await _shot("j03_river")
	_place(fire, Vector3(0, 0.3, -93.5), 0.0)
	_place(ice, Vector3(-6, 0.3, -112), 0.6)
	await _wait(1.5)
	await _shot("j04_swamp")
	_place(fire, Vector3(0, 0.3, -180), 0.0)
	_place(ice, Vector3(4, 0.3, -204.5), -0.7)
	await _wait(1.5)
	await _shot("j05_lagoon")
	_place(fire, Vector3(-2, 0.3, -229), -1.2)
	_place(ice, Vector3(0, 0.3, -238), 0.0)
	await _wait(1.5)
	await _shot("j06_shrine_and_thorns")
	# Every jungle monster side by side, facing the cameras
	game.get_tree().call_group("enemies", "queue_free")
	(game.level.get_node("BigArena") as Arena).state = "cleared"
	var x := -5.5
	for path in ["jaguar", "anaconda", "crocodile", "piranha", "jungle_demon"]:
		var m := _monster_at(path, Vector3(x, 0, -306))
		m.aggro_range = 0.0
		m.rotation.y = PI
		if m.swim_leash > 0.0:
			m.set_physics_process(false)
			m._model.position.y = 0.0
		x += 2.8
	_place(fire, Vector3(-2.5, 0.3, -297.5), 0.0)
	_place(ice, Vector3(2.5, 0.3, -297.5), 0.0)
	await _wait(1.5)
	await _shot("j07_monster_lineup")
	# The demon's roots attack
	game.get_tree().call_group("enemies", "queue_free")
	var big := game.level.get_node("BigArena") as Arena
	big.state = "active"
	(game.level.get_node("ThornDoor") as Node3D).queue_free()
	var demon: Enemy = (load("res://scenes/enemies/jungle_demon.tscn") as PackedScene).instantiate()
	big.add_child(demon)
	demon.global_position = Vector3(0, 0, -275)
	demon._roots_timer = 0.0
	demon.aggro_range = 60.0
	_place(fire, Vector3(-3, 0.3, -258), 0.0)
	_place(ice, Vector3(3, 0.3, -258), 0.0)
	fire._invulnerable = 999.0
	ice._invulnerable = 999.0
	for i in 60:
		await _wait(0.05)
		if demon._root_marks.size() > 0:
			break
	await _wait(0.6)
	await _shot("j08_demon_roots")
	await _wait(0.75)
	await _shot("j09_roots_burst")
	_place(fire, Vector3(-1.5, 0.3, -305), 0.0)
	_place(ice, Vector3(1.5, 0.3, -305), 0.0)
	await _wait(1.5)
	await _shot("j10_portal")


func _place(w: Wizard, pos: Vector3, yaw: float) -> void:
	w.teleport(pos, true)
	w.camera_rig.set_yaw(yaw)


func _monster_at(path: String, pos: Vector3) -> Enemy:
	var m: Enemy = (load("res://scenes/enemies/%s.tscn" % path) as PackedScene).instantiate()
	game.level.add_child(m)
	m.global_position = pos
	return m


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(out_dir.path_join(name + ".png"))
	print("saved %s (%d fps)" % [name, Engine.get_frames_per_second()])
