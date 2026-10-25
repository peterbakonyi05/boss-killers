class_name Enemy
extends CharacterBody3D
## Base monster: health, chasing, melee or ranged attacks, burn/slow/freeze, money drop.
## Every monster scene (imp, brute, jaguar, crocodile, ...) uses this script with different numbers.

signal died(enemy: Enemy)

enum Look { IMP, BRUTE, KNIGHT, JAGUAR, SNAKE, CROC, PIRANHA, DEMON }

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
## Never walks, only turns and attacks (for spitters on rock islands).
@export var stationary := false
## Circles around the wizard while getting ready for the next pounce (jaguars).
@export var prowl := false
## Water monster: swims at the height it was placed (the water surface), never leaves
## the water and stays this close to where it started. 0 = walks on land.
@export var swim_leash := 0.0

var health := 30.0
var max_health := 30.0
## Money this monster gave the team when it died.
var money_dropped := 0
var damage := 6.0
var dead := false
var aim_height := 0.8
var always_aggro := false
## Hidden under water: wizards don't aim at it (piranhas until they jump).
var submerged := false

var _state := "idle"
var _roared := false
var _roar_left := 0.0
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
var _roots_timer := 3.0
## Where the roots attack will burst up (one glowing ring per wizard).
var _root_marks: Array[MeshInstance3D] = []
## Water monsters: where they started (the water surface) and how deep they hide.
var _home := Vector3.INF
var _sink := 0.0

# Lunges and charges move the monster in a straight line for a short time.
var _dash_dir := Vector3.ZERO
var _dash_speed := 0.0
var _dash_left := 0.0
var _dash_time := 0.0
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
var _wings: Array[Node3D] = []
var _legs: Array[Node3D] = []
## Snake body pieces that wiggle behind the head.
var _segments: Array[Node3D] = []
var _head: Node3D
var _jaw: Node3D
var _tail: Node3D
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
			_height = 1.45
		Look.BRUTE:
			_radius = 0.9
			_height = 2.5
		Look.KNIGHT:
			_radius = 1.1
			_height = 3.8
		Look.JAGUAR:
			_radius = 0.55
			_height = 1.2
		Look.SNAKE:
			_radius = 0.8
			_height = 1.7
		Look.CROC:
			_radius = 0.75
			_height = 0.8
			_sink = 0.45
		Look.PIRANHA:
			_radius = 0.35
			_height = 0.6
			_sink = 0.9
		Look.DEMON:
			_radius = 1.3
			_height = 4.8
	aim_height = _height * 0.55 - _sink
	Build.collision_capsule(self, _radius, _height, Vector3(0, _height * 0.5 - _sink, 0))
	if look == Look.PIRANHA:
		# Piranhas swim under the walkways and jump out of the water through them.
		collision_mask = 0
		submerged = true
	_model = Node3D.new()
	add_child(_model)
	_model.position.y = -_sink
	_body = Build.pivot(_model)
	match look:
		Look.IMP:
			_build_imp()
		Look.BRUTE:
			_build_brute()
		Look.KNIGHT:
			_build_knight()
		Look.JAGUAR:
			_build_jaguar()
		Look.SNAKE:
			_build_snake()
		Look.CROC:
			_build_croc()
		Look.PIRANHA:
			_build_piranha()
		Look.DEMON:
			_build_demon()
	_flash_mat = Build.glow(Color(1, 1, 1), 2.0)
	_flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_flash_mat.albedo_color.a = 0.6
	_slow_mat = Build.glow(Color(0.4, 0.8, 1.0), 0.6)
	_slow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_slow_mat.albedo_color.a = 0.35
	if _eye_mat:
		_eye_mat.emission_energy_multiplier = _eye_energy()
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
## With a texture id (assets/textures/) the skin gets real detail.
func _skin(color: Color, roughness: float, texture := "") -> StandardMaterial3D:
	var m: StandardMaterial3D
	if texture != "":
		m = Build.pbr(texture, color, 2.5, true).duplicate()
	else:
		m = Build.mat(color, roughness)
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 0.25 if texture != "" else 0.35
	m.rim_enabled = true
	m.rim = 0.6
	return m


func _eyes(y: float, z: float, spread: float, size: float, parent: Node3D = null) -> void:
	_eye_mat = Build.glow(eye_color, 6.0)
	var p := parent if parent else _body
	Build.part(p, Build.sphere(size * 1.3), _eye_mat, Vector3(-spread, y, z))
	Build.part(p, Build.sphere(size * 1.3), _eye_mat, Vector3(spread, y, z))


