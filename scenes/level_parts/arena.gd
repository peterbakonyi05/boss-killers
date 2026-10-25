class_name Arena
extends Node3D
## A fight room. When a wizard walks in, the gates close and monsters come in waves.
## The gates open again when every monster is defeated.
##
## Each wave list has one number per wave. Example: imps = [4, 2] and brutes = [0, 1]
## means wave 1 has 4 imps, wave 2 has 2 imps and 1 brute.
## Put Gate scenes and Marker3D nodes named "Spawn..." (and one "Entry") inside the arena.

signal started
signal cleared

const IMP := preload("res://scenes/enemies/imp.tscn")
const BRUTE := preload("res://scenes/enemies/brute.tscn")
const KNIGHT := preload("res://scenes/enemies/demon_knight.tscn")

@export var arena_name := "Arena"
## Size of the room floor (x = width, z = depth).
@export var size := Vector3(24, 6, 24)
@export var wave_imps := PackedInt32Array([4, 2])
@export var wave_spitters := PackedInt32Array([0, 2])
@export var wave_brutes := PackedInt32Array([0, 0])
@export var wave_knights := PackedInt32Array([0, 0])
## Something that appears in the middle when the arena is cleared (e.g. the key).
@export var reward_scene: PackedScene

var state := "idle"   # idle, active, cleared
var wave := 0
var _alive: Array[Enemy] = []
var _spawning := 0
var _run := 0   # changes on every start, so old timers from a reset fight are ignored
var _earned := 0   # money from this fight, taken back if the team falls and the fight restarts


func _ready() -> void:
	add_to_group("arenas")
	var trigger := Area3D.new()
	trigger.collision_layer = 0
	trigger.collision_mask = 2
	add_child(trigger)
	# A bit smaller than the room, so the gates close behind the wizards.
	Build.collision_box(trigger, Vector3(size.x - 4.0, size.y, size.z - 5.0), Vector3(0, size.y * 0.5, 0))
	trigger.body_entered.connect(_on_body_entered)


func wave_count() -> int:
	return maxi(maxi(wave_imps.size(), wave_spitters.size()), maxi(wave_brutes.size(), wave_knights.size()))


func _on_body_entered(body: Node3D) -> void:
	if state == "idle" and body is Wizard and not (body as Wizard).is_down:
		start()


func start() -> void:
	state = "active"
	wave = 0
	_earned = 0
	_run += 1
	_spawning = 0
	for gate in _gates():
		gate.close()
	# Pull the other wizard inside so nobody is stuck outside the gates.
	var entry := get_node_or_null("Entry") as Node3D
	var entry_pos := entry.global_position if entry else global_position
	var i := 0
	for w in get_tree().get_nodes_in_group("wizards"):
		var wiz := w as Wizard
		if not _is_inside(wiz.global_position):
			wiz.teleport(entry_pos + global_basis.x * (i * 1.5 - 0.75), true)
		i += 1
	if Game.instance:
		Game.instance.toast("Defeat all the monsters!", Color(1.0, 0.45, 0.3))
	started.emit()
	_spawn_wave_later(1.0)


func _is_inside(pos: Vector3) -> bool:
	var local := to_local(pos)
	return absf(local.x) < size.x * 0.5 - 0.5 and absf(local.z) < size.z * 0.5 - 0.5


func _gates() -> Array[Gate]:
	var list: Array[Gate] = []
	for child in get_children():
		if child is Gate:
			list.append(child)
	return list


func _spawn_points() -> Array[Vector3]:
	var points: Array[Vector3] = []
	for child in get_children():
		if child is Marker3D and child.name.begins_with("Spawn"):
			points.append((child as Marker3D).global_position)
	if points.is_empty():
		for k in 6:
			points.append(to_global(Vector3(randf_range(-0.35, 0.35) * size.x, 0, randf_range(-0.4, 0.0) * size.z)))
	return points


