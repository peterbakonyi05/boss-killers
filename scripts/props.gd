class_name Props
## Decoration props by name, used by themes (LevelTheme.wall_props...) and the Prop
## level part. Each prop sits on the floor at its origin with its front facing −Z
## (its back against a wall). Visual only: no collision, so they never block paths.
## Some use CC0 models from assets/models/, the rest are built from shapes.

## Every kind spawn() knows. Keep in sync with the match below.
const KINDS := [
	"rock_small", "rock_mossy", "boulder", "dead_log", "barrel", "barrel_pile", "crate",
	"bucket", "statue", "fallen_knight", "lantern", "cage", "chandelier", "skull",
	"skull_pile", "bones", "candles", "cobweb", "chains", "gravestone", "coffin",
	"mushrooms", "crystals",
]

static var _bone_mat: StandardMaterial3D
static var _dark_mat: StandardMaterial3D
static var _wax_mat: StandardMaterial3D
static var _web_mat: ShaderMaterial


## Builds one prop under parent. rng picks sizes/variants (seeded = same every load).
## Returns null for an unknown kind or a missing model.
static func spawn(kind: String, parent: Node3D, pos: Vector3, yaw: float,
		rng: RandomNumberGenerator, theme: LevelTheme = null) -> Node3D:
	var root := Node3D.new()
	root.name = "Prop_" + kind
	root.position = pos
	root.rotation.y = yaw
	parent.add_child(root)
	var ok := true
	match kind:
		"rock_small":
			ok = Build.model(root, "rock_07", Vector3.ZERO, Vector3(0, rng.randf() * 360, 0), rng.randf_range(1.5, 3.5)) != null
		"rock_mossy":
			var n := rng.randi_range(7, 13)
			ok = Build.model(root, "rock_moss_set_02", Vector3.ZERO, Vector3(0, rng.randf() * 360, 0),
				rng.randf_range(0.45, 0.8), "rock_moss_set_02_rock%02d" % n) != null
		"boulder":
			var n := rng.randi_range(1, 6)
			ok = Build.model(root, "rock_moss_set_01", Vector3(0, -0.15, 0.3), Vector3(0, rng.randf() * 360, 0),
				rng.randf_range(0.55, 0.85), "rock_moss_set_01_rock%02d" % n) != null
		"dead_log":
			ok = Build.model(root, "dead_tree_trunk", Vector3(0, 0, 0.1), Vector3(0, rng.randf_range(-15, 15), rng.randf_range(-4, 4)), rng.randf_range(0.6, 0.9)) != null
		"barrel":
			ok = Build.model(root, "wine_barrel_01", Vector3.ZERO, Vector3(0, rng.randf() * 360, 0), rng.randf_range(0.9, 1.1)) != null
			if rng.randf() < 0.5:
				Build.model(root, "wine_barrel_01", Vector3(0.8, 0, 0.1), Vector3(0, rng.randf() * 360, 0), 0.95)
		"barrel_pile":
			ok = Build.model(root, "wooden_barrels_01", Vector3(-0.4, 0, 0), Vector3(0, rng.randf() * 360, 0), 1.0, "wooden_barrels_01_barrel01") != null
			Build.model(root, "wooden_barrels_01", Vector3(0.45, 0, 0.1), Vector3(0, rng.randf() * 360, 0), 1.0, "wooden_barrels_01_barrel02")
			Build.model(root, "wooden_barrels_01", Vector3(0.0, 0, -0.7), Vector3(0, rng.randf() * 360, 0), 1.0, "wooden_barrels_01_piece01")
		"crate":
			ok = Build.model(root, "wooden_crate_01", Vector3.ZERO, Vector3(0, rng.randf_range(-20, 20), 0), 1.6) != null
			if rng.randf() < 0.5:
				Build.model(root, "wooden_crate_01", Vector3(0.1, 0.5, 0), Vector3(0, rng.randf_range(-40, 40), 0), 1.3)
		"bucket":
			ok = Build.model(root, "wooden_bucket_01", Vector3.ZERO, Vector3(0, rng.randf() * 360, 0), 1.3) != null
		"statue":
			ok = Build.model(root, "gothic_statue", Vector3(0, 0, 0.2), Vector3(0, 180, 0), 1.3) != null
		"fallen_knight":
			# What is left of a knight who did not make it: shield, mace and a skull.
			ok = Build.model(root, "kite_shield", Vector3(0, 0.7, 0.25), Vector3(15, rng.randf_range(-10, 10), rng.randf_range(-8, 8))) != null
			Build.model(root, "ornate_medieval_mace", Vector3(0.5, 0.05, -0.1), Vector3(0, rng.randf() * 360, 90))
			_skull(root, Vector3(-0.35, 0, -0.2), rng)
			_bones(root, Vector3(0.1, 0, -0.45), rng, 3)
		"lantern":
			ok = Build.model(root, "Lantern_01", Vector3.ZERO, Vector3(0, rng.randf() * 360, 0), 2.2) != null
			var flame_color := theme.torch_color if theme else Color(1.0, 0.6, 0.25)
			Build.part(root, Build.sphere(0.045), Build.glow(flame_color, 6.0), Vector3(0, 0.2, 0))
			Build.light(root, flame_color, 0.6, 3.0, Vector3(0, 0.35, 0))
		"cage":
			# High prop: hangs from an iron arm sticking out of the wall.
			var drop := rng.randf_range(0.5, 1.4)
			_bracket(root, 0.8)
			_chain(root, Vector3(0, 0, -0.8), drop)
			ok = Build.model(root, "caged_hanging_light", Vector3(0, -drop, -0.8), Vector3(0, 90, 0), 1.3) != null
		"chandelier":
			_bracket(root, 1.0)
			_chain(root, Vector3(0, 0, -1.0), 0.6)
			ok = Build.model(root, "Chandelier_02", Vector3(0, -0.6 - 0.95 * 1.3, -1.0), Vector3.ZERO, 1.3) != null
		"skull":
			_skull(root, Vector3.ZERO, rng)
		"skull_pile":
			for i in rng.randi_range(4, 7):
				var a := rng.randf() * TAU
				var r := rng.randf_range(0.0, 0.35)
				_skull(root, Vector3(cos(a) * r, 0.0 if r > 0.18 else 0.16, sin(a) * r), rng)
			_bones(root, Vector3(0, 0, -0.2), rng, 4)
		"bones":
			_bones(root, Vector3.ZERO, rng, rng.randi_range(2, 5))
		"candles":
			_candles(root, rng, theme)
		"cobweb":
			_cobweb(root, rng)
		"chains":
			for i in rng.randi_range(1, 3):
				_chain(root, Vector3(rng.randf_range(-0.6, 0.6), 0, -0.05), rng.randf_range(1.2, 3.0))
		"gravestone":
			_gravestone(root, rng, theme)
		"coffin":
			_coffin(root, rng)
		"mushrooms":
			_mushrooms(root, rng)
		"crystals":
			_crystals(root, rng, theme)
		_:
			ok = false
	if not ok:
		root.queue_free()
		return null
	for gi in root.find_children("*", "GeometryInstance3D", true, false):
		var g := gi as GeometryInstance3D
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		g.visibility_range_end = 45.0
		g.visibility_range_end_margin = 5.0
		g.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	return root


