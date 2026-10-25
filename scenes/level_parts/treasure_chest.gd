class_name TreasureChest
extends StaticBody3D
## A chest full of coins. Walk up to it and press Square (interact) to open it.
## Chests in hidden places count as secrets on the level complete screen.

@export var money := 60
@export var secret := true

var opened := false
var _lid: Node3D
var _light: OmniLight3D
var _sparkles: GPUParticles3D


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("treasure")
	if secret:
		add_to_group("secrets")
	collision_layer = 1
	Build.collision_box(self, Vector3(1.2, 0.8, 0.8), Vector3(0, 0.4, 0))
	var wood := Build.mat(Color(0.35, 0.2, 0.1), 0.85)
	var gold := Build.glow(UIUtil.GOLD, 1.0)
	gold.metallic = 0.9
	Build.part(self, Build.box(Vector3(1.2, 0.6, 0.8)), wood, Vector3(0, 0.3, 0))
	for x in [-0.45, 0.45]:
		Build.part(self, Build.box(Vector3(0.08, 0.62, 0.82)), gold, Vector3(x, 0.3, 0))
	Build.part(self, Build.box(Vector3(1.0, 0.05, 0.6)), Build.glow(UIUtil.GOLD, 2.5), Vector3(0, 0.58, 0))
	# The lid swings open around a hinge at the back.
	_lid = Build.pivot(self, Vector3(0, 0.6, 0.4))
	Build.part(_lid, Build.box(Vector3(1.24, 0.25, 0.84)), wood, Vector3(0, 0.12, -0.42))
	Build.part(_lid, Build.box(Vector3(0.2, 0.2, 0.06)), gold, Vector3(0, 0.05, -0.85))
	_light = Build.light(self, UIUtil.GOLD, 1.2, 4.0, Vector3(0, 1.2, -0.6))
	_sparkles = FX.particles(UIUtil.GOLD * 2.0, 8, 1.2, 0.1, {"radius": 0.6, "speed_min": 0.1, "speed_max": 0.3})
	_sparkles.position = Vector3(0, 0.8, 0)
	add_child(_sparkles)
	_sparkles.emitting = true


func can_interact(wizard: Wizard) -> bool:
	return not opened and not wizard.is_down


func get_prompt(_wizard: Wizard) -> String:
	return "Open the chest"


func interact(wizard: Wizard) -> void:
	open(wizard)


func open(wizard: Wizard = null) -> void:
	if opened:
		return
	opened = true
	_sparkles.emitting = false
	create_tween().tween_property(_lid, "rotation:x", 1.9, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var top := global_position + Vector3(0, 1.0, 0)
	FX.burst(self, top, UIUtil.GOLD * 2.0, 40, 5.0, 0.2, 0.8, {"direction": Vector3.UP, "spread": 40.0, "gravity": Vector3(0, -10, 0)})
	FX.float_text(self, top + Vector3(0, 0.8, 0), "+%d" % money, UIUtil.GOLD, 90)
	FX.coins(self, top, clampi(money / 10, 3, 12), wizard)
	GameState.add_money(money)
	_light.light_energy = 3.0
	if Game.instance and secret:
		Game.instance.found_secret()
