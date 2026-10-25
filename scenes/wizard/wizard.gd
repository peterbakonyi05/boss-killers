class_name Wizard
extends CharacterBody3D
## A player wizard: moves, jumps, casts spells, raises shields, falls and revives.

signal downed(wizard: Wizard)
signal revived(wizard: Wizard)

const SHIELD_SCENE := preload("res://scenes/magic/shield.tscn")

const SPEED := 6.5
const SHIELD_SPEED := 3.5
const ACCEL := 45.0
const AIR_ACCEL := 20.0
const JUMP_VELOCITY := 8.5
const GRAVITY := 22.0
const AIM_RANGE := 32.0
const AIM_ANGLE := 0.56  # about 32 degrees
const INTERACT_RANGE := 3.0
const SLOTS := ["spell_strong", "spell_weak", "shield_strong", "shield_weak"]

@export var player_index := 0
@export_enum("fire", "ice") var element := "fire"

var game  # Game (untyped to avoid a circular class reference)
var camera_rig: CameraRig
var hud  # PlayerHUD
var spell: SpellData

var max_health := 100.0
var health := 100.0
var is_down := false
var revive_left := 0.0
var controls_locked := false
var last_safe_position := Vector3.ZERO

var _cooldowns := {}
var _shield: Shield
var _shield_slot := ""
var _shield_left := 0.0
var _invulnerable := 0.0
var _regen_wait := 0.0
var _aim_hold := 0.0
var _aim_dir := Vector3.FORWARD
var _safe_timer := 0.0
var _hurt_flash := 0.0
var _interactable = null

var _model: Node3D
var _body_pivot: Node3D
var _arm_right: Node3D
var _orb_mat: StandardMaterial3D
var _orb_light: OmniLight3D
var _hurt_mat: StandardMaterial3D
var _model_meshes: Array[MeshInstance3D] = []
var _walk_time := 0.0


func _ready() -> void:
	add_to_group("wizards")
	collision_layer = 2
	collision_mask = 1 | 4
	floor_snap_length = 0.3
	var balance := GameState.balance
	max_health = balance.wizard_max_health
	health = max_health
	spell = GameState.spell_data(element)
	for slot in SLOTS:
		_cooldowns[slot] = 0.0
	_build_model()
	_shield = SHIELD_SCENE.instantiate()
	_shield.wizard = self
	_shield.position = Vector3(0, 1.0, 0)
	add_child(_shield)
	last_safe_position = global_position


func display_name() -> String:
	return UIUtil.wizard_name(element)


func element_color() -> Color:
	return UIUtil.element_color(element)


# --- Model -------------------------------------------------------------------

func _build_model() -> void:
	var fire := element == "fire"
	var robe := Color(0.55, 0.08, 0.05) if fire else Color(0.08, 0.2, 0.55)
	var robe_dark := robe.darkened(0.35)
	var trim := element_color()
	var skin := Color(0.96, 0.78, 0.64) if fire else Color(0.85, 0.66, 0.52)
	var hair := Color(0.75, 0.25, 0.08) if fire else Color(0.9, 0.95, 1.0)
	_model = Node3D.new()
	add_child(_model)
	_body_pivot = Build.pivot(_model)
	var robe_mat := Build.mat(robe, 0.9)
	var p := _body_pivot
	_model_meshes.append(Build.part(p, Build.cylinder(0.5, 1.15, 0.24), robe_mat, Vector3(0, 0.575, 0)))
	_model_meshes.append(Build.part(p, Build.cylinder(0.52, 0.08), Build.glow(trim, 1.5), Vector3(0, 0.05, 0)))
	_model_meshes.append(Build.part(p, Build.cylinder(0.3, 0.08), Build.glow(trim, 1.2), Vector3(0, 0.98, 0)))
	_model_meshes.append(Build.part(p, Build.sphere(0.3), Build.mat(robe_dark, 0.9), Vector3(0, 1.2, 0), Vector3.ZERO, Vector3(1.1, 0.8, 0.85)))
	# Head and face
	_model_meshes.append(Build.part(p, Build.sphere(0.23), Build.mat(skin, 0.7), Vector3(0, 1.52, 0)))
	_model_meshes.append(Build.part(p, Build.sphere(0.245), Build.mat(hair, 0.9), Vector3(0, 1.57, 0.05), Vector3.ZERO, Vector3(1.0, 0.9, 1.0)))
	var eye_mat := Build.mat(Color(0.08, 0.06, 0.06), 0.3)
	Build.part(p, Build.sphere(0.035), eye_mat, Vector3(-0.08, 1.55, -0.2))
	Build.part(p, Build.sphere(0.035), eye_mat, Vector3(0.08, 1.55, -0.2))
	# Hat
	var hat_mat := Build.mat(robe_dark, 0.85)
	_model_meshes.append(Build.part(p, Build.cylinder(0.44, 0.05), hat_mat, Vector3(0, 1.68, 0)))
	_model_meshes.append(Build.part(p, Build.cone(0.27, 0.7), hat_mat, Vector3(0, 2.02, 0.06), Vector3(-14, 0, 0)))
	Build.part(p, Build.cylinder(0.28, 0.06), Build.glow(trim, 2.0), Vector3(0, 1.74, 0))
	# Arms
	var left_arm := Build.pivot(p, Vector3(-0.32, 1.25, 0))
	_model_meshes.append(Build.part(left_arm, Build.capsule(0.09, 0.62), robe_mat, Vector3(0, -0.25, 0), Vector3(0, 0, -12)))
	_arm_right = Build.pivot(p, Vector3(0.32, 1.25, 0))
	_model_meshes.append(Build.part(_arm_right, Build.capsule(0.09, 0.62), robe_mat, Vector3(0, -0.25, 0), Vector3(0, 0, 12)))
	# Staff with a glowing orb
	var staff := Build.pivot(_arm_right, Vector3(0.1, -0.45, -0.12))
	Build.part(staff, Build.cylinder(0.035, 1.6), Build.mat(Color(0.35, 0.2, 0.1), 0.8), Vector3(0, 0.2, 0))
	_orb_mat = Build.glow(trim, 3.0)
	if fire:
		Build.part(staff, Build.sphere(0.12), _orb_mat, Vector3(0, 1.05, 0))
	else:
		Build.part(staff, Build.cone(0.1, 0.32), _orb_mat, Vector3(0, 1.1, 0))
		Build.part(staff, Build.cone(0.1, 0.2), _orb_mat, Vector3(0, 0.92, 0), Vector3(180, 0, 0))
	_orb_light = Build.light(staff, trim, 1.4, 5.0, Vector3(0, 1.05, 0))
	_hurt_mat = Build.glow(Color(1, 0.2, 0.2), 1.5)
	_hurt_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_hurt_mat.albedo_color.a = 0.0


