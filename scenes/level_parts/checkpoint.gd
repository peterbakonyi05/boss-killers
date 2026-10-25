class_name Checkpoint
extends Area3D
## Walk through it to save your spot. If both wizards fall, they come back here.

## The checkpoint where the level starts.
@export var start_active := false
## Width of the walk-through zone (across the path).
@export var zone_width := 8.0
## Where the glowing brazier stands, relative to the checkpoint.
@export var brazier_offset := Vector3(-3.0, 0, 0)

var active := false
var _flame: GPUParticles3D
var _light: OmniLight3D
var _gem_mat: StandardMaterial3D


func _ready() -> void:
	add_to_group("checkpoints")
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	Build.collision_box(self, Vector3(zone_width, 4.0, 2.5), Vector3(0, 2.0, 0))
	_build_brazier()
	body_entered.connect(_on_body_entered)
	_set_look(false)
	if start_active:
		active = true
		_set_look(true)


func _build_brazier() -> void:
	var base := StaticBody3D.new()
	base.position = brazier_offset
	add_child(base)
	Build.collision_box(base, Vector3(0.9, 1.4, 0.9), Vector3(0, 0.7, 0))
	var stone := Build.mat(Color(0.3, 0.27, 0.27), 0.95)
	Build.part(base, Build.cylinder(0.45, 0.25), stone, Vector3(0, 0.12, 0))
	Build.part(base, Build.cylinder(0.25, 0.9, 0.3), stone, Vector3(0, 0.65, 0))
	Build.part(base, Build.cylinder(0.5, 0.25, 0.35), stone, Vector3(0, 1.2, 0))
	_gem_mat = Build.glow(Color(1.0, 0.85, 0.4), 1.0)
	Build.part(base, Build.sphere(0.18), _gem_mat, Vector3(0, 1.4, 0))
	_flame = FX.particles(Color(1.0, 0.8, 0.35) * 2.0, 30, 0.8, 0.45,
		{"direction": Vector3.UP, "spread": 15.0, "speed_min": 1.0, "speed_max": 2.0, "radius": 0.2})
	_flame.position = Vector3(0, 1.4, 0)
	base.add_child(_flame)
	_light = Build.light(base, Color(1.0, 0.8, 0.45), 1.0, 8.0, Vector3(0, 2.0, 0))


func _set_look(on: bool) -> void:
	_flame.emitting = on
	_light.light_energy = 2.5 if on else 0.3
	_gem_mat.emission_energy_multiplier = 4.0 if on else 0.4


func _on_body_entered(body: Node3D) -> void:
	if active or not body is Wizard or (body as Wizard).is_down:
		return
	activate()


func activate() -> void:
	active = true
	_set_look(true)
	FX.burst(self, global_position + brazier_offset + Vector3(0, 1.5, 0), Color(1.0, 0.85, 0.4) * 2.0, 40, 5.0, 0.3, 0.8)
	if Game.instance:
		Game.instance.set_checkpoint(self)


## Where wizard 0 or 1 appears after both fall.
func spawn_point(index: int) -> Vector3:
	var side := -1.2 if index == 0 else 1.2
	return global_position + global_basis.x * side + Vector3(0, 0.3, 0)
