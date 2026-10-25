class_name Prop
extends Node3D
## A hand-placed decoration (a skeleton by the riddle stone, a coffin in a secret room).
## Any kind from scripts/props.gd; front faces −Z. Only looks, no collision.

@export_enum("rock_small", "rock_mossy", "boulder", "dead_log", "barrel", "barrel_pile", "crate",
	"bucket", "statue", "fallen_knight", "lantern", "cage", "chandelier", "skull",
	"skull_pile", "bones", "candles", "cobweb", "chains", "gravestone", "coffin",
	"mushrooms", "crystals", "jungle_tree", "fern", "big_leaves", "vines", "ruin_pillar",
	"glow_flowers", "skull_totem") var kind := "skull_pile"
## Change to get a different random variant of the same kind.
@export var variant := 0


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = variant
	Props.spawn(kind, self, Vector3.ZERO, 0.0, rng, LevelTheme.of(self))
