class_name Enemy
extends CharacterBody3D
## Base monster: health, chasing, melee or ranged attacks, burn/slow/freeze, money drop.
## imp.tscn, brute.tscn and demon_knight.tscn use this script with different numbers.

signal died(enemy: Enemy)

enum Look { IMP, BRUTE, KNIGHT }

@export var look: Look = Look.IMP
@export var display_name := "Imp"
## Health and damage at level 1. They grow with the level (enemy power).
@export var base_health := 30.0
@export var base_damage := 6.0
@export var move_speed := 4.6
@export var attack_range := 1.7
@export var attack_cooldown := 1.3
## Time the monster "winds up" before hitting, so players can see it coming.
@export var windup_time := 0.45
@export var ranged := false
@export var ranged_range := 14.0
@export var projectile_speed := 11.0
## The monster notices wizards this close.
@export var aggro_range := 13.0
@export_enum("small", "medium", "big") var money_size := "small"
@export var body_color := Color(0.45, 0.08, 0.12)
@export var eye_color := Color(1.0, 0.85, 0.2)
## Mini-boss: big health bar on screen and special attacks.
@export var is_boss := false

@export_group("Special moves")
## Melee monsters jump at the wizard from this far away (0 = no lunge).
@export var lunge_distance := 0.0
## Running charge at wizards that are a bit far away (0 = never charges).
@export var charge_speed := 0.0
@export var charge_cooldown := 6.0
## Ranged monsters side-step at this speed while reloading (0 = stand still).
@export var strafe_speed := 0.0

var health := 30.0
var max_health := 30.0
## Money this monster gave the team when it died.
var money_dropped := 0
var damage := 6.0
var dead := false
var aim_height := 0.8
var always_aggro := false

var _state := "idle"
var _target: Wizard
var _target_timer := 0.0
var _attack_timer := 0.0
var _windup_left := 0.0
var _attack_kind := ""
var _volley_timer := 2.0
var _enraged := false
var _charge_timer := 2.0
var _strafe_dir := 1.0
var _strafe_timer := 0.0

# Lunges and charges move the monster in a straight line for a short time.
var _dash_dir := Vector3.ZERO
var _dash_speed := 0.0
var _dash_left := 0.0
var _dash_can_hit := false

var _burn_left := 0.0
var _burn_dps := 0.0
var _burn_tick := 0.0
var _slow_stacks := 0
var _slow_left := 0.0
var _slow_per_stack := 0.2
var _frozen_left := 0.0
var _freeze_immune := 0.0
var _stagger := 0.0

var _nav: NavigationAgent3D
var _last_goal := Vector3.INF
var _model: Node3D
var _body: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _meshes: Array[MeshInstance3D] = []
var _eye_mat: StandardMaterial3D
var _flash_mat: StandardMaterial3D
var _slow_mat: StandardMaterial3D
var _flash := 0.0
var _ice_block: MeshInstance3D
var _burn_fx: GPUParticles3D
var _bar_bg: Sprite3D
var _bar_fg: Sprite3D
var _telegraph: MeshInstance3D
var _charge_line: MeshInstance3D
var _anim_time := 0.0
var _radius := 0.45
var _height := 1.2

static var _bar_texture: ImageTexture


func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 4
	collision_mask = 1 | 2 | 4
	var power := GameState.enemy_scale()
	max_health = base_health * power
	health = max_health
	damage = base_damage * power
	_anim_time = randf() * 10.0
	match look:
		Look.IMP:
			_radius = 0.42
			_height = 1.2
		Look.BRUTE:
			_radius = 0.9
			_height = 2.5
		Look.KNIGHT:
			_radius = 1.1
			_height = 3.8
	aim_height = _height * 0.55
	Build.collision_capsule(self, _radius, _height, Vector3(0, _height * 0.5, 0))
	_model = Node3D.new()
	add_child(_model)
	_body = Build.pivot(_model)
	match look:
		Look.IMP:
			_build_imp()
		Look.BRUTE:
			_build_brute()
		Look.KNIGHT:
			_build_knight()
	_flash_mat = Build.glow(Color(1, 1, 1), 2.0)
	_flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_flash_mat.albedo_color.a = 0.6
	_slow_mat = Build.glow(Color(0.4, 0.8, 1.0), 0.6)
	_slow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_slow_mat.albedo_color.a = 0.35
	_build_health_bar()
	_nav = NavigationAgent3D.new()
	_nav.path_desired_distance = 0.8
	_nav.target_desired_distance = 0.8
	_nav.radius = _radius
	_nav.height = _height
	_nav.path_max_distance = 4.0
	add_child(_nav)
	if is_boss and Game.instance:
		Game.instance.show_boss(self)


