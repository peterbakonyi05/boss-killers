class_name LavaPool
extends Node3D
## A lake of lava under walkways. Wizards that fall in get hurt and pop back to
## safe ground; monsters burn up. The origin is the middle of the lava surface.

@export var size := Vector2(20, 20)
## How far below the surface the solid bottom is.
@export var depth := 1.0

var _lava_mat: StandardMaterial3D


func _ready() -> void:
	_lava_mat = Build.lava_material()
	# A big lake glows a lot more than a narrow trench, so it is dimmer.
	_lava_mat.emission_energy_multiplier = 0.7
	var plane := PlaneMesh.new()
	plane.size = size
	var lava := Build.part(self, plane, _lava_mat)
	lava.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# A few lights spread over the lake so the whole cave glows.
	var count := maxi(1, int(round(size.y / 14.0)))
	for i in count:
		var z := lerpf(-size.y * 0.5, size.y * 0.5, (i + 0.5) / count)
		Build.light(self, Color(1.0, 0.4, 0.1), 1.5, 16.0, Vector3(0, 3.0, z))
	var embers := FX.particles(Color(1.0, 0.5, 0.1) * 2.0, 80, 3.0, 0.18,
		{"direction": Vector3.UP, "spread": 20.0, "speed_min": 1.0, "speed_max": 2.5,
		"box": Vector3(size.x * 0.5, 0.1, size.y * 0.5)})
	embers.position = Vector3(0, 0.1, 0)
	embers.visibility_aabb = AABB(Vector3(-size.x, -2, -size.y), Vector3(size.x * 2, 10, size.y * 2))
	add_child(embers)
	embers.emitting = true
	var bottom := StaticBody3D.new()
	bottom.add_to_group("unsafe_ground")
	add_child(bottom)
	Build.collision_box(bottom, Vector3(size.x, 1.0, size.y), Vector3(0, -depth - 0.5, 0))
	var kill := Area3D.new()
	kill.collision_layer = 0
	kill.collision_mask = 2 | 4
	add_child(kill)
	Build.collision_box(kill, Vector3(size.x, 1.4, size.y), Vector3(0, -0.3, 0))
	kill.body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_lava_mat.uv1_offset += Vector3(0.02, 0.03, 0) * delta


func _on_body_entered(body: Node3D) -> void:
	if body.has_method("fall_in_lava"):
		FX.burst(self, body.global_position, Color(1.0, 0.5, 0.1) * 2.0, 30, 5.0, 0.3, 0.6)
		body.call_deferred("fall_in_lava")