func _spawn_wave_later(delay: float) -> void:
	var run := _run
	_spawning += 1
	await get_tree().create_timer(delay).timeout
	if run != _run or state != "active":
		return
	_spawning -= 1
	_spawn_wave()


func _wave_value(list: PackedInt32Array) -> int:
	return _wave_value_at(list, wave)


func _wave_value_at(list: PackedInt32Array, index: int) -> int:
	return list[index] if index < list.size() else 0


func _spawn_wave() -> void:
	var todo: Array = []
	for k in _wave_value(wave_knights):
		todo.append(KNIGHT)
	for k in _wave_value(wave_brutes):
		todo.append(BRUTE)
	for k in _wave_value(wave_imps):
		todo.append(IMP)
	for k in _wave_value(wave_spitters):
		todo.append("spitter")
	var points := _spawn_points()
	points.shuffle()
	if Game.instance and wave_count() > 1:
		Game.instance.toast("Wave %d of %d" % [wave + 1, wave_count()], Color(1.0, 0.75, 0.4))
	for k in todo.size():
		var pos: Vector3 = points[k % points.size()] + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1))
		_spawn_enemy(todo[k], pos, 0.15 * k)
	if todo.is_empty():
		_on_wave_done()


func _spawn_enemy(kind, pos: Vector3, delay: float) -> void:
	var run := _run
	_spawning += 1
	FX.burst(self, pos + Vector3(0, 1, 0), Color(0.5, 0.2, 0.7, 0.8), 24, 3.0, 1.2, 1.0,
		{"smoke": true, "radius": 0.8, "gravity": Vector3(0, 2, 0)})
	FX.burst(self, pos + Vector3(0, 0.5, 0), Color(0.8, 0.3, 1.0) * 2.0, 20, 5.0, 0.2, 0.8,
		{"direction": Vector3.UP, "spread": 25.0})
	await get_tree().create_timer(0.6 + delay).timeout
	if run != _run or state != "active":
		return
	_spawning -= 1
	var enemy: Enemy
	if kind is String:
		enemy = IMP.instantiate()
		enemy.ranged = true
		enemy.display_name = "Spitter Imp"
		enemy.body_color = Color(0.2, 0.35, 0.12)
		enemy.eye_color = Color(0.7, 1.0, 0.2)
		enemy.attack_cooldown = 2.0
		enemy.windup_time = 0.6
	else:
		enemy = (kind as PackedScene).instantiate()
	enemy.always_aggro = true
	add_child(enemy)
	enemy.global_position = pos
	enemy.died.connect(_on_enemy_died)
	_alive.append(enemy)


func _on_enemy_died(enemy: Enemy) -> void:
	_alive.erase(enemy)
	_earned += enemy.money_dropped
	if _alive.is_empty() and _spawning == 0 and state == "active":
		_on_wave_done()


func _on_wave_done() -> void:
	wave += 1
	if wave < wave_count():
		_spawn_wave_later(1.5)
	else:
		_clear()


func _clear() -> void:
	state = "cleared"
	for gate in _gates():
		gate.open()
	if Game.instance:
		Game.instance.toast("%s cleared!" % arena_name, UIUtil.GOLD)
	if reward_scene:
		var reward := reward_scene.instantiate() as Node3D
		add_child(reward)
		reward.global_position = global_position + Vector3(0, 0.2, 0)
		FX.burst(self, global_position + Vector3(0, 1.5, 0), UIUtil.GOLD * 2.0, 50, 6.0, 0.3, 1.0)
	cleared.emit()


## After both wizards fall: remove the monsters and let the fight start over.
## Money from this try is taken back, so the same waves can't be farmed.
func reset() -> void:
	if state != "active":
		return
	state = "idle"
	wave = 0
	if _earned > 0:
		GameState.add_money(-mini(_earned, GameState.money))
		_earned = 0
	for enemy in _alive:
		if is_instance_valid(enemy):
			enemy.queue_free()
	_alive.clear()
	for gate in _gates():
		gate.open()