# --- Models ------------------------------------------------------------------

func _add(mesh: Mesh, material: Material, pos: Vector3, rot := Vector3.ZERO, scl := Vector3.ONE, parent: Node3D = null) -> MeshInstance3D:
	var mi := Build.part(parent if parent else _body, mesh, material, pos, rot, scl)
	_meshes.append(mi)
	return mi


## Body material with a faint glow so monsters are easy to spot in dark caves.
func _skin(color: Color, roughness: float) -> StandardMaterial3D:
	var m := Build.mat(color, roughness)
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 0.35
	m.rim_enabled = true
	m.rim = 0.6
	return m


func _eyes(y: float, z: float, spread: float, size: float, parent: Node3D = null) -> void:
	_eye_mat = Build.glow(eye_color, 6.0)
	var p := parent if parent else _body
	Build.part(p, Build.sphere(size * 1.3), _eye_mat, Vector3(-spread, y, z))
	Build.part(p, Build.sphere(size * 1.3), _eye_mat, Vector3(spread, y, z))


func _build_imp() -> void:
	var skin := _skin(body_color, 0.7)
	var dark := Build.mat(body_color.darkened(0.5), 0.8)
	var horn := Build.mat(Color(0.9, 0.85, 0.7), 0.5)
	_add(Build.sphere(0.38), skin, Vector3(0, 0.62, 0), Vector3.ZERO, Vector3(1.0, 1.05, 0.9))
	_add(Build.sphere(0.28), skin, Vector3(0, 1.05, -0.05))
	_add(Build.cone(0.07, 0.3), horn, Vector3(-0.15, 1.3, -0.02), Vector3(0, 0, 25))
	_add(Build.cone(0.07, 0.3), horn, Vector3(0.15, 1.3, -0.02), Vector3(0, 0, -25))
	_add(Build.sphere(0.12), dark, Vector3(0, 0.98, -0.25), Vector3.ZERO, Vector3(1.2, 0.6, 0.6))
	_eyes(1.1, -0.24, 0.1, 0.055)
	_arm_l = Build.pivot(_body, Vector3(-0.36, 0.75, 0))
	_arm_r = Build.pivot(_body, Vector3(0.36, 0.75, 0))
	_add(Build.capsule(0.07, 0.42), skin, Vector3(0, -0.15, -0.05), Vector3(20, 0, -20), Vector3.ONE, _arm_l)
	_add(Build.capsule(0.07, 0.42), skin, Vector3(0, -0.15, -0.05), Vector3(20, 0, 20), Vector3.ONE, _arm_r)
	_add(Build.capsule(0.08, 0.4), dark, Vector3(-0.15, 0.2, 0))
	_add(Build.capsule(0.08, 0.4), dark, Vector3(0.15, 0.2, 0))
	# Little bat wings
	var wing := Build.mat(body_color.darkened(0.3), 0.8)
	_add(Build.box(Vector3(0.5, 0.3, 0.03)), wing, Vector3(-0.35, 0.85, 0.25), Vector3(0, 30, 20))
	_add(Build.box(Vector3(0.5, 0.3, 0.03)), wing, Vector3(0.35, 0.85, 0.25), Vector3(0, -30, -20))
	if ranged:
		# Spitters carry a glowing ember in their hand.
		Build.part(_arm_r, Build.sphere(0.1), Build.glow(Color(0.6, 1.0, 0.2), 4.0), Vector3(0, -0.4, -0.15))


