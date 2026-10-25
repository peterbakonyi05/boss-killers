class_name IceDoor
extends StaticBody3D
## A wall of ice (or thorny jungle vines). Only fire magic can melt / burn it.

@export var width := 8.0
@export var height := 6.0
@export var thickness := 1.2
## How much fire damage it takes to melt.
@export var melt_health := 80.0
## The "Fire Wizard: melt the door" sign. Secret ice walls have none.
@export var show_sign := true
## "ice" = ice wall, "thorns" = wall of thorny vines (jungle levels).
@export_enum("ice", "thorns") var style := "ice"

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
	if style == "thorns":
		_build_thorns()
	else:
		_build_ice()
	var text := "FIRE WIZARD:\nBurn the thorns!" if style == "thorns" else "FIRE WIZARD:\nMelt the ice door!"
	_sign = Build.label3d(self, text, Vector3(0, height - 0.6, thickness + 0.6), 44, Color(1.0, 0.7, 0.4))
	_sign.visible = show_sign


func _build_ice() -> void:
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


## A tangle of thick vines with long thorns and a few leaves, dark green inside.
func _build_thorns() -> void:
	_mat = Build.mat(Color(0.05, 0.09, 0.03), 1.0)
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	Build.part(_ice, Build.box(Vector3(width, height, thickness * 0.5)), _mat, Vector3(0, height * 0.5, 0))
	var vine := Build.pbr("bark_brown_02", Color(0.45, 0.5, 0.3), 2.0, true)
	var thorn := Build.mat(Color(0.75, 0.68, 0.5), 0.6)
	var leaf := Build.mat(Color(0.15, 0.35, 0.08), 0.8)
	leaf.cull_mode = BaseMaterial3D.CULL_DISABLED
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in 16:
		var y := rng.randf_range(0.3, height - 0.3)
		var tilt := rng.randf_range(-40, 40)
		var z := rng.randf_range(-thickness * 0.4, thickness * 0.4)
		var length := width / cos(deg_to_rad(absf(tilt))) * 1.05
		var piece := Build.pivot(_ice, Vector3(0, y, z))
		piece.rotation_degrees.z = tilt
		Build.part(piece, Build.cylinder(rng.randf_range(0.08, 0.16), length), vine, Vector3.ZERO, Vector3(0, 0, 90))
		for k in 7:
			var x := rng.randf_range(-length * 0.45, length * 0.45)
			var side := 1.0 if rng.randf() < 0.5 else -1.0
			Build.part(piece, Build.cone(0.05, 0.3), thorn, Vector3(x, 0, side * 0.15), Vector3(side * 90, 0, rng.randf_range(-30, 30)))
		for k in 3:
			Build.part(piece, Build.sphere(0.22), leaf, Vector3(rng.randf_range(-length * 0.4, length * 0.4), 0.1, 0.12 * (1 if k % 2 == 0 else -1)),
				Vector3(rng.randf() * 360, 0, 0), Vector3(1.0, 0.12, 0.55))


func _process(delta: float) -> void:
	_hint_cooldown = maxf(0.0, _hint_cooldown - delta)


func take_hit(p: Projectile) -> bool:
	if _hp <= 0.0 or p.team != "player":
		return true
	if p.element == "fire":
		_hp -= p.damage
		var smoke := Color(0.25, 0.2, 0.15, 0.7) if style == "thorns" else Color(0.9, 0.9, 1.0, 0.7)
		FX.burst(self, p.global_position, smoke, 12, 2.0, 0.8, 0.8,
			{"smoke": true, "gravity": Vector3(0, 2, 0)})
		var left := clampf(_hp / melt_health, 0.0, 1.0)
		_ice.scale = Vector3(lerpf(0.75, 1.0, left), lerpf(0.15, 1.0, left), lerpf(0.6, 1.0, left))
		_mat.albedo_color.a = lerpf(0.45, 0.8 if style == "ice" else 1.0, left)
		if _hp <= 0.0:
			_melt()
	else:
		FX.burst(self, p.global_position, Color(0.7, 0.95, 1.0) * 2.0, 10, 3.0, 0.2, 0.4)
		if _hint_cooldown <= 0.0:
			_hint_cooldown = 4.0
			var hint := "Ice can't burn thorns!" if style == "thorns" else "Ice can't melt ice!"
			FX.float_text(self, p.global_position, hint, Color(0.7, 0.92, 1.0), 56)
			if Game.instance and show_sign:
				var ask := "Fire Wizard, burn the thorns!" if style == "thorns" else "Fire Wizard, melt the ice door!"
				Game.instance.toast(ask, UIUtil.FIRE_COLOR)
	return true


func _melt() -> void:
	collision_layer = 0
	_sign.visible = false
	var thorns := style == "thorns"
	FX.burst(self, global_position + Vector3(0, height * 0.4, 0), Color(0.25, 0.2, 0.15, 0.7) if thorns else Color(0.9, 0.9, 1.0, 0.7), 60, 4.0, 1.6, 1.5,
		{"smoke": true, "box": Vector3(width * 0.5, height * 0.4, 0.5), "gravity": Vector3(0, 2, 0)})
	if thorns:
		FX.burst(self, global_position + Vector3(0, height * 0.4, 0), Color(1.0, 0.5, 0.1) * 2.0, 50, 3.0, 0.15, 1.0,
			{"box": Vector3(width * 0.5, height * 0.4, 0.5), "direction": Vector3.UP, "spread": 40.0})
	FX.float_text(self, global_position + Vector3(0, height * 0.6, 0), "BURNED!" if thorns else "MELTED!", Color(1.0, 0.7, 0.3), 100)
	if Game.instance:
		Game.instance.toast("The thorns burned away!" if thorns else "The ice door melted!", UIUtil.FIRE_COLOR)
	var tw := create_tween()
	tw.tween_property(_ice, "scale", Vector3(0.7, 0.01, 0.4), 0.6)
	tw.tween_callback(queue_free)
