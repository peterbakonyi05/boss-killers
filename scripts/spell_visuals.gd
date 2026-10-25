class_name SpellVisuals
## How each spell looks while flying and when it hits. A projectile's `style`
## (from SpellData.strong_style / weak_style, or "acid"/"hellfire" for monsters)
## picks the builder. Flames and ice use small shaders, so nothing needs texture files.

static var _flame_shader: Shader
static var _ice_shader: Shader
static var _noise: NoiseTexture2D
static var _rock_mat: StandardMaterial3D
static var _scorch_tex: GradientTexture2D


## Swirling see-through fire (also used for acid and the fire pool).
static func flame_material(core: Color, edge: Color, speed := 2.0) -> ShaderMaterial:
	if _flame_shader == null:
		_noise = NoiseTexture2D.new()
		var n := FastNoiseLite.new()
		n.frequency = 0.02
		n.fractal_octaves = 3
		_noise.noise = n
		_noise.seamless = true
		_noise.width = 128
		_noise.height = 128
		_flame_shader = Shader.new()
		_flame_shader.code = """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled;
uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform vec4 core : source_color = vec4(1.0, 0.9, 0.5, 1.0);
uniform vec4 edge : source_color = vec4(1.0, 0.3, 0.05, 1.0);
uniform float speed = 2.0;
uniform float fade = 1.0;
void fragment() {
	vec2 uv = UV * vec2(2.0, 1.0);
	float n = texture(noise_tex, uv + vec2(TIME * 0.3, -TIME * speed * 0.5)).r;
	float n2 = texture(noise_tex, uv * 1.7 - vec2(TIME * 0.45, TIME * speed * 0.35)).r;
	float f = clamp(n * 0.7 + n2 * 0.7 - 0.2, 0.0, 1.0);
	float rim = 1.0 - abs(dot(NORMAL, VIEW));
	vec3 c = mix(core.rgb, edge.rgb, clamp(rim * 1.4 + (1.0 - f) * 0.6, 0.0, 1.0));
	ALBEDO = c * (1.2 + f * 2.0);
	ALPHA = clamp(f * 1.3 - rim * 0.7 + 0.35, 0.0, 1.0) * fade;
}
"""
	var m := ShaderMaterial.new()
	m.shader = _flame_shader
	m.set_shader_parameter("noise_tex", _noise)
	m.set_shader_parameter("core", core)
	m.set_shader_parameter("edge", edge)
	m.set_shader_parameter("speed", speed)
	return m


## Faceted, glassy ice that sparkles at the edges.
static func ice_material(color: Color, glow := 0.6) -> ShaderMaterial:
	if _ice_shader == null:
		_ice_shader = Shader.new()
		_ice_shader.code = """
shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, specular_schlick_ggx;
uniform vec4 color : source_color = vec4(0.6, 0.9, 1.0, 1.0);
uniform float glow = 0.6;
uniform float fade = 1.0;
void fragment() {
	// Flat normals from screen-space derivatives: every face is a clean facet.
	vec3 n = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	NORMAL = n;
	float rim = pow(1.0 - abs(dot(n, VIEW)), 2.0);
	ALBEDO = color.rgb * 0.6;
	ROUGHNESS = 0.05;
	SPECULAR = 0.9;
	EMISSION = color.rgb * glow + vec3(0.8, 0.95, 1.0) * rim * 2.5;
	ALPHA = clamp(0.55 + rim * 0.45, 0.0, 1.0) * fade;
}
"""
	var m := ShaderMaterial.new()
	m.shader = _ice_shader
	m.set_shader_parameter("color", color)
	m.set_shader_parameter("glow", glow)
	return m


static func _crystal(radius: float, length: float, sides := 6) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.radial_segments = sides
	m.rings = 1
	m.top_radius = 0.0
	m.bottom_radius = radius
	m.height = length
	return m


static func _gem(radius: float) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	m.radial_segments = 7
	m.rings = 4
	return m