func _build_brute() -> void:
	var stone := _skin(body_color, 0.95)
	var crack := Build.glow(Color(1.0, 0.4, 0.05), 3.0)
	_add(Build.capsule(0.75, 1.7), stone, Vector3(0, 1.35, 0.1), Vector3(-15, 0, 0), Vector3(1.15, 1.0, 0.9))
	_add(Build.box(Vector3(0.9, 0.06, 0.1)), crack, Vector3(0, 1.5, -0.6), Vector3(-10, 0, 15))
	_add(Build.box(Vector3(0.6, 0.06, 0.1)), crack, Vector3(0.1, 1.15, -0.62), Vector3(-10, 0, -20))
	_add(Build.sphere(0.36), stone, Vector3(0, 2.25, -0.35))
	_eyes(2.3, -0.66, 0.13, 0.07)
	_add(Build.cone(0.1, 0.35), Build.mat(Color(0.2, 0.18, 0.18), 0.8), Vector3(-0.3, 2.5, -0.3), Vector3(0, 0, 35))
	_add(Build.cone(0.1, 0.35), Build.mat(Color(0.2, 0.18, 0.18), 0.8), Vector3(0.3, 2.5, -0.3), Vector3(0, 0, -35))
	_arm_l = Build.pivot(_body, Vector3(-0.95, 1.85, 0))
	_arm_r = Build.pivot(_body, Vector3(0.95, 1.85, 0))
	for arm in [_arm_l, _arm_r]:
		_add(Build.capsule(0.28, 1.3), stone, Vector3(0, -0.55, -0.1), Vector3(10, 0, 0), Vector3.ONE, arm)
		_add(Build.sphere(0.38), stone, Vector3(0, -1.25, -0.2), Vector3.ZERO, Vector3.ONE, arm)
		_add(Build.box(Vector3(0.5, 0.05, 0.1)), crack, Vector3(0, -0.6, -0.36), Vector3.ZERO, Vector3.ONE, arm)
	_add(Build.capsule(0.3, 0.8), stone, Vector3(-0.4, 0.35, 0))
	_add(Build.capsule(0.3, 0.8), stone, Vector3(0.4, 0.35, 0))
	Build.light(_body, Color(1.0, 0.4, 0.1), 0.8, 3.0, Vector3(0, 1.4, -1.0))


func _build_knight() -> void:
	var armor := Build.mat(body_color, 0.4, 0.7)
	var dark := Build.mat(body_color.darkened(0.5), 0.5, 0.6)
	var red := Build.glow(Color(1.0, 0.15, 0.05), 3.5)
	_add(Build.box(Vector3(1.6, 1.5, 0.9)), armor, Vector3(0, 2.3, 0))
	_add(Build.box(Vector3(1.2, 0.5, 0.8)), dark, Vector3(0, 1.4, 0))
	_add(Build.sphere(0.55), armor, Vector3(-0.95, 2.9, 0), Vector3.ZERO, Vector3(1.0, 0.7, 1.0))
	_add(Build.sphere(0.55), armor, Vector3(0.95, 2.9, 0), Vector3.ZERO, Vector3(1.0, 0.7, 1.0))
	_add(Build.box(Vector3(0.1, 1.0, 0.05)), red, Vector3(0, 2.3, -0.47))
	# Helmet with horns and a glowing eye slit
	_add(Build.box(Vector3(0.8, 0.8, 0.8)), dark, Vector3(0, 3.4, -0.05))
	_add(Build.box(Vector3(0.6, 0.08, 0.05)), red, Vector3(0, 3.45, -0.46))
	_eye_mat = red
	_add(Build.cone(0.14, 0.7), Build.mat(Color(0.9, 0.85, 0.75), 0.5), Vector3(-0.5, 3.85, 0), Vector3(0, 0, 40))
	_add(Build.cone(0.14, 0.7), Build.mat(Color(0.9, 0.85, 0.75), 0.5), Vector3(0.5, 3.85, 0), Vector3(0, 0, -40))
	_add(Build.box(Vector3(0.45, 1.2, 0.5)), dark, Vector3(-0.4, 0.6, 0))
	_add(Build.box(Vector3(0.45, 1.2, 0.5)), dark, Vector3(0.4, 0.6, 0))
	# Cape
	_add(Build.box(Vector3(1.5, 2.4, 0.08)), Build.mat(Color(0.25, 0.02, 0.05), 0.9), Vector3(0, 1.8, 0.52), Vector3(8, 0, 0))
	_arm_l = Build.pivot(_body, Vector3(-1.05, 2.7, 0))
	_arm_r = Build.pivot(_body, Vector3(1.05, 2.7, 0))
	_add(Build.capsule(0.25, 1.3), armor, Vector3(0, -0.6, 0), Vector3.ZERO, Vector3.ONE, _arm_l)
	_add(Build.capsule(0.25, 1.3), armor, Vector3(0, -0.6, 0), Vector3.ZERO, Vector3.ONE, _arm_r)
	# Big glowing sword
	var sword := Build.pivot(_arm_r, Vector3(0, -1.2, -0.2))
	_add(Build.box(Vector3(0.12, 0.5, 0.12)), dark, Vector3(0, 0, 0), Vector3.ZERO, Vector3.ONE, sword)
	_add(Build.box(Vector3(0.7, 0.1, 0.15)), dark, Vector3(0, 0, -0.1), Vector3(90, 0, 0), Vector3.ONE, sword)
	_add(Build.box(Vector3(0.25, 0.08, 2.4)), Build.glow(Color(1.0, 0.3, 0.1), 2.5), Vector3(0, 0, -1.3), Vector3.ZERO, Vector3.ONE, sword)
	Build.light(_body, Color(1.0, 0.2, 0.05), 2.0, 7.0, Vector3(0, 3.0, -1.0))


