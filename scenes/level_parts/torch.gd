class_name Torch
extends Node3D
## A wall torch with a flickering flame and light. Uses the level theme's flame color
## and flicker unless `color` is changed on the instance.

const DEFAULT_COLOR := Color(1.0, 0.55, 0.2)

@export var color := DEFAULT_COLOR
@export var energy := 2.2
@export var light_range := 10.0
@export var shadows := false

var _light: OmniLight3D
var _flame: GPUParticles3D
var _time := 0.0
var _flicker := 0.5
## Seconds until the flame next gutters (almost goes out for a moment).
var _gutter_in := 0.0
var _gutter := 0.0


func _ready() -> void:
	_time = randf() * 100.0
	var theme := LevelTheme.of(self)
	if theme:
		_flicker = theme.torch_flicker
		if color == DEFAULT_COLOR:
			color = theme.torch_color
	_gutter_in = randf_range(4.0, 14.0)
	var iron := Build.pbr("rusty_metal_02", Color(0.45, 0.42, 0.4), 3.0, false)
	var wood := Build.pbr("wood_planks", Color(0.5, 0.35, 0.25), 3.0, false)
	# Wooden handle wrapped in cloth, iron basket with glowing coals
	Build.part(self, Build.cylinder(0.05, 0.7, 0.07), wood, Vector3(0, 0, 0))
	Build.part(self, Build.cylinder(0.08, 0.12), Build.pbr("denim_fabric_03", Color(0.4, 0.3, 0.2), 4.0, false), Vector3(0, 0.25, 0))
	for k in 6:
		var a := k * TAU / 6.0
		Build.part(self, Build.box(Vector3(0.025, 0.22, 0.025)), iron, Vector3(cos(a) * 0.13, 0.42, sin(a) * 0.13), Vector3(sin(a) * 18.0, 0, -cos(a) * 18.0))
	Build.part(self, Build.torus(0.14, 0.17), iron, Vector3(0, 0.52, 0))
	Build.part(self, Build.sphere(0.12), Build.glow(color, 4.0), Vector3(0, 0.45, 0), Vector3.ZERO, Vector3(1, 0.6, 1))
	_flame = FX.particles(color * 2.0, 28, 0.6, 0.35,
		{"direction": Vector3.UP, "spread": 12.0, "speed_min": 0.8, "speed_max": 1.6, "radius": 0.08})
	_flame.position = Vector3(0, 0.5, 0)
	add_child(_flame)
	_flame.emitting = true
	var smoke := FX.particles(Color(0.12, 0.1, 0.1, 0.35), 8, 1.6, 0.5,
		{"direction": Vector3.UP, "spread": 10.0, "speed_min": 0.5, "speed_max": 0.9, "radius": 0.06, "smoke": true})
	smoke.position = Vector3(0, 0.9, 0)
	add_child(smoke)
	smoke.emitting = true
	_light = Build.light(self, color, energy, light_range, Vector3(0, 0.8, 0), shadows)


func _process(delta: float) -> void:
	_time += delta
	_gutter_in -= delta * _flicker
	if _gutter_in <= 0.0:
		_gutter_in = randf_range(6.0, 16.0)
		_gutter = 1.0
	_gutter = maxf(0.0, _gutter - delta * 1.6)
	var dip := sin(_gutter * PI) * 0.75
	var wobble := 1.0 + _flicker * (0.2 * sin(_time * 11.0) + 0.1 * sin(_time * 23.0) - 0.1)
	_light.light_energy = energy * wobble * (1.0 - dip)
	_flame.scale = Vector3.ONE * (1.0 - dip * 0.8)
