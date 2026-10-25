extends Node
## Headless smoke test for Level 1. Run with:
##   Godot --headless --path . res://tests/smoke_test.tscn
## Prints PASS/FAIL for each check and quits (exit code 1 on any failure).

var _failures := 0
var game: Game


func _ready() -> void:
	GameState.save_enabled = false
	GameState.reset_progress()
	game = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(game)
	await _frames(40)
	await _run()
	print("SMOKE TEST: %s (%d failures)" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		_failures += 1


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _spawn(scene_path: String, pos: Vector3) -> Enemy:
	var enemy: Enemy = (load(scene_path) as PackedScene).instantiate()
	enemy.always_aggro = true
	game.level.add_child(enemy)
	enemy.global_position = pos
	return enemy


## Waits up to max_frames physics frames for the condition to become true.
func _wait_for(condition: Callable, max_frames: int) -> bool:
	for i in max_frames:
		if condition.call():
			return true
		await get_tree().physics_frame
	return false


func _alive_monster(name: String) -> Enemy:
	return game.level.get_node_or_null("PathMonsters/" + name) as Enemy


## The most money a team can get in this level (every monster, every treasure).
func _max_level_money() -> int:
	var total := 0
	for node in get_tree().get_nodes_in_group("enemies"):
		total += GameState.money_for((node as Enemy).money_size)
	for node in get_tree().get_nodes_in_group("arenas"):
		var arena := node as Arena
		for w in arena.wave_count():
			var small := arena._wave_value_at(arena.wave_imps, w) + arena._wave_value_at(arena.wave_spitters, w)
			total += small * GameState.money_for("small")
			total += arena._wave_value_at(arena.wave_brutes, w) * GameState.money_for("medium")
			total += arena._wave_value_at(arena.wave_knights, w) * GameState.money_for("big")
	for node in get_tree().get_nodes_in_group("treasure"):
		total += int(node.get("money"))
	return total


func _check_economy() -> void:
	var most := _max_level_money()
	var cheap := GameState.base_price("shield_weak")
	var second := GameState.base_price("spell_weak")
	# After level 1 each wizard can buy one cheap upgrade, but not three cheap things
	# and not the most expensive one plus something else.
	_check(most >= cheap * 2, "level 1 pays for one cheap upgrade each (%d >= %d)" % [most, cheap * 2])
	_check(most < cheap * 2 + second, "level 1 can't buy three upgrades (%d < %d)" % [most, cheap * 2 + second])
	_check(GameState.base_price("spell_strong") > GameState.base_price("shield_weak") * 2, "strong spell costs much more than a quick shield")


func _run() -> void:
	var fire := game.wizards[0]
	var ice := game.wizards[1]
	_check_economy()
	_check(game.wizards.size() == 2, "two wizards spawned")
	_check(fire.element == "fire" and ice.element == "ice", "wizard elements")
	var nav := game.level.get_node("Nav") as NavigationRegion3D
	await _frames(30)
	_check(nav.navigation_mesh.get_polygon_count() > 0, "navigation mesh baked (%d polygons)" % nav.navigation_mesh.get_polygon_count())

	# Casting every spell and shield
	fire.teleport(Vector3(2, 0.3, -12))
	ice.teleport(Vector3(-1, 0.3, -12))
	await _frames(5)
	_check(fire.cast(true), "fire strong spell cast")
	_check(fire.cast(false), "fire weak spell cast")
	_check(ice.cast(true), "ice strong spell cast")
	_check(ice.cast(false), "ice weak spell cast")
	_check(get_tree().get_nodes_in_group("projectiles").size() >= 4, "projectiles flying")
	fire._try_shield("shield_strong")
	_check(fire.shield_active("shield_strong"), "strong shield up")
	var hp := fire.health
	fire.take_damage(30.0, fire.global_position + Vector3.FORWARD)
	_check(is_equal_approx(fire.health, hp), "strong shield blocks damage")
	fire._end_shield()
	ice._try_shield("shield_weak")
	_check(ice.shield_active("shield_weak"), "weak shield up")

	# A real projectile hitting a monster
	var imp2 := game.level.get_node("PathMonsters/Imp2") as Enemy
	await _frames(60)
	fire.teleport(Vector3(2, 0.3, -14))
	fire._cooldowns["spell_strong"] = 0.0
	await _frames(2)
	fire.cast(true)
	await _frames(40)
	_check(not is_instance_valid(imp2) or imp2.health < imp2.max_health, "fireball hurts an imp")
	if is_instance_valid(imp2) and not imp2.dead:
		_check(imp2._burn_left > 0.0 or imp2.dead, "fire makes the imp burn")

	# Killing gives money
	var imp1 := _alive_monster("Imp4")
	var money := GameState.money
	imp1.hit(9999.0, "fire", null, 1, fire)
	_check(imp1.dead, "imp dies")
	_check(GameState.money - money == GameState.money_for("small"), "imp drops %d money" % GameState.money_for("small"))

	# Ice stacks freeze
	var imp3 := _alive_monster("Imp5")
	var ice_data := GameState.spell_data("ice")
	for i in ice_data.freeze_stacks:
		imp3.hit(0.1, "ice", ice_data, 1, ice)
	_check(imp3._frozen_left > 0.0, "ice hits freeze a monster")
	imp3.hit(1.0, "fire", GameState.spell_data("fire"), 1, fire)
	_check(imp3._frozen_left <= 0.0, "fire shatters the freeze")

	# Lava trench: an ice spell over the lava freezes a bridge
	var trench := game.level.get_node("LavaTrench") as LavaTrench
	ice.teleport(Vector3(0, 0.3, -71.5))
	ice._cooldowns["spell_weak"] = 0.0
	ice._end_shield()
	await _frames(3)
	ice.cast(false)
	await _frames(30)
	_check(trench.frozen, "ice spell freezes the lava trench")

	# Lava sends you back
	fire.teleport(Vector3(0, 0.3, -70), true)
	await _frames(20)
	fire.teleport(Vector3(0, -1.5, -78))
	trench._melt()
	await _frames(30)
	_check(fire.global_position.z > -75.0, "falling in lava returns the wizard to safe ground")

	# Ice door: fire melts it
	var door := game.level.get_node("IceDoor") as IceDoor
	for e in game.level.get_node("PathMonsters").get_children():
		if e is Enemy and not e.dead:
			e.die()
	await _frames(30)
	fire.teleport(Vector3(-1, 0.3, -130.5))
	await _frames(5)
	for i in 6:
		fire._cooldowns["spell_strong"] = 0.0
		fire.cast(true)
		await _frames(25)
	await _frames(40)
	_check(not is_instance_valid(door) or door.collision_layer == 0, "fire melts the ice door")

	# Arena: walking in closes the gates and spawns monsters
	var arena := game.level.get_node("Arena1") as Arena
	fire.teleport(Vector3(0, 0.3, -52))
	await _frames(10)
	_check(arena.state == "active", "arena starts when a wizard walks in")
	_check(ice.global_position.z < -40.0 and ice.global_position.z > -64.0, "other wizard pulled into the arena")
	await _frames(120)
	var safety := 0
	while arena.state == "active" and safety < 20:
		safety += 1
		for e in arena.get_children():
			if e is Enemy and not e.dead:
				e.hit(9999.0, "fire", null, 1, fire)
		await _frames(150)
	_check(arena.state == "cleared", "arena cleared after all waves")
	var gates_open := true
	for g in arena._gates():
		if g.closed:
			gates_open = false
	_check(gates_open, "arena gates open after clearing")

	# Both wizards falling sends the team back to the checkpoint
	await _frames(60)
	fire._invulnerable = 0.0
	ice._invulnerable = 0.0
	fire.take_damage(9999.0)
	_check(fire.is_down, "fire wizard falls")
	ice.take_damage(9999.0)
	_check(ice.is_down, "ice wizard falls")
	await get_tree().create_timer(3.5).timeout
	_check(not fire.is_down and not ice.is_down, "both wizards back up after team wipe")
	_check(fire.global_position.distance_to(game.checkpoint.global_position) < 4.0, "respawned at checkpoint")

	# One wizard falling revives by itself
	fire._invulnerable = 0.0
	fire.take_damage(9999.0)
	fire.revive_left = 0.2
	await get_tree().create_timer(0.6).timeout
	_check(not fire.is_down, "single wizard revives after the timer")

	# Items open the portal
	_check(not game.has_all_items(), "portal locked without items")
	game.collect_item("key")
	game.collect_item("rune")
	_check(game.has_all_items(), "portal opens with key and rune")

	# Monsters chase and attack wizards that stand still
	var arena2 := game.level.get_node("Arena2") as Arena
	fire.teleport(Vector3(0, 0.3, -97), true)
	await _frames(10)
	_check(arena2.state == "active", "second arena starts")
	var start_health := fire.health + ice.health
	await get_tree().create_timer(9.0).timeout
	var hurt := fire.is_down or ice.is_down or fire.health + ice.health < start_health
	_check(hurt, "monsters reach and hurt the wizards")

	# A restarted fight takes back the money from the failed try
	var money_before_kill := GameState.money - arena2._earned
	for e in arena2.get_children():
		if e is Enemy and not e.dead:
			e.hit(9999.0, "fire", null, 1, fire)
			break
	_check(arena2._earned > 0, "arena counts money from its monsters")
	arena2.reset()
	_check(GameState.money == money_before_kill, "arena money taken back when the fight restarts")

	# Special moves: imps lunge, brutes charge, an enraged boss calls helpers
	for w in [fire, ice]:
		if w.is_down:
			w.revive(true)
	ice.teleport(Vector3(0, 0.3, -20))
	fire.teleport(Vector3(0, 0.3, -46))
	var imp := _spawn("res://scenes/enemies/imp.tscn", Vector3(0, 0, -52))
	_check(await _wait_for(func() -> bool: return imp._state == "roar", 30), "monster roars when it spots a wizard")
	_check(await _wait_for(func() -> bool: return imp._attack_kind == "melee" and imp._dash_left > 0.0, 300), "imp lunges at a wizard")
	imp.die()
	var brute := _spawn("res://scenes/enemies/brute.tscn", Vector3(0, 0, -60))
	_check(await _wait_for(func() -> bool: return brute._attack_kind == "charge" and brute._dash_left > 0.0, 400), "brute charges at a far wizard")
	brute.die()
	var big := game.level.get_node("BigArena") as Arena
	big.state = "active"
	var knight: Enemy = (load("res://scenes/enemies/demon_knight.tscn") as PackedScene).instantiate()
	big.add_child(knight)
	knight.global_position = big.global_position
	await _frames(2)
	knight.hit(knight.max_health * 0.6, "fire", null, 1, fire)
	_check(knight._enraged, "boss gets enraged at half health")
	await _frames(60)
	_check(big._alive.size() >= 2, "enraged boss calls imps into the arena")
	knight.die()
	big.reset()

	# Finishing the level unlocks the next magic set
	game.finish_level()
	await get_tree().create_timer(1.5).timeout
	_check(GameState.level == 2, "level counter goes up")
	_check(GameState.spell_data("fire").tier == 2 and GameState.spell_data("ice").tier == 2, "tier 2 magic unlocked")
	_check(GameState.level_data().level_number == 1, "unbuilt level 2 falls back to level 1 layout")