static func _bone() -> StandardMaterial3D:
	if _bone_mat == null:
		_bone_mat = Build.mat(Color(0.82, 0.77, 0.66), 0.7)
		_dark_mat = Build.mat(Color(0.02, 0.015, 0.015), 1.0)
	return _bone_mat


## A friendly-spooky skull: round head, jaw, dark eye holes.
static func _skull(parent: Node3D, pos: Vector3, rng: RandomNumberGenerator) -> void:
	var s := Build.pivot(parent, pos)
	s.rotation_degrees = Vector3(rng.randf_range(-15, 15), rng.randf_range(-60, 60), rng.randf_range(-15, 15))
	var sc := rng.randf_range(0.85, 1.15)
	s.scale = Vector3.ONE * sc
	var bone := _bone()
	Build.part(s, Build.sphere(0.12), bone, Vector3(0, 0.13, 0.02), Vector3.ZERO, Vector3(0.95, 0.9, 1.1))
	Build.part(s, Build.box(Vector3(0.15, 0.07, 0.1)), bone, Vector3(0, 0.05, -0.06))
	for side in [-1.0, 1.0]:
		Build.part(s, Build.sphere(0.035), _dark_mat, Vector3(side * 0.045, 0.12, -0.09), Vector3.ZERO, Vector3(1.0, 1.2, 0.6))
	Build.part(s, Build.cone(0.018, 0.04), _dark_mat, Vector3(0, 0.075, -0.105), Vector3(180, 0, 0))
	for i in 4:
		Build.part(s, Build.box(Vector3(0.018, 0.022, 0.01)), bone, Vector3(-0.03 + i * 0.02, 0.025, -0.112))