## A part pointing forward (−Z, where the projectile flies).
static func _forward(parent: Node3D, mesh: Mesh, mat: Material, pos := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := Build.part(parent, mesh, mat, pos, Vector3(-90, 0, 0), scl)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func _trail(p: Projectile, color: Color, amount: int, life: float, size: float, opts := {}) -> GPUParticles3D:
	var t := FX.particles(color, amount, life, size, opts)
	t.local_coords = false
	p.add_child(t)
	t.emitting = true
	return t


## Builds the flying look of p. Sets p.visual_core (the part that spins / spirals).
static func build(p: Projectile) -> void:
	var r := p.radius
	var c := p.color
	var core := Node3D.new()
	p.add_child(core)
	p.visual_core = core
	match p.style:
		"fireball":
			Build.part(core, Build.sphere(r * 0.55), Build.glow(Color(1.0, 0.9, 0.6), 6.0))
			Build.part(core, Build.sphere(r * 1.15), flame_material(Color(1.0, 0.85, 0.4), c, 2.5))
			_trail(p, c * 2.0, 28, 0.45, r * 2.0, {"speed_min": 0.3, "speed_max": 1.2, "radius": r * 0.6, "gravity": Vector3(0, 2.5, 0)})
			_trail(p, Color(0.15, 0.1, 0.1, 0.5), 14, 0.9, r * 2.4, {"smoke": true, "speed_min": 0.2, "speed_max": 0.6, "radius": r * 0.5, "gravity": Vector3(0, 1.5, 0)})
			p.visual_spin = 6.0
		"ember_dart", "twin_flame":
			_forward(core, Build.sphere(r), flame_material(Color(1.0, 0.9, 0.5), c, 4.0), Vector3.ZERO, Vector3(0.8, 2.6, 0.8))
			Build.part(core, Build.sphere(r * 0.5), Build.glow(Color(1.0, 0.85, 0.5), 6.0))
			_trail(p, c * 2.0, 18, 0.3, r * 1.6, {"speed_min": 0.0, "speed_max": 0.3, "radius": r * 0.3, "gravity": Vector3(0, 1.5, 0)})
			if p.style == "twin_flame":
				p.visual_spiral = 0.25
				p.visual_spin = 14.0
		"meteor":
			if _rock_mat == null:
				_rock_mat = Build.pbr("dark_rock", Color(0.6, 0.45, 0.4), 2.0, true).duplicate()
				_rock_mat.emission_enabled = true
				_rock_mat.emission = Color(1.0, 0.3, 0.05)
				_rock_mat.emission_energy_multiplier = 0.8
			Build.part(core, _gem(r * 0.8), _rock_mat)
			Build.part(core, Build.sphere(r * 1.3), flame_material(Color(1.0, 0.8, 0.3), c, 5.0))
			_trail(p, c * 2.0, 40, 0.5, r * 2.2, {"speed_min": 0.5, "speed_max": 2.0, "radius": r * 0.7})
			_trail(p, Color(0.12, 0.08, 0.08, 0.6), 24, 1.4, r * 3.0, {"smoke": true, "speed_min": 0.2, "speed_max": 0.8, "radius": r * 0.6, "gravity": Vector3(0, 0.8, 0)})
			p.visual_spin = 4.0
		"ice_comet":
			Build.part(core, _gem(r), ice_material(c, 0.8))
			Build.part(core, Build.sphere(r * 0.45), Build.glow(Color(0.85, 0.97, 1.0), 4.0))
			for k in 4:
				var spike := Build.pivot(core)
				spike.rotation = Vector3(randf() * TAU, randf() * TAU, 0)
				Build.part(spike, _crystal(r * 0.3, r * 1.6), ice_material(c, 0.8), Vector3(0, r * 0.8, 0))
			_trail(p, Color(0.9, 0.97, 1.0, 0.9), 26, 0.8, r * 0.6, {"speed_min": 0.2, "speed_max": 0.8, "radius": r * 0.6, "gravity": Vector3(0, -3.0, 0)})
			_trail(p, Color(0.7, 0.9, 1.0, 0.35), 12, 0.7, r * 2.5, {"smoke": true, "speed_min": 0.1, "speed_max": 0.4, "radius": r * 0.4})
			p.visual_spin = 3.0
		"frost_shard", "twin_icicle":
			var length := r * (5.0 if p.style == "twin_icicle" else 4.0)
			_forward(core, _crystal(r * 0.75, length, 5), ice_material(c.lightened(0.2), 1.0), Vector3(0, 0, -length * 0.2))
			_forward(core, _crystal(r * 0.75, length * 0.35, 5), ice_material(c.lightened(0.2), 1.0), Vector3(0, 0, length * 0.42), Vector3(1, -1, 1))
			_trail(p, Color(0.85, 0.97, 1.0, 0.8), 12, 0.35, r * 0.7, {"speed_min": 0.0, "speed_max": 0.3, "radius": r * 0.4})
			p.visual_spin = 12.0
			if p.style == "twin_icicle":
				p.visual_spiral = 0.22
		"glacier_spear":
			var length := r * 6.0
			_forward(core, _crystal(r * 0.55, length, 6), ice_material(c, 0.9), Vector3(0, 0, -length * 0.25))
			var shaft := CylinderMesh.new()
			shaft.radial_segments = 6
			shaft.rings = 1
			shaft.top_radius = r * 0.35
			shaft.bottom_radius = r * 0.2
			shaft.height = length * 0.8
			_forward(core, shaft, ice_material(c, 0.6), Vector3(0, 0, length * 0.4))
			for k in 3:
				var fin := Build.pivot(core, Vector3(0, 0, length * 0.65))
				fin.rotation.z = k * TAU / 3.0
				Build.part(fin, _crystal(r * 0.25, r * 1.6, 4), ice_material(c, 0.9), Vector3(0, r * 0.6, 0), Vector3(30, 0, 0))
			_trail(p, Color(0.8, 0.95, 1.0, 0.8), 30, 0.6, r * 0.8, {"speed_min": 0.3, "speed_max": 1.2, "radius": r * 0.4, "gravity": Vector3(0, -2.0, 0)})
			p.visual_spin = 2.0
		"acid":
			Build.part(core, Build.sphere(r), Build.glow(c, 3.0))
			Build.part(core, Build.sphere(r * 1.4), flame_material(c.lightened(0.4), c.darkened(0.3), 1.5))
			_trail(p, c * 1.5, 14, 0.6, r * 0.8, {"speed_min": 0.0, "speed_max": 0.4, "radius": r * 0.5, "gravity": Vector3(0, -6.0, 0)})
			p.visual_spin = 5.0
		"hellfire":
			Build.part(core, Build.sphere(r * 0.6), Build.glow(Color(1.0, 0.5, 0.2), 5.0))
			Build.part(core, Build.sphere(r * 1.3), flame_material(Color(1.0, 0.35, 0.1), Color(0.5, 0.0, 0.05), 3.0))
			_trail(p, c * 2.0, 18, 0.4, r * 1.8, {"speed_min": 0.2, "speed_max": 0.8, "radius": r * 0.5, "gravity": Vector3(0, 2.0, 0)})
			_trail(p, Color(0.08, 0.02, 0.02, 0.6), 10, 0.8, r * 2.0, {"smoke": true, "speed_min": 0.1, "speed_max": 0.5, "radius": r * 0.4})
		_:
			Build.part(core, Build.sphere(r), Build.glow(c, 4.0))
			_trail(p, c * 1.8, 12, 0.35, r * 2.0, {"speed_min": 0.2, "speed_max": 1.0, "radius": r * 0.6})
	for gi in p.find_children("*", "GeometryInstance3D", true, false):
		(gi as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Build.light(p, c, 1.6 if p.strong else 0.8, 4.5 if p.strong else 2.5)


static func _is_ice(style: String) -> bool:
	return style in ["ice_comet", "frost_shard", "twin_icicle", "glacier_spear"]


## The hit effect where p ends. big = strong player spell.
static func impact(p: Projectile, pos: Vector3, big: bool) -> void:
	var c := p.color
	var r := p.radius
	if _is_ice(p.style):
		_shatter(p, pos, c, 10 if big else 4, r)
		FX.burst(p, pos, Color(0.85, 0.97, 1.0, 0.9), 24 if big else 8, 5.0 if big else 2.5, r * 0.8, 0.6, {"gravity": Vector3(0, -6, 0)})
		if big:
			_ring(p, pos, c, 2.4, 0.35)
			FX.burst(p, pos, Color(0.75, 0.9, 1.0, 0.45), 14, 2.0, 1.4, 1.0, {"smoke": true})
	elif p.style == "acid":
		FX.burst(p, pos, c * 1.5, 16, 3.0, r * 0.8, 0.6, {"gravity": Vector3(0, -8, 0)})
		FX.burst(p, pos, Color(0.3, 0.5, 0.1, 0.5), 6, 1.0, 0.8, 0.8, {"smoke": true})
	else:
		FX.burst(p, pos, c * 2.0, 30 if big else 10, 6.0 if big else 3.0, r * 1.4, 0.45)
		_puff(p, pos, c, r * (3.5 if big else 1.8))
		if big:
			FX.burst(p, pos, Color(0.15, 0.1, 0.1, 0.6), 14, 2.0, 1.6, 1.4, {"smoke": true, "gravity": Vector3(0, 1.5, 0)})
			_ring(p, pos, c, 3.0 if p.style == "meteor" else 2.0, 0.3)
			scorch(p, pos, r * (5.0 if p.style == "meteor" else 3.0))
		if p.style == "meteor":
			_debris(p, pos)
	if big:
		FX.flash_light(p, pos, c, 5.0, 7.0, 0.35)


## A quick ball of fire that grows and fades.
static func _puff(from: Node, pos: Vector3, c: Color, size: float) -> void:
	var parent := FX.world(from)
	if parent == null:
		return
	var m := flame_material(Color(1.0, 0.85, 0.4), c, 4.0)
	var mi := MeshInstance3D.new()
	mi.mesh = Build.sphere(1.0)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = pos
	mi.scale = Vector3.ONE * size * 0.3
	var tw := mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * size, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_method(func(v: float) -> void: m.set_shader_parameter("fade", v), 1.0, 0.0, 0.35)
	tw.chain().tween_callback(mi.queue_free)


## A flat shockwave ring on the ground.
static func _ring(from: Node, pos: Vector3, c: Color, size: float, time: float) -> void:
	var parent := FX.world(from)
	if parent == null:
		return
	var m := Build.glow(c, 3.0)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var mi := MeshInstance3D.new()
	mi.mesh = Build.torus(0.85, 1.0)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = pos
	mi.scale = Vector3(0.2, 0.3, 0.2)
	var tw := mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(size, 0.3, size), time).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "albedo_color:a", 0.0, time)
	tw.chain().tween_callback(mi.queue_free)