func _build_imp() -> void:
	var skin := _skin(body_color.lightened(0.15), 0.7, "leather_white")
	var dark := _skin(body_color.darkened(0.55), 0.8, "leather_white")
	var bone := Build.mat(Color(0.9, 0.85, 0.72), 0.5)
	var ember := Build.glow(eye_color.lerp(Color(1.0, 0.3, 0.05), 0.5), 2.5)
	# Hunched body leaning forward, with glowing cracks and spikes down the back
	_add(Build.capsule(0.3, 0.85), skin, Vector3(0, 0.78, 0.02), Vector3(-30, 0, 0))
	_add(Build.box(Vector3(0.28, 0.04, 0.05)), ember, Vector3(0.02, 0.8, -0.27), Vector3(-30, 0, 20))
	for i in 3:
		_add(Build.cone(0.06, 0.28), bone, Vector3(0, 1.02 - i * 0.2, 0.22 + i * 0.04), Vector3(50, 0, 0))
	# Head pushed forward: big jaw full of teeth, long horns, angry brow
	_add(Build.sphere(0.24), skin, Vector3(0, 1.2, -0.25), Vector3.ZERO, Vector3(1.0, 0.85, 1.15))
	_add(Build.box(Vector3(0.36, 0.1, 0.3)), dark, Vector3(0, 1.03, -0.36), Vector3(12, 0, 0))
	for x in [-0.12, -0.04, 0.04, 0.12]:
		_add(Build.cone(0.025, 0.1), bone, Vector3(x, 1.1, -0.48), Vector3(180, 0, 0))
	_add(Build.cone(0.06, 0.45), bone, Vector3(-0.15, 1.42, -0.15), Vector3(40, 0, 30))
	_add(Build.cone(0.06, 0.45), bone, Vector3(0.15, 1.42, -0.15), Vector3(40, 0, -30))
	_add(Build.box(Vector3(0.34, 0.05, 0.08)), dark, Vector3(0, 1.31, -0.47), Vector3(-15, 0, 0))
	_eyes(1.25, -0.47, 0.085, 0.05)
	# Long arms with claws
	_arm_l = Build.pivot(_body, Vector3(-0.3, 0.98, -0.1))
	_arm_r = Build.pivot(_body, Vector3(0.3, 0.98, -0.1))
	for arm in [_arm_l, _arm_r]:
		_add(Build.capsule(0.06, 0.6), skin, Vector3(0, -0.22, -0.12), Vector3(30, 0, 0), Vector3.ONE, arm)
		for x in [-0.05, 0.0, 0.05]:
			_add(Build.cone(0.022, 0.16), bone, Vector3(x, -0.5, -0.3), Vector3(-150, 0, 0), Vector3.ONE, arm)
	# Crouched legs and a whip tail
	_add(Build.capsule(0.08, 0.45), dark, Vector3(-0.15, 0.22, 0.05), Vector3(-15, 0, 0))
	_add(Build.capsule(0.08, 0.45), dark, Vector3(0.15, 0.22, 0.05), Vector3(-15, 0, 0))
	_add(Build.cylinder(0.04, 0.7, 0.015), dark, Vector3(0, 0.45, 0.45), Vector3(60, 0, 0))
	_add(Build.cone(0.07, 0.15), bone, Vector3(0, 0.62, 0.76), Vector3(60, 0, 0))
	# Pale belly and pointed ears
	_add(Build.sphere(0.2), Build.mat(body_color.lightened(0.35), 0.8), Vector3(0, 0.72, -0.18), Vector3(-30, 0, 0), Vector3(1.0, 1.4, 0.6))
	for side in [-1.0, 1.0]:
		_add(Build.cone(0.06, 0.22), skin, Vector3(side * 0.24, 1.25, -0.2), Vector3(0, 0, side * -75))
	# Bat wings: bony fingers with a thin skin between them, they flap while it moves
	var wing := Build.mat(body_color.darkened(0.45), 0.8)
	wing.cull_mode = BaseMaterial3D.CULL_DISABLED
	for side in [-1.0, 1.0]:
		var w := Build.pivot(_body, Vector3(side * 0.18, 1.08, 0.22))
		w.rotation_degrees = Vector3(0, side * -25, 0)
		_wings.append(w)
		for k in 3:
			var angle: float = side * (-35.0 + k * 30.0)
			var finger := Build.pivot(w)
			finger.rotation_degrees.z = angle
			var length := 0.6 - k * 0.1
			_add(Build.cylinder(0.018, length, 0.008), bone, Vector3(side * length * 0.5, 0, 0), Vector3(0, 0, side * -90), Vector3.ONE, finger)
		_add(Build.box(Vector3(0.55, 0.38, 0.015)), wing, Vector3(side * 0.28, -0.05, 0.01), Vector3.ZERO, Vector3.ONE, w)
		_add(Build.box(Vector3(0.3, 0.22, 0.015)), wing, Vector3(side * 0.46, -0.26, 0.01), Vector3(0, 0, side * 25), Vector3.ONE, w)
	if ranged:
		# Spitters have a glowing poison sac in the throat and an ember in the hand.
		var poison := Build.glow(Color(0.6, 1.0, 0.2), 4.0)
		_add(Build.sphere(0.13), poison, Vector3(0, 1.02, -0.3), Vector3.ZERO, Vector3(1.0, 0.8, 1.0))
		Build.part(_arm_r, Build.sphere(0.1), poison, Vector3(0, -0.5, -0.3))


func _build_brute() -> void:
	var stone := _skin(body_color.lightened(0.2), 0.95, "dark_rock")
	var crack := Build.glow(Color(1.0, 0.4, 0.05), 3.0)
	var iron := Build.pbr("rusty_metal_02", Color(0.5, 0.42, 0.4), 2.0, true).duplicate() as StandardMaterial3D
	iron.metallic = 0.6
	_add(Build.capsule(0.75, 1.7), stone, Vector3(0, 1.35, 0.1), Vector3(-15, 0, 0), Vector3(1.15, 1.0, 0.9))
	_add(Build.box(Vector3(0.9, 0.06, 0.1)), crack, Vector3(0, 1.5, -0.6), Vector3(-10, 0, 15))
	_add(Build.box(Vector3(0.6, 0.06, 0.1)), crack, Vector3(0.1, 1.15, -0.62), Vector3(-10, 0, -20))
	_add(Build.sphere(0.36), stone, Vector3(0, 2.25, -0.35))
	_eyes(2.3, -0.66, 0.13, 0.07)
	# Curved horns, a glowing mouth with teeth and spikes on the shoulders
	var horn := Build.mat(Color(0.12, 0.1, 0.1), 0.7)
	var bone := Build.mat(Color(0.9, 0.85, 0.72), 0.5)
	for side in [-1.0, 1.0]:
		_add(Build.cone(0.14, 0.5), horn, Vector3(side * 0.32, 2.48, -0.3), Vector3(0, 0, side * -60))
		_add(Build.cone(0.08, 0.4), horn, Vector3(side * 0.6, 2.68, -0.3), Vector3(0, 0, side * -10))
		for k in 3:
			_add(Build.cone(0.12, 0.45), horn, Vector3(side * (0.55 + k * 0.18), 2.15 - k * 0.12, 0.1), Vector3(-20, 0, side * -40))
	_add(Build.box(Vector3(0.4, 0.1, 0.1)), crack, Vector3(0, 2.1, -0.66))
	for x in [-0.14, -0.05, 0.05, 0.14]:
		_add(Build.cone(0.035, 0.14), bone, Vector3(x, 2.17, -0.7), Vector3(180, 0, 0))
	_arm_l = Build.pivot(_body, Vector3(-0.95, 1.85, 0))
	_arm_r = Build.pivot(_body, Vector3(0.95, 1.85, 0))
	for arm in [_arm_l, _arm_r]:
		_add(Build.capsule(0.28, 1.3), stone, Vector3(0, -0.55, -0.1), Vector3(10, 0, 0), Vector3.ONE, arm)
		_add(Build.sphere(0.38), stone, Vector3(0, -1.25, -0.2), Vector3.ZERO, Vector3.ONE, arm)
		_add(Build.box(Vector3(0.5, 0.05, 0.1)), crack, Vector3(0, -0.6, -0.36), Vector3.ZERO, Vector3.ONE, arm)
	# Iron shackles with broken chains, a riveted shoulder plate and a belt
	for arm in [_arm_l, _arm_r]:
		_add(Build.cylinder(0.32, 0.22), iron, Vector3(0, -0.95, -0.15), Vector3(10, 0, 0), Vector3.ONE, arm)
		Props.chain(arm, Vector3(0, -1.05, -0.15), 0.5)
	_add(Build.sphere(0.5), iron, Vector3(-0.85, 2.0, 0.05), Vector3(0, 0, 20), Vector3(1.0, 0.55, 1.0))
	for k in 4:
		_add(Build.sphere(0.05), iron, Vector3(-0.85 + cos(k * 1.2) * 0.3, 2.2, sin(k * 1.2) * 0.3 - 0.1))
	_add(Build.cylinder(0.72, 0.25), Build.pbr("brown_leather", Color(0.45, 0.35, 0.3), 2.0, true), Vector3(0, 0.75, 0.1), Vector3(-10, 0, 0), Vector3(1.1, 1.0, 0.85))
	_add(Build.box(Vector3(0.3, 0.3, 0.1)), iron, Vector3(0, 0.75, -0.55))
	_add(Build.capsule(0.3, 0.8), stone, Vector3(-0.4, 0.35, 0))
	_add(Build.capsule(0.3, 0.8), stone, Vector3(0.4, 0.35, 0))
	Build.light(_body, Color(1.0, 0.4, 0.1), 0.8, 3.0, Vector3(0, 1.4, -1.0))


