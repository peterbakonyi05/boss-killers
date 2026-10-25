class_name ExitPortal
extends Node3D
## The way out. It opens when the team has every item the level needs.
## Both wizards must stand in it to finish the level.

var active := false
var _inside: Array[Wizard] = []
var _ring_mat: StandardMaterial3D
var _swirl_mat: StandardMaterial3D
var _swirl: MeshInstance3D
var _light: OmniLight3D
var _particles: GPUParticles3D
var _label: Label3D


func _ready() -> void:
	add_to_group("portals")
	var stone := Build.mat(Color(0.25, 0.22, 0.26), 0.9)
	var base := StaticBody3D.new()
	add_child(base)
	Build.part(base, Build.cylinder(2.6, 0.4), stone, Vector3(0, 0.2, 0))
	Build.collision_box(base, Vector3(4.6, 0.4, 4.6), Vector3(0, 0.2, 0))
	_ring_mat = Build.glow(Color(0.4, 0.38, 0.45), 0.3)
	Build.part(self, Build.torus(1.8, 2.3), _ring_mat, Vector3(0, 2.6, 0), Vector3(90, 0, 0))
	var noise := FastNoiseLite.new()
	noise.frequency = 0.03
	var tex := NoiseTexture2D.new()
	tex.noise = noise
	tex.seamless = true
	_swirl_mat = StandardMaterial3D.new()
	_swirl_mat.albedo_texture = tex
	_swirl_mat.emission_enabled = true
	_swirl_mat.emission_texture = tex
	_swirl_mat.emission = Color(0.55, 0.2, 0.9)
	_swirl_mat.emission_energy_multiplier = 0.0
	_swirl_mat.albedo_color = Color(0.1, 0.05, 0.12)
	_swirl_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_swirl_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_swirl = Build.part(self, Build.cylinder(1.85, 0.05), _swirl_mat, Vector3(0, 2.6, 0), Vector3(90, 0, 0))
	_light = Build.light(self, Color(0.7, 0.35, 1.0), 0.0, 10.0, Vector3(0, 2.6, 1.5))
	_particles = FX.particles(Color(0.8, 0.5, 1.0) * 2.0, 40, 1.5, 0.15,
		{"radius": 2.0, "speed_min": 0.2, "speed_max": 0.8, "gravity": Vector3(0, 0.5, 0)})
	_particles.position = Vector3(0, 2.6, 0)
	add_child(_particles)
	_particles.emitting = false
	_label = Build.label3d(self, "", Vector3(0, 5.4, 0), 40, Color(0.9, 0.8, 1.0))
	var zone := Area3D.new()
	zone.collision_layer = 0
	zone.collision_mask = 2
	add_child(zone)
	Build.collision_box(zone, Vector3(4.0, 4.0, 4.0), Vector3(0, 2.0, 0))
	zone.body_entered.connect(_on_body_entered)
	zone.body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node3D) -> void:
	var w := body as Wizard
	if w and not _inside.has(w):
		_inside.append(w)


func _on_body_exited(body: Node3D) -> void:
	var w := body as Wizard
	if w:
		_inside.erase(w)


func _process(delta: float) -> void:
	var game := Game.instance
	if game == null:
		return
	var should_be_active := game.has_all_items()
	if should_be_active != active:
		_set_active(should_be_active)
	if active:
		_swirl.rotate_object_local(Vector3.UP, delta * 1.5)
		_swirl_mat.uv1_offset += Vector3(0.1, 0.05, 0) * delta
		var standing := 0
		for w in _inside:
			if is_instance_valid(w) and not w.is_down:
				standing += 1
		var needed := game.wizards.size()
		_label.text = "EXIT PORTAL\nBoth wizards step in! (%d/%d)" % [standing, needed]
		if standing >= needed and needed > 0:
			game.finish_level()
	else:
		var names: Array[String] = []
		for id in game.missing_items():
			names.append(game.item_name(id).to_upper())
		_label.text = "EXIT PORTAL\nNeeds: %s" % " + ".join(names)


func _set_active(on: bool) -> void:
	active = on
	_ring_mat.albedo_color = Color(0.6, 0.3, 0.9) if on else Color(0.4, 0.38, 0.45)
	_ring_mat.emission = Color(0.7, 0.35, 1.0) if on else Color(0.4, 0.38, 0.45)
	_ring_mat.emission_energy_multiplier = 2.0 if on else 0.3
	_swirl_mat.emission_energy_multiplier = 0.9 if on else 0.0
	_swirl_mat.albedo_color = Color(0.35, 0.1, 0.55, 0.85) if on else Color(0.1, 0.05, 0.12)
	_light.light_energy = 3.0 if on else 0.0
	_particles.emitting = on
	if on:
		FX.burst(self, global_position + Vector3(0, 2.6, 0), Color(0.8, 0.5, 1.0) * 2.0, 80, 8.0, 0.3, 1.2)
