class_name Balance
extends Resource
## All the big game numbers in one place.
## Open data/balance.tres in Godot to change them.

@export_group("Enemies")
## Enemy power = level x this number (level 1 = 10, level 12 = 120).
## Enemy health and damage are multiplied by power / 10.
@export var enemy_power_per_level := 10

@export_group("Money")
## Money for defeating a small (imp), medium (brute) or big (boss) monster.
@export var money_small := 8
@export var money_medium := 25
@export var money_big := 100
## Extra money per kill for every level after level 1 (0.15 = +15% per level).
@export var money_level_bonus := 0.15

@export_group("Wizards")
@export var wizard_max_health := 100.0
## Seconds until a fallen wizard gets back up.
@export var revive_time := 7.0
## Part of the health a wizard gets back after reviving (0.5 = half).
@export var revive_health := 0.5
## Seconds without getting hit before health starts coming back.
@export var regen_delay := 5.0
@export var regen_per_second := 3.0
## Damage taken when falling into lava.
@export var lava_damage := 20.0
## Damage taken when falling into piranha water.
@export var water_damage := 15.0

@export_group("Shop")
## Price of the first upgrade of each kind of magic. Bigger magic costs more,
## so the team has to save up for it over a few levels.
@export var price_spell_strong := 900
@export var price_spell_weak := 400
@export var price_shield_strong := 600
@export var price_shield_weak := 300
## Each rank costs this much more than the first one (0.75 = +75% of the first price per rank).
@export var shop_price_growth := 0.75
@export var shop_max_rank := 5
## Each upgrade rank makes that spell or shield this much stronger (0.15 = +15%).
@export var upgrade_bonus_per_rank := 0.15
