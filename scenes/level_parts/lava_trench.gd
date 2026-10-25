class_name LavaTrench
extends Node3D
## A gap full of lava. The ice wizard shoots ice over it to freeze a bridge for a while.
## Leave a gap in the floor where this sits. The origin is the middle of the gap at floor height.

## Length of the gap (along the path, local Z).
@export var length := 8.0
## Width of the gap (across the path, local X).
@export var width := 8.0
@export var depth := 1.8
## Seconds the ice bridge lasts.
@export var bridge_time := 15.0

var frozen := false
var _bridge: StaticBody3D
var _bridge_mesh: MeshInstance3D
var _bridge_mat: StandardMaterial3D
var _lava_mat: StandardMaterial3D
var _lava_light: OmniLight3D
var _ice_light: OmniLight3D
var _time_left := 0.0
var _sign: Label3D


func _ready() -> void:
	_build_pit()
	_build_lava()
	_build_bridge()
	_build_freeze_zone()
	_sign = Build.label3d(self, "ICE WIZARD:\nShoot ice at the lava\nto make a bridge!", Vector3(0, 3.6, length * 0.5 + 1.0), 56, Color(0.7, 0.92, 1.0))


func _build_pit() -> void:
	var rock := Build.mat(Color(0.2, 0.12, 0.1), 0.95)
	var body := StaticBody3D.new()
	add_child(body)
	# Front and back walls of the pit, and the side walls.
	for z in [-1.0, 1.0]:
		var pos := Vector3(0, -depth * 0.5 - 0.5, z * (length * 0.5 + 0.5))
		var s := Vector3(width + 2.0, depth + 1.0, 1.0)
		Build.part(body, Build.box(s), rock, pos)
		Build.collision_box(body, s, pos)
	for x in [-1.0, 1.0]:
		var pos := Vector3(x * (width * 0.5 + 0.5), -depth * 0.5, 0)
		var s := Vector3(1.0, depth + 2.0, length + 2.0)
		Build.part(body, Build.box(s), rock, pos)
		Build.collision_box(body, s, pos)
	var bottom_pos := Vector3(0, -depth - 0.5, 0)
	Build.collision_box(body, Vector3(width, 1.0, length), bottom_pos)


func _build_lava() -> void:
	var noise := FastNoiseLite.new()
	noise.frequency = 0.04
	var tex := NoiseTexture2D.new()
	tex.noise = noise
	tex.seamless = true
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.5, 0.05, 0.0))
	ramp.set_color(1, Color(1.0, 0.75, 0.2))
	tex.color_ramp = ramp
	_lava_mat = StandardMaterial3D.new()
	_lava_mat.albedo_texture = tex
	_lava_mat.emission_enabled = true
	_lava_mat.emission_texture = tex
	_lava_mat.emission = Color(1, 1, 1)
	_lava_mat.emission_energy_multiplier = 1.6
	_lava_mat.uv1_scale = Vector3(2, 2, 2)
	var plane := PlaneMesh.new()
	plane.size = Vector2(width, length)
	var lava := Build.part(self, plane, _lava_mat, Vector3(0, -depth + 0.3, 0))
	lava.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_lava_light = Build.light(self, Color(1.0, 0.4, 0.1), 5.0, 14.0, Vector3(0, 0.8, 0))
	var embers := FX.particles(Color(1.0, 0.5, 0.1) * 2.0, 60, 2.5, 0.18,
		{"direction": Vector3.UP, "spread": 20.0, "speed_min": 1.5, "speed_max": 3.0,
		"box": Vector3(width * 0.5, 0.1, length * 0.5)})
	embers.position = Vector3(0, -depth + 0.4, 0)
	add_child(embers)
	embers.emitting = true
	# Falling in sends you back to the edge.
	var kill := Area3D.new()
	kill.collision_layer = 0
	kill.collision_mask = 2 | 4
	add_child(kill)
	Build.collision_box(kill, Vector3(width, 1.6, length), Vector3(0, -depth + 0.6, 0))
	kill.body_entered.connect(_on_lava_entered)


