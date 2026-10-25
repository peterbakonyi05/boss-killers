class_name FX
## Particle bursts, smoke, coins and floating text, all made from code.

static var _soft_texture: GradientTexture2D
static var _glow_particle_mat: StandardMaterial3D
static var _smoke_particle_mat: StandardMaterial3D
static var _coin_mesh: CylinderMesh
static var _coin_mat: StandardMaterial3D


## The node effects get added to (the level, so they stay in the 3D world).
static func world(node: Node) -> Node3D:
	if node == null or not node.is_inside_tree():
		return null
	var level := node.get_tree().get_first_node_in_group("level") as Node3D
	if level:
		return level
	return node.get_parent() as Node3D


static func soft_texture() -> Texture2D:
	if _soft_texture == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(0.5, 0.0)
		t.width = 64
		t.height = 64
		_soft_texture = t
	return _soft_texture


static func particle_material(smoke := false) -> StandardMaterial3D:
	if smoke and _smoke_particle_mat:
		return _smoke_particle_mat
	if not smoke and _glow_particle_mat:
		return _glow_particle_mat
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = soft_texture()
	if smoke:
		_smoke_particle_mat = m
	else:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_glow_particle_mat = m
	return m


## Makes a particle emitter. Options: direction, spread, speed_min, speed_max,
## gravity, radius, box (Vector3 extents), damping, smoke (bool).
static func particles(color: Color, amount: int, lifetime: float, size: float, opts := {}) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = lifetime
	var pm := ParticleProcessMaterial.new()
	pm.direction = opts.get("direction", Vector3.UP)
	pm.spread = opts.get("spread", 180.0)
	pm.initial_velocity_min = opts.get("speed_min", 0.5)
	pm.initial_velocity_max = opts.get("speed_max", 2.0)
	pm.gravity = opts.get("gravity", Vector3.ZERO)
	pm.damping_min = opts.get("damping", 0.0)
	pm.damping_max = opts.get("damping", 0.0)
	pm.scale_min = 0.6
	pm.scale_max = 1.2
	if opts.has("box"):
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		pm.emission_box_extents = opts["box"]
	else:
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		pm.emission_sphere_radius = opts.get("radius", 0.2)
	var ramp := Gradient.new()
	ramp.set_color(0, color)
	ramp.set_color(1, Color(color.r, color.g, color.b, 0.0))
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	pm.color_ramp = ramp_tex
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(1.0, 0.2))
	var curve_tex := CurveTexture.new()
	curve_tex.curve = curve
	pm.scale_curve = curve_tex
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	quad.material = particle_material(opts.get("smoke", false))
	p.draw_pass_1 = quad
	p.visibility_aabb = AABB(Vector3(-8, -8, -8), Vector3(16, 16, 16))
	return p


## A one-time explosion of particles at a position.
static func burst(from: Node, pos: Vector3, color: Color, amount := 24, speed := 5.0,
		size := 0.3, lifetime := 0.6, opts := {}) -> void:
	var parent := world(from)
	if parent == null:
		return
	var o := opts.duplicate()
	o["speed_min"] = o.get("speed_min", speed * 0.4)
	o["speed_max"] = speed
	o["damping"] = o.get("damping", speed * 1.5)
	var p := particles(color, amount, lifetime, size, o)
	p.one_shot = true
	p.explosiveness = 0.95
	parent.add_child(p)
	p.global_position = pos
	p.emitting = true
	parent.get_tree().create_timer(lifetime + 0.5).timeout.connect(p.queue_free)


## Puff of smoke and sparks when a monster is defeated. No blood!
static func poof(from: Node, pos: Vector3, spark_color: Color, scale := 1.0) -> void:
	burst(from, pos, Color(0.35, 0.3, 0.4, 0.8), int(20 * scale), 2.5 * scale, 1.1 * scale, 1.2,
		{"smoke": true, "radius": 0.5 * scale, "gravity": Vector3(0, 1.5, 0)})
	burst(from, pos, spark_color * 2.0, int(30 * scale), 7.0 * scale, 0.22, 0.7,
		{"gravity": Vector3(0, -6, 0)})
	flash_light(from, pos, spark_color, 4.0 * scale, 6.0 * scale, 0.35)


