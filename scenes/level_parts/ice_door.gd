class_name IceDoor
extends StaticBody3D
## A wall of ice. Only fire magic can melt it.

@export var width := 8.0
@export var height := 6.0
@export var thickness := 1.2
## How much fire damage it takes to melt.
@export var melt_health := 80.0
## The "Fire Wizard: melt the door" sign. Secret ice walls have none.
@export var show_sign := true

var _hp := 80.0
var _ice: Node3D
var _mat: StandardMaterial3D
var _sign: Label3D
var _hint_cooldown := 0.0


func _ready() -> void:
	collision_layer = 1
	_hp = melt_health
	Build.collision_box(self, Vector3(width, height, thickness), Vector3(0, height * 0.5, 0))
	_ice = Build.pivot(self)
	_mat = Build.see_through(Color(0.55, 0.85, 1.0, 0.8), 0.6)
	Build.part(_ice, Build.box(Vector3(width, height, thickness)), _mat, Vector3(0, height * 0.5, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 9:
		var s := Vector3(rng.randf_range(0.8, 1.8), rng.randf_range(1.0, 2.6), rng.randf_range(0.4, 0.8))
		var pos := Vector3(rng.randf_range(-width * 0.45, width * 0.45), rng.randf_range(0.5, height - 0.6), thickness * 0.5)
		Build.part(_ice, Build.box(s), _mat, pos, Vector3(0, 0, rng.randf_range(-30, 30)))
		Build.part(_ice, Build.box(s), _mat, pos * Vector3(1, 1, -1), Vector3(0, 0, rng.randf_range(-30, 30)))
	Build.light(self, Color(0.5, 0.85, 1.0), 1.5, 8.0, Vector3(0, height * 0.5, thickness + 1.0))
	_sign = Build.label3d(self, "FIRE WIZARD:\nMelt the ice door!", Vector3(0, height - 0.6, thickness + 0.6), 44, Color(1.0, 0.7, 0.4))
	_sign.visible = show_sign


func _process(delta: float) -> void:
	_hint_cooldown = maxf(0.0, _hint_cooldown - delta)


func take_hit(p: Projectile) -> bool:
	if _hp <= 0.0 or p.team != "player":
		return true
	if p.element == "fire":
		_hp -= p.damage
		FX.burst(self, p.global_position, Color(0.9, 0.9, 1.0, 0.7), 12, 2.0, 0.8, 0.8,
			{"smoke": true, "gravity": Vector3(0, 2, 0)})
		var left := clampf(_hp / melt_health, 0.0, 1.0)
		_ice.scale = Vector3(lerpf(0.75, 1.0, left), lerpf(0.15, 1.0, left), lerpf(0.6, 1.0, left))
		_mat.albedo_color.a = lerpf(0.45, 0.8, left)
		if _hp <= 0.0:
			_melt()
	else:
		FX.burst(self, p.global_position, Color(0.7, 0.95, 1.0) * 2.0, 10, 3.0, 0.2, 0.4)
		if _hint_cooldown <= 0.0:
			_hint_cooldown = 4.0
			FX.float_text(self, p.global_position, "Ice can't melt ice!", Color(0.7, 0.92, 1.0), 56)
			if Game.instance and show_sign:
				Game.instance.toast("Fire Wizard, melt the ice door!", UIUtil.FIRE_COLOR)
	return true


func _melt() -> void:
	collision_layer = 0
	_sign.visible = false
	FX.burst(self, global_position + Vector3(0, height * 0.4, 0), Color(0.9, 0.9, 1.0, 0.7), 60, 4.0, 1.6, 1.5,
		{"smoke": true, "box": Vector3(width * 0.5, height * 0.4, 0.5), "gravity": Vector3(0, 2, 0)})
	FX.float_text(self, global_position + Vector3(0, height * 0.6, 0), "MELTED!", Color(1.0, 0.7, 0.3), 100)
	if Game.instance:
		Game.instance.toast("The ice door melted!", UIUtil.FIRE_COLOR)
	var tw := create_tween()
	tw.tween_property(_ice, "scale", Vector3(0.7, 0.01, 0.4), 0.6)
	tw.tween_callback(queue_free)