func _build_health_bar() -> void:
	if _bar_texture == null:
		var img := Image.create(100, 12, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		_bar_texture = ImageTexture.create_from_image(img)
	var y := _height + 0.45
	_bar_bg = Sprite3D.new()
	_bar_bg.texture = _bar_texture
	_bar_bg.pixel_size = 0.012 * (1.5 if look != Look.IMP else 1.0)
	_bar_bg.modulate = Color(0.05, 0.0, 0.0, 0.8)
	_bar_bg.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bar_bg.position = Vector3(0, y, 0)
	_bar_bg.render_priority = 1
	add_child(_bar_bg)
	_bar_fg = Sprite3D.new()
	_bar_fg.texture = _bar_texture
	_bar_fg.pixel_size = _bar_bg.pixel_size
	_bar_fg.modulate = Color(1.0, 0.25, 0.2)
	_bar_fg.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bar_fg.centered = false
	_bar_fg.offset = Vector2(-50, -6)
	_bar_fg.region_enabled = true
	_bar_fg.region_rect = Rect2(0, 0, 100, 12)
	_bar_fg.position = Vector3(0, y, 0)
	_bar_fg.render_priority = 2
	add_child(_bar_fg)
	_bar_bg.visible = false
	_bar_fg.visible = false


func _update_health_bar() -> void:
	var show_bar := health < max_health and not dead and not is_boss
	_bar_bg.visible = show_bar
	_bar_fg.visible = show_bar
	_bar_fg.region_rect = Rect2(0, 0, maxf(1.0, 100.0 * health / max_health), 12)


# --- Main loop ---------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if dead:
		return
	_tick_status(delta)
	if dead:
		return
	if not is_on_floor():
		velocity.y -= 22.0 * delta
	else:
		velocity.y = maxf(velocity.y, -1.0)
	var move := Vector3.ZERO
	var speed := move_speed * _speed_mult()
	if _enraged:
		speed *= 1.25
	if _frozen_left > 0.0:
		_end_dash()
	elif _dash_left > 0.0:
		move = _dash_dir
		speed = _dash_speed * _speed_mult()
		_update_dash(delta)
	elif _stagger > 0.0:
		_stagger -= delta
	else:
		move = _think(delta)
	velocity.x = move.x * speed
	velocity.z = move.z * speed
	move_and_slide()
	_animate(delta, move)
	if global_position.y < -25.0:
		fall_in_lava()


func _speed_mult() -> float:
	return 1.0 - minf(0.6, _slow_stacks * _slow_per_stack)


func _tick_status(delta: float) -> void:
	_attack_timer = maxf(0.0, _attack_timer - delta)
	_volley_timer = maxf(0.0, _volley_timer - delta)
	_charge_timer = maxf(0.0, _charge_timer - delta)
	_freeze_immune = maxf(0.0, _freeze_immune - delta)
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 6.0)
		_flash_mat.albedo_color.a = _flash * 0.7
		if _flash == 0.0:
			_refresh_overlay()
	if _burn_left > 0.0:
		_burn_left -= delta
		_burn_tick -= delta
		if _burn_tick <= 0.0:
			_burn_tick = 0.5
			_apply_damage(_burn_dps * 0.5, false)
		if _burn_left <= 0.0 and _burn_fx:
			_burn_fx.emitting = false
	if _slow_left > 0.0:
		_slow_left -= delta
		if _slow_left <= 0.0:
			_slow_stacks = 0
			_refresh_overlay()
	if _frozen_left > 0.0:
		_frozen_left -= delta
		if _frozen_left <= 0.0:
			_unfreeze(false)


