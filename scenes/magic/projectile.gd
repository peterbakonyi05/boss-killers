class_name Projectile
extends Node3D
## A flying spell. Player spells are driven by SpellData (damage, speed, burn/freeze).
## Monsters use the same script with team = "enemy".

const PLAYER_MASK := 1 | 4 | 32   # world, enemies, element targets (lava, ice door)
const ENEMY_MASK := 1 | 2 | 16    # world, players, shields

var team := "player"
var element := "fire"
var damage := 10.0
var speed := 20.0
var direction := Vector3.FORWARD
var radius := 0.3
var color := Color(1, 0.5, 0.1)
var strong := false
var spell: SpellData
var caster: Node3D
var life := 2.5

var _query: PhysicsShapeQueryParameters3D
var _done := false


## Creates and launches a projectile in the level.
static func launch(from: Node, pos: Vector3, dir: Vector3, setup: Dictionary) -> Projectile:
	var parent := FX.world(from)
	if parent == null:
		return null
	var p := Projectile.new()
	for key in setup:
		p.set(key, setup[key])
	p.direction = dir.normalized()
	parent.add_child(p)
	p.global_position = pos
	return p


func _ready() -> void:
	add_to_group("projectiles")
	_build_visual()
	var shape := SphereShape3D.new()
	shape.radius = radius
	_query = PhysicsShapeQueryParameters3D.new()
	_query.shape = shape
	_query.collide_with_areas = true
	_query.collide_with_bodies = true
	_query.collision_mask = PLAYER_MASK if team == "player" else ENEMY_MASK
	if caster is CollisionObject3D:
		_query.exclude = [(caster as CollisionObject3D).get_rid()]


func _build_visual() -> void:
	var core := MeshInstance3D.new()
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if element == "ice" and team == "player":
		# Ice shard pointing where it flies.
		core.mesh = Build.cone(radius * 0.9, radius * 4.0)
		core.rotation_degrees = Vector3(-90, 0, 0)
		core.material_override = Build.glow(color.lightened(0.3), 3.0)
	else:
		core.mesh = Build.sphere(radius)
		core.material_override = Build.glow(color, 4.0)
	add_child(core)
	var halo := MeshInstance3D.new()
	halo.mesh = Build.sphere(radius * 1.8)
	halo.material_override = FX.bubble_material(color, 0.8)
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(halo)
	var trail := FX.particles(color * 1.8, 20 if strong else 12, 0.35, radius * 2.2,
		{"speed_min": 0.2, "speed_max": 1.0, "radius": radius * 0.6,
		"gravity": Vector3(0, 2.0, 0) if element == "fire" else Vector3(0, -1.0, 0)})
	trail.local_coords = false
	add_child(trail)
	trail.emitting = true
	Build.light(self, color, 1.5 if strong else 0.8, 4.0 if strong else 2.5)
	if absf(direction.y) < 0.99:
		look_at(global_position + direction, Vector3.UP)


func _physics_process(delta: float) -> void:
	if _done:
		return
	global_position += direction * speed * delta
	life -= delta
	if life <= 0.0:
		_explode(null)
		return
	_check_hits()


func _check_hits() -> void:
	_query.transform = Transform3D(Basis(), global_position)
	var hits := get_world_3d().direct_space_state.intersect_shape(_query, 8)
	if hits.is_empty():
		return
	# Shields first: an enemy spell that touches a raised shield is blocked.
	if team == "enemy":
		for hit in hits:
			var shield := hit.get("collider") as Shield
			if shield and shield.is_up():
				shield.on_block(global_position)
				_explode(null)
				return
	for hit in hits:
		var other = hit.get("collider")
		if other == null or other == caster or other is Shield:
			continue
		if team == "player" and other is Wizard:
			continue
		if team == "enemy" and other is Enemy:
			continue
		if other.has_method("take_hit"):
			if other.take_hit(self):
				_explode(other)
				return
			continue
		if other is Area3D:
			continue
		# Walls, floors and other solid things.
		_explode(null)
		return


func _explode(direct_target: Object) -> void:
	if _done:
		return
	_done = true
	var big := strong and team == "player"
	FX.burst(self, global_position, color * 2.0, 26 if big else 10, 6.0 if big else 3.0, radius * 1.4, 0.45)
	if big:
		FX.flash_light(self, global_position, color, 5.0, 7.0, 0.3)
	if team == "player" and spell and strong and spell.strong_splash_radius > 0.0:
		for node in get_tree().get_nodes_in_group("enemies"):
			var enemy = node
			if enemy == direct_target or not enemy.has_method("hit"):
				continue
			if enemy.global_position.distance_to(global_position) <= spell.strong_splash_radius + 0.5:
				enemy.hit(damage * 0.5, element, spell, 1, caster)
	queue_free()
