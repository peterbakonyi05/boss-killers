class_name ItemPickup
extends Area3D
## A floating item (like the golden key). Touch it to pick it up for the team.

@export var item_id := "key"

var _model: Node3D
var _time := 0.0
var _taken := false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	Build.collision_sphere(self, 1.2, Vector3(0, 1.2, 0))
	_model = Build.pivot(self, Vector3(0, 1.4, 0))
	var gold := Build.glow(UIUtil.GOLD, 2.0)
	gold.metallic = 0.9
	gold.roughness = 0.25
	Build.part(_model, Build.torus(0.18, 0.32), gold, Vector3(0, 0.45, 0), Vector3(90, 0, 0))
	Build.part(_model, Build.cylinder(0.06, 0.9), gold, Vector3(0, -0.1, 0))
	Build.part(_model, Build.box(Vector3(0.25, 0.08, 0.08)), gold, Vector3(0.12, -0.42, 0))
	Build.part(_model, Build.box(Vector3(0.18, 0.08, 0.08)), gold, Vector3(0.09, -0.25, 0))
	Build.light(self, UIUtil.GOLD, 2.5, 7.0, Vector3(0, 1.6, 0))
	var sparkles := FX.particles(UIUtil.GOLD * 2.0, 16, 1.2, 0.12, {"radius": 0.7, "speed_min": 0.1, "speed_max": 0.4})
	sparkles.position = Vector3(0, 1.4, 0)
	add_child(sparkles)
	sparkles.emitting = true
	Build.label3d(self, "KEY", Vector3(0, 2.6, 0), 48, UIUtil.GOLD)
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_time += delta
	_model.rotation.y += delta * 2.0
	_model.position.y = 1.4 + sin(_time * 2.5) * 0.15


func _on_body_entered(body: Node3D) -> void:
	if _taken or not body is Wizard or (body as Wizard).is_down:
		return
	_taken = true
	FX.burst(self, global_position + Vector3(0, 1.4, 0), UIUtil.GOLD * 2.0, 50, 6.0, 0.25, 0.8)
	FX.float_text(self, global_position + Vector3(0, 2.2, 0), "GOT THE KEY!", UIUtil.GOLD, 90)
	if Game.instance:
		Game.instance.collect_item(item_id)
	queue_free()
