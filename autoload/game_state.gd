extends Node
## Team progress: shared money, current level, unlocked magic and shop upgrades.
## Saved to user://save.json after each level and after shopping.

signal money_changed(amount: int)

const SAVE_PATH := "user://save.json"
const ELEMENTS := ["fire", "ice"]
const SLOTS := ["spell_strong", "spell_weak", "shield_strong", "shield_weak"]
const MAX_LEVEL := 12

var balance: Balance
var money := 0
var level := 1
## Highest magic tier each wizard has unlocked, e.g. {"fire": 1, "ice": 1}.
var tiers := {}
## Shop upgrade rank per wizard per slot, e.g. ranks["fire"]["spell_strong"] = 2.
var ranks := {}
## Which players pressed join on the title screen.
var joined: Array[bool] = [false, false]
## Tests turn this off so they never touch the real save file.
var save_enabled := true

var _riddles: Array = []


func _ready() -> void:
	balance = load("res://data/balance.tres") as Balance
	_reset()
	load_game()
	_load_riddles()


func reset_progress() -> void:
	_reset()


func _reset() -> void:
	money = 0
	level = 1
	tiers = {"fire": 1, "ice": 1}
	ranks = {}
	for element in ELEMENTS:
		ranks[element] = {}
		for slot in SLOTS:
			ranks[element][slot] = 0


func new_game() -> void:
	_reset()
	save_game()
	money_changed.emit(money)


func has_save() -> bool:
	return level > 1 or money > 0


func add_money(amount: int) -> void:
	money += amount
	money_changed.emit(money)


# --- Enemies and money -------------------------------------------------------

func enemy_power() -> int:
	return level * balance.enemy_power_per_level


## Multiplier for enemy health and damage. Level 1 = 1.0, level 12 = 12.0.
func enemy_scale() -> float:
	return enemy_power() / 10.0


func money_for(size: String) -> int:
	var base := balance.money_small
	match size:
		"medium":
			base = balance.money_medium
		"big":
			base = balance.money_big
	return int(round(base * (1.0 + balance.money_level_bonus * (level - 1))))


# --- Magic -------------------------------------------------------------------

func spell_path(element: String, tier: int) -> String:
	return "res://data/spells/%s_%d.tres" % [element, tier]


## The best magic set this wizard has unlocked (that exists as a file).
func spell_data(element: String) -> SpellData:
	var tier: int = tiers.get(element, 1)
	while tier > 1 and not ResourceLoader.exists(spell_path(element, tier)):
		tier -= 1
	return load(spell_path(element, tier)) as SpellData


func rank(element: String, slot: String) -> int:
	return ranks[element][slot]


func upgrade_mult(element: String, slot: String) -> float:
	return 1.0 + balance.upgrade_bonus_per_rank * rank(element, slot)


func upgrade_price(element: String, slot: String) -> int:
	return balance.shop_base_price + balance.shop_price_per_rank * rank(element, slot)


func can_upgrade(element: String, slot: String) -> bool:
	return rank(element, slot) < balance.shop_max_rank


func buy_upgrade(element: String, slot: String) -> bool:
	if not can_upgrade(element, slot):
		return false
	var price := upgrade_price(element, slot)
	if money < price:
		return false
	money -= price
	ranks[element][slot] = rank(element, slot) + 1
	save_game()
	money_changed.emit(money)
	return true


# --- Levels ------------------------------------------------------------------

func level_path(number: int) -> String:
	return "res://data/levels/level_%02d.tres" % number


func is_level_built(number: int) -> bool:
	return ResourceLoader.exists(level_path(number))


## Data for the current level. Levels that are not built yet fall back to the
## newest built level (enemies still use the current level's strength).
func level_data(number := -1) -> LevelData:
	if number < 0:
		number = level
	for n in range(number, 0, -1):
		if is_level_built(n):
			return load(level_path(n)) as LevelData
	return null


## Called when both wizards enter the exit portal.
## Returns {"fire": SpellData, "ice": SpellData} for magic that was just unlocked.
func complete_level(data: LevelData) -> Dictionary:
	var unlocked := {}
	for element in ELEMENTS:
		var before: int = tiers[element]
		var after := maxi(before, data.unlocks_tier if data else before + 1)
		if after == before:
			after = before + 1
		tiers[element] = after
		if ResourceLoader.exists(spell_path(element, after)):
			unlocked[element] = load(spell_path(element, after))
	level = mini(level + 1, MAX_LEVEL)
	save_game()
	return unlocked


# --- Riddles -----------------------------------------------------------------

func _load_riddles() -> void:
	var file := FileAccess.open("res://data/riddles.json", FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Array:
		_riddles = parsed


## Riddles with these ids (or all riddles when the list is empty).
func get_riddles(ids: PackedStringArray) -> Array:
	if ids.is_empty():
		return _riddles.duplicate()
	return _riddles.filter(func(r): return ids.has(str(r.get("id", ""))))


# --- Saving ------------------------------------------------------------------

func save_game() -> void:
	if not save_enabled:
		return
	var data := {"money": money, "level": level, "tiers": tiers, "ranks": ranks}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var data = JSON.parse_string(file.get_as_text())
	if not data is Dictionary:
		return
	money = int(data.get("money", 0))
	level = clampi(int(data.get("level", 1)), 1, MAX_LEVEL)
	var saved_tiers: Dictionary = data.get("tiers", {})
	var saved_ranks: Dictionary = data.get("ranks", {})
	for element in ELEMENTS:
		tiers[element] = maxi(1, int(saved_tiers.get(element, 1)))
		var element_ranks: Dictionary = saved_ranks.get(element, {})
		for slot in SLOTS:
			ranks[element][slot] = clampi(int(element_ranks.get(slot, 0)), 0, balance.shop_max_rank)