func _build_knight() -> void:
	var armor := Build.pbr("rusty_metal_02", body_color.lightened(0.25), 1.5, true).duplicate() as StandardMaterial3D
	armor.metallic = 0.75
	var dark := Build.pbr("rusty_metal_02", body_color.darkened(0.35), 1.5, true).duplicate() as StandardMaterial3D
	dark.metallic = 0.7
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
	var bone := Build.mat(Color(0.9, 0.85, 0.75), 0.5)
	for side in [-1.0, 1.0]:
		# Big curled horns and rows of spikes on the shoulder plates
		_add(Build.cone(0.2, 0.9), bone, Vector3(side * 0.6, 3.9, 0), Vector3(0, 0, side * -55))
		_add(Build.cone(0.12, 0.6), bone, Vector3(side * 1.05, 4.35, 0), Vector3(0, 0, side * -5))
		for k in 3:
			_add(Build.cone(0.1, 0.5), dark, Vector3(side * 0.95, 3.25, -0.3 + k * 0.3), Vector3(0, 0, side * -25))
	_add(Build.box(Vector3(0.45, 1.2, 0.5)), dark, Vector3(-0.4, 0.6, 0))
	_add(Build.box(Vector3(0.45, 1.2, 0.5)), dark, Vector3(0.4, 0.6, 0))
	# Glowing lava cracks across the chest plate
	for k in 4:
		_add(Build.box(Vector3(0.5 - k * 0.08, 0.04, 0.03)), red, Vector3(-0.35 + k * 0.22, 2.0 + k * 0.25, -0.46), Vector3(0, 0, -30 + k * 25))
	# Tattered cape: strips of different length
	var cape := Build.pbr("cotton_jersey", Color(0.4, 0.04, 0.07), 2.0, true)
	for k in 5:
		var x := -0.6 + k * 0.3
		var length := 2.4 - absf(sin(k * 2.3)) * 0.7
		_add(Build.box(Vector3(0.3, length, 0.06)), cape, Vector3(x, 3.0 - length * 0.5, 0.52 + length * 0.07), Vector3(8, 0, x * -4.0))
	_arm_l = Build.pivot(_body, Vector3(-1.05, 2.7, 0))
	_arm_r = Build.pivot(_body, Vector3(1.05, 2.7, 0))
	_add(Build.capsule(0.25, 1.3), armor, Vector3(0, -0.6, 0), Vector3.ZERO, Vector3.ONE, _arm_l)
	_add(Build.capsule(0.25, 1.3), armor, Vector3(0, -0.6, 0), Vector3.ZERO, Vector3.ONE, _arm_r)
	# Big glowing sword
	var sword := Build.pivot(_arm_r, Vector3(0, -1.2, -0.2))
	_add(Build.box(Vector3(0.12, 0.5, 0.12)), dark, Vector3(0, 0, 0), Vector3.ZERO, Vector3.ONE, sword)
	_add(Build.box(Vector3(0.7, 0.1, 0.15)), dark, Vector3(0, 0, -0.1), Vector3(90, 0, 0), Vector3.ONE, sword)
	_add(Build.box(Vector3(0.25, 0.08, 2.4)), dark, Vector3(0, 0, -1.3), Vector3.ZERO, Vector3.ONE, sword)
	_add(Build.box(Vector3(0.12, 0.1, 2.2)), Build.glow(Color(1.0, 0.3, 0.1), 3.0), Vector3(0, 0, -1.35), Vector3.ZERO, Vector3.ONE, sword)
	_add(Build.cone(0.13, 0.4), dark, Vector3(0, 0, -2.7), Vector3(-90, 0, 0), Vector3(1, 1, 0.35), sword)
	Build.light(_body, Color(1.0, 0.2, 0.05), 2.0, 7.0, Vector3(0, 3.0, -1.0))


