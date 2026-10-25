class_name LevelDresser
extends Node3D
## Decorates a level with its theme's props: along the walls, high on the walls and
## scattered on floors. Created by level.gd after the walls have collision.
## Only looks: props have no collision, and they keep away from gameplay things
## (checkpoints, gates, doors, chests, portals, lava) so nothing important is hidden.

## Wall spots in the dark, far from torches (AmbientFX puts lurking eyes there).
var dark_spots: Array[Transform3D] = []
## Floor spots in open places (AmbientFX uses them as ghost wisp homes).
var open_spots: Array[Vector3] = []

var _theme: LevelTheme
var _rng := RandomNumberGenerator.new()
var _space: PhysicsDirectSpaceState3D
var _geometry: Node3D
var _walls: Array[CSGBox3D] = []
var _wall_boxes: Array[AABB] = []
## [position, radius] of things props must not cover.
var _keep_clear: Array = []
var _lights: Array[Vector3] = []


func dress(theme: LevelTheme, geometry: Node3D) -> void:
	_theme = theme
	_geometry = geometry
	_rng.seed = theme.prop_seed
	_space = get_world_3d().direct_space_state
	_collect()
	for wall in _walls:
		_dress_wall(wall)
	for floor_node in geometry.get_children():
		if floor_node is CSGBox3D and not _walls.has(floor_node):
			_dress_floor(floor_node as CSGBox3D)


func _collect() -> void:
	for c in _geometry.get_children():
		if c is CSGBox3D and _is_wall(c as CSGBox3D):
			_walls.append(c)
			_wall_boxes.append(_global_aabb(c as CSGBox3D).grow(0.25))
	var tree := get_tree()
	var groups := {"checkpoints": 3.0, "interactable": 2.5, "portals": 4.0, "gates": 3.0,
		"treasure": 2.0, "secrets": 3.5, "unsafe_ground": 2.0}
	for group in groups:
		for n in tree.get_nodes_in_group(group):
			if n is Node3D:
				_keep_clear.append([(n as Node3D).global_position, groups[group]])
	for n in tree.get_nodes_in_group("level")[0].find_children("*", "", true, false):
		# Level parts that are not in a group: doors, breakable walls, lava, item pickups.
		if n is IceDoor or n is BreakableWall or n is LavaTrench or n is LavaPool or n is ItemPickup:
			_keep_clear.append([(n as Node3D).global_position, 3.5])
		if n is Torch:
			_lights.append((n as Node3D).global_position)
			_keep_clear.append([(n as Node3D).global_position - Vector3(0, 1.5, 0), 1.2])
		elif n is OmniLight3D:
			_lights.append((n as Node3D).global_position)


## Thin, tall boxes are walls (floors are flat, rubble is low).
func _is_wall(box: CSGBox3D) -> bool:
	return box.size.y >= 3.0 and minf(box.size.x, box.size.z) <= 2.5


func _global_aabb(box: CSGBox3D) -> AABB:
	return box.global_transform * AABB(-box.size * 0.5, box.size)


func _dress_wall(wall: CSGBox3D) -> void:
	var xf := wall.global_transform
	var along_x := wall.size.x >= wall.size.z
	var along := (xf.basis.x if along_x else xf.basis.z).normalized()
	var length := wall.size.x if along_x else wall.size.z
	var thick := wall.size.z if along_x else wall.size.x
	var side := (xf.basis.z if along_x else xf.basis.x).normalized()
	var top := xf.origin.y + wall.size.y * 0.5
	for normal in [side, -side]:
		var face: Vector3 = xf.origin + normal * thick * 0.5
		_line(face, along, length, normal, top)


