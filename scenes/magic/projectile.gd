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
## Look, see SpellVisuals (fireball, ember_dart, meteor, ice_comet, acid...).
var style := ""
## Monsters it can still fly through.
var pierce := 0
## Turn rate toward the closest monster ahead (radians per second).
var homing := 0.0
## Where a meteor lands (shows a warning circle there while it falls).
var sky_target := Vector3.INF

## Set by SpellVisuals: the part that spins, and how far it circles the flight line.
var visual_core: Node3D
var visual_spin := 0.0
var visual_spiral := 0.0
## Twin spells circle in opposite phase.
var spiral_phase := 0.0

var _query: PhysicsShapeQueryParameters3D
var _done := false
var _pierced: Array[Node] = []
var _age := 0.0
var _spike_travel := 0.0
var _marker: Node3D


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
	if style == "":
		style = "acid" if team == "enemy" else ("ice_comet" if element == "ice" else "fireball")
	SpellVisuals.build(self)
	if absf(direction.y) < 0.99:
		look_at(global_position + direction, Vector3.UP)
	else:
		look_at(global_position + direction, Vector3.FORWARD)
	if sky_target != Vector3.INF:
		_marker = _warning_circle(sky_target)


## Red ring on the ground where a meteor will land.
func _warning_circle(pos: Vector3) -> Node3D:
	var parent := FX.world(self)
	if parent == null:
		return null
	var m := Build.glow(color, 2.5)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color.a = 0.8
	var ring := MeshInstance3D.new()
	ring.mesh = Build.torus(0.9, 1.0)
	ring.material_override = m
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(ring)
	ring.global_position = pos + Vector3(0, 0.05, 0)
	var size := spell.strong_splash_radius if spell else 2.0
	ring.scale = Vector3(size * 1.6, 1, size * 1.6)
	ring.create_tween().tween_property(ring, "scale", Vector3(size, 1, size), 0.5)
	return ring


func _physics_process(delta: float) -> void:
	if _done:
		return
	_age += delta
	if homing > 0.0:
		_steer(delta)
	global_position += direction * speed * delta
	life -= delta
	if visual_core:
		visual_core.rotation.z += visual_spin * delta
		if visual_spiral > 0.0:
			var a := _age * 14.0 + spiral_phase
			visual_core.position = Vector3(cos(a), sin(a), 0) * visual_spiral
	if style == "glacier_spear":
		_spike_travel += speed * delta
		if _spike_travel > 1.6:
			_spike_travel = 0.0
			_spike_trail()
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
		if other in _pierced:
			continue
		if other.has_method("take_hit"):
			if other.take_hit(self):
				if pierce > 0 and other is Enemy:
					# Flies on through the monster.
					pierce -= 1
					_pierced.append(other)
					# Level out so it does not dive into the floor behind the first monster.
					if absf(direction.y) < 0.5:
						direction = Vector3(direction.x, 0.0, direction.z).normalized()
					SpellVisuals.impact(self, global_position, false)
					continue
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
	SpellVisuals.impact(self, global_position, big)
	if is_instance_valid(_marker):
		_marker.queue_free()
	if big and spell and spell.ground_effect != "none":
		GroundEffect.spawn(self, global_position, {
			"kind": spell.ground_effect, "radius": spell.ground_radius, "time": spell.ground_time,
			"power": spell.ground_power, "spell": spell, "caster": caster})
	if big and spell and spell.strong_from_sky:
		# A meteor landing shakes the ground.
		for w in get_tree().get_nodes_in_group("wizards"):
			var wiz := w as Wizard
			if wiz.camera_rig and wiz.global_position.distance_to(global_position) < 12.0:
				wiz.camera_rig.shake(0.35)
	if team == "player" and spell and strong and spell.strong_splash_radius > 0.0:
		for node in get_tree().get_nodes_in_group("enemies"):
			var enemy = node
			if enemy == direct_target or not enemy.has_method("hit"):
				continue
			if enemy.global_position.distance_to(global_position) <= spell.strong_splash_radius + 0.5:
				enemy.hit(damage * 0.5, element, spell, 1, caster)
	queue_free()


## Turns gently toward the closest monster in front (helps young players hit).
func _steer(delta: float) -> void:
	var best: Node3D = null
	var best_d := 18.0
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Node3D
		if e == null or e.get("dead") == true or e in _pierced:
			continue
		var to := e.global_position + Vector3(0, float(e.get("aim_height")), 0) - global_position
		var d := to.length()
		if d < best_d and direction.dot(to / maxf(d, 0.01)) > 0.4:
			best = e
			best_d = d
	if best == null:
		return
	var want := (best.global_position + Vector3(0, float(best.get("aim_height")), 0) - global_position).normalized()
	var angle := direction.angle_to(want)
	if angle < 0.001:
		return
	direction = direction.slerp(want, minf(1.0, homing * delta / angle)).normalized()
	if absf(direction.y) < 0.99:
		look_at(global_position + direction, Vector3.UP)


## Glacier spear: ice spikes pop up on the floor along its path.
func _spike_trail() -> void:
	var q := PhysicsRayQueryParameters3D.create(global_position, global_position + Vector3(0, -3.0, 0), 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		SpellVisuals.ice_spikes(self, hit["position"], color)