func _build_jaguar() -> void:
	var fur := _skin(body_color, 0.8, "leather_white")
	var spot := Build.mat(Color(0.03, 0.025, 0.02), 0.9)
	var belly := Build.mat(body_color.lightened(0.45), 0.9)
	var bone := Build.mat(Color(0.95, 0.92, 0.8), 0.4)
	var mouth := Build.glow(Color(0.7, 0.05, 0.05), 1.5)
	# Long, low body with dark rosettes on the back and sides
	_add(Build.capsule(0.32, 1.6), fur, Vector3(0, 0.72, 0.1), Vector3(90, 0, 0))
	_add(Build.capsule(0.24, 1.2), belly, Vector3(0, 0.6, 0.1), Vector3(90, 0, 0), Vector3(0.9, 0.8, 1.0))
	for k in 14:
		var side := -1.0 if k % 2 == 0 else 1.0
		var z := -0.5 + floorf(k / 2.0) * 0.19
		_add(Build.sphere(0.075), spot, Vector3(side * 0.27, 0.8 + (k % 3) * 0.05, z), Vector3.ZERO, Vector3(0.4, 1.0, 1.2))
	for k in 5:
		_add(Build.sphere(0.07), spot, Vector3(((k % 2) - 0.5) * 0.18, 1.03, -0.4 + k * 0.22), Vector3.ZERO, Vector3(1.2, 0.4, 1.0))
	# Big head low in front: snarling jaw with long fangs, round ears, blazing eyes
	_head = Build.pivot(_body, Vector3(0, 0.95, -0.82))
	_add(Build.sphere(0.26), fur, Vector3.ZERO, Vector3.ZERO, Vector3(1.0, 0.85, 1.05), _head)
	_add(Build.box(Vector3(0.24, 0.13, 0.22)), fur, Vector3(0, -0.06, -0.22), Vector3.ZERO, Vector3.ONE, _head)
	_add(Build.box(Vector3(0.2, 0.05, 0.18)), mouth, Vector3(0, -0.14, -0.22), Vector3.ZERO, Vector3.ONE, _head)
	_add(Build.box(Vector3(0.2, 0.06, 0.18)), belly, Vector3(0, -0.19, -0.2), Vector3(12, 0, 0), Vector3.ONE, _head)
	_add(Build.sphere(0.05), spot, Vector3(0, -0.01, -0.34), Vector3.ZERO, Vector3(1.2, 0.8, 0.8), _head)
	for side in [-1.0, 1.0]:
		_add(Build.cone(0.03, 0.16), bone, Vector3(side * 0.07, -0.2, -0.3), Vector3(180, 0, 0), Vector3.ONE, _head)
		_add(Build.sphere(0.08), fur, Vector3(side * 0.17, 0.2, 0.05), Vector3.ZERO, Vector3(1.0, 1.0, 0.5), _head)
		_add(Build.sphere(0.04), spot, Vector3(side * 0.17, 0.2, 0.0), Vector3.ZERO, Vector3(1.0, 1.0, 0.5), _head)
		# Angry brow over each eye
		_add(Build.box(Vector3(0.12, 0.03, 0.05)), spot, Vector3(side * 0.09, 0.12, -0.22), Vector3(0, 0, side * 20), Vector3.ONE, _head)
	_eyes(0.06, -0.22, 0.09, 0.045, _head)
	# Four legs with paws and claws (they swing while it runs)
	for p in [Vector3(-0.2, 0.62, -0.5), Vector3(0.2, 0.62, -0.5), Vector3(-0.2, 0.66, 0.62), Vector3(0.2, 0.66, 0.62)]:
		var leg := Build.pivot(_body, p)
		_legs.append(leg)
		_add(Build.capsule(0.1, 0.72), fur, Vector3(0, -0.3, 0), Vector3.ZERO, Vector3.ONE, leg)
		_add(Build.sphere(0.11), fur, Vector3(0, -0.6, -0.05), Vector3.ZERO, Vector3(1.0, 0.6, 1.3), leg)
		for x in [-0.05, 0.0, 0.05]:
			_add(Build.cone(0.018, 0.09), bone, Vector3(x, -0.62, -0.18), Vector3(-100, 0, 0), Vector3.ONE, leg)
	# Long tail that swishes
	_tail = Build.pivot(_body, Vector3(0, 0.82, 0.9))
	_add(Build.cylinder(0.07, 1.0, 0.04), fur, Vector3(0, 0.12, 0.45), Vector3(65, 0, 0), Vector3.ONE, _tail)
	_add(Build.sphere(0.06), spot, Vector3(0, 0.33, 0.9), Vector3.ZERO, Vector3.ONE, _tail)


func _build_snake() -> void:
	var scales := _skin(body_color, 0.6, "brown_leather")
	var blotch := Build.mat(body_color.darkened(0.7), 0.7)
	var belly := Build.mat(Color(0.75, 0.68, 0.4), 0.7)
	var bone := Build.mat(Color(0.95, 0.92, 0.8), 0.4)
	# Neck rising up from the ground to the head
	for k in 3:
		var r := 0.42 - k * 0.04
		_add(Build.sphere(r), scales, Vector3(0, 0.4 + k * 0.38, 0.25 - k * 0.22))
		_add(Build.sphere(r * 0.75), belly, Vector3(0, 0.38 + k * 0.38, 0.1 - k * 0.24), Vector3.ZERO, Vector3(0.9, 1.0, 0.5))
	# Flat, wide head with a gaping mouth, fangs and a forked tongue
	_head = Build.pivot(_body, Vector3(0, 1.45, -0.45))
	_add(Build.sphere(0.34), scales, Vector3.ZERO, Vector3.ZERO, Vector3(1.0, 0.55, 1.5), _head)
	_add(Build.sphere(0.28), blotch, Vector3(0, 0.1, 0.05), Vector3.ZERO, Vector3(0.7, 0.3, 1.1), _head)
	_add(Build.box(Vector3(0.36, 0.06, 0.4)), Build.glow(Color(0.7, 0.08, 0.1), 1.5), Vector3(0, -0.12, -0.25), Vector3.ZERO, Vector3.ONE, _head)
	_add(Build.sphere(0.27), belly, Vector3(0, -0.2, -0.05), Vector3(10, 0, 0), Vector3(1.0, 0.3, 1.4), _head)
	for side in [-1.0, 1.0]:
		_add(Build.cone(0.035, 0.22), bone, Vector3(side * 0.12, -0.18, -0.38), Vector3(170, 0, 0), Vector3.ONE, _head)
		_add(Build.box(Vector3(0.14, 0.04, 0.08)), blotch, Vector3(side * 0.15, 0.13, -0.18), Vector3(0, side * 20, side * 15), Vector3.ONE, _head)
	var tongue := Build.glow(Color(0.9, 0.1, 0.2), 1.5)
	for side in [-1.0, 1.0]:
		_add(Build.box(Vector3(0.025, 0.015, 0.28)), tongue, Vector3(side * 0.03, -0.12, -0.62), Vector3(0, side * 12, 0), Vector3.ONE, _head)
	_eyes(0.09, -0.3, 0.19, 0.06, _head)
	# Long body lying behind, getting thinner toward the tail; it wiggles while moving
	for i in 10:
		var r := lerpf(0.44, 0.14, i / 9.0)
		var seg := Build.pivot(_body, Vector3(0, r, 0.55 + i * 0.5))
		_segments.append(seg)
		_add(Build.sphere(r), scales, Vector3.ZERO, Vector3.ZERO, Vector3(1.0, 0.9, 1.3), seg)
		_add(Build.sphere(r * 0.6), blotch, Vector3(0, r * 0.6, 0), Vector3.ZERO, Vector3(1.0, 0.45, 1.3), seg)