## Decides what to do and returns the direction to walk in.
func _think(delta: float) -> Vector3:
	_target_timer -= delta
	if _target_timer <= 0.0 or not _target_alive():
		_target_timer = 0.3
		_target = _closest_wizard()
	if _target == null:
		_state = "idle"
		return Vector3.ZERO
	var to_target := _target.global_position - global_position
	to_target.y = 0.0
	var dist := to_target.length()
	match _state:
		"idle":
			if always_aggro or dist < aggro_range:
				_state = "chase"
			return Vector3.ZERO
		"windup":
			_face(to_target, delta, 8.0)
			_windup_left -= delta
			if _windup_left <= 0.0:
				_do_attack()
				_state = "chase"
				_attack_timer = attack_cooldown * (0.7 if _enraged else 1.0)
				_hide_telegraph()
			return Vector3.ZERO
	# Chasing
	if not always_aggro and dist > aggro_range * 2.5:
		_state = "idle"
		return Vector3.ZERO
	if _attack_timer <= 0.0:
		var choice := _choose_attack(dist)
		if choice != "":
			_start_windup(choice)
			return Vector3.ZERO
	var keep_away := ranged and dist < ranged_range * 0.7
	if keep_away:
		_face(to_target, delta, 8.0)
		return _strafe(to_target, delta)
	if dist < attack_range * 0.8:
		_face(to_target, delta, 8.0)
		return Vector3.ZERO
	var dir := _path_direction(_target.global_position)
	_face(dir, delta, 8.0)
	return dir


## Side-steps left and right so ranged monsters are harder to hit.
func _strafe(to_target: Vector3, delta: float) -> Vector3:
	if strafe_speed <= 0.0:
		return Vector3.ZERO
	_strafe_timer -= delta
	if _strafe_timer <= 0.0 or is_on_wall():
		_strafe_timer = randf_range(0.8, 1.8)
		_strafe_dir = -_strafe_dir
	var side := to_target.normalized().cross(Vector3.UP) * _strafe_dir
	return side * (strafe_speed / move_speed)


func _wants_charge(dist: float, head: Vector3) -> bool:
	return charge_speed > 0.0 and _charge_timer <= 0.0 and dist > 5.0 and dist < 16.0 \
		and _can_see(head, _target_chest())


func _choose_attack(dist: float) -> String:
	var head := global_position + Vector3(0, aim_height, 0)
	if is_boss:
		if dist < 4.5:
			return "slam"
		if _wants_charge(dist, head):
			return "charge"
		if _volley_timer <= 0.0 and dist < 22.0 and _can_see(head, _target_chest()):
			return "volley"
		return ""
	if ranged:
		if dist < ranged_range and _can_see(head, _target_chest()):
			return "shoot"
		return ""
	if _wants_charge(dist, head):
		return "charge"
	if dist < attack_range + 0.3 + lunge_distance:
		return "slam" if look == Look.BRUTE else "melee"
	return ""


func _start_windup(kind: String) -> void:
	_state = "windup"
	_attack_kind = kind
	_windup_left = windup_time
	if kind == "slam":
		_windup_left = windup_time * (1.6 if is_boss else 1.2)
		_show_telegraph(_slam_radius())
	elif kind == "charge":
		_windup_left = maxf(0.8, windup_time * 1.4)
		_show_charge_line()
	var tw := create_tween()
	tw.tween_property(_body, "scale", Vector3(1.1, 0.9, 1.1), _windup_left * 0.8)
	tw.tween_property(_body, "scale", Vector3.ONE, 0.1)
	if _eye_mat:
		_eye_mat.emission_energy_multiplier = 14.0
	if _arm_r:
		var arm_tw := create_tween()
		arm_tw.tween_property(_arm_r, "rotation:x", -2.2 if kind != "volley" else -1.4, _windup_left)
		arm_tw.tween_property(_arm_r, "rotation:x", 0.5, 0.1)
		arm_tw.tween_property(_arm_r, "rotation:x", 0.0, 0.3)


func _slam_radius() -> float:
	return 4.0 if is_boss else 2.6