static func flash_light(from: Node, pos: Vector3, color: Color, energy: float, light_range: float, time: float) -> void:
	var parent := world(from)
	if parent == null:
		return
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = energy
	l.omni_range = light_range
	parent.add_child(l)
	l.global_position = pos
	var tw := l.create_tween()
	tw.tween_property(l, "light_energy", 0.0, time)
	tw.tween_callback(l.queue_free)


## Text that floats up and fades, like "+100" or "FROZEN!".
static func float_text(from: Node, pos: Vector3, text: String, color: Color, font_size := 64) -> void:
	var parent := world(from)
	if parent == null:
		return
	var l := Label3D.new()
	l.text = text
	l.font_size = font_size
	l.outline_size = 14
	l.modulate = color
	l.outline_modulate = Color(0, 0, 0, 0.9)
	l.pixel_size = 0.01
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.render_priority = 5
	l.outline_render_priority = 4
	parent.add_child(l)
	l.global_position = pos
	var tw := l.create_tween().set_parallel(true)
	tw.tween_property(l, "global_position", pos + Vector3(0, 1.6, 0), 1.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(l, "modulate:a", 0.0, 0.5).set_delay(0.7)
	tw.tween_property(l, "outline_modulate:a", 0.0, 0.5).set_delay(0.7)
	tw.chain().tween_callback(l.queue_free)


## Coins that pop out and fly to a wizard.
static func coins(from: Node, pos: Vector3, count: int, target: Node3D) -> void:
	var parent := world(from)
	if parent == null:
		return
	if _coin_mesh == null:
		_coin_mesh = Build.cylinder(0.16, 0.05)
		_coin_mat = Build.glow(Color(1.0, 0.8, 0.2), 1.2)
		_coin_mat.metallic = 0.8
		_coin_mat.roughness = 0.3
	for i in count:
		var c := MeshInstance3D.new()
		c.mesh = _coin_mesh
		c.material_override = _coin_mat
		c.rotation_degrees = Vector3(90, randf() * 360.0, 0)
		parent.add_child(c)
		var start := pos + Vector3(0, 1.0, 0)
		c.global_position = start
		var up := start + Vector3(randf_range(-1.4, 1.4), randf_range(1.0, 2.4), randf_range(-1.4, 1.4))
		var tw := c.create_tween()
		tw.tween_property(c, "global_position", up, 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tw.tween_interval(0.05 * i)
		var fly := func(t: float) -> void:
			if is_instance_valid(target):
				c.global_position = up.lerp(target.global_position + Vector3(0, 1.2, 0), t)
			c.rotate_y(0.4)
		tw.tween_method(fly, 0.0, 1.0, 0.4).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		tw.tween_callback(c.queue_free)


static var _shield_shader: Shader

## See-through glowing bubble material (brighter at the edges).
static func bubble_material(color: Color, strength := 1.0) -> ShaderMaterial:
	if _shield_shader == null:
		_shield_shader = Shader.new()
		_shield_shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never, shadows_disabled;
uniform vec4 color : source_color = vec4(1.0);
uniform float strength = 1.0;
void fragment() {
	float rim = pow(1.0 - abs(dot(NORMAL, VIEW)), 2.5);
	float bands = 0.5 + 0.5 * sin(UV.y * 60.0 + TIME * 4.0);
	ALBEDO = color.rgb * (0.6 + rim * 2.0);
	ALPHA = clamp((0.12 + rim * 0.9 + bands * 0.04) * strength, 0.0, 1.0) * color.a;
}
"""
	var m := ShaderMaterial.new()
	m.shader = _shield_shader
	m.set_shader_parameter("color", color)
	m.set_shader_parameter("strength", strength)
	return m
