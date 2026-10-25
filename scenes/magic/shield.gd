class_name Shield
extends Area3D
## Magic bubble around a wizard. Blocks damage and enemy projectiles while it is up.

var wizard: Node3D
var block := 0.0
var strong := false
var _up := false
var _shape: CollisionShape3D
var _mesh: MeshInstance3D
var _mat: ShaderMaterial
var _tween: Tween
var _flash := 0.0
var _base_strength := 1.0


func _ready() -> void:
	collision_layer = 16
	collision_mask = 0
	monitoring = false
	monitorable = true
	_shape = Build.collision_sphere(self, 1.0)
	_shape.disabled = true
	_mesh = MeshInstance3D.new()
	_mesh.mesh = Build.sphere(1.0)
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh)
	visible = false


func is_up() -> bool:
	return _up


## pattern: see FX.bubble_material (1 = flames, 2 = ice crystals).
func raise(color: Color, radius: float, block_amount: float, is_strong: bool, pattern := 0) -> void:
	_up = true
	block = block_amount
	strong = is_strong
	_base_strength = 1.3 if is_strong else 0.8
	_mat = FX.bubble_material(color, _base_strength, pattern)
	_mesh.material_override = _mat
	_shape.set_deferred("disabled", false)
	visible = true
	if _tween:
		_tween.kill()
	scale = Vector3.ONE * 0.3
	_tween = create_tween()
	# The collision sphere has radius 1, so scaling the shield sets its size.
	_tween.tween_property(self, "scale", Vector3.ONE * radius, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func drop() -> void:
	if not _up:
		return
	_up = false
	_shape.set_deferred("disabled", true)
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "scale", Vector3.ONE * 0.2, 0.15)
	_tween.tween_callback(func() -> void: visible = false)


## Called when something hits the shield.
func on_block(hit_position: Vector3) -> void:
	_flash = 1.0
	if _mat:
		FX.burst(self, hit_position, (_mat.get_shader_parameter("color") as Color) * 2.0, 14, 4.0, 0.2, 0.4)


func _process(delta: float) -> void:
	if _flash > 0.0 and _mat:
		_flash = maxf(0.0, _flash - delta * 4.0)
		_mat.set_shader_parameter("strength", _base_strength + _flash * 2.0)
