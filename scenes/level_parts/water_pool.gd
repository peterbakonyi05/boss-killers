class_name WaterPool
extends Node3D
## Dark jungle water under walkways and stepping stones. Wizards that fall in get
## bitten by piranhas and pop back to safe ground. Crocodiles and piranhas live in it.
## The origin is the middle of the water surface.

@export var size := Vector2(20, 20)
## How far below the surface the solid bottom is.
@export var depth := 1.5

var _water_mat: StandardMaterial3D


func _ready() -> void:
	_water_mat = Build.water_material()
	var plane := PlaneMesh.new()
	plane.size = size
	var water := Build.part(self, plane, _water_mat)
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Swamp mist and little bubbles rising from below.
	var mist := FX.particles(Color(0.6, 0.8, 0.7, 0.1), 16, 7.0, 2.5,
		{"smoke": true, "spread": 180.0, "speed_min": 0.05, "speed_max": 0.2,
		"box": Vector3(size.x * 0.5, 0.1, size.y * 0.5)})
	mist.position = Vector3(0, 0.3, 0)
	mist.visibility_aabb = AABB(Vector3(-size.x, -2, -size.y), Vector3(size.x * 2, 6, size.y * 2))
	add_child(mist)
	mist.emitting = true
	var bubbles := FX.particles(Color(0.7, 0.95, 0.85, 0.7), 24, 1.2, 0.06,
		{"direction": Vector3.UP, "spread": 10.0, "speed_min": 0.2, "speed_max": 0.5,
		"box": Vector3(size.x * 0.5, 0.05, size.y * 0.5)})
	bubbles.position = Vector3(0, 0.02, 0)
	bubbles.visibility_aabb = mist.visibility_aabb
	add_child(bubbles)
	bubbles.emitting = true
	var bottom := StaticBody3D.new()
	bottom.add_to_group("unsafe_ground")
	add_child(bottom)
	Build.collision_box(bottom, Vector3(size.x, 1.0, size.y), Vector3(0, -depth - 0.5, 0))
	# Only wizards fall in: the monsters living here must not drown.
	var bite := Area3D.new()
	bite.collision_layer = 0
	bite.collision_mask = 2
	add_child(bite)
	Build.collision_box(bite, Vector3(size.x, 1.0, size.y), Vector3(0, -0.6, 0))
	bite.body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_water_mat.uv1_offset += Vector3(0.01, 0.015, 0) * delta


func _on_body_entered(body: Node3D) -> void:
	if body.has_method("fall_in_water"):
		FX.burst(self, body.global_position + Vector3(0, 0.3, 0), Color(0.75, 0.95, 0.9, 0.8), 30, 4.0, 0.15, 0.6,
			{"direction": Vector3.UP, "spread": 45.0, "gravity": Vector3(0, -9, 0)})
		body.call_deferred("fall_in_water")