static func _bones(parent: Node3D, pos: Vector3, rng: RandomNumberGenerator, count: int) -> void:
	var bone := _bone()
	for i in count:
		var b := Build.pivot(parent, pos + Vector3(rng.randf_range(-0.35, 0.35), 0.03, rng.randf_range(-0.25, 0.25)))
		b.rotation_degrees = Vector3(0, rng.randf() * 360, 90)
		var length := rng.randf_range(0.25, 0.45)
		Build.part(b, Build.cylinder(0.022, length), bone)
		for end in [-1.0, 1.0]:
			Build.part(b, Build.sphere(0.035), bone, Vector3(0.015, end * length * 0.5, 0))
			Build.part(b, Build.sphere(0.035), bone, Vector3(-0.015, end * length * 0.5, 0))


static func _candles(parent: Node3D, rng: RandomNumberGenerator, theme: LevelTheme) -> void:
	if _wax_mat == null:
		_wax_mat = Build.mat(Color(0.88, 0.84, 0.72), 0.5)
	var flame_color := theme.torch_color if theme else Color(1.0, 0.6, 0.25)
	var flame_mat := Build.glow(flame_color.lightened(0.2), 5.0)
	for i in rng.randi_range(3, 6):
		var p := Vector3(rng.randf_range(-0.3, 0.3), 0, rng.randf_range(-0.2, 0.2))
		var h := rng.randf_range(0.12, 0.45)
		var r := rng.randf_range(0.03, 0.05)
		Build.part(parent, Build.cylinder(r, h), _wax_mat, p + Vector3(0, h * 0.5, 0))
		# Melted wax at the bottom
		Build.part(parent, Build.cylinder(r * 1.8, 0.02), _wax_mat, p + Vector3(0, 0.01, 0))
		Build.part(parent, Build.sphere(0.022), flame_mat, p + Vector3(0, h + 0.035, 0), Vector3.ZERO, Vector3(0.7, 1.6, 0.7))
	Build.light(parent, flame_color, 0.7, 3.5, Vector3(0, 0.6, -0.2))


## A spider web flat against the wall (drawn by a shader, no texture file).
static func _cobweb(parent: Node3D, rng: RandomNumberGenerator) -> void:
	if _web_mat == null:
		var sh := Shader.new()
		sh.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 color : source_color = vec4(0.85, 0.85, 0.9, 0.55);
