class_name CameraRig
extends Node3D
## Third-person camera for one player. Right stick turns it (Q/Z or ,/. on keyboard).

const TURN_SPEED := 2.8
const PITCH_SPEED := 1.8
const MIN_PITCH := -1.05
const MAX_PITCH := 0.3
const FOLLOW_SHARPNESS := 14.0
const HEAD_HEIGHT := 1.7

@export var player_index := 0

var target: Node3D
var yaw := 0.0
var pitch := -0.32
var _shake := 0.0

@onready var _pitch_node: Node3D = $Pitch
@onready var _arm: SpringArm3D = $Pitch/SpringArm3D
@onready var camera: Camera3D = $Pitch/SpringArm3D/Camera3D


func _ready() -> void:
	camera.current = true


func follow(node: Node3D) -> void:
	target = node
	if target is CollisionObject3D:
		_arm.add_excluded_object((target as CollisionObject3D).get_rid())
	snap()


func set_yaw(value: float) -> void:
	yaw = value
	rotation.y = yaw


## Jump straight to the target (after a teleport).
func snap() -> void:
	if target:
		global_position = target.global_position + Vector3(0, HEAD_HEIGHT, 0)


## Small screen shake when the wizard gets hit.
func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


func get_yaw() -> float:
	return yaw


func _process(delta: float) -> void:
	var look := PlayerInput.get_look(player_index)
	yaw -= look.x * TURN_SPEED * delta
	pitch = clampf(pitch - look.y * PITCH_SPEED * delta, MIN_PITCH, MAX_PITCH)
	rotation.y = yaw
	_pitch_node.rotation.x = pitch
	if target:
		var goal := target.global_position + Vector3(0, HEAD_HEIGHT, 0)
		global_position = global_position.lerp(goal, 1.0 - exp(-FOLLOW_SHARPNESS * delta))
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 1.5)
		camera.h_offset = randf_range(-1.0, 1.0) * _shake * 0.3
		camera.v_offset = randf_range(-1.0, 1.0) * _shake * 0.3
	else:
		camera.h_offset = 0.0
		camera.v_offset = 0.0