# --- Main loop ---------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_tick_timers(delta)
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	if is_down:
		velocity.x = move_toward(velocity.x, 0.0, ACCEL * delta)
		velocity.z = move_toward(velocity.z, 0.0, ACCEL * delta)
		move_and_slide()
		return

	var input := Vector2.ZERO if controls_locked else PlayerInput.get_move(player_index)
	var yaw := camera_rig.get_yaw() if camera_rig else 0.0
	var dir := Vector3(input.x, 0.0, input.y).rotated(Vector3.UP, yaw)
	var top_speed := SHIELD_SPEED if _shield_slot == "shield_strong" else SPEED
	var accel := ACCEL if is_on_floor() else AIR_ACCEL
	velocity.x = move_toward(velocity.x, dir.x * top_speed, accel * delta)
	velocity.z = move_toward(velocity.z, dir.z * top_speed, accel * delta)
	if not controls_locked and is_on_floor() and PlayerInput.just_pressed(player_index, "jump"):
		velocity.y = JUMP_VELOCITY
	move_and_slide()

	_update_facing(dir, delta)
	_animate(delta, Vector2(velocity.x, velocity.z).length())
	_track_safe_ground(delta)
	if global_position.y < -25.0:
		fall_in_lava()
	if controls_locked:
		return
	_handle_magic()
	_handle_interact()


func _tick_timers(delta: float) -> void:
	for slot in SLOTS:
		_cooldowns[slot] = maxf(0.0, _cooldowns[slot] - delta)
	_invulnerable = maxf(0.0, _invulnerable - delta)
	_aim_hold = maxf(0.0, _aim_hold - delta)
	if _hurt_flash > 0.0:
		_hurt_flash = maxf(0.0, _hurt_flash - delta * 3.0)
		_hurt_mat.albedo_color.a = _hurt_flash * 0.6
		_hurt_mat.emission_energy_multiplier = _hurt_flash * 2.0
		if _hurt_flash == 0.0:
			_set_overlay(null)
	if _shield_slot != "":
		_shield_left -= delta
		var released := _shield_slot == "shield_strong" and not PlayerInput.pressed(player_index, "shield_strong")
		if _shield_left <= 0.0 or released or is_down:
			_end_shield()
	if is_down:
		var busy: bool = game != null and game.busy
		if not busy:
			revive_left -= delta
			if revive_left <= 0.0:
				revive()
		return
	_regen_wait -= delta
	if _regen_wait <= 0.0 and health < max_health:
		health = minf(max_health, health + GameState.balance.regen_per_second * delta)


func _update_facing(dir: Vector3, delta: float) -> void:
	var face := Vector3.ZERO
	if _aim_hold > 0.0:
		face = _aim_dir
	elif dir.length() > 0.1:
		face = dir
	if face.length() > 0.01:
		var target_yaw := atan2(-face.x, -face.z)
		_model.rotation.y = lerp_angle(_model.rotation.y, target_yaw, 1.0 - exp(-14.0 * delta))


