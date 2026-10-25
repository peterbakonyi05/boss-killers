class_name Gate
extends StaticBody3D
## Iron bars that rise out of the floor to lock an arena.

@export var width := 8.0
@export var height := 6.0
@export var start_closed := false

var closed := false
var _closed_y := 0.0
var _rune_mat: StandardMaterial3D
var _tween: Tween


func _ready() -> void:
	add_to_group("gates")
	collision_layer = 1
	_closed_y = position.y
	Build.collision_box(self, Vector3(width, height, 0.6), Vector3(0, height * 0.5, 0))
	var iron := Build.pbr("rusty_metal_02", Color(0.42, 0.38, 0.38), 1.5, true)
	iron.metallic = 0.6
	_rune_mat = Build.glow(Color(1.0, 0.2, 0.1), 3.0)
	var bars := int(width / 0.7)
	for i in bars + 1:
		var x := -width * 0.5 + i * (width / bars)
		Build.part(self, Build.cylinder(0.08, height), iron, Vector3(x, height * 0.5, 0))
		Build.part(self, Build.cone(0.12, 0.35), iron, Vector3(x, height + 0.15, 0))
	for y in [0.6, height * 0.5, height - 0.4]:
		Build.part(self, Build.box(Vector3(width, 0.18, 0.25)), iron, Vector3(0, y, 0))
	Build.part(self, Build.box(Vector3(width * 0.8, 0.08, 0.3)), _rune_mat, Vector3(0, height * 0.5, 0))
	# Iron skull crest with glowing eyes on both sides
	for z in [-0.2, 0.2]:
		var crest := Build.pivot(self, Vector3(0, height - 0.4, z))
		crest.rotation.y = 0.0 if z < 0.0 else PI
		Build.part(crest, Build.sphere(0.3), iron, Vector3(0, 0.05, 0), Vector3.ZERO, Vector3(1.0, 1.0, 0.6))
		Build.part(crest, Build.box(Vector3(0.36, 0.18, 0.2)), iron, Vector3(0, -0.22, 0))
		for side in [-1.0, 1.0]:
			Build.part(crest, Build.sphere(0.06), _rune_mat, Vector3(side * 0.11, 0.05, -0.16))
	closed = start_closed
	position.y = _closed_y if closed else _open_y()


func _open_y() -> float:
	return _closed_y - height - 0.3


func close() -> void:
	_move(true)


func open() -> void:
	_move(false)


func _move(to_closed: bool) -> void:
	if closed == to_closed:
		return
	closed = to_closed
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "position:y", _closed_y if closed else _open_y(), 0.6 if closed else 1.2) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Dust where the bars come out of the floor.
	var floor_pos := global_position
	var parent := get_parent() as Node3D
	if parent:
		floor_pos = parent.to_global(Vector3(position.x, _closed_y, position.z))
	FX.burst(self, floor_pos + Vector3(0, 0.3, 0), Color(0.4, 0.35, 0.35, 0.8), 16, 3.0, 1.0, 0.8,
		{"smoke": true, "box": Vector3(width * 0.5, 0.2, 0.3)})
