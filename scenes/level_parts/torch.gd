extends Node3D
## A wall torch with a flickering flame and light.

@export var color := Color(1.0, 0.55, 0.2)
@export var energy := 2.2
@export var light_range := 10.0
@export var shadows := false

var _light: OmniLight3D
var _time := 0.0


func _ready() -> void:
	_time = randf() * 100.0
	var iron := Build.mat(Color(0.15, 0.13, 0.12), 0.6, 0.7)
	Build.part(self, Build.cylinder(0.06, 0.7, 0.1), Build.mat(Color(0.3, 0.18, 0.1), 0.9), Vector3(0, 0, 0))
	Build.part(self, Build.cylinder(0.16, 0.18, 0.12), iron, Vector3(0, 0.38, 0))
	Build.part(self, Build.sphere(0.12), Build.glow(color, 4.0), Vector3(0, 0.5, 0))
	var flame := FX.particles(color * 2.0, 24, 0.6, 0.35,
		{"direction": Vector3.UP, "spread": 12.0, "speed_min": 0.8, "speed_max": 1.6, "radius": 0.08})
	flame.position = Vector3(0, 0.5, 0)
	add_child(flame)
	flame.emitting = true
	_light = Build.light(self, color, energy, light_range, Vector3(0, 0.8, 0), shadows)


func _process(delta: float) -> void:
	_time += delta
	_light.light_energy = energy * (0.85 + 0.1 * sin(_time * 11.0) + 0.05 * sin(_time * 23.0))