## Ice pieces that fly apart and fall.
static func _shatter(from: Node, pos: Vector3, c: Color, count: int, r: float) -> void:
	var parent := FX.world(from)
	if parent == null:
		return
	var m := ice_material(c.lightened(0.2), 1.0)
	for i in count:
		var mi := MeshInstance3D.new()
		mi.mesh = _crystal(r * 0.4, r * randf_range(1.0, 2.0), 4)
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mi)
		mi.global_position = pos
		mi.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
		var vel := Vector3(randf_range(-1, 1), randf_range(0.5, 1.5), randf_range(-1, 1)) * 4.0
		var fly := func(t: float) -> void:
			mi.global_position = pos + vel * t + Vector3(0, -9.0, 0) * t * t * 0.5
			mi.rotate_x(0.2)
			mi.scale = Vector3.ONE * (1.0 - t * 0.9)
		var tw := mi.create_tween()
		tw.tween_method(fly, 0.0, 0.7, 0.7)
		tw.tween_callback(mi.queue_free)


## Glowing rocks thrown out by a meteor.
static func _debris(from: Node, pos: Vector3) -> void:
	var parent := FX.world(from)
	if parent == null or _rock_mat == null:
		return
	for i in 8:
		var mi := MeshInstance3D.new()
		mi.mesh = _gem(randf_range(0.08, 0.18))
		mi.material_override = _rock_mat
		parent.add_child(mi)
		var vel := Vector3(randf_range(-1, 1), randf_range(0.8, 1.6), randf_range(-1, 1)) * 5.0
		var fly := func(t: float) -> void:
			mi.global_position = pos + vel * t + Vector3(0, -12.0, 0) * t * t * 0.5
		var tw := mi.create_tween()
		tw.tween_method(fly, 0.0, 0.9, 0.9)
		tw.tween_callback(mi.queue_free)


