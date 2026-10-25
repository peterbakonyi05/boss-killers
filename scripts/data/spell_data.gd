class_name SpellData
extends Resource
## One set of magic for one wizard: strong spell, weak spell, strong shield, weak shield.
## There is one file per element per tier, e.g. data/spells/fire_1.tres.

@export var set_name := "Ember Magic"
@export_enum("fire", "ice") var element := "fire"
@export var tier := 1
@export var color := Color(1.0, 0.45, 0.1)

@export_group("Strong spell (R2)")
@export var strong_name := "Fireball"
@export var strong_damage := 24.0
@export var strong_cooldown := 1.1
@export var strong_speed := 18.0
## Radius of the projectile in meters.
@export var strong_size := 0.42
## Monsters this close to the hit also take half damage.
@export var strong_splash_radius := 2.0
## How many projectiles fly out at once.
@export var strong_count := 1

@export_group("Weak spell (R1)")
@export var weak_name := "Flame Darts"
@export var weak_damage := 7.0
@export var weak_cooldown := 0.26
@export var weak_speed := 28.0
@export var weak_size := 0.16
@export var weak_count := 1

@export_group("Strong shield (L2)")
@export var shield_strong_name := "Flame Dome"
## 1.0 blocks all damage, 0.5 blocks half.
@export var shield_strong_block := 1.0
## Longest time the shield stays up while the button is held.
@export var shield_strong_duration := 3.0
@export var shield_strong_cooldown := 6.0
@export var shield_strong_radius := 1.5

@export_group("Weak shield (L1)")
@export var shield_weak_name := "Spark Guard"
@export var shield_weak_block := 0.6
@export var shield_weak_duration := 0.9
@export var shield_weak_cooldown := 1.5
@export var shield_weak_radius := 1.15

@export_group("Fire effect: burn")
## Damage per second while a monster burns.
@export var burn_dps := 5.0
@export var burn_time := 3.0

@export_group("Ice effect: slow and freeze")
## Each ice hit slows a monster by this much (0.2 = 20% slower).
@export var slow_per_stack := 0.2
@export var slow_time := 2.5
## Ice hits needed to freeze a monster solid.
@export var freeze_stacks := 5
@export var freeze_time := 2.5
## A strong ice spell counts as this many hits.
@export var strong_stacks := 2


func slot_name(slot: String) -> String:
	match slot:
		"spell_strong":
			return strong_name
		"spell_weak":
			return weak_name
		"shield_strong":
			return shield_strong_name
		"shield_weak":
			return shield_weak_name
	return slot


func slot_cooldown(slot: String) -> float:
	match slot:
		"spell_strong":
			return strong_cooldown
		"spell_weak":
			return weak_cooldown
		"shield_strong":
			return shield_strong_cooldown
		"shield_weak":
			return shield_weak_cooldown
	return 1.0