func _animate(delta: float, speed: float) -> void:
	if speed > 0.5 and is_on_floor():
		_walk_time += delta * speed * 1.6
	_body_pivot.position.y = absf(sin(_walk_time)) * 0.06
	_body_pivot.rotation.z = sin(_walk_time) * 0.04
	_arm_right.rotation.x = lerpf(_arm_right.rotation.x, -1.2 if _aim_hold > 0.0 else 0.0, 1.0 - exp(-12.0 * delta))
	var glow := 3.0 + _aim_hold * 6.0
	_orb_mat.emission_energy_multiplier = glow
	_orb_light.light_energy = 1.2 + _aim_hold * 3.0


func _track_safe_ground(delta: float) -> void:
	_safe_timer -= delta
	if _safe_timer > 0.0 or not is_on_floor():
		return
	_safe_timer = 0.25
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		if c.get_normal().y < 0.7:
			continue
		var floor_node := c.get_collider() as Node
		if floor_node and not floor_node.is_in_group("unsafe_ground"):
			last_safe_position = global_position
		return


# --- Magic -------------------------------------------------------------------

func _handle_magic() -> void:
	if PlayerInput.pressed(player_index, "spell_strong"):
		_try_cast(true)
	if PlayerInput.pressed(player_index, "spell_weak"):
		_try_cast(false)
	if PlayerInput.just_pressed(player_index, "shield_strong"):
		_try_shield("shield_strong")
	if PlayerInput.just_pressed(player_index, "shield_weak"):
		_try_shield("shield_weak")


func cast(strong: bool) -> bool:
	return _try_cast(strong)


func _try_cast(strong: bool) -> bool:
	var slot := "spell_strong" if strong else "spell_weak"
	if _cooldowns[slot] > 0.0 or _shield_slot == "shield_strong" or is_down:
		return false
	_cooldowns[slot] = spell.slot_cooldown(slot)
	var aim := _aim_direction()
	_aim_dir = Vector3(aim.x, 0.0, aim.z).normalized()
	_aim_hold = 0.45
	_model.rotation.y = atan2(-_aim_dir.x, -_aim_dir.z)
	var count := spell.strong_count if strong else spell.weak_count
	var dmg := (spell.strong_damage if strong else spell.weak_damage) * GameState.upgrade_mult(element, slot)
	var start := global_position + Vector3(0, 1.35, 0) + _aim_dir * 0.7
	for i in count:
		var spread := 0.0 if count == 1 else lerpf(-0.12, 0.12, float(i) / float(count - 1))
		var dir := aim.rotated(Vector3.UP, spread)
		Projectile.launch(self, start + _aim_dir.cross(Vector3.UP) * spread * 2.0, dir, {
			"team": "player",
			"element": element,
			"damage": dmg,
			"speed": spell.strong_speed if strong else spell.weak_speed,
			"radius": spell.strong_size if strong else spell.weak_size,
			"color": spell.color,
			"strong": strong,
			"spell": spell,
			"caster": self,
			"life": 2.2 if strong else 1.4,
		})
	if strong:
		PlayerInput.rumble(player_index, 0.3, 0.0, 0.12)
	return true


## Where spells fly: toward the monster closest to the middle of the screen,
## or straight ahead if there is none (helps younger players hit things).
func _aim_direction() -> Vector3:
	var forward := Vector3.FORWARD.rotated(Vector3.UP, camera_rig.get_yaw() if camera_rig else _model.rotation.y)
	var origin := global_position + Vector3(0, 1.35, 0)
	var best: Node3D = null
	var best_score := INF
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var e := enemy as Node3D
		if e == null or e.get("dead") == true:
			continue
		var target := e.global_position + Vector3(0, float(e.get("aim_height")), 0)
		var to := target - origin
		var dist := to.length()
		if dist > AIM_RANGE or dist < 0.1:
			continue
		var angle := forward.angle_to(Vector3(to.x, 0, to.z).normalized())
		if angle > AIM_ANGLE:
			continue
		var score := angle * 10.0 + dist * 0.15
		if score < best_score and _can_see(origin, target):
			best_score = score
			best = e
	if best:
		var target := best.global_position + Vector3(0, float(best.get("aim_height")), 0)
		return (target - origin).normalized()
	return forward


func _can_see(from: Vector3, to: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, to, 1)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _try_shield(slot: String) -> void:
	if _cooldowns[slot] > 0.0 or _shield_slot != "":
		return
	var strong := slot == "shield_strong"
	var mult := GameState.upgrade_mult(element, slot)
	_shield_slot = slot
	if strong:
		_shield_left = spell.shield_strong_duration * mult
		_shield.raise(spell.color, spell.shield_strong_radius, spell.shield_strong_block, true)
	else:
		_shield_left = spell.shield_weak_duration * mult
		_shield.raise(spell.color, spell.shield_weak_radius, minf(0.95, spell.shield_weak_block * mult), false)