## Props along one wall face.
func _line(face: Vector3, along: Vector3, length: float, normal: Vector3, top: float) -> void:
	var usable := length - 2.0
	if usable <= 0.5:
		return
	# Low props against the wall.
	if not _theme.wall_props.is_empty():
		var count := int(usable * _theme.wall_prop_density + _rng.randf())
		for i in count:
			var t := _rng.randf_range(-usable * 0.5, usable * 0.5)
			var spot := _floor_at(face + along * t + normal * 0.7)
			if spot == Vector3.INF or not _clear(spot, 1.0):
				continue
			var kind: String = _theme.wall_props[_rng.randi() % _theme.wall_props.size()]
			var yaw := atan2(-normal.x, -normal.z)
			Props.spawn(kind, self, spot - normal * 0.35, yaw, _rng, _theme)
	# High props hang on the wall face.
	if not _theme.high_props.is_empty():
		var count := int(usable * _theme.high_prop_density + _rng.randf())
		for i in count:
			var t := _rng.randf_range(-usable * 0.5, usable * 0.5)
			var spot := _floor_at(face + along * t + normal * 0.7)
			if spot == Vector3.INF or not _clear(spot, 1.0):
				continue
			var kind: String = _theme.high_props[_rng.randi() % _theme.high_props.size()]
			var height := minf(top - 0.3, spot.y + _rng.randf_range(4.0, 5.5))
			var p := face + along * t + normal * 0.02
			Props.spawn(kind, self, Vector3(p.x, height, p.z), atan2(-normal.x, -normal.z), _rng, _theme)
	# Remember dark wall spots for lurking eyes.
	for i in 2:
		var t := _rng.randf_range(-usable * 0.5, usable * 0.5)
		var spot := _floor_at(face + along * t + normal * 0.7)
		if spot != Vector3.INF and _clear(spot, 2.0) and _far_from_lights(spot, 7.0):
			var eye_pos := face + along * t + normal * 0.1
			eye_pos.y = spot.y + _rng.randf_range(0.5, 1.6)
			dark_spots.append(Transform3D(Basis(Vector3.UP, atan2(-normal.x, -normal.z)), eye_pos))


func _dress_floor(box: CSGBox3D) -> void:
	var aabb := _global_aabb(box)
	if aabb.size.y > 3.0:
		return
	var area := aabb.size.x * aabb.size.z
	var count := int(area * _theme.floor_prop_density + _rng.randf())
	for i in count + 2:
		var p := aabb.position + Vector3(_rng.randf() * aabb.size.x, aabb.size.y, _rng.randf() * aabb.size.z)
		var spot := _floor_at(p)
		if spot == Vector3.INF or not _clear(spot, 0.6):
			continue
		if i >= count:
			# The last two spots are not decorated: they are homes for ghost wisps.
			open_spots.append(spot)
			continue
		if _theme.floor_props.is_empty():
			continue
		var kind: String = _theme.floor_props[_rng.randi() % _theme.floor_props.size()]
		Props.spawn(kind, self, spot, _rng.randf() * TAU, _rng, _theme)


## The floor point under p (Vector3.INF if there is no level floor there).
func _floor_at(p: Vector3) -> Vector3:
	for box in _wall_boxes:
		if box.has_point(Vector3(p.x, box.get_center().y, p.z)):
			return Vector3.INF
	var q := PhysicsRayQueryParameters3D.create(Vector3(p.x, p.y + 6.0, p.z), Vector3(p.x, p.y - 10.0, p.z), 1)
	var hit := _space.intersect_ray(q)
	if hit.is_empty():
		return Vector3.INF
	var collider := hit["collider"] as Node
	if collider == null or not _geometry.is_ancestor_of(collider) or (hit["normal"] as Vector3).y < 0.9:
		return Vector3.INF
	return hit["position"]


func _clear(p: Vector3, radius: float) -> bool:
	for k in _keep_clear:
		var other: Vector3 = k[0]
		if Vector2(p.x - other.x, p.z - other.z).length() < radius + float(k[1]) and absf(p.y - other.y) < 6.0:
			return false
	return true


func _far_from_lights(p: Vector3, dist: float) -> bool:
	for l in _lights:
		if l.distance_to(p) < dist:
			return false
	return true