func _build_croc() -> void:
	var hide := _skin(body_color, 0.8, "brown_leather")
	var dark := Build.mat(body_color.darkened(0.5), 0.9)
	var belly := Build.mat(Color(0.6, 0.6, 0.4), 0.8)
	var bone := Build.mat(Color(0.95, 0.92, 0.8), 0.4)
	# Flat armored body with two rows of spikes down the back
	_add(Build.capsule(0.42, 2.2), hide, Vector3(0, 0.4, 0.3), Vector3(90, 0, 0), Vector3(1.25, 1.0, 0.7))
	_add(Build.capsule(0.36, 1.8), belly, Vector3(0, 0.28, 0.3), Vector3(90, 0, 0), Vector3(1.1, 1.0, 0.5))
	for k in 7:
		for side in [-1.0, 1.0]:
			_add(Build.cone(0.07, 0.16), dark, Vector3(side * 0.16, 0.66, -0.4 + k * 0.24))
	# Long snout: the upper jaw opens wide before it snaps
	_add(Build.box(Vector3(0.44, 0.12, 1.0)), hide, Vector3(0, 0.28, -1.15))
	_add(Build.box(Vector3(0.36, 0.04, 0.9)), Build.glow(Color(0.7, 0.1, 0.1), 1.2), Vector3(0, 0.35, -1.12))
	for k in 6:
		for side in [-1.0, 1.0]:
			_add(Build.cone(0.03, 0.1), bone, Vector3(side * 0.19, 0.38, -0.75 - k * 0.15))
	_jaw = Build.pivot(_body, Vector3(0, 0.42, -0.62))
	_add(Build.box(Vector3(0.48, 0.16, 1.05)), hide, Vector3(0, 0.03, -0.52), Vector3.ZERO, Vector3.ONE, _jaw)
	for k in 6:
		for side in [-1.0, 1.0]:
			_add(Build.cone(0.03, 0.11), bone, Vector3(side * 0.2, -0.08, -0.15 - k * 0.15), Vector3(180, 0, 0), Vector3.ONE, _jaw)
	_add(Build.sphere(0.05), dark, Vector3(-0.07, 0.11, -1.0), Vector3.ZERO, Vector3.ONE, _jaw)
	_add(Build.sphere(0.05), dark, Vector3(0.07, 0.11, -1.0), Vector3.ZERO, Vector3.ONE, _jaw)
	# Bumpy eyes on top of the head: often the only thing you see above the water
	for side in [-1.0, 1.0]:
		_add(Build.sphere(0.1), hide, Vector3(side * 0.16, 0.6, -0.55))
	_eyes(0.66, -0.62, 0.16, 0.05)
	# Short splayed legs and a thick tail with spikes
	for p in [Vector3(-0.5, 0.3, -0.35), Vector3(0.5, 0.3, -0.35), Vector3(-0.5, 0.3, 0.9), Vector3(0.5, 0.3, 0.9)]:
		var leg := Build.pivot(_body, p)
		_legs.append(leg)
		_add(Build.capsule(0.11, 0.5), hide, Vector3(signf(p.x) * 0.12, -0.12, 0), Vector3(0, 0, signf(p.x) * 60), Vector3.ONE, leg)
	_tail = Build.pivot(_body, Vector3(0, 0.38, 1.45))
	_add(Build.cylinder(0.32, 1.8, 0.04), hide, Vector3(0, 0, 0.9), Vector3(90, 0, 0), Vector3(1.0, 1.0, 0.6), _tail)
	for k in 5:
		_add(Build.cone(0.06, 0.15), dark, Vector3(0, 0.2 - k * 0.03, 0.2 + k * 0.32), Vector3.ZERO, Vector3.ONE, _tail)


func _build_piranha() -> void:
	var scales := _skin(body_color, 0.4)
	var red := Build.glow(Color(0.9, 0.15, 0.08), 1.2)
	var bone := Build.mat(Color(0.98, 0.96, 0.9), 0.3)
	# Round fish body, red belly, huge underbite full of teeth
	_add(Build.sphere(0.3), scales, Vector3(0, 0.3, 0), Vector3.ZERO, Vector3(0.6, 1.0, 1.15))
	_add(Build.sphere(0.24), red, Vector3(0, 0.2, -0.05), Vector3.ZERO, Vector3(0.55, 0.7, 1.0))
	_add(Build.box(Vector3(0.16, 0.08, 0.14)), scales, Vector3(0, 0.16, -0.33), Vector3(-15, 0, 0))
	for x in [-0.05, 0.0, 0.05]:
		_add(Build.cone(0.022, 0.07), bone, Vector3(x, 0.24, -0.38))
		_add(Build.cone(0.02, 0.06), bone, Vector3(x, 0.3, -0.32), Vector3(180, 0, 0))
	_eyes(0.38, -0.24, 0.09, 0.04)
	# Fins: tall one on the back (breaks the water before it jumps) and a tail fin
	var fin := Build.mat(body_color.darkened(0.3), 0.6)
	fin.cull_mode = BaseMaterial3D.CULL_DISABLED
	_add(Build.box(Vector3(0.02, 0.22, 0.25)), fin, Vector3(0, 0.62, 0.05), Vector3(-25, 0, 0))
	_tail = Build.pivot(_body, Vector3(0, 0.3, 0.32))
	_add(Build.box(Vector3(0.02, 0.32, 0.2)), fin, Vector3(0, 0, 0.1), Vector3.ZERO, Vector3.ONE, _tail)


