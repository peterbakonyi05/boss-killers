class_name AmbientFX
extends Node3D
## The spooky mood of a level, from its theme: floating particles around each wizard,
## ghost wisps that flee when you come close, bat flocks overhead and lurking eyes
## that blink in dark corners. Purely for looks, never hurts anyone.

var _theme: LevelTheme
var _wisps: Array[Node3D] = []
var _wisp_homes: Array[Vector3] = []
var _eyes: Array[Node3D] = []
var _bat_timer := 0.0
var _check_timer := 0.0
var _time := 0.0


func setup(theme: LevelTheme, dresser: LevelDresser) -> void:
	_theme = theme
	_bat_timer = randf_range(8.0, 16.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = theme.prop_seed + 7
	var homes := dresser.open_spots.duplicate()
	for i in mini(theme.ghost_wisps, homes.size()):
		var home: Vector3 = homes.pop_at(rng.randi() % homes.size())
		_wisp_homes.append(home + Vector3(0, 1.4, 0))
		_wisps.append(_make_wisp(home + Vector3(0, 1.4, 0)))
	var spots := dresser.dark_spots.duplicate()
	for i in mini(theme.lurking_eyes, spots.size()):
		_eyes.append(_make_eyes(spots.pop_at(rng.randi() % spots.size())))


func _process(delta: float) -> void:
	if _theme == null:
		return
	_time += delta
	var wizards := get_tree().get_nodes_in_group("wizards")
	_check_timer -= delta
	if _check_timer <= 0.0:
		_check_timer = 1.0
		for w in wizards:
			if _theme.ambient_particles != "" and not (w as Node).has_node("AmbientParticles"):
				_add_particles(w as Node3D)
	for i in _wisps.size():
		_update_wisp(_wisps[i], _wisp_homes[i], wizards, delta)
	for e in _eyes:
		_update_eyes(e, wizards, delta)
	if _theme.bats and not wizards.is_empty():
		_bat_timer -= delta
		if _bat_timer <= 0.0:
			_bat_timer = randf_range(18.0, 35.0)
			_bat_flock(wizards[randi() % wizards.size()] as Node3D)


# --- Floating particles --------------------------------------------------------

func _add_particles(w: Node3D) -> void:
	var p: GPUParticles3D
	var box := Vector3(9, 3, 9)
	match _theme.ambient_particles:
		"embers":
			p = FX.particles(Color(1.0, 0.45, 0.1) * 2.0, 40, 4.0, 0.06,
				{"box": box, "direction": Vector3.UP, "spread": 30.0, "speed_min": 0.2, "speed_max": 0.7, "gravity": Vector3(0, 0.15, 0)})
		"dust":
			p = FX.particles(Color(0.8, 0.75, 0.7, 0.35), 50, 6.0, 0.05,
				{"box": box, "spread": 180.0, "speed_min": 0.02, "speed_max": 0.15, "smoke": true})
		"spores":
			p = FX.particles(Color(0.5, 1.0, 0.4) * 1.5, 40, 6.0, 0.06,
				{"box": box, "direction": Vector3.UP, "spread": 60.0, "speed_min": 0.05, "speed_max": 0.25})
		"snow":
			p = FX.particles(Color(0.95, 0.97, 1.0, 0.9), 120, 5.0, 0.07,
				{"box": Vector3(10, 1, 10), "direction": Vector3.DOWN, "spread": 15.0, "speed_min": 0.8, "speed_max": 1.4, "smoke": true})
			p.position.y = 5.0
		"fireflies":
			p = FX.particles(Color(0.9, 1.0, 0.3) * 2.0, 24, 5.0, 0.08,
				{"box": box, "spread": 180.0, "speed_min": 0.1, "speed_max": 0.4})
		_:
			return
	p.name = "AmbientParticles"
	p.local_coords = false
	p.position.y += 1.5
	p.visibility_aabb = AABB(Vector3(-12, -6, -12), Vector3(24, 12, 24))
	w.add_child(p)
	p.emitting = true


# --- Ghost wisps -----------------------------------------------------------------

func _make_wisp(pos: Vector3) -> Node3D:
	var c := _theme.wisp_color
	var wisp := Node3D.new()
	wisp.name = "Wisp"
	add_child(wisp)
	wisp.global_position = pos
	Build.part(wisp, Build.sphere(0.1), Build.glow(c, 5.0))
	var halo := Build.part(wisp, Build.sphere(0.3), FX.bubble_material(Color(c.r, c.g, c.b, 0.5), 0.6))
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var trail := FX.particles(c * 1.5, 16, 0.9, 0.18, {"speed_min": 0.05, "speed_max": 0.3, "radius": 0.08})
	trail.local_coords = false
	wisp.add_child(trail)
	trail.emitting = true
	Build.light(wisp, c, 0.7, 3.5)
	wisp.set_meta("phase", randf() * TAU)
	wisp.set_meta("flee", Vector3.ZERO)
	return wisp


func _update_wisp(wisp: Node3D, home: Vector3, wizards: Array, delta: float) -> void:
	var phase: float = wisp.get_meta("phase")
	var target := home + Vector3(sin(_time * 0.5 + phase) * 1.5, sin(_time * 1.3 + phase) * 0.4, cos(_time * 0.4 + phase) * 1.5)
	var flee: Vector3 = wisp.get_meta("flee")
	for w in wizards:
		var away: Vector3 = wisp.global_position - (w as Node3D).global_position
		away.y = 0.0
		if away.length() < 5.0:
			flee += away.normalized() * delta * 6.0
	flee = flee.limit_length(6.0).lerp(Vector3.ZERO, delta * 0.3)
	wisp.set_meta("flee", flee)
	wisp.global_position = wisp.global_position.lerp(target + flee + Vector3(0, flee.length() * 0.3, 0), delta * 1.5)


# --- Lurking eyes ----------------------------------------------------------------

func _make_eyes(xf: Transform3D) -> Node3D:
	var eyes := Node3D.new()
	eyes.name = "LurkingEyes"
	add_child(eyes)
	eyes.global_transform = xf
	var m := Build.glow(_theme.eye_color, 6.0)
	for side in [-1.0, 1.0]:
		Build.part(eyes, Build.sphere(0.045), m, Vector3(side * 0.09, 0, -0.05), Vector3(0, 0, side * -15), Vector3(1.4, 0.7, 0.5))
	eyes.set_meta("blink", randf_range(1.0, 4.0))
	eyes.set_meta("show", 1.0)
	return eyes


func _update_eyes(eyes: Node3D, wizards: Array, delta: float) -> void:
	var near := false
	for w in wizards:
		if (w as Node3D).global_position.distance_to(eyes.global_position) < 7.0:
			near = true
	# They hide when you come close... and peek out again when you leave.
	var show: float = move_toward(eyes.get_meta("show"), 0.0 if near else 1.0, delta * (4.0 if near else 0.4))
	eyes.set_meta("show", show)
	var blink: float = eyes.get_meta("blink") - delta
	if blink < -0.15:
		blink = randf_range(1.5, 5.0)
	eyes.set_meta("blink", blink)
	eyes.scale = Vector3(1.0, 0.1 if blink < 0.0 else 1.0, 1.0) * maxf(show, 0.001)
	eyes.visible = show > 0.01


# --- Bats --------------------------------------------------------------------------

func _bat_flock(w: Node3D) -> void:
	var side := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
	if side == Vector3.ZERO:
		side = Vector3.RIGHT
	var start := w.global_position + side * 12.0 + Vector3(0, 4.5, 0)
	var end := w.global_position - side * 12.0 + Vector3(0, 5.5, 0)
	var body := Build.mat(Color(0.06, 0.04, 0.05), 0.9)
	for i in randi_range(5, 9):
		var bat := Node3D.new()
		add_child(bat)
		var offset := Vector3(randf_range(-1.5, 1.5), randf_range(-0.8, 0.8), randf_range(-1.5, 1.5))
		bat.global_position = start + offset
		bat.look_at(end + offset, Vector3.UP)
		Build.part(bat, Build.sphere(0.07), body, Vector3.ZERO, Vector3.ZERO, Vector3(1, 0.8, 1.4))
		var wings: Array[Node3D] = []
		for s in [-1.0, 1.0]:
			var pivot := Build.pivot(bat)
			Build.part(pivot, Build.box(Vector3(0.28, 0.01, 0.14)), body, Vector3(s * 0.15, 0, 0))
			wings.append(pivot)
		var eye := Build.glow(Color(1, 0.2, 0.1), 4.0)
		Build.part(bat, Build.sphere(0.012), eye, Vector3(-0.025, 0.02, -0.09))
		Build.part(bat, Build.sphere(0.012), eye, Vector3(0.025, 0.02, -0.09))
		var t := randf_range(2.6, 3.4)
		var flap := randf() * TAU
		var fly := func(k: float) -> void:
			bat.global_position = (start + offset).lerp(end + offset, k) + Vector3(0, sin(k * 12.0 + flap) * 0.3, 0)
			var a := sin(k * t * 30.0 + flap) * 0.9
			wings[0].rotation.z = a
			wings[1].rotation.z = -a
		var tw := bat.create_tween()
		tw.tween_interval(i * 0.12)
		tw.tween_method(fly, 0.0, 1.0, t)
		tw.tween_callback(bat.queue_free)
