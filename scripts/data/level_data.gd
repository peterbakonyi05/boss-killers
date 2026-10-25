class_name LevelData
extends Resource
## Settings for one level. One file per level: data/levels/level_01.tres, ...

@export var level_number := 1
@export var title := "The Burning Caves"
@export_file("*.tscn") var scene_path := "res://scenes/levels/level_01.tscn"
## Magic tier both wizards get after finishing this level.
@export var unlocks_tier := 2
## Riddle ids from data/riddles.json that riddle stones in this level can ask.
@export var riddle_ids := PackedStringArray()
## Items the team needs before the exit portal opens.
@export var required_items := PackedStringArray(["key", "rune"])
## Short goal text shown at the top of the screen.
@export var goal_text := "Find the KEY and solve the RIDDLE to open the portal!"