func _do_attack() -> void:
	if _eye_mat:
		_eye_mat.emission_energy_multiplier = 6.0 if not _enraged else 10.0
	if _target == null:
		return
	var to_target := _target.global_position - global_position
	to_target.y = 0.0
	match _attack_kind:
		"melee":
			if lunge_distance > 0.0:
				# Jump at the wizard: only hits if they don't get out of the way.
				_start_dash(to_target, clampf(to_target.length() - 0.5, 0.5, lunge_distance + attack_range), 0.2)
			elif to_target.length() < attack_range + 0.8:
				_target.take_damage(damage, global_position)
		"charge":
			_charge_timer = charge_cooldown
			_start_dash(_forward(), charge_speed * 1.1, 1.1)
		"slam":
			var center := global_position + _forward() * (_slam_radius() * 0.6)
			FX.burst(self, center + Vector3(0, 0.2, 0), Color(1.0, 0.5, 0.2) * 1.5, 40, 8.0, 0.4, 0.6,
				{"direction": Vector3.UP, "spread": 70.0, "gravity": Vector3(0, -12, 0)})
			FX.burst(self, center, Color(0.4, 0.35, 0.35, 0.8), 16, 4.0, 1.0, 0.8, {"smoke": true})
			for w in get_tree().get_nodes_in_group("wizards"):
				var wiz := w as Wizard
				if wiz and not wiz.is_down and wiz.global_position.distance_to(center) < _slam_radius():
					wiz.take_damage(damage * (1.3 if is_boss else 1.0), global_position)
		"shoot":
			_shoot(_target_chest(), 1, 0.0)
		"volley":
			_volley_timer = 3.5
			var count := 5 if _enraged else 3
			_shoot(_target_chest(), count, 0.22)


func _shoot(at: Vector3, count: int, spread: float) -> void:
	var start := global_position + Vector3(0, aim_height + 0.3, 0) + _forward() * (_radius + 0.4)
	var dir := (at - start).normalized()
	var color := Color(1.0, 0.3, 0.1) if is_boss else Color(0.55, 1.0, 0.2)
	for i in count:
		var angle := (i - (count - 1) * 0.5) * spread
		Projectile.launch(self, start, dir.rotated(Vector3.UP, angle), {
			"team": "enemy",
			"element": "fire",
			"damage": damage * (0.7 if is_boss else 1.0),
			"speed": projectile_speed,
			"radius": 0.35 if is_boss else 0.25,
			"color": color,
			"caster": self,
			"life": 3.0,
		})


func _start_dash(dir: Vector3, distance: float, time: float) -> void:
	dir.y = 0.0
	if dir.length() < 0.01:
		return
	_dash_dir = dir.normalized()
	_dash_speed = distance / time
	_dash_left = time
	_dash_can_hit = true
	_face(_dash_dir, 1.0, 100.0)


func _update_dash(delta: float) -> void:
	_dash_left -= delta
	var charging := _attack_kind == "charge"
	if _dash_can_hit:
		for w in get_tree().get_nodes_in_group("wizards"):
			var wiz := w as Wizard
			if wiz == null or wiz.is_down:
				continue
			var gap := wiz.global_position - global_position
			gap.y = 0.0
			if gap.length() < _radius + 0.9:
				_dash_can_hit = false
				wiz.take_damage(damage * (1.3 if charging else 1.0), global_position)
				if charging:
					wiz.velocity += _dash_dir * 9.0 + Vector3.UP * 5.0
				break
	# A charge that runs into a wall stuns the monster: time to hit back!
	if charging and is_on_wall() and _dash_left < 1.0:
		_end_dash()
		_stagger = 1.4
		FX.burst(self, global_position + _forward() * _radius + Vector3(0, _height * 0.5, 0),
			Color(0.5, 0.45, 0.4, 0.8), 18, 4.0, 0.9, 0.8, {"smoke": true})
		FX.float_text(self, global_position + Vector3(0, _height + 0.5, 0), "DIZZY!", Color(1.0, 0.9, 0.4))
		return
	if _dash_left <= 0.0:
		_end_dash()


func _end_dash() -> void:
	_dash_left = 0.0
	_dash_can_hit = false
	if _charge_line:
		_charge_line.visible = false


## A long glowing strip in front of the monster: "I'm about to charge this way!"
func _show_charge_line() -> void:
	var length := charge_speed * 1.1
	if _charge_line == null:
		_charge_line = MeshInstance3D.new()
		_charge_line.mesh = Build.box(Vector3(_radius * 2.0, 0.04, 1.0))
		var m := Build.glow(Color(1.0, 0.1, 0.05), 2.0)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color.a = 0.35
		_charge_line.material_override = m
		_charge_line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_model.add_child(_charge_line)
	_charge_line.visible = true
	_charge_line.position = Vector3(0, 0.05, -length * 0.5)
	_charge_line.scale = Vector3(1, 1, length)


func _show_telegraph(radius: float) -> void:
	if _telegraph == null:
		_telegraph = MeshInstance3D.new()
		_telegraph.mesh = Build.cylinder(1.0, 0.04)
		var m := Build.glow(Color(1.0, 0.1, 0.05), 2.0)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color.a = 0.35
		_telegraph.material_override = m
		_telegraph.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_telegraph)
	_telegraph.visible = true
	_telegraph.position = _model.transform.basis * Vector3(0, 0.05, -radius * 0.6)
	_telegraph.scale = Vector3(0.2, 1, 0.2) * radius
	create_tween().tween_property(_telegraph, "scale", Vector3(radius, 1, radius), _windup_left * 0.9)