## A dark burn mark on the floor that fades away.
static func scorch(from: Node, pos: Vector3, size: float) -> void:
	var parent := FX.world(from)
	if parent == null:
		return
	if _scorch_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(0.02, 0.01, 0.01, 0.85))
		g.set_color(1, Color(0.02, 0.01, 0.01, 0.0))
		_scorch_tex = GradientTexture2D.new()
		_scorch_tex.gradient = g
		_scorch_tex.fill = GradientTexture2D.FILL_RADIAL
		_scorch_tex.fill_from = Vector2(0.5, 0.5)
		_scorch_tex.fill_to = Vector2(0.5, 0.0)
	var d := Decal.new()
	d.texture_albedo = _scorch_tex
	d.size = Vector3(size, 2.0, size)
	d.cull_mask = 1
	parent.add_child(d)
	d.global_position = pos
	d.rotation.y = randf() * TAU
	var tw := d.create_tween()
	tw.tween_interval(3.0)
	tw.tween_property(d, "modulate:a", 0.0, 1.5)
	tw.tween_callback(d.queue_free)


## Small ice spikes left on the ground behind a glacier spear.
static func ice_spikes(from: Node, pos: Vector3, c: Color) -> void:
	var parent := FX.world(from)
	if parent == null:
		return
	var root := Node3D.new()
	parent.add_child(root)
	root.global_position = pos
	var m := ice_material(c, 0.7)
	for i in 3:
		var h := randf_range(0.3, 0.7)
		var mi := Build.part(root, _crystal(h * 0.25, h, 5), m, Vector3(randf_range(-0.3, 0.3), h * 0.4, randf_range(-0.3, 0.3)),
			Vector3(randf_range(-25, 25), randf() * 360.0, randf_range(-25, 25)))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.scale = Vector3(1, 0.05, 1)
	var tw := root.create_tween()
	tw.tween_property(root, "scale", Vector3.ONE, 0.15).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.2)
	tw.tween_property(root, "scale", Vector3(1, 0.05, 1), 0.4)
	tw.tween_callback(root.queue_free)
