class_name Game
extends Node
## Runs one level in split screen: spawns both wizards, handles checkpoints,
## reviving, items and finishing the level.

const WIZARD_SCENE := preload("res://scenes/wizard/wizard.tscn")
const ITEM_NAMES := {"key": "Key", "rune": "Riddle Rune"}

static var instance: Game

## True while the team is being sent back to a checkpoint.
var busy := false
var finished := false
var level_data: LevelData
var level: Node3D
var wizards: Array[Wizard] = []
var checkpoint: Checkpoint
var items := {}
var _money_at_start := 0

@onready var _viewports: Array[SubViewport] = [$Split/Left/Viewport, $Split/Right/Viewport]
@onready var _rigs: Array[CameraRig] = [$Split/Left/Viewport/CameraRig, $Split/Right/Viewport/CameraRig]
@onready var _huds: Array[PlayerHUD] = [$Split/Left/Viewport/HUD, $Split/Right/Viewport/HUD]
@onready var overlay: TeamOverlay = $Overlay
@onready var _pause_menu = $PauseMenu
@onready var _level_complete = $LevelComplete


func _enter_tree() -> void:
	instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null


func _ready() -> void:
	get_tree().paused = false
	# Both halves of the screen look into the same 3D world.
	var world := World3D.new()
	for vp in _viewports:
		vp.world_3d = world
	level_data = GameState.level_data()
	level = (load(level_data.scene_path) as PackedScene).instantiate()
	_viewports[0].add_child(level)
	_money_at_start = GameState.money
	checkpoint = _find_start_checkpoint()
	for i in 2:
		_spawn_wizard(i)
	overlay.setup(self)
	_pause_menu.game = self
	var subtitle := level_data.title
	if level_data.level_number != GameState.level:
		subtitle += "\n(Level %d is not built yet: monsters are level %d strong)" % [GameState.level, GameState.level]
	overlay.show_intro("LEVEL %d" % GameState.level, subtitle)


func _find_start_checkpoint() -> Checkpoint:
	var first: Checkpoint = null
	for node in get_tree().get_nodes_in_group("checkpoints"):
		var cp := node as Checkpoint
		if first == null:
			first = cp
		if cp.start_active:
			return cp
	return first


func _spawn_wizard(i: int) -> void:
	var w: Wizard = WIZARD_SCENE.instantiate()
	w.player_index = i
	w.element = GameState.ELEMENTS[i]
	w.game = self
	w.camera_rig = _rigs[i]
	w.hud = _huds[i]
	level.add_child(w)
	var pos := checkpoint.spawn_point(i) if checkpoint else Vector3(i * 2.0 - 1.0, 0.5, 0)
	w.teleport(pos, true)
	_rigs[i].player_index = i
	_rigs[i].set_yaw(checkpoint.global_rotation.y if checkpoint else 0.0)
	_rigs[i].follow(w)
	_huds[i].player_index = i
	_huds[i].setup(w, self)
	w.downed.connect(_on_wizard_downed)
	wizards.append(w)


# --- Called by level parts ---------------------------------------------------

func toast(text: String, color := Color(1, 0.95, 0.85)) -> void:
	overlay.toast(text, color)


func set_checkpoint(cp: Checkpoint) -> void:
	checkpoint = cp
	toast("Checkpoint!", UIUtil.GOLD)


func item_name(id: String) -> String:
	return ITEM_NAMES.get(id, id.capitalize())


func collect_item(id: String) -> void:
	items[id] = true
	overlay.refresh_items()
	toast("Got the %s!" % item_name(id), UIUtil.GOLD)
	if has_all_items():
		toast("The exit portal is open!", Color(0.85, 0.6, 1.0))


func has_item(id: String) -> bool:
	return items.has(id)


func has_all_items() -> bool:
	return missing_items().is_empty()


func missing_items() -> Array[String]:
	var list: Array[String] = []
	for id in level_data.required_items:
		if not items.has(id):
			list.append(id)
	return list


func open_riddle(wizard: Wizard, stone: RiddleStone) -> void:
	wizard.controls_locked = true
	wizard.hud.open_riddle(stone)


func show_boss(enemy: Enemy) -> void:
	overlay.show_boss(enemy)
	toast("A %s appears!" % enemy.display_name.to_upper(), Color(1, 0.35, 0.25))


# --- Falling and checkpoints -------------------------------------------------

func alive_wizards() -> Array[Wizard]:
	var list: Array[Wizard] = []
	for w in wizards:
		if not w.is_down:
			list.append(w)
	return list


func _on_wizard_downed(w: Wizard) -> void:
	if busy or finished:
		return
	if alive_wizards().is_empty():
		_team_wipe("Both wizards fell! Back to the checkpoint...")
	else:
		toast("%s is down! Back in %d seconds" % [w.display_name(), int(GameState.balance.revive_time)], Color(1, 0.6, 0.5))


func back_to_checkpoint() -> void:
	if not busy and not finished:
		_team_wipe("Back to the checkpoint!")


func _team_wipe(message: String) -> void:
	busy = true
	toast(message, Color(1, 0.6, 0.5))
	await get_tree().create_timer(1.2).timeout
	await overlay.fade_to(1.0, 0.5)
	for arena in get_tree().get_nodes_in_group("arenas"):
		arena.reset()
	for p in get_tree().get_nodes_in_group("projectiles"):
		p.queue_free()
	for i in wizards.size():
		wizards[i].respawn(checkpoint.spawn_point(i))
		_huds[i].close_riddle()
	await get_tree().create_timer(0.3).timeout
	await overlay.fade_to(0.0, 0.5)
	busy = false


# --- Finishing ---------------------------------------------------------------

func finish_level() -> void:
	if finished or busy:
		return
	finished = true
	for w in wizards:
		w.controls_locked = true
	var number := GameState.level
	var earned := GameState.money - _money_at_start
	var unlocked := GameState.complete_level(level_data)
	toast("Level complete!", UIUtil.GOLD)
	await get_tree().create_timer(0.8).timeout
	_level_complete.open(number, earned, unlocked)