func _build_demon() -> void:
	var bark := _skin(body_color, 0.9, "bark_brown_02")
	var moss := _skin(Color(0.18, 0.32, 0.08), 0.9, "forest_leaves_02")
	var glow := Build.glow(eye_color, 3.5)
	var bone := Build.mat(Color(0.88, 0.84, 0.72), 0.6)
	# Legs like tree roots, toes digging into the ground
	for side in [-1.0, 1.0]:
		_add(Build.cylinder(0.36, 1.9, 0.26), bark, Vector3(side * 0.55, 0.95, 0.05), Vector3(0, 0, side * 6))
		for k in 3:
			_add(Build.cone(0.12, 0.8), bark, Vector3(side * 0.55 + (k - 1) * 0.25, 0.15, -0.3), Vector3(-75, (k - 1) * 30, 0))
	# Huge hunched torso of bark, with moss on the shoulders and glowing cracks
	_add(Build.capsule(0.9, 2.6), bark, Vector3(0, 2.7, 0.05), Vector3(-12, 0, 0), Vector3(1.25, 1.0, 0.85))
	for side in [-1.0, 1.0]:
		_add(Build.sphere(0.65), moss, Vector3(side * 0.95, 3.55, 0.1), Vector3.ZERO, Vector3(1.0, 0.6, 1.0))
	for k in 5:
		_add(Build.box(Vector3(0.55 - k * 0.06, 0.05, 0.04)), glow, Vector3(-0.4 + k * 0.2, 2.2 + k * 0.28, -0.72), Vector3(0, 0, -35 + k * 20))
	# Ribs of bone sticking out of the chest
	for k in 3:
		for side in [-1.0, 1.0]:
			_add(Build.cylinder(0.05, 0.6), bone, Vector3(side * 0.45, 2.5 + k * 0.3, -0.7), Vector3(0, 0, side * 70))
	# Skull face with a glowing mouth and big antlers like dead branches
	_head = Build.pivot(_body, Vector3(0, 4.25, -0.45))
	_add(Build.sphere(0.55), bone, Vector3.ZERO, Vector3.ZERO, Vector3(1.0, 1.1, 0.95), _head)
	_add(Build.box(Vector3(0.6, 0.12, 0.12)), glow, Vector3(0, -0.32, -0.45), Vector3.ZERO, Vector3.ONE, _head)
	for x in [-0.2, -0.07, 0.07, 0.2]:
		_add(Build.cone(0.05, 0.2), bone, Vector3(x, -0.22, -0.5), Vector3(180, 0, 0), Vector3.ONE, _head)
	_add(Build.box(Vector3(0.7, 0.1, 0.15)), bark, Vector3(0, 0.15, -0.48), Vector3(-10, 0, 0), Vector3.ONE, _head)
	_eyes(0.02, -0.5, 0.2, 0.09, _head)
	for side in [-1.0, 1.0]:
		var antler := Build.pivot(_head, Vector3(side * 0.35, 0.4, 0))
		antler.rotation_degrees = Vector3(-10, 0, side * -35)
		_add(Build.cylinder(0.09, 1.5, 0.04), bark, Vector3(0, 0.75, 0), Vector3.ZERO, Vector3.ONE, antler)
		for k in 3:
			_add(Build.cylinder(0.05, 0.6, 0.02), bark, Vector3(side * 0.15, 0.4 + k * 0.38, 0), Vector3(0, 0, side * -50), Vector3.ONE, antler)
		# Vines hanging from the antlers
		_add(Build.cylinder(0.025, 1.2), moss, Vector3(side * 0.3, 0.2, 0.05), Vector3(0, 0, side * 8), Vector3.ONE, antler)
	# Long arms wrapped in vines, ending in claws like sharp branches
	_arm_l = Build.pivot(_body, Vector3(-1.25, 3.5, 0))
	_arm_r = Build.pivot(_body, Vector3(1.25, 3.5, 0))
	for arm in [_arm_l, _arm_r]:
		_add(Build.capsule(0.3, 2.1), bark, Vector3(0, -0.95, -0.1), Vector3(8, 0, 0), Vector3.ONE, arm)
		for k in 3:
			_add(Build.torus(0.28, 0.36), moss, Vector3(0, -0.4 - k * 0.5, -0.1), Vector3(10, 0, 20 - k * 15), Vector3.ONE, arm)
		for x in [-0.15, 0.0, 0.15]:
			_add(Build.cone(0.07, 0.7), bone, Vector3(x, -2.15, -0.25), Vector3(-160, 0, 0), Vector3.ONE, arm)
	# Glowing spores hang around it
	var spores := FX.particles(eye_color * 1.5, 20, 3.0, 0.08,
		{"radius": 1.5, "direction": Vector3.UP, "spread": 60.0, "speed_min": 0.1, "speed_max": 0.4, "gravity": Vector3(0, 0.3, 0)})
	spores.position = Vector3(0, 3.0, 0)
	_body.add_child(spores)
	spores.emitting = true
	Build.light(_body, eye_color, 2.0, 8.0, Vector3(0, 3.5, -1.2))


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
	if swim_leash > 0.0:
		# Swimmers float at the water surface (only a piranha jump lifts them out).
		if _home == Vector3.INF:
			_home = global_position
		velocity.y = 0.0
	elif not is_on_floor():
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
	_roots_timer = maxf(0.0, _roots_timer - delta)
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
				_start_roar()
			return Vector3.ZERO
		"roar":
			_face(to_target, delta, 10.0)
			_roar_left -= delta
			if _roar_left <= 0.0:
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
		if _eye_mat:
			_eye_mat.emission_energy_multiplier = _eye_energy()
		return Vector3.ZERO
	if _attack_timer <= 0.0:
		var choice := _choose_attack(dist)
		if choice != "":
			_start_windup(choice)
			return Vector3.ZERO
	if stationary:
		_face(to_target, delta, 8.0)
		return Vector3.ZERO
	if prowl and _attack_timer > 0.0 and dist < 8.0:
		# Circle around the wizard, backing off a little, until ready to pounce again.
		_face(to_target, delta, 8.0)
		var around := _strafe(to_target, delta)
		if dist < 4.5:
			around -= to_target.normalized() * 0.6
		return around
	if swim_leash > 0.0:
		return _swim_direction(to_target, dist, delta)
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