func _end_shield() -> void:
	if _shield_slot == "":
		return
	_cooldowns[_shield_slot] = spell.slot_cooldown(_shield_slot)
	_shield_slot = ""
	_shield.drop()


func shield_active(slot: String) -> bool:
	return _shield_slot == slot


## 1.0 right after use, 0.0 when ready.
func cooldown_fraction(slot: String) -> float:
	var total := spell.slot_cooldown(slot)
	if total <= 0.0:
		return 0.0
	return clampf(_cooldowns[slot] / total, 0.0, 1.0)


# --- Interacting -------------------------------------------------------------

func _handle_interact() -> void:
	var best = null
	var best_dist := INTERACT_RANGE
	for node in get_tree().get_nodes_in_group("interactable"):
		var n = node
		if not n.can_interact(self):
			continue
		var d: float = n.global_position.distance_to(global_position)
		if d < best_dist:
			best_dist = d
			best = n
	_interactable = best
	if hud:
		hud.set_prompt(best.get_prompt(self) if best else "")
	if best and PlayerInput.just_pressed(player_index, "interact"):
		best.interact(self)


# --- Getting hurt ------------------------------------------------------------

## Hit by a monster's projectile.
func take_hit(p: Projectile) -> bool:
	if is_down:
		return false
	take_damage(p.damage, p.global_position)
	return true


func take_damage(amount: float, from := Vector3.INF, ignore_shield := false) -> void:
	if is_down or _invulnerable > 0.0:
		return
	if _shield_slot != "" and not ignore_shield:
		amount *= 1.0 - _shield.block
		_shield.on_block(global_position + Vector3(0, 1.0, 0) + (from - global_position).normalized() * 1.2 if from != Vector3.INF else global_position + Vector3.UP)
		if amount <= 0.01:
			return
	health -= amount
	_regen_wait = GameState.balance.regen_delay
	_hurt_flash = 1.0
	_set_overlay(_hurt_mat)
	if camera_rig:
		camera_rig.shake(0.5)
	PlayerInput.rumble(player_index, 0.6, 0.4, 0.2)
	if hud:
		hud.flash_hurt()
	if from != Vector3.INF:
		var push := global_position - from
		push.y = 0.0
		if push.length() > 0.01:
			velocity += push.normalized() * 4.0
	if health <= 0.0:
		_go_down()


func _set_overlay(m: Material) -> void:
	for mi in _model_meshes:
		mi.material_overlay = m


func _go_down() -> void:
	health = 0.0
	is_down = true
	revive_left = GameState.balance.revive_time
	_end_shield()
	_aim_hold = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_model, "rotation:x", deg_to_rad(-80.0), 0.4).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_property(_model, "position:y", 0.35, 0.4)
	FX.burst(self, global_position + Vector3(0, 1, 0), element_color() * 1.5, 20, 3.0, 0.3, 0.8)
	PlayerInput.rumble(player_index, 0.8, 0.8, 0.5)
	downed.emit(self)


func revive(full := false) -> void:
	is_down = false
	revive_left = 0.0
	health = max_health if full else max_health * GameState.balance.revive_health
	_invulnerable = 2.0
	_regen_wait = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_model, "rotation:x", 0.0, 0.3)
	tw.tween_property(_model, "position:y", 0.0, 0.3)
	FX.burst(self, global_position + Vector3(0, 1, 0), Color(1, 0.95, 0.6) * 2.0, 30, 4.0, 0.3, 0.8)
	revived.emit(self)


## Fell into lava: lose some health and pop back to where we last stood safely.
func fall_in_lava() -> void:
	var was_down := is_down
	_invulnerable = 0.0
	take_damage(GameState.balance.lava_damage, Vector3.INF, true)
	teleport(last_safe_position + Vector3(0, 0.5, 0))
	if not was_down and not is_down:
		_invulnerable = 1.0
	if hud:
		hud.show_message("Ouch! Hot lava!", 1.5)


func teleport(pos: Vector3, safe := false) -> void:
	global_position = pos
	velocity = Vector3.ZERO
	if safe:
		last_safe_position = pos
	if camera_rig:
		camera_rig.snap()


## Back to a checkpoint with full health (after both wizards fell).
func respawn(pos: Vector3) -> void:
	_end_shield()
	controls_locked = false
	teleport(pos, true)
	if is_down:
		revive(true)
	else:
		health = max_health
		_invulnerable = 2.0
	for slot in SLOTS:
		_cooldowns[slot] = 0.0
