class_name BreakableWall
extends StaticBody3D
## A cracked rock wall that hides a secret. A few hits of any magic break it.
## The glowing cracks are the only hint that something is behind it.

@export var width := 3.0
@export var height := 6.0
@export var thickness := 1.0
## How much spell damage it takes to break.
@export var break_health := 50.0

var _hp := 50.0
var _rock: Node3D
var _crack_mat: StandardMaterial3D
var _shake := 0.0


func _ready() -> void:
	collision_layer = 1
	_hp = break_health
	Build.collision_box(self, Vector3(width, height, thickness), Vector3(0, height * 0.5, 0))
	_rock = Build.pivot(self)
	var stone := Build.mat(Color(0.4, 0.31, 0.3), 0.95)
	Build.part(_rock, Build.box(Vector3(width, height, thickness)), stone, Vector3(0, height * 0.5, 0))
	_crack_mat = Build.glow(Color(1.0, 0.55, 0.2), 0.8)
	# A zig-zag crack up both faces.
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for face in [-1.0, 1.0]:
		var pos := Vector2(0.0, 0.4)
		while pos.y < height * 0.7:
			var length := rng.randf_range(0.4, 0.8)
			var angle := rng.randf_range(-45.0, 45.0)
			var step := Vector2(-sin(deg_to_rad(angle)), cos(deg_to_rad(angle))) * length
			var mid := pos + step * 0.5
			Build.part(_rock, Build.box(Vector3(0.07, length, 0.02)), _crack_mat,
				Vector3(mid.x, mid.y, face * (thickness * 0.5 + 0.01)), Vector3(0, 0, angle))
			pos += step
			pos.x = clampf(pos.x, -width * 0.35, width * 0.35)


func _process(delta: float) -> void:
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta)
		_rock.position = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)) * _shake * 0.3
	else:
		_rock.position = Vector3.ZERO


func take_hit(p: Projectile) -> bool:
	if _hp <= 0.0 or p.team != "player":
		return true
	_hp -= p.damage
	_shake = 0.25
	_crack_mat.emission_energy_multiplier = lerpf(4.0, 0.8, clampf(_hp / break_health, 0.0, 1.0))
	FX.burst(self, p.global_position, Color(0.45, 0.38, 0.35, 0.8), 10, 2.5, 0.6, 0.7, {"smoke": true})
	if _hp <= 0.0:
		_crumble()
	return true


func _crumble() -> void:
	collision_layer = 0
	FX.burst(self, global_position + Vector3(0, height * 0.4, 0), Color(0.45, 0.38, 0.35, 0.9), 50, 4.0, 1.4, 1.4,
		{"smoke": true, "box": Vector3(width * 0.5, height * 0.4, 0.4), "gravity": Vector3(0, -3, 0)})
	FX.burst(self, global_position + Vector3(0, height * 0.4, 0), Color(1.0, 0.55, 0.2) * 2.0, 30, 6.0, 0.25, 0.8,
		{"box": Vector3(width * 0.5, height * 0.4, 0.4), "gravity": Vector3(0, -12, 0)})
	FX.float_text(self, global_position + Vector3(0, height * 0.6, 0), "SECRET PASSAGE!", UIUtil.GOLD, 90)
	if Game.instance:
		Game.instance.toast("You found a secret passage!", UIUtil.GOLD)
	var tw := create_tween()
	tw.tween_property(_rock, "scale", Vector3(1.1, 0.01, 1.1), 0.5)
	tw.tween_callback(queue_free)