## Water monsters swim straight at the wizard, but never further than swim_leash
## from home, so they stay in their pond and wait at the edge.
func _swim_direction(to_target: Vector3, dist: float, delta: float) -> Vector3:
	_face(to_target, delta, 5.0)
	if dist < attack_range * 0.8:
		return Vector3.ZERO
	var goal := _target.global_position - _home
	goal.y = 0.0
	goal = _home + goal.limit_length(swim_leash)
	var step := goal - global_position
	step.y = 0.0
	return step.normalized() if step.length() > 0.3 else Vector3.ZERO


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


## The first time a monster sees the wizards it rears up and roars, with
## blazing eyes. Big monsters shake the screen of wizards close by.
func _start_roar() -> void:
	if _roared:
		_state = "chase"
		return
	_roared = true
	_state = "roar"
	_roar_left = 0.45 if _is_small() else 0.9
	if _eye_mat:
		_eye_mat.emission_energy_multiplier = 16.0
	var tw := create_tween()
	tw.tween_property(_body, "scale", Vector3(1.15, 1.2, 1.15), _roar_left * 0.4).set_trans(Tween.TRANS_BACK)
	tw.tween_property(_body, "scale", Vector3.ONE, _roar_left * 0.6)
	tw.tween_callback(func() -> void:
		if _eye_mat and _state != "windup":
			_eye_mat.emission_energy_multiplier = _eye_energy())
	if _arm_l and _arm_r:
		for arm in [_arm_l, _arm_r]:
			var arm_tw := create_tween()
			arm_tw.tween_property(arm, "rotation:x", -2.4, _roar_left * 0.4)
			arm_tw.tween_property(arm, "rotation:x", 0.0, _roar_left * 0.6)
	if not _is_small():
		for w in get_tree().get_nodes_in_group("wizards"):
			var wiz := w as Wizard
			if wiz and wiz.global_position.distance_to(global_position) < 18.0:
				if wiz.camera_rig:
					wiz.camera_rig.shake(0.6 if is_boss else 0.35)
				PlayerInput.rumble(wiz.player_index, 0.5, 0.3 if is_boss else 0.1, 0.4)


## Little monsters: short roar, no screen shake, flinch from big hits.
func _is_small() -> bool:
	return look == Look.IMP or look == Look.PIRANHA


## Eyes are dim while a monster lurks and blaze once it hunts.
func _eye_energy() -> float:
	if _enraged:
		return 10.0
	return 1.5 if _state == "idle" else 6.0


func _choose_attack(dist: float) -> String:
	var head := global_position + Vector3(0, aim_height, 0)
	if is_boss:
		if look == Look.DEMON and _roots_timer <= 0.0 and dist < 24.0:
			return "roots"
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
		return "slam" if look in [Look.BRUTE, Look.SNAKE] else "melee"
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
	elif kind == "roots":
		_windup_left = 1.2
		_show_root_marks()
	if look == Look.PIRANHA:
		# Ripples and a fin breaking the water: "something is about to jump!"
		FX.burst(self, global_position + Vector3(0, 0.05, 0), Color(0.8, 0.95, 0.9, 0.8), 18, 2.5, 0.12, 0.5,
			{"direction": Vector3.UP, "spread": 50.0, "gravity": Vector3(0, -9, 0)})
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
		_eye_mat.emission_energy_multiplier = _eye_energy()
	if _target == null:
		return
	var to_target := _target.global_position - global_position
	to_target.y = 0.0
	match _attack_kind:
		"melee":
			if lunge_distance > 0.0:
				# Jump at the wizard: only hits if they don't get out of the way.
				_start_dash(to_target, clampf(to_target.length() - 0.5, 0.5, lunge_distance + attack_range), _lunge_time())
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
		"roots":
			_roots_timer = 4.5 if _enraged else 7.0
			_burst_roots()


## Seconds a lunge takes: jaguars leap a bit slower so you see them fly,
## piranhas arc high out of the water.
func _lunge_time() -> float:
	match look:
		Look.JAGUAR:
			return 0.35
		Look.PIRANHA:
			return 0.55
	return 0.2


## Roots attack: a glowing ring under every wizard, then thorny roots burst up there.
func _show_root_marks() -> void:
	_hide_root_marks()
	for w in get_tree().get_nodes_in_group("wizards"):
		var wiz := w as Wizard
		if wiz == null or wiz.is_down:
			continue
		var ring := MeshInstance3D.new()
		ring.mesh = Build.cylinder(1.6, 0.04)
		var m := Build.glow(eye_color, 2.0)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color.a = 0.4
		ring.material_override = m
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ring.top_level = true
		add_child(ring)
		ring.global_position = wiz.global_position + Vector3(0, 0.06, 0)
		ring.scale = Vector3(0.2, 1, 0.2)
		create_tween().tween_property(ring, "scale", Vector3.ONE, _windup_left * 0.9)
		_root_marks.append(ring)


func _hide_root_marks() -> void:
	for ring in _root_marks:
		if is_instance_valid(ring):
			ring.queue_free()
	_root_marks.clear()


func _burst_roots() -> void:
	var bark := Build.pbr("bark_brown_02", Color(0.85, 0.75, 0.55), 2.0, true)
	var tip := Build.glow(eye_color, 2.5)
	for ring in _root_marks:
		var center := ring.global_position
		var roots := Node3D.new()
		roots.top_level = true
		add_child(roots)
		roots.global_position = center
		for k in 6:
			var a := k * TAU / 6.0 + randf() * 0.4
			var spike := Build.part(roots, Build.cone(0.18, 1.6), bark,
				Vector3(cos(a) * 0.9, 0.7, sin(a) * 0.9), Vector3(cos(a) * 20.0, 0, sin(a) * -20.0))
			spike.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			Build.part(spike, Build.cone(0.07, 0.5), tip, Vector3(0, 0.62, 0))
		roots.scale = Vector3(1, 0.05, 1)
		var tw := roots.create_tween()
		tw.tween_property(roots, "scale", Vector3.ONE, 0.12).set_trans(Tween.TRANS_BACK)
		tw.tween_interval(0.6)
		tw.tween_property(roots, "scale", Vector3(1, 0.05, 1), 0.3)
		tw.tween_callback(roots.queue_free)
		FX.burst(self, center + Vector3(0, 0.3, 0), Color(0.45, 0.35, 0.25, 0.8), 20, 4.0, 0.6, 0.7,
			{"smoke": true, "gravity": Vector3(0, -6, 0)})
		for w in get_tree().get_nodes_in_group("wizards"):
			var wiz := w as Wizard
			if wiz and not wiz.is_down and wiz.global_position.distance_to(center) < 1.8:
				wiz.take_damage(damage, center)
	_hide_root_marks()