void fragment() {
	// Web anchored in the top corner (uv 0,0): spokes + rings.
	vec2 p = UV;
	float r = length(p);
	float a = atan(p.y, p.x);
	float spokes = smoothstep(0.035, 0.0, abs(fract(a * 9.0 / 3.14159) - 0.5) * r * 2.2);
	float rings = smoothstep(0.012, 0.0, abs(fract(r * 9.0 + sin(a * 18.0) * 0.06) - 0.5) * 0.11);
	float web = max(spokes, rings * step(0.08, r)) * smoothstep(1.0, 0.75, r);
	ALBEDO = color.rgb;
	ALPHA = web * color.a;
}
"""
		_web_mat = ShaderMaterial.new()
		_web_mat.shader = sh
	var size := rng.randf_range(0.9, 1.8)
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	# Quad center is offset so its uv (0,0) corner hangs at the prop origin.
	var mi := Build.part(parent, q, _web_mat, Vector3(size * 0.5 * (1 if rng.randf() < 0.5 else -1), -size * 0.5, 0.02))
	if mi.position.x < 0.0:
		mi.scale.x = -1.0


static func _iron() -> StandardMaterial3D:
	return Build.pbr("rusty_metal_02", Color(0.55, 0.5, 0.48), 2.0, false)


## A chain hanging down from top.
static func _chain(parent: Node3D, top: Vector3, length: float) -> void:
	var metal := _iron()
	for i in int(length / 0.11):
		Build.part(parent, Build.torus(0.025, 0.05), metal, top - Vector3(0, 0.06 + i * 0.11, 0),
			Vector3(90, 90 * (i % 2), 0), Vector3(1.0, 1.0, 1.6))


## An iron arm from the wall (origin) reaching out to −Z.
static func _bracket(parent: Node3D, reach: float) -> void:
	var metal := _iron()
	Build.part(parent, Build.box(Vector3(0.06, 0.06, reach)), metal, Vector3(0, 0, -reach * 0.5))
	Build.part(parent, Build.box(Vector3(0.05, 0.4, 0.05)), metal, Vector3(0, -0.2, -0.03))
	Build.part(parent, Build.box(Vector3(0.04, 0.04, reach * 0.7)), metal, Vector3(0, -0.2, -reach * 0.3), Vector3(-30, 0, 0))


static func _gravestone(parent: Node3D, rng: RandomNumberGenerator, theme: LevelTheme) -> void:
	var stone := Build.pbr(theme.stone_texture if theme else "mossy_stone_wall", Color(0.75, 0.75, 0.78), 1.2, true)
	var stone_root := Build.pivot(parent)
	stone_root.rotation_degrees = Vector3(rng.randf_range(-8, 8), rng.randf_range(-15, 15), rng.randf_range(-8, 8))
	var w := rng.randf_range(0.55, 0.8)
	var h := rng.randf_range(0.7, 1.1)
	Build.part(stone_root, Build.box(Vector3(w, h, 0.16)), stone, Vector3(0, h * 0.5, 0))
	Build.part(stone_root, Build.cylinder(w * 0.5, 0.16), stone, Vector3(0, h, 0), Vector3(90, 0, 0))
	var groove := Build.mat(Color(0.05, 0.05, 0.06), 1.0)
	Build.part(stone_root, Build.box(Vector3(0.05, 0.36, 0.01)), groove, Vector3(0, h * 0.75, -0.081))
	Build.part(stone_root, Build.box(Vector3(0.22, 0.05, 0.01)), groove, Vector3(0, h * 0.82, -0.081))
	# Little mound of earth
	Build.part(parent, Build.sphere(0.45), Build.pbr("burned_ground_01", Color(0.6, 0.5, 0.45), 1.0), Vector3(0, -0.28, -0.5), Vector3.ZERO, Vector3(1.2, 0.7, 2.0))


static func _coffin(parent: Node3D, rng: RandomNumberGenerator) -> void:
	var wood := Build.pbr("wood_planks", Color(0.45, 0.32, 0.25), 1.5, true)
	var c := Build.pivot(parent, Vector3(0, 0.22, -0.2))
	c.rotation_degrees.y = 90 + rng.randf_range(-20, 20)
	var body := CylinderMesh.new()
	body.radial_segments = 6
	body.rings = 1
	body.top_radius = 0.45
	body.bottom_radius = 0.45
	body.height = 0.4
	Build.part(c, body, wood, Vector3.ZERO, Vector3.ZERO, Vector3(2.2, 1.0, 0.75))
	# Lid pushed open a bit... who is inside?
	var lid := Build.pivot(c, Vector3(0.15, 0.24, 0.05))
	lid.rotation_degrees = Vector3(0, rng.randf_range(8, 20), rng.randf_range(-6, 0))
	var lid_mesh := body.duplicate() as CylinderMesh
	lid_mesh.height = 0.06
	Build.part(lid, lid_mesh, wood, Vector3.ZERO, Vector3.ZERO, Vector3(2.2, 1.0, 0.75))
	var metal := Build.mat(Color(0.3, 0.27, 0.22), 0.4, 0.8)
	Build.part(lid, Build.box(Vector3(0.05, 0.02, 0.4)), metal, Vector3(-0.35, 0.04, 0))
	Build.part(lid, Build.box(Vector3(0.2, 0.02, 0.05)), metal, Vector3(-0.35, 0.04, 0))


static func _mushrooms(parent: Node3D, rng: RandomNumberGenerator) -> void:
	var stem := Build.mat(Color(0.8, 0.78, 0.7), 0.8)
	var hue := rng.randf_range(0.45, 0.8)
	var cap := Build.glow(Color.from_hsv(hue, 0.7, 0.9), 1.5)
	for i in rng.randi_range(3, 7):
		var p := Vector3(rng.randf_range(-0.4, 0.4), 0, rng.randf_range(-0.3, 0.3))
		var h := rng.randf_range(0.08, 0.3)
		Build.part(parent, Build.cylinder(0.02, h, 0.015), stem, p + Vector3(0, h * 0.5, 0))
		Build.part(parent, Build.sphere(rng.randf_range(0.04, 0.09)), cap, p + Vector3(0, h, 0), Vector3.ZERO, Vector3(1.0, 0.45, 1.0))


static func _crystals(parent: Node3D, rng: RandomNumberGenerator, theme: LevelTheme) -> void:
	var color := theme.wisp_color if theme else Color(0.5, 0.8, 1.0)
	var m := Build.see_through(Color(color.r, color.g, color.b, 0.75), 1.4)
	for i in rng.randi_range(3, 6):
		var h := rng.randf_range(0.3, 1.0)
		var c := Build.part(parent, Build.cylinder(h * 0.15, h, 0.0), m,
			Vector3(rng.randf_range(-0.3, 0.3), h * 0.4, rng.randf_range(-0.2, 0.2)),
			Vector3(rng.randf_range(-25, 25), 0, rng.randf_range(-25, 25)))
		(c.mesh as CylinderMesh).radial_segments = 6
