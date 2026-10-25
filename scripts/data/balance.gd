class_name Balance
extends Resource
## All the big game numbers in one place.
## Open data/balance.tres in Godot to change them.

@export_group("Enemies")
## Enemy power = level x this number (level 1 = 10, level 12 = 120).
## Enemy health and damage are multiplied by power / 10.
@export var enemy_power_per_level := 10

@export_group("Money")
@export var money_small := 100
@export var money_medium := 250
@export var money_big := 500
## Extra money per kill for every level after level 1 (0.15 = +15% per level).
@export var money_level_bonus := 0.15

@export_group("Wizards")
@export var wizard_max_health := 100.0
## Seconds until a fallen wizard gets back up.
@export var revive_time := 7.0
## Part of the health a wizard gets back after reviving (0.5 = half).
@export var revive_health := 0.5
## Seconds without getting hit before health starts coming back.
@export var regen_delay := 4.0
@export var regen_per_second := 4.0
## Damage taken when falling into lava.
@export var lava_damage := 20.0

@export_group("Shop")
@export var shop_base_price := 300
## Each rank costs this much more than the one before.
@export var shop_price_per_rank := 250
@export var shop_max_rank := 5
## Each upgrade rank makes that spell or shield this much stronger (0.15 = +15%).
@export var upgrade_bonus_per_rank := 0.15