func _hide_telegraph() -> void:
	if _telegraph:
		_telegraph.visible = false
	if _charge_line and _dash_left <= 0.0:
		_charge_line.visible = false


func _forward() -> Vector3:
	return -_model.global_transform.basis.z.normalized()


func _face(dir: Vector3, delta: float, sharpness: float) -> void:
	if dir.length() < 0.01:
		return
	var target_yaw := atan2(-dir.x, -dir.z)
	_model.rotation.y = lerp_angle(_model.rotation.y, target_yaw, 1.0 - exp(-sharpness * delta))


func _animate(delta: float, move: Vector3) -> void:
	if _frozen_left > 0.0:
		return
	_anim_time += delta * (8.0 if move.length() > 0.1 else 2.5) * _speed_mult()
	match look:
		Look.IMP:
			_body.position.y = absf(sin(_anim_time)) * 0.15 + 0.05
		_:
			_body.position.y = absf(sin(_anim_time * 0.6)) * 0.08
			_body.rotation.z = sin(_anim_time * 0.6) * 0.04
	if _state != "windup" and _arm_l:
		_arm_l.rotation.x = sin(_anim_time) * 0.4


func _path_direction(goal: Vector3) -> Vector3:
	var direct := goal - global_position
	direct.y = 0.0
	var map := _nav.get_navigation_map()
	if map.is_valid() and NavigationServer3D.map_get_iteration_id(map) > 0:
		# Only ask for a new path when the target moved a bit.
		if goal.distance_to(_last_goal) > 0.75:
			_nav.target_position = goal
			_last_goal = goal
		var next := _nav.get_next_path_position()
		var step := next - global_position
		step.y = 0.0
		if step.length() > 0.1:
			return step.normalized()
	return direct.normalized() if direct.length() > 0.01 else Vector3.ZERO


func _closest_wizard() -> Wizard:
	var best: Wizard = null
	var best_dist := INF
	for w in get_tree().get_nodes_in_group("wizards"):
		var wiz := w as Wizard
		if wiz == null or wiz.is_down:
			continue
		var d := wiz.global_position.distance_to(global_position)
		if d < best_dist:
			best_dist = d
			best = wiz
	return best


func _target_alive() -> bool:
	return _target != null and is_instance_valid(_target) and not _target.is_down


func _target_chest() -> Vector3:
	return _target.global_position + Vector3(0, 1.1, 0)


func _can_see(from: Vector3, to: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, to, 1)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


# --- Getting hit -------------------------------------------------------------

## Hit by a wizard's projectile.
func take_hit(p: Projectile) -> bool:
	if dead:
		return false
	hit(p.damage, p.element, p.spell, (p.spell.strong_stacks if p.strong and p.spell else 1), p.caster)
	return true


func hit(amount: float, element: String, spell: SpellData, stacks: int, source: Node3D) -> void:
	if dead:
		return
	if element == "fire":
		if _frozen_left > 0.0:
			# Fire on a frozen monster shatters the ice for bonus damage!
			amount *= 1.5
			_unfreeze(true)
		if spell:
			_burn_left = spell.burn_time
			_burn_dps = maxf(_burn_dps, spell.burn_dps * GameState.upgrade_mult("fire", "spell_weak"))
			_start_burn_fx()
	elif element == "ice" and spell:
		_slow_per_stack = spell.slow_per_stack
		_slow_left = spell.slow_time
		_burn_left = 0.0
		if _burn_fx:
			_burn_fx.emitting = false
		if _frozen_left <= 0.0:
			_slow_stacks += stacks
			if _slow_stacks >= spell.freeze_stacks and _freeze_immune <= 0.0:
				_freeze(spell.freeze_time * (0.5 if is_boss else 1.0))
		_refresh_overlay()
	if _state == "idle":
		_state = "chase"
		if source is Wizard:
			_target = source as Wizard
	# Only big hits make imps flinch, so fast spells can't keep them stuck.
	if not is_boss and look == Look.IMP and amount >= max_health * 0.3:
		_stagger = 0.12
	_apply_damage(amount, true)