func _shoot(at: Vector3, count: int, spread: float) -> void:
	var start := global_position + Vector3(0, aim_height + 0.3, 0) + _forward() * (_radius + 0.4)
	var dir := (at - start).normalized()
	var color := Color(0.55, 1.0, 0.2)
	var style := "acid"
	if look == Look.DEMON:
		color = Color(0.5, 1.0, 0.25)
		style = "thorn"
	elif is_boss:
		color = Color(1.0, 0.3, 0.1)
		style = "hellfire"
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
			"style": style,
		})


func _start_dash(dir: Vector3, distance: float, time: float) -> void:
	dir.y = 0.0
	if dir.length() < 0.01:
		return
	_dash_dir = dir.normalized()
	_dash_speed = distance / time
	_dash_left = time
	_dash_time = time
	if look == Look.PIRANHA:
		submerged = false
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
	if look == Look.PIRANHA and _home != Vector3.INF:
		# Jump out of the water in an arc and splash back in.
		var t := clampf(1.0 - _dash_left / _dash_time, 0.0, 1.0)
		global_position.y = _home.y + sin(t * PI) * 2.4
	if _dash_left <= 0.0:
		_end_dash()


func _end_dash() -> void:
	_dash_left = 0.0
	_dash_can_hit = false
	if look == Look.PIRANHA and _home != Vector3.INF and not submerged:
		global_position.y = _home.y
		submerged = true
		FX.burst(self, global_position + Vector3(0, 0.1, 0), Color(0.8, 0.95, 0.9, 0.8), 24, 3.5, 0.12, 0.6,
			{"direction": Vector3.UP, "spread": 40.0, "gravity": Vector3(0, -9, 0)})
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
	_hide_root_marks()
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
			for i in _wings.size():
				var side := -1.0 if i == 0 else 1.0
				_wings[i].rotation.y = side * (-0.45 + sin(_anim_time * 2.0) * 0.5)
		Look.JAGUAR:
			var running := move.length() > 0.1 or _dash_left > 0.0
			for i in _legs.size():
				var phase := 0.0 if i in [0, 3] else PI
				_legs[i].rotation.x = sin(_anim_time * 1.2 + phase) * (0.7 if running else 0.05)
			_tail.rotation.y = sin(_anim_time * 0.7) * 0.5
			_tail.rotation.x = 0.2 + sin(_anim_time * 0.5) * 0.15
			# Pounce: the whole cat flies up in an arc, legs stretched out.
			var leap := 0.0
			if _dash_left > 0.0 and _dash_time > 0.0:
				leap = sin((1.0 - _dash_left / _dash_time) * PI) * 0.9
			_body.position.y = leap + absf(sin(_anim_time * 1.2)) * (0.06 if running else 0.0)
			_head.rotation.x = -0.25 if _state == "windup" else 0.0
		Look.SNAKE:
			# The body wiggles side to side, more toward the tail.
			for i in _segments.size():
				var amount := 0.15 + 0.35 * i / float(_segments.size())
				_segments[i].position.x = sin(_anim_time * 0.8 - i * 0.7) * amount
			_head.position.x = sin(_anim_time * 0.8 + 0.7) * 0.08
			var rear := 0.35 if _state == "windup" else 0.0
			_head.position.y = lerpf(_head.position.y, 1.45 + rear, 1.0 - exp(-10.0 * delta))
			_head.rotation.x = lerpf(_head.rotation.x, rear * 0.8, 1.0 - exp(-10.0 * delta))
		Look.CROC, Look.PIRANHA:
			# Hidden low in the water while lurking, rising up to attack.
			var rise := -_sink
			if _dash_left > 0.0:
				rise = 0.0
			elif _state == "windup":
				rise = 0.05 if look == Look.CROC else -0.45
			elif _state == "chase" and look == Look.CROC:
				rise = -0.25
			_model.position.y = lerpf(_model.position.y, rise, 1.0 - exp(-8.0 * delta))
			_tail.rotation.y = sin(_anim_time * (0.6 if look == Look.CROC else 2.0)) * 0.35
			if _jaw:
				var open := -0.7 if _state == "windup" else -0.05 - absf(sin(_anim_time * 0.3)) * 0.08
				_jaw.rotation.x = lerpf(_jaw.rotation.x, -open, 1.0 - exp(-14.0 * delta))
			for i in _legs.size():
				_legs[i].rotation.y = sin(_anim_time + i * PI * 0.5) * 0.4
			if look == Look.PIRANHA and _dash_left > 0.0:
				_body.rotation.x = lerpf(0.9, -0.9, 1.0 - _dash_left / _dash_time)
			else:
				_body.rotation.x = 0.0
		_:
			_body.position.y = absf(sin(_anim_time * 0.6)) * 0.08
			_body.rotation.z = sin(_anim_time * 0.6) * 0.04
			if look == Look.DEMON:
				_head.rotation.y = sin(_anim_time * 0.4) * 0.15
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
	if _state == "idle" or _state == "roar":
		_state = "chase"
		if _eye_mat:
			_eye_mat.emission_energy_multiplier = _eye_energy()
		if source is Wizard:
			_target = source as Wizard
	# Only big hits make imps flinch, so fast spells can't keep them stuck.
	if not is_boss and _is_small() and amount >= max_health * 0.3:
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


## An enraged boss calls two helpers into its arena (imps, or jaguars for the Jungle Demon).
func _summon_helpers() -> void:
	var arena := get_parent()
	if not arena.has_method("summon"):
		return
	for side in [-1.0, 1.0]:
		arena.summon("jaguar" if look == Look.DEMON else "imp", global_position + _model.global_basis.x * side * 3.0)


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
	var size_scale := 1.0
	match look:
		Look.JAGUAR:
			size_scale = 1.3
		Look.BRUTE, Look.SNAKE, Look.CROC:
			size_scale = 1.6
		Look.KNIGHT, Look.DEMON:
			size_scale = 2.4
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
