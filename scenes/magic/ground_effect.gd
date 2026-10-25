class_name GroundEffect
extends Node3D
## A patch a strong spell leaves on the floor for a few seconds.
## Fire pool: monsters standing in it burn. Frost patch: monsters in it slow down
## (and freeze if they stay too long). Never hurts wizards, has no collision.

var kind := "fire_pool"
var radius := 1.6
var time := 3.0
## Fire pool: damage per second. Frost patch: slow stacks per second.
var power := 3.0
var spell: SpellData
var caster: Node3D

var _left := 0.0
var _tick := 0.0
var _mat: ShaderMaterial
var _light: OmniLight3D


## Puts an effect on the floor under pos (nothing if there is no floor close below).
static func spawn(from: Node, pos: Vector3, setup: Dictionary) -> GroundEffect:
	var parent := FX.world(from)
	if parent == null:
		return null
	var q := PhysicsRayQueryParameters3D.create(pos + Vector3(0, 0.5, 0), pos + Vector3(0, -3.0, 0), 1)
	var hit := parent.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return null
	var g := GroundEffect.new()
	for key in setup:
		g.set(key, setup[key])
	parent.add_child(g)
	g.global_position = (hit["position"] as Vector3) + Vector3(0, 0.03, 0)
	return g


func _ready() -> void:
	add_to_group("ground_effects")
	_left = time
	var fire := kind == "fire_pool"
	var color := spell.color if spell else (Color(1, 0.4, 0.1) if fire else Color(0.6, 0.9, 1))
	var disc := CylinderMesh.new()
	disc.top_radius = radius
	disc.bottom_radius = radius
	disc.height = 0.04
	disc.radial_segments = 24
	if fire:
		_mat = SpellVisuals.flame_material(Color(1.0, 0.8, 0.3), color, 1.0)
		Build.part(self, disc, _mat).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var flames := FX.particles(color * 2.0, int(12 * radius), 0.7, 0.4,
			{"direction": Vector3.UP, "spread": 10.0, "speed_min": 0.8, "speed_max": 1.8, "box": Vector3(radius * 0.7, 0.05, radius * 0.7)})
		add_child(flames)
		flames.emitting = true
		SpellVisuals.scorch(self, global_position, radius * 2.4)
	else:
		_mat = SpellVisuals.ice_material(color, 0.5)
		Build.part(self, disc, _mat).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var rng := RandomNumberGenerator.new()
		for i in int(radius * 5.0):
			var a := rng.randf() * TAU
			var d := sqrt(rng.randf()) * radius * 0.9
			var h := rng.randf_range(0.15, 0.45)
			var spike := CylinderMesh.new()
			spike.radial_segments = 5
			spike.rings = 1
			spike.top_radius = 0.0
			spike.bottom_radius = h * 0.25
			spike.height = h
			Build.part(self, spike, _mat, Vector3(cos(a) * d, h * 0.4, sin(a) * d),
				Vector3(rng.randf_range(-25, 25), 0, rng.randf_range(-25, 25))).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var mist := FX.particles(Color(0.8, 0.95, 1.0, 0.3), int(6 * radius), 1.5, 0.8,
			{"smoke": true, "speed_min": 0.05, "speed_max": 0.2, "box": Vector3(radius * 0.7, 0.05, radius * 0.7)})
		add_child(mist)
		mist.emitting = true
	_light = Build.light(self, color, 1.2, radius * 3.0, Vector3(0, 0.6, 0))
	scale = Vector3(0.2, 1, 0.2)
	create_tween().tween_property(self, "scale", Vector3.ONE, 0.2).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	_left -= delta
	if _left < 0.5:
		var f := maxf(0.0, _left / 0.5)
		_mat.set_shader_parameter("fade", f)
		_light.light_energy = 1.2 * f
	if _left <= 0.0:
		queue_free()
		return
	_tick -= delta
	if _tick > 0.0:
		return
	var fire := kind == "fire_pool"
	_tick = 0.5 if fire else 1.0
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Node3D
		if e == null or not e.has_method("hit") or e.get("dead") == true:
			continue
		var d := e.global_position - global_position
		if Vector2(d.x, d.z).length() > radius + 0.4 or absf(d.y) > 1.5:
			continue
		if fire:
			e.hit(power * _tick, "fire", spell, 0, caster)
		else:
			e.hit(0.0, "ice", spell, int(round(power * _tick)), caster)