func _apply_damage(amount: float, flash: bool) -> void:
	if dead:
		return
	health -= amount
	if flash:
		_flash = 1.0
		_refresh_overlay()
	_update_health_bar()
	if is_boss and not _enraged and health < max_health * 0.5:
		_enraged = true
		_eye_mat.emission_energy_multiplier = 8.0
		FX.float_text(self, global_position + Vector3(0, _height + 0.8, 0), "ENRAGED!", Color(1, 0.3, 0.2), 90)
		_summon_helpers()
	if health <= 0.0:
		die()


## An enraged boss calls two imps into its arena.
func _summon_helpers() -> void:
	var arena := get_parent()
	if not arena.has_method("summon"):
		return
	for side in [-1.0, 1.0]:
		arena.summon("imp", global_position + _model.global_basis.x * side * 3.0)


func _refresh_overlay() -> void:
	var m: Material = null
	if _flash > 0.0:
		m = _flash_mat
	elif _slow_stacks > 0 and _frozen_left <= 0.0:
		m = _slow_mat
	for mi in _meshes:
		mi.material_overlay = m


func _start_burn_fx() -> void:
	if _burn_fx == null:
		_burn_fx = FX.particles(Color(1.0, 0.45, 0.1) * 2.0, 20, 0.6, 0.35,
			{"speed_min": 0.5, "speed_max": 1.5, "radius": _radius, "gravity": Vector3(0, 3, 0)})
		_burn_fx.position = Vector3(0, _height * 0.5, 0)
		add_child(_burn_fx)
	_burn_fx.emitting = true


func _freeze(time: float) -> void:
	_frozen_left = time
	_slow_stacks = 0
	_state = "chase"
	_hide_telegraph()
	if _ice_block == null:
		_ice_block = MeshInstance3D.new()
		_ice_block.mesh = Build.box(Vector3(_radius * 2.6, _height * 1.1, _radius * 2.6))
		_ice_block.material_override = Build.see_through(Color(0.6, 0.9, 1.0, 0.55), 0.8)
		_ice_block.position = Vector3(0, _height * 0.55, 0)
		add_child(_ice_block)
	_ice_block.visible = true
	_ice_block.scale = Vector3.ONE * 0.6
	create_tween().tween_property(_ice_block, "scale", Vector3.ONE, 0.15)
	FX.burst(self, global_position + Vector3(0, _height * 0.5, 0), Color(0.6, 0.9, 1.0) * 2.0, 30, 5.0, 0.3, 0.6)
	FX.float_text(self, global_position + Vector3(0, _height + 0.5, 0), "FROZEN!", Color(0.6, 0.9, 1.0))
	_refresh_overlay()


func _unfreeze(shatter: bool) -> void:
	_frozen_left = 0.0
	_freeze_immune = 2.0
	if _ice_block:
		_ice_block.visible = false
	if shatter:
		FX.burst(self, global_position + Vector3(0, _height * 0.5, 0), Color(0.8, 0.95, 1.0) * 2.0, 40, 8.0, 0.25, 0.7,
			{"gravity": Vector3(0, -10, 0)})
		FX.float_text(self, global_position + Vector3(0, _height + 0.5, 0), "SHATTER!", Color(1.0, 0.7, 0.3))
	_refresh_overlay()


func fall_in_lava() -> void:
	if not dead:
		die()


func die() -> void:
	if dead:
		return
	dead = true
	health = 0.0
	remove_from_group("enemies")
	collision_layer = 0
	collision_mask = 0
	_update_health_bar()
	_end_dash()
	_hide_telegraph()
	if _burn_fx:
		_burn_fx.emitting = false
	var center := global_position + Vector3(0, _height * 0.5, 0)
	var size_scale := 1.0 if look == Look.IMP else (1.6 if look == Look.BRUTE else 2.4)
	FX.poof(self, center, eye_color, size_scale)
	var amount := GameState.money_for(money_size)
	money_dropped = amount
	GameState.add_money(amount)
	FX.float_text(self, center + Vector3(0, 0.8, 0), "+%d" % amount, UIUtil.GOLD, 72)
	var collector := _closest_wizard()
	if collector == null:
		var all := get_tree().get_nodes_in_group("wizards")
		if all.size() > 0:
			collector = all[0] as Wizard
	FX.coins(self, global_position, clampi(amount / 50, 2, 12), collector)
	died.emit(self)
	var tw := create_tween()
	tw.tween_property(_model, "scale", Vector3(1.3, 0.05, 1.3), 0.2)
	tw.tween_callback(queue_free)