func _build_bridge() -> void:
	_bridge = StaticBody3D.new()
	_bridge.add_to_group("unsafe_ground")
	_bridge.collision_layer = 0
	add_child(_bridge)
	var s := Vector3(width, 0.5, length + 1.0)
	Build.collision_box(_bridge, s, Vector3(0, -0.25, 0))
	_bridge_mat = Build.see_through(Color(0.6, 0.9, 1.0, 0.85), 0.7)
	_bridge_mesh = Build.part(_bridge, Build.box(s), _bridge_mat, Vector3(0, -0.25, 0))
	# Some ice spikes along the sides.
	for i in 6:
		var z := lerpf(-length * 0.5, length * 0.5, i / 5.0)
		Build.part(_bridge, Build.cone(0.25, 0.9), _bridge_mat, Vector3(-width * 0.5 + 0.3, 0.3, z))
		Build.part(_bridge, Build.cone(0.25, 0.9), _bridge_mat, Vector3(width * 0.5 - 0.3, 0.3, z))
	_ice_light = Build.light(_bridge, Color(0.5, 0.85, 1.0), 2.0, 10.0, Vector3(0, 1.0, 0))
	_bridge.visible = false


func _build_freeze_zone() -> void:
	# Ice spells flying over the lava hit this invisible box.
	var zone: Area3D = preload("res://scenes/level_parts/element_target.gd").new()
	zone.set("handler", _on_spell_hit)
	zone.collision_layer = 32
	zone.collision_mask = 0
	zone.monitoring = false
	add_child(zone)
	Build.collision_box(zone, Vector3(width, 4.0, length), Vector3(0, 0.5, 0))


func _on_spell_hit(p: Projectile) -> bool:
	if p.element != "ice":
		return false
	freeze(p.global_position)
	return true


func freeze(hit_pos := Vector3.INF) -> void:
	var was_frozen := frozen
	frozen = true
	_time_left = bridge_time
	_bridge.collision_layer = 1
	_bridge.visible = true
	_bridge_mat.albedo_color.a = 0.85
	_lava_light.light_energy = 1.5
	if hit_pos != Vector3.INF:
		FX.burst(self, hit_pos, Color(0.7, 0.95, 1.0) * 2.0, 30, 5.0, 0.3, 0.6)
	if not was_frozen:
		_bridge.scale = Vector3(1, 0.1, 1)
		create_tween().tween_property(_bridge, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		FX.burst(self, global_position, Color(0.7, 0.95, 1.0) * 2.0, 80, 6.0, 0.4, 1.0,
			{"box": Vector3(width * 0.5, 0.2, length * 0.5)})
		FX.float_text(self, global_position + Vector3(0, 1.5, 0), "ICE BRIDGE!", Color(0.7, 0.95, 1.0), 90)
		_sign.visible = false
		if Game.instance:
			Game.instance.toast("Ice bridge! Cross before it melts!", Color(0.6, 0.9, 1.0))


func _melt() -> void:
	frozen = false
	_bridge.collision_layer = 0
	_bridge.visible = false
	_lava_light.light_energy = 5.0
	_sign.visible = true
	FX.burst(self, global_position, Color(0.85, 0.85, 0.9, 0.7), 40, 3.0, 1.2, 1.2,
		{"smoke": true, "box": Vector3(width * 0.5, 0.2, length * 0.5), "gravity": Vector3(0, 2, 0)})


func _process(delta: float) -> void:
	_lava_mat.uv1_offset += Vector3(0.03, 0.05, 0) * delta
	if not frozen:
		return
	_time_left -= delta
	# Blink in the last seconds so players know it is melting.
	if _time_left < 3.0:
		var blink := 0.5 + 0.5 * sin(_time_left * 14.0)
		_bridge_mat.albedo_color.a = lerpf(0.3, 0.85, blink)
		_ice_light.light_energy = lerpf(0.5, 2.0, blink)
	if _time_left <= 0.0:
		_melt()


func _on_lava_entered(body: Node3D) -> void:
	if body.has_method("fall_in_lava"):
		FX.burst(self, body.global_position, Color(1.0, 0.5, 0.1) * 2.0, 30, 5.0, 0.3, 0.6)
		body.call_deferred("fall_in_lava")
