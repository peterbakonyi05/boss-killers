class_name RiddleStone
extends StaticBody3D
## A talking stone with a riddle. Answer it right to get the Riddle Rune.

## Riddle ids to pick from. Empty = use the level's riddle list.
@export var riddle_ids := PackedStringArray()
@export var item_id := "rune"

var solved := false
var _riddles: Array = []
var _last_id := ""
var _rune_mat: StandardMaterial3D
var _light: OmniLight3D
var _label: Label3D


func _ready() -> void:
	add_to_group("interactable")
	collision_layer = 1
	Build.collision_box(self, Vector3(1.4, 2.8, 0.8), Vector3(0, 1.4, 0))
	var stone := Build.mat(Color(0.28, 0.25, 0.3), 0.95)
	Build.part(self, Build.box(Vector3(1.4, 2.8, 0.8)), stone, Vector3(0, 1.4, 0))
	Build.part(self, Build.box(Vector3(1.7, 0.3, 1.1)), stone, Vector3(0, 0.15, 0))
	Build.part(self, Build.sphere(0.55), stone, Vector3(0, 2.8, 0), Vector3.ZERO, Vector3(1.3, 0.6, 0.75))
	_rune_mat = Build.glow(Color(0.75, 0.4, 1.0), 3.0)
	# Glowing rune marks on both faces
	for z in [-0.41, 0.41]:
		Build.part(self, Build.box(Vector3(0.5, 0.08, 0.02)), _rune_mat, Vector3(0, 2.1, z))
		Build.part(self, Build.box(Vector3(0.08, 0.7, 0.02)), _rune_mat, Vector3(0, 1.6, z))
		Build.part(self, Build.box(Vector3(0.4, 0.08, 0.02)), _rune_mat, Vector3(0, 1.2, z), Vector3(0, 0, 35))
		Build.part(self, Build.sphere(0.12), _rune_mat, Vector3(0, 0.8, z), Vector3.ZERO, Vector3(1, 1, 0.2))
	_light = Build.light(self, Color(0.7, 0.4, 1.0), 2.0, 7.0, Vector3(0, 2.0, 1.2))
	_label = Build.label3d(self, "RIDDLE STONE", Vector3(0, 3.6, 0), 44, Color(0.85, 0.65, 1.0))


func _get_riddles() -> Array:
	if _riddles.is_empty():
		var ids := riddle_ids
		if ids.is_empty() and Game.instance and Game.instance.level_data:
			ids = Game.instance.level_data.riddle_ids
		_riddles = GameState.get_riddles(ids)
	return _riddles


## A riddle that is different from the last one shown.
func next_riddle() -> Dictionary:
	var list := _get_riddles()
	if list.is_empty():
		return {"id": "none", "question": "What color is fire?", "answers": ["Blue", "Orange", "Green"], "correct": 1}
	var pick: Dictionary = list.pick_random()
	if list.size() > 1:
		while str(pick.get("id", "")) == _last_id:
			pick = list.pick_random()
	_last_id = str(pick.get("id", ""))
	return pick


func can_interact(wizard: Wizard) -> bool:
	return not solved and not wizard.is_down


func get_prompt(_wizard: Wizard) -> String:
	return "Read the riddle"


func interact(wizard: Wizard) -> void:
	if Game.instance:
		Game.instance.open_riddle(wizard, self)


func solve() -> void:
	if solved:
		return
	solved = true
	_rune_mat.albedo_color = UIUtil.GOLD
	_rune_mat.emission = UIUtil.GOLD
	_rune_mat.emission_energy_multiplier = 6.0
	_light.light_color = UIUtil.GOLD
	_label.text = "SOLVED!"
	_label.modulate = UIUtil.GOLD
	FX.burst(self, global_position + Vector3(0, 2.0, 0), UIUtil.GOLD * 2.0, 60, 6.0, 0.3, 1.0)
	FX.float_text(self, global_position + Vector3(0, 3.0, 0), "RIDDLE RUNE!", UIUtil.GOLD, 90)
	if Game.instance:
		Game.instance.collect_item(item_id)
