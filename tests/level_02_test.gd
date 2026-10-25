extends Node
## Headless test for Level 2 (The Jungle of Shadows). Run with:
##   Godot --headless --path . res://tests/level_02_test.tscn
## Prints PASS/FAIL for each check and quits (exit code 1 on any failure).

var _failures := 0
var game: Game
## Path monsters moved out of the way while single monsters are tested.
var _parked := {}


func _ready() -> void:
	GameState.save_enabled = false
	GameState.reset_progress()
	GameState.level = 2
	game = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(game)
	await _frames(40)
	await _run()
	print("LEVEL 2 TEST: %s (%d failures)" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		_failures += 1


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _wait_for(condition: Callable, max_frames: int) -> bool:
	for i in max_frames:
		if condition.call():
			return true
		await get_tree().physics_frame
	return false


func _spawn(scene_path: String, pos: Vector3, parent: Node = null) -> Enemy:
	var enemy: Enemy = (load(scene_path) as PackedScene).instantiate()
	enemy.always_aggro = true
	(parent if parent else game.level).add_child(enemy)
	enemy.global_position = pos
	return enemy


func _monster(name: String) -> Enemy:
	return game.level.get_node_or_null("PathMonsters/" + name) as Enemy


## Both wizards up, full health, nothing on cooldown.
func _fresh(wizards: Array) -> void:
	for w in wizards:
		var wiz := w as Wizard
		if wiz.is_down:
			wiz.revive(true)
		wiz.health = wiz.max_health
		wiz._invulnerable = 0.0
		wiz._end_shield()
		for slot in Wizard.SLOTS:
			wiz._cooldowns[slot] = 0.0


func _park_path_monsters() -> void:
	for node in game.level.get_node("PathMonsters").get_children():
		var e := node as Enemy
		if e and not e.dead:
			_parked[e] = e.global_position
			e.set_physics_process(false)
			e.global_position += Vector3(0, -40, 0)


func _unpark(e: Enemy) -> void:
	e.global_position = _parked[e]
	e.set_physics_process(true)
	_parked.erase(e)


## The most money a team can get in this level (every monster, every treasure).
func _max_level_money() -> int:
	var total := 0
	for node in get_tree().get_nodes_in_group("enemies"):
		total += GameState.money_for((node as Enemy).money_size)
	for node in get_tree().get_nodes_in_group("arenas"):
		var arena := node as Arena
		for w in arena.wave_count():
			var small := arena._wave_value_at(arena.wave_imps, w) + arena._wave_value_at(arena.wave_spitters, w) \
				+ arena._wave_value_at(arena.wave_jaguars, w)
			var medium := arena._wave_value_at(arena.wave_brutes, w) + arena._wave_value_at(arena.wave_anacondas, w)
			var big := arena._wave_value_at(arena.wave_knights, w) + arena._wave_value_at(arena.wave_demons, w)
			total += small * GameState.money_for("small") + medium * GameState.money_for("medium") + big * GameState.money_for("big")
	for node in get_tree().get_nodes_in_group("treasure"):
		total += int(node.get("money"))
	return total


func _check_level_basics() -> void:
	_check(game.level_data.level_number == 2 and game.level.scene_file_path.ends_with("level_02.tscn"), "level 2 loads the jungle layout")
	_check(GameState.get_riddles(game.level_data.riddle_ids).size() == game.level_data.riddle_ids.size(), "all level 2 riddles exist")
	# Economy: level 2 (with what is left from level 1) pays for one strong spell, not two.
	var most := _max_level_money()
	var strong := GameState.base_price("spell_strong")
	var cheap := GameState.base_price("shield_weak")
	_check(most >= strong, "level 2 pays for one strong spell (%d >= %d)" % [most, strong])
	_check(most < strong * 2 - cheap, "level 2 can't buy two strong spells (%d < %d)" % [most, strong * 2 - cheap])
	_check(game.secrets_total == 3, "level has 3 secrets (%d)" % game.secrets_total)
	_check((game.level.get_node("ExitPortal") as Node3D).global_position.z < -300.0, "longer than level 1 (portal past 300 m)")


func _check_nav() -> void:
	var nav := game.level.get_node("Nav") as NavigationRegion3D
	_check(nav.navigation_mesh.get_polygon_count() > 0, "navigation mesh baked (%d polygons)" % nav.navigation_mesh.get_polygon_count())
	# Walkable stretches between the water gaps (the lagoon needs jumping, the trench an ice bridge).
	var stretches := [
		[Vector3(0, 0, -5), Vector3(0, 0, -46), "start to the river"],
		[Vector3(0, 0, -5), Vector3(-10, 0, -30), "trail to the secret ruin"],
		[Vector3(0, 0, -46), Vector3(0, 0, -65), "log bridge over the river"],
		[Vector3(0, 0, -65), Vector3(-6, 0, -115), "river to the end of the boardwalk"],
		[Vector3(0, 0, -125), Vector3(0, 0, -179.5), "trench to the lagoon"],
		[Vector3(0, 0, -224), Vector3(0, 0, -308), "lagoon exit to the portal"],
		[Vector3(0, 0, -230), Vector3(11, 0, -233), "shrine to the hidden shrine"],
	]
	for st in stretches:
		var path := NavigationServer3D.map_get_path(nav.get_navigation_map(), st[0], st[1], true)
		var reached := path.size() > 0 and path[path.size() - 1].distance_to(st[1]) < 1.5
		_check(reached, "walkable: %s" % st[2])


func _check_theme() -> void:
	var level := game.level
	var theme := LevelTheme.of(level)
	_check(theme != null and theme.theme_name == "Night Jungle", "level uses the jungle theme")
	var placeholders := 0
	for node in level.find_children("*", "CSGShape3D", true, false):
		var m: Material = node.get("material")
		if m and m.resource_path.begins_with("res://data/surfaces/"):
			placeholders += 1
	_check(placeholders == 0, "theme replaced all surface materials (%d left)" % placeholders)
	var dresser: LevelDresser = level.get("dresser")
	var props := dresser.get_child_count() if dresser else 0
	_check(props > 80, "jungle props placed along the walls (%d)" % props)
	for kind in ["jungle_tree", "fern", "big_leaves", "vines", "ruin_pillar", "glow_flowers", "skull_totem"]:
		var p := Props.spawn(kind, level, Vector3(0, -50, 0), 0.0, RandomNumberGenerator.new(), theme)
		_check(p != null, "prop builds: %s" % kind)
		if p:
			p.queue_free()
	var bodies := dresser.find_children("*", "CollisionObject3D", true, false).size() if dresser else 0
	_check(bodies == 0, "props have no collision")


func _check_jaguar(fire: Wizard, ice: Wizard) -> void:
	fire.teleport(Vector3(0, 0.3, -4), true)
	ice.teleport(Vector3(-6, 0.3, -2), true)
	_fresh([fire, ice])
	var jag := _spawn("res://scenes/enemies/jaguar.tscn", Vector3(0, 0, -12))
	_check(await _wait_for(func() -> bool: return jag._attack_kind == "melee" and jag._dash_left > 0.0, 400), "jaguar pounces at a wizard")
	var prowled := await _wait_for(func() -> bool:
		if jag._attack_timer <= 0.0 or jag._dash_left > 0.0 or jag._state != "chase" or jag._target == null:
			return false
		var to := jag._target.global_position - jag.global_position
		var v := Vector3(jag.velocity.x, 0, jag.velocity.z)
		return v.length() > 1.0 and absf(v.normalized().dot(Vector3(to.x, 0, to.z).normalized())) < 0.75, 300)
	_check(prowled, "jaguar circles around the wizard between pounces")
	jag.die()
	await _frames(5)


func _check_anaconda(fire: Wizard, ice: Wizard) -> void:
	_fresh([fire, ice])
	fire.teleport(Vector3(0, 0.3, -2), true)
	ice.teleport(Vector3(-6, 0.3, -2), true)
	var snake := _spawn("res://scenes/enemies/anaconda.tscn", Vector3(0, 0, -12))
	_check(await _wait_for(func() -> bool: return snake._attack_kind == "charge" and snake._dash_left > 0.0, 400), "anaconda strikes from far away")
	_check(await _wait_for(func() -> bool: return snake._attack_kind == "slam" and snake._state == "windup" and snake._telegraph.visible, 500),
		"anaconda tail sweep shows a warning circle")
	snake.die()
	await _frames(5)


func _check_water_monsters(fire: Wizard, ice: Wizard) -> void:
	# Crocodile: swims to the bank and snaps at a wizard standing at the edge.
	_fresh([fire, ice])
	var croc := _monster("Croc1")
	ice.teleport(Vector3(-2, 0.3, -20), true)
	fire.teleport(Vector3(6.5, 0.3, -93.8), true)
	_unpark(croc)
	await _frames(2)
	var home := croc.global_position
	var hp := fire.health
	var bit := await _wait_for(func() -> bool: return fire.health < hp, 600)
	var swam := Vector2(croc.global_position.x - home.x, croc.global_position.z - home.z).length()
	_check(bit, "crocodile bites a wizard standing on the bank")
	_check(swam <= croc.swim_leash + 0.1 and absf(croc.global_position.y - home.y) < 0.1, "crocodile stays in its water (%.1f m from home)" % swam)
	croc.die()

	# Piranha: hides under water (no auto-aim), then jumps out at a wizard on the bridge.
	_fresh([fire, ice])
	var fish := _monster("RiverPiranha1")
	fire.teleport(Vector3(0, 0.3, -48.5), true)
	fire.camera_rig.set_yaw(PI / 4.0)
	_unpark(fish)
	await _frames(2)
	var surface := fish.global_position.y
	_check(fish.submerged and fire._aim_target() == null, "piranha under water is not auto-aimed")
	fire.teleport(Vector3(0, 0.3, -51.5), true)
	var leapt := await _wait_for(func() -> bool: return fish._dash_left > 0.0 and fish.global_position.y > surface + 1.0, 400)
	_check(leapt and not fish.submerged, "piranha leaps out of the water")
	_check(await _wait_for(func() -> bool: return fish._dash_left <= 0.0 and fish.submerged and is_equal_approx(fish.global_position.y, surface), 120),
		"piranha splashes back into the water")
	fish.die()

	# Falling into the water: piranhas bite and the wizard pops back to the bank.
	_fresh([fire, ice])
	ice.teleport(Vector3(0, 0.3, -46), true)
	await _frames(10)
	var ice_hp := ice.health
	ice.teleport(Vector3(6, 0.5, -56))
	await _frames(40)
	_check(ice.health < ice_hp and ice.global_position.distance_to(Vector3(0, 0.3, -46)) < 3.0, "falling in the water bites and returns the wizard")
	_check(ice.health > ice_hp - GameState.balance.water_damage * 1.5, "water only bites once per fall")


func _check_puzzles(fire: Wizard, ice: Wizard) -> void:
	# The river gap freezes into an ice bridge.
	_fresh([fire, ice])
	var trench := game.level.get_node("RiverTrench") as LavaTrench
	_check(trench.water, "river gap is water, not lava")
	ice.teleport(Vector3(0, 0.3, -115.5), true)
	ice.camera_rig.set_yaw(0.0)
	await _frames(3)
	ice.cast(false)
	await _frames(30)
	_check(trench.frozen, "ice spell freezes the river gap")

	# The thorn door only burns with fire.
	var door := game.level.get_node("ThornDoor") as IceDoor
	_check(door.style == "thorns", "boss door is a thorn wall")
	ice.teleport(Vector3(1, 0.3, -238.5), true)
	ice.camera_rig.set_yaw(0.0)
	fire.teleport(Vector3(-1, 0.3, -238.5), true)
	fire.camera_rig.set_yaw(0.0)
	await _frames(5)
	ice._cooldowns["spell_strong"] = 0.0
	ice.cast(true)
	await _frames(25)
	_check(is_equal_approx(door._hp, door.melt_health), "ice does not hurt the thorns")
	for i in 6:
		fire._cooldowns["spell_strong"] = 0.0
		fire.cast(true)
		await _frames(25)
	await _frames(40)
	_check(not is_instance_valid(door) or door.collision_layer == 0, "fire burns the thorn door")

	# Secrets: a cracked wall, a thorn wall without a sign, chests with money.
	var cracked := game.level.get_node("CrackedWall") as BreakableWall
	fire.teleport(Vector3(-1, 0.3, -30), true)
	fire.camera_rig.set_yaw(PI / 2.0)
	await _frames(5)
	for i in 6:
		fire._cooldowns["spell_strong"] = 0.0
		fire.cast(true)
		await _frames(20)
	await _frames(40)
	_check(not is_instance_valid(cracked) or cracked.collision_layer == 0, "spells break the cracked ruin wall")
	var chest := game.level.get_node("ChestRuin") as TreasureChest
	var money := GameState.money
	chest.interact(fire)
	_check(GameState.money - money == chest.money and game.secrets_found == 1, "secret chest gives %d money" % chest.money)
	var thorns := game.level.get_node("SecretThorns") as IceDoor
	_check(thorns.style == "thorns" and not thorns._sign.visible, "secret thorn wall has no sign")


func _check_arena(fire: Wizard, ice: Wizard) -> void:
	_fresh([fire, ice])
	var arena := game.level.get_node("Arena1") as Arena
	ice.teleport(Vector3(0, 0.3, -60), true)
	fire.teleport(Vector3(0, 0.3, -76))
	await _frames(10)
	_check(arena.state == "active", "jaguar den starts when a wizard walks in")
	# Jaguars hit hard: keep the team up so the fight is not reset by a team wipe.
	fire._invulnerable = 999.0
	ice._invulnerable = 999.0
	await _frames(160)
	var jaguars := arena.get_children().filter(func(n: Node) -> bool: return n is Enemy and (n as Enemy).look == Enemy.Look.JAGUAR)
	_check(jaguars.size() == arena.wave_jaguars[0], "first wave has %d jaguars (%d)" % [arena.wave_jaguars[0], jaguars.size()])
	var safety := 0
	while arena.state == "active" and safety < 20:
		safety += 1
		for e in arena.get_children():
			if e is Enemy and not e.dead:
				e.hit(9999.0, "fire", null, 1, fire)
		await _frames(150)
	_check(arena.state == "cleared", "jaguar den cleared after all waves")


func _check_boss(fire: Wizard, ice: Wizard) -> void:
	_fresh([fire, ice])
	var big := game.level.get_node("BigArena") as Arena
	big.state = "active"
	ice.teleport(Vector3(-14, 0.3, -258), true)
	fire.teleport(Vector3(0, 0.3, -259), true)
	var demon: Enemy = (load("res://scenes/enemies/jungle_demon.tscn") as PackedScene).instantiate()
	big.add_child(demon)
	demon.global_position = big.global_position
	await _frames(2)
	_check(demon.is_boss, "jungle demon is a boss")
	# Charges and thorns must not knock the team out before the roots come.
	fire._invulnerable = 999.0
	ice._invulnerable = 999.0
	var marked := await _wait_for(func() -> bool: return demon._attack_kind == "roots" and demon._root_marks.size() > 0, 900)
	_check(marked, "roots attack shows warning rings under the wizards")
	if marked:
		var ring := demon._root_marks[0].global_position
		var near := fire if fire.global_position.distance_to(ring) < ice.global_position.distance_to(ring) else ice
		near._invulnerable = 0.0
		var hp := near.health
		_check(await _wait_for(func() -> bool: return demon._root_marks.is_empty(), 120), "roots burst up after the warning")
		_check(near.health < hp, "roots hurt a wizard who stays in the ring")
	_fresh([fire, ice])
	demon.hit(demon.max_health * 0.6, "fire", null, 1, fire)
	_check(demon._enraged, "jungle demon gets enraged at half health")
	await _frames(60)
	var helpers := big._alive.filter(func(e: Enemy) -> bool: return e.look == Enemy.Look.JAGUAR)
	_check(helpers.size() >= 2, "enraged demon calls jaguars")
	demon.die()
	big.reset()


func _run() -> void:
	var fire := game.wizards[0]
	var ice := game.wizards[1]
	_check_level_basics()
	await _frames(30)
	_check_nav()
	_check_theme()
	_park_path_monsters()
	await _check_jaguar(fire, ice)
	await _check_anaconda(fire, ice)
	await _check_water_monsters(fire, ice)
	await _check_puzzles(fire, ice)
	await _check_arena(fire, ice)
	await _check_boss(fire, ice)

	_fresh([fire, ice])
	game.collect_item("key")
	game.collect_item("rune")
	game.finish_level()
	await get_tree().create_timer(1.5).timeout
	_check(GameState.level == 3, "level counter goes up to 3")
	_check(GameState.level_data().level_number == 2, "unbuilt level 3 falls back to the jungle layout")
