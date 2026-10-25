class_name Build
## Helpers that build simple models out of Godot shapes (spheres, boxes, cones...),
## plus real textures (assets/textures/) and models (assets/models/), see assets/CREDITS.md.

static var _pbr_cache := {}
static var _model_cache := {}


## A realistic material from a texture folder in assets/textures/<id>/
## (albedo, normal, roughness). uv_scale = repeats per meter. Falls back to a flat
## color when the folder does not exist, so a theme with a typo still works.
static func pbr(id: String, tint := Color.WHITE, uv_scale := 0.25, triplanar := true,
		normal_strength := 1.2) -> StandardMaterial3D:
	var key := "%s|%s|%s|%s|%s" % [id, tint, uv_scale, triplanar, normal_strength]
	if _pbr_cache.has(key):
		return _pbr_cache[key]
	var dir := "res://assets/textures/%s/" % id
	var m := StandardMaterial3D.new()
	m.albedo_color = tint
	if id != "" and ResourceLoader.exists(dir + "albedo.jpg"):
		m.albedo_texture = load(dir + "albedo.jpg")
		m.normal_enabled = true
		m.normal_texture = load(dir + "normal.jpg")
		m.normal_scale = normal_strength
		m.roughness_texture = load(dir + "roughness.jpg")
		m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
		m.roughness = 1.0
		m.uv1_scale = Vector3.ONE * uv_scale
		m.uv1_triplanar = triplanar
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	else:
		m.albedo_color = tint * Color(0.5, 0.45, 0.42)
		m.roughness = 0.9
	_pbr_cache[key] = m
	return m


## The scene of a model in assets/models/<id>/<id>.gltf (null if missing).
static func model_scene(id: String) -> PackedScene:
	if not _model_cache.has(id):
		var path := "res://assets/models/%s/%s.gltf" % [id, id]
		_model_cache[id] = load(path) if ResourceLoader.exists(path) else null
	return _model_cache[id]


## Adds a model to parent. With `piece`, only that one mesh of a model set is added
## (e.g. one rock of "rock_moss_set_01"), moved so its bottom middle sits at pos.
static func model(parent: Node3D, id: String, pos := Vector3.ZERO, rot_deg := Vector3.ZERO,
		scl := 1.0, piece := "") -> Node3D:
	var ps := model_scene(id)
	if ps == null:
		return null
	var holder := Node3D.new()
	holder.position = pos
	holder.rotation_degrees = rot_deg
	holder.scale = Vector3.ONE * scl
	parent.add_child(holder)
	var inst := ps.instantiate() as Node3D
	if piece == "":
		holder.add_child(inst)
	else:
		var mi := inst.find_child(piece, true, false) as MeshInstance3D
		if mi:
			var copy := MeshInstance3D.new()
			copy.mesh = mi.mesh
			var aabb := mi.mesh.get_aabb()
			copy.position = -Vector3(aabb.get_center().x, aabb.position.y, aabb.get_center().z)
			holder.add_child(copy)
		inst.free()
	for mi in holder.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return holder


static func mat(color: Color, roughness := 0.8, metallic := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	return m


## A material that glows (works great with the glow effect in the dark caves).
static func glow(color: Color, energy := 2.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m


static func see_through(color: Color, energy := 0.5) -> StandardMaterial3D:
	var m := glow(color, energy)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.15
	m.metallic_specular = 1.0
	return m


## Glowing, swirly lava (move uv1_offset every frame to make it flow).
static func lava_material() -> StandardMaterial3D:
	var noise := FastNoiseLite.new()
	noise.frequency = 0.04
	var tex := NoiseTexture2D.new()
	tex.noise = noise
	tex.seamless = true
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.5, 0.05, 0.0))
	ramp.set_color(1, Color(1.0, 0.75, 0.2))
	tex.color_ramp = ramp
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.emission_enabled = true
	m.emission_texture = tex
	# Tinted orange so bright spots stay lava-colored instead of turning white.
	m.albedo_color = Color(1.0, 0.55, 0.3)
	m.emission = Color(1.0, 0.45, 0.12)
	m.emission_energy_multiplier = 1.6
	m.uv1_scale = Vector3(2, 2, 2)
	return m


## Dark, murky jungle water with slow ripples (move uv1_offset every frame).
static func water_material() -> StandardMaterial3D:
	var noise := FastNoiseLite.new()
	noise.frequency = 0.05
	var tex := NoiseTexture2D.new()
	tex.noise = noise
	tex.seamless = true
	tex.as_normal_map = true
	tex.bump_strength = 4.0
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.05, 0.13, 0.1, 0.92)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.08
	m.metallic_specular = 0.9
	m.normal_enabled = true
	m.normal_texture = tex
	m.normal_scale = 0.6
	m.emission_enabled = true
	m.emission = Color(0.04, 0.12, 0.08)
	m.emission_energy_multiplier = 0.5
	m.uv1_scale = Vector3(2, 2, 2)
	return m


static func sphere(radius: float) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	m.radial_segments = 24
	m.rings = 12
	return m


static func box(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m


static func capsule(radius: float, height: float) -> CapsuleMesh:
	var m := CapsuleMesh.new()
	m.radius = radius
	m.height = height
	return m


static func cylinder(radius: float, height: float, top_radius := -1.0) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.bottom_radius = radius
	m.top_radius = radius if top_radius < 0.0 else top_radius
	m.height = height
	m.radial_segments = 20
	return m


static func cone(radius: float, height: float) -> CylinderMesh:
	return cylinder(radius, height, 0.0)


static func torus(inner: float, outer: float) -> TorusMesh:
	var m := TorusMesh.new()
	m.inner_radius = inner
	m.outer_radius = outer
	m.rings = 32
	m.ring_segments = 12
	return m


## Adds a mesh to parent and returns it.
static func part(parent: Node3D, mesh: Mesh, material: Material, pos := Vector3.ZERO,
		rot_deg := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.scale = scl
	parent.add_child(mi)
	return mi


static func pivot(parent: Node3D, pos := Vector3.ZERO) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	return n


static func light(parent: Node3D, color: Color, energy: float, light_range: float,
		pos := Vector3.ZERO, shadows := false) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = energy
	l.omni_range = light_range
	l.position = pos
	l.shadow_enabled = shadows
	parent.add_child(l)
	return l


static func collision_box(parent: Node, size: Vector3, pos := Vector3.ZERO) -> CollisionShape3D:
	var shape := BoxShape3D.new()
	shape.size = size
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = pos
	parent.add_child(cs)
	return cs


static func collision_capsule(parent: Node, radius: float, height: float, pos := Vector3.ZERO) -> CollisionShape3D:
	var shape := CapsuleShape3D.new()
	shape.radius = radius
	shape.height = height
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = pos
	parent.add_child(cs)
	return cs


static func collision_sphere(parent: Node, radius: float, pos := Vector3.ZERO) -> CollisionShape3D:
	var shape := SphereShape3D.new()
	shape.radius = radius
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = pos
	parent.add_child(cs)
	return cs


static func label3d(parent: Node3D, text: String, pos: Vector3, font_size := 48,
		color := Color.WHITE) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.position = pos
	l.font_size = font_size
	l.outline_size = 12
	l.modulate = color
	l.outline_modulate = Color(0, 0, 0, 0.9)
	l.pixel_size = 0.01
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(l)
	return l
